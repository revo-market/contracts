//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "./IMoolaStakingRewards.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./IRevoFees.sol";
import "./openzeppelin-solidity/contracts/ERC20.sol";
import "./openzeppelin-solidity/contracts/AccessControl.sol";
import "./openzeppelin-solidity/contracts/SafeERC20.sol";
import "./openzeppelin-solidity/contracts/Pausable.sol";

contract UbeswapFarmBot is ERC20, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    event FeesUpdated(address indexed by, address indexed to);
    event RouterUpdated(address indexed by, address indexed routerAddress);
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
        uint256 compounderFeeAmount,
        uint256 reserveFeeAmount
    );
    event GrantRole(
        address indexed by,
        address indexed newRoleRecipient,
        bytes32 role
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
        address _owner,
        address _reserveAddress,
        address _stakingRewards,
        address _stakingToken,
        address _revoFees,
        address _router,
        address[] memory _rewardsTokens,
        string memory _symbol
    ) ERC20("Revo FP Token", _symbol) {
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

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        emit GrantRole(msg.sender, _owner, DEFAULT_ADMIN_ROLE);
    }

    function grantRole(bytes32 role, address account)
        public
        virtual
        override
        onlyRole(getRoleAdmin(role))
    {
        super.grantRole(role, account);
        emit GrantRole(msg.sender, account, role);
    }

    function updateRouterAddress(address _router)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        router = IUniswapV2Router02(_router);
        emit RouterUpdated(msg.sender, _router);
    }

    function updateReserveAddress(address _reserveAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _reserveAddress != address(0),
            "Cannot set reserve address to 0"
        );
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

    function deposit(uint256 _lpAmount) external whenNotPaused {
        bool transferSuccess = stakingToken.transferFrom(
            msg.sender,
            address(this),
            _lpAmount
        );
        require(transferSuccess, "Transfer failed, aborting deposit");

        uint256 _fpAmount = this.getFpAmount(_lpAmount);
        _mint(msg.sender, _fpAmount);
        lpTotalBalance += _lpAmount;
        _investInFarm(_lpAmount);
        emit Deposit(msg.sender, _lpAmount);
    }

    function withdrawAll() external {
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

    function _investInFarm(uint256 _lpAmount) private {
        require(_lpAmount > 0, "Cannot invest in farm because _lpAmount is 0");
        stakingToken.approve(address(stakingRewards), _lpAmount);
        stakingRewards.stake(_lpAmount);
    }

    /**
     * Swap a rewards token for a token in the liquidity pool.
     *
     * @param _swapPath: path for the swap. Must start with _startToken and end with the desired token
     * @param _startTokenBudget: amount of _startToken to swap
     * @param _startToken: token to spend
     * @param _minAmountOut: minimum amount of the desired token (revert if the swap yields less)
     * @param _deadline: deadline for the swap
     */
    function _swapForTokenInPool(
        address[] memory _swapPath,
        uint256 _startTokenBudget,
        IERC20 _startToken,
        uint256 _minAmountOut,
        uint256 _deadline
    ) private returns (uint256) {
        if (_swapPath.length >= 2 && _startTokenBudget > 0) {
            _startToken.safeApprove(address(router), _startTokenBudget);
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

    function _addLiquidity(
        uint256[] memory _tokenBalances,
        address[][2][] memory _paths,
        uint256[2][] memory _minAmountsOut,
        uint256 _deadline
    ) private {
        uint256 _totalAmountToken0 = 0;
        uint256 _totalAmountToken1 = 0;
        for (uint256 i = 0; i < _tokenBalances.length; i++) {
            uint256 _halfTokens = _tokenBalances[i] / 2;
            _totalAmountToken0 += _swapForTokenInPool(
                _paths[i][0],
                _halfTokens,
                rewardsTokens[i],
                _minAmountsOut[i][0],
                _deadline
            );
            _totalAmountToken1 += _swapForTokenInPool(
                _paths[i][1],
                _halfTokens,
                rewardsTokens[i],
                _minAmountsOut[i][1],
                _deadline
            );
        }

        // Approve the router to spend the bot's token0/token1
        stakingToken0.safeApprove(address(router), _totalAmountToken0);
        stakingToken1.safeApprove(address(router), _totalAmountToken1);

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
    ) external ensure(_deadline) onlyRole(COMPOUNDER_ROLE) whenNotPaused {
        require(
            _paths.length == rewardsTokens.length,
            "Parameter _paths must have length equal to rewardsTokens"
        );
        require(
            _minAmountsOut.length == rewardsTokens.length,
            "Parameter _minAmountsOut must have length equal to rewardsTokens"
        );

        stakingRewards.getReward();

        uint256[] memory _tokenBalances = new uint256[](rewardsTokens.length);
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            _tokenBalances[i] = rewardsTokens[i].balanceOf(address(this));
        }

        // Perform swaps and add liquidity
        _addLiquidity(_tokenBalances, _paths, _minAmountsOut, _deadline);

        // send fees to compounder and reserve
        uint256 lpBalance = stakingToken.balanceOf(address(this));
        uint256 compounderFee = revoFees.compounderFee(lpBalance);
        uint256 reserveFee = revoFees.reserveFee(lpBalance);
        require(
            compounderFee + reserveFee <=
                (lpBalance * maxPerformanceFeeNumerator) /
                    maxPerformanceFeeDenominator,
            "Performance fee too high"
        );
        bool compounderFeeSuccess = stakingToken.transfer(
            msg.sender,
            compounderFee
        );
        bool reserveFeeSuccess = stakingToken.transfer(
            reserveAddress,
            reserveFee
        );
        require(
            compounderFeeSuccess && reserveFeeSuccess,
            "Sending fees failed"
        );

        // reinvest LPs and adjust FP weight
        uint256 lpEarnings = lpBalance - compounderFee - reserveFee;
        _investInFarm(lpEarnings);
        lpTotalBalance += lpEarnings;

        // update interest rate
        interestEarnedNumerator =
            (lpEarnings * interestEarnedDenominator) /
            lpTotalBalance;

        revoFees.issueCompounderBonus(msg.sender);
        emit Compound(
            msg.sender,
            lpEarnings,
            lpTotalBalance,
            compounderFee,
            reserveFee
        );
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();

        uint256 lpBalance = stakingToken.balanceOf(address(this));
        if (lpBalance > 0) {
            _investInFarm(lpBalance);
        }
    }
}
