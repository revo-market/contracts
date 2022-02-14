//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./IMoolaStakingRewards.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./IRevoFees.sol";
import "./openzeppelin-solidity/contracts/ERC20.sol";
import "./openzeppelin-solidity/contracts/AccessControl.sol";
import "./openzeppelin-solidity/contracts/SafeERC20.sol";

contract UbeswapFarmBot is ERC20, AccessControl {
    using SafeERC20 for IERC20;

    event FeesUpdated(address indexed by, address indexed to);
    event ReserveUpdated(address indexed by, address indexed reserveAddress);
    event SlippageUpdated(
        address indexed by,
        uint256 numerator,
        uint256 denominator
    );
    event Deposit(address indexed by, uint256 lpAmount);
    event Withdraw(address indexed by, uint256 lpAmount, uint256 fee);
    event Compound(
        address indexed by,
        uint256 lpStaked,
        uint256 newLPTotalBalance,
        uint256[] compounderFeeAmounts,
        uint256[] reserveFeeAmounts
    );

    bytes32 public constant COMPOUNDER_ROLE = keccak256("COMPOUNDER_ROLE");

    uint256 public lpTotalBalance; // total number of LP tokens owned by Farm Bot

    // fractional increase of LP balance last time compound was called. Used to calculate withdrawal fee.
    uint256 public interestEarnedNumerator;
    uint256 public interestEarnedDenominator = 10000;

    IMoolaStakingRewards public stakingRewards;

    // List of rewards tokens. The first token in this list is assumed to be the primary token;
    // the rest correspond to the staking reward contract's external reward tokens. The order of these tokens
    // is very important; the first must correspond to the MoolaStakingRewards contract's "native" reward token,
    // and the rest must correspond to its "external" tokens, in the same order as they appear in the contract.
    IERC20[] public rewardsTokens;

    IUniswapV2Pair public stakingToken; // LP that's being staked
    IERC20 public stakingToken0; // LP token0
    IERC20 public stakingToken1; // LP token1

    IUniswapV2Router02 public router; // Router address

    // Acceptable slippage when minting LP; can be updated by admin
    uint256 public slippageNumerator = 99;
    uint256 public slippageDenominator = 100;

    // Configurable fees contract. Determines:
    //  - "compounder fee" for calling compound on behalf of farm investors.
    //  - "reserve fee" sent to reserve
    //  - "compounder bonus" (paid by reserve) for calling compound
    //  - "withdrawal fee" for withdrawing (necessary for security, guaranteed <= 0.25%)
    //  Note that compounder fees + reserve fees are "performance fees", meaning they are charged only on earnings.
    //  Performance fees are guaranteed to be at most 4%, the current standard, and should be much less.
    IRevoFees public revoFees;
    uint256 public maxPerformanceFeeNumerator = 40;
    uint256 public maxPerformanceFeeDenominator = 1000;
    uint256 public maxWithdrawalFeeNumerator = 25;
    uint256 public maxWithdrawalFeeDenominator = 10000;

    address public reserveAddress;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "FarmBot: EXPIRED");
        _;
    }

    constructor(
        address _reserveAddress,
        address _stakingRewards,
        address _stakingToken,
        address _revoFees,
        address _router,
        address[] memory _rewardsTokens,
        string memory _symbol
    ) ERC20("FarmBot FP Token", _symbol) {
        stakingRewards = IMoolaStakingRewards(_stakingRewards);

        for (uint256 i = 0; i < _rewardsTokens.length; i++) {
            rewardsTokens.push(IERC20(_rewardsTokens[i]));
        }

        revoFees = IRevoFees(_revoFees);

        stakingToken = IUniswapV2Pair(_stakingToken);
        stakingToken0 = IERC20(stakingToken.token0());
        stakingToken1 = IERC20(stakingToken.token1());

        reserveAddress = _reserveAddress;

        router = IUniswapV2Router02(_router);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function updateReserveAddress(address _reserveAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        reserveAddress = _reserveAddress;
        emit ReserveUpdated(msg.sender, _reserveAddress);
    }

    function updateFees(address _revoFees)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revoFees = IRevoFees(_revoFees);
        emit FeesUpdated(msg.sender, _revoFees);
    }

    function updateSlippage(
        uint256 _slippageNumerator,
        uint256 _slippageDenominator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        slippageNumerator = _slippageNumerator;
        slippageDenominator = _slippageDenominator;
        emit SlippageUpdated(
            msg.sender,
            _slippageNumerator,
            _slippageDenominator
        );
    }

    function getFpAmount(uint256 _lpAmount) public view returns (uint256) {
        if (lpTotalBalance == 0) {
            return _lpAmount;
        } else {
            return (_lpAmount * totalSupply()) / lpTotalBalance;
        }
    }

    function getLpAmount(uint256 _fpAmount) public view returns (uint256) {
        if (totalSupply() == 0) {
            return 0;
        } else {
            return (_fpAmount * lpTotalBalance) / totalSupply();
        }
    }

    function deposit(uint256 _lpAmount) public {
        bool transferSuccess = stakingToken.transferFrom(
            msg.sender,
            address(this),
            _lpAmount
        );
        require(transferSuccess, "Transfer failed, aborting deposit");

        uint256 _fpAmount = this.getFpAmount(_lpAmount);
        _mint(msg.sender, _fpAmount);
        lpTotalBalance += _lpAmount;
        investInFarm();
        emit Deposit(msg.sender, _lpAmount);
    }

    function withdrawAll() public {
        require(balanceOf(msg.sender) > 0, "Cannot withdraw zero balance");
        uint256 _lpAmount = getLpAmount(balanceOf(msg.sender));
        withdraw(_lpAmount);
    }

    function withdraw(uint256 _lpAmount) public {
        uint256 _fpAmount = this.getFpAmount(_lpAmount);
        require(
            balanceOf(msg.sender) >= _fpAmount,
            "Cannot withdraw more than the total balance of the owner"
        );

        uint256 tokenBalance = stakingToken.balanceOf(address(this));
        if (_lpAmount > tokenBalance) {
            stakingRewards.withdraw(_lpAmount - tokenBalance);
        }

        // fee
        (uint256 feeNumerator, uint256 feeDenominator) = revoFees.withdrawalFee(
            interestEarnedNumerator,
            interestEarnedDenominator
        );
        uint256 _withdrawalFee = (feeNumerator * _lpAmount) / feeDenominator;
        uint256 _maxWithdrawalFee = (maxPerformanceFeeNumerator * _lpAmount) /
            maxPerformanceFeeDenominator;
        if (_withdrawalFee > _maxWithdrawalFee) {
            // guarantee the max fee
            _withdrawalFee = _maxWithdrawalFee;
        }

        bool feeSuccess = stakingToken.transfer(reserveAddress, _withdrawalFee);
        require(feeSuccess, "Fee failed, aborting withdrawal");
        bool transferSuccess = stakingToken.transfer(
            msg.sender,
            _lpAmount - _withdrawalFee
        );
        require(transferSuccess, "Transfer failed, aborting withdrawal");
        _burn(msg.sender, _fpAmount);
        lpTotalBalance -= _lpAmount;
        emit Withdraw(msg.sender, _lpAmount, _withdrawalFee);
    }

    function investInFarm() private returns (uint256) {
        uint256 tokenBalance = stakingToken.balanceOf(address(this));
        require(
            tokenBalance > 0,
            "Cannot invest in farm because tokenBalance is 0"
        );
        stakingToken.approve(address(stakingRewards), tokenBalance);
        stakingRewards.stake(tokenBalance);
        return tokenBalance;
    }

    // Private method used to calculate what tokens would be available for reinvestment if compound were called
    // right now.
    // Annoyingly, the MoolaStakingRewards.earnedExternal method is not declared as a view, so we cannot declare this
    // method as a view itself.
    function calculateRewards() private returns (TokenAmount[] memory) {
        uint256[] memory _leftoverBalances = new uint256[](
            rewardsTokens.length
        );
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            _leftoverBalances[i] = rewardsTokens[i].balanceOf(address(this));
        }

        // The MoolaStakingRewards contract treats the "native" reward token as fundamentally
        // different than the "external" ones, so we have to query the earned balance separately
        uint256[] memory _interestEarned = new uint256[](rewardsTokens.length);
        _interestEarned[0] = stakingRewards.earned(address(this));

        uint256[] memory _externalEarned = stakingRewards.earnedExternal(
            address(this)
        );
        require(
            _externalEarned.length == rewardsTokens.length - 1,
            "Incorrect amount of external rewards tokens"
        );
        for (uint256 i = 0; i < _externalEarned.length; i++) {
            _interestEarned[i + 1] = _externalEarned[i];
        }

        TokenAmount[] memory _rewardsTokenBalances = new TokenAmount[](
            rewardsTokens.length
        );
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            _rewardsTokenBalances[i] = TokenAmount(
                rewardsTokens[i],
                _interestEarned[i] + _leftoverBalances[i]
            );
        }
        return _rewardsTokenBalances;
    }

    // convenience method for anyone considering calling compound (who may want to compare bounty to gas cost)
    function previewCompounderRewards()
        external
        returns (
            TokenAmount[] memory compounderFee,
            TokenAmount[] memory compounderBonus
        )
    {
        TokenAmount[] memory _rewardsTokenBalances = calculateRewards();

        compounderFee = revoFees.compounderFee(_rewardsTokenBalances);
        compounderBonus = revoFees.compounderBonus(_rewardsTokenBalances);
    }

    // Figure out best-case scenario amount of token we can get and swap
    function swapForTokenInPool(
        address[] memory _swapPath,
        uint256 _startTokenBudget,
        IERC20 _startToken,
        uint256 _minAmountOut,
        uint256 _deadline
    ) private returns (uint256) {
        if (_swapPath.length >= 2) {
            _startToken.approve(address(router), _startTokenBudget);
            uint256[] memory _swapResultAmounts = router
                .swapExactTokensForTokens(
                    _startTokenBudget,
                    _minAmountOut,
                    _swapPath,
                    address(this),
                    _deadline
                );
            return _swapResultAmounts[_swapResultAmounts.length - 1];
        } else {
            return _startTokenBudget;
        }
    }

    function addLiquidity(
        uint256[] memory _tokenBalances,
        uint256[] memory _compounderFee,
        uint256[] memory _reserveFee,
        address[][2][] memory _paths,
        uint256[2][] memory _minAmountsOut,
        uint256 _deadline
    ) private {
        uint256 _totalAmountToken0 = 0;
        uint256 _totalAmountToken1 = 0;
        for (uint256 i = 0; i < _compounderFee.length; i++) {
            uint256 _halfTokens = (_tokenBalances[i] -
                _compounderFee[i] -
                _reserveFee[i]) / 2;
            _totalAmountToken0 += swapForTokenInPool(
                _paths[i][0],
                _halfTokens,
                rewardsTokens[i],
                _minAmountsOut[i][0],
                _deadline
            );
            _totalAmountToken1 += swapForTokenInPool(
                _paths[i][1],
                _halfTokens,
                rewardsTokens[i],
                _minAmountsOut[i][1],
                _deadline
            );
        }

        // Approve the router to spend the bot's token0/token1
        stakingToken0.approve(address(router), _totalAmountToken0);
        stakingToken1.approve(address(router), _totalAmountToken1);
        // Actually add liquidity
        router.addLiquidity(
            address(stakingToken0),
            address(stakingToken1),
            _totalAmountToken0,
            _totalAmountToken1,
            (_totalAmountToken0 * slippageNumerator) / slippageDenominator,
            (_totalAmountToken1 * slippageNumerator) / slippageDenominator,
            address(this),
            _deadline
        );
    }

    /**
     * The _paths parameter represents a list of paths to use when swapping each rewards token to token0/token1 of the LP.
     *  Each top-level entry represents a pair of paths for each rewardsToken.
     *
     * Example:
     *  // string token names used in place of addresses for readability
     *  rewardsTokens = ['cUSD', 'Celo', 'UBE']
     *  stakingTokens = ['cEUR', 'MOO']
     *  paths = [
     *    [ // paths from cUSD to staking tokens
     *      ['cUSD', 'cEUR'], // order matters here (need first staking token first)
     *      ['cUSD', 'mcUSD', 'MOO']
     *    ],
     *    [ // paths from Celo to staking tokens
     *      ...
     *    ],
     *    [ // paths from UBE to staking tokens
     *      ...
     *    ]
     *  ]
     *
     * The _minAmountsOut parameter represents a list of minimum amounts for token0/token1 we expect to receive when swapping
     *  each rewardsToken. If we do not receive at least this much of token0/token1 for some swap, the transaction will revert.
     * If a path corresponding to some swap has length < 2, the minimum amount specified for that swap will be ignored.
     */
    function compound(
        address[][2][] memory _paths,
        uint256[2][] memory _minAmountsOut,
        uint256 _deadline
    ) public ensure(_deadline) onlyRole(COMPOUNDER_ROLE) {
        require(
            _paths.length == rewardsTokens.length,
            "Parameter _paths must have length equal to rewardsTokens"
        );
        require(
            _minAmountsOut.length == rewardsTokens.length,
            "Parameter _minAmountsOut must have length equal to rewardsTokens"
        );

        stakingRewards.getReward();

        // compute fees
        uint256[] memory _tokenBalances = new uint256[](rewardsTokens.length);
        uint256[] memory _compounderFeeAmounts = new uint256[](
            rewardsTokens.length
        );
        uint256[] memory _reserveFeeAmounts = new uint256[](
            rewardsTokens.length
        );

        {
            // block is to prevent 'stack too deep' compilation error.
            TokenAmount[] memory _interestAccrued = new TokenAmount[](
                rewardsTokens.length
            );
            for (uint256 i = 0; i < rewardsTokens.length; i++) {
                _tokenBalances[i] = rewardsTokens[i].balanceOf(address(this));
                _interestAccrued[i] = TokenAmount(
                    rewardsTokens[i],
                    _tokenBalances[i]
                );
            }

            TokenAmount[] memory _compounderFees = revoFees.compounderFee(
                _interestAccrued
            );
            TokenAmount[] memory _reserveFees = revoFees.reserveFee(
                _interestAccrued
            );
            require(
                _compounderFees.length == _reserveFees.length,
                "Got conflicting results from RevoFees"
            );
            for (uint256 i = 0; i < _compounderFees.length; i++) {
                _compounderFeeAmounts[i] = _compounderFees[i].amount;
                _reserveFeeAmounts[i] = _reserveFees[i].amount;
                require(
                    _compounderFeeAmounts[i] + _reserveFeeAmounts[i] <=
                        (maxPerformanceFeeNumerator * _tokenBalances[i]) /
                            maxPerformanceFeeDenominator,
                    "Performance fee too high"
                );
            }
        }

        // Perform swaps and add liquidity
        addLiquidity(
            _tokenBalances,
            _compounderFeeAmounts,
            _reserveFeeAmounts,
            _paths,
            _minAmountsOut,
            _deadline
        );

        // reinvest LPs and adjust FP weight
        uint256 lpBalance = investInFarm();
        lpTotalBalance += lpBalance;

        // update interest rate
        interestEarnedNumerator =
            (lpBalance * interestEarnedDenominator) /
            lpTotalBalance;

        // Send fees to compounder and reserve
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            rewardsTokens[i].safeTransfer(msg.sender, _compounderFeeAmounts[i]);
            rewardsTokens[i].safeTransfer(
                reserveAddress,
                _reserveFeeAmounts[i]
            );
        }
        revoFees.issueCompounderBonus(msg.sender);
        emit Compound(
            msg.sender,
            lpBalance,
            lpTotalBalance,
            _compounderFeeAmounts,
            _reserveFeeAmounts
        );
    }
}