//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "hardhat/console.sol";

import "./ubeswap-farming/contracts/Owned.sol";
import "./IMoolaStakingRewards.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./FarmbotERC20.sol";
import "./IRevoBounty.sol";


contract FarmBot is Owned, FarmbotERC20 {
    uint256 public lpTotalBalance; // total number of LP tokens owned by Farm Bot

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

    // Paths for swapping; can be updated by owner
    // Paths to use when swapping rewardsTokens for token0/token1. Each top-level entry represents a pair of paths for each rewardsToken.
    address[][2][] public paths;

    // Acceptable slippage when swapping/minting LP; can be updated by owner
    uint256 public slippageNumerator = 99;
    uint256 public slippageDenominator = 100;

    // Configurable bounty contract. Determines the bounty for calling claimRewards on behalf of farm investors.
    //      May issue external reward (e.g. a governance token), plus a small fee on interest earned by FP holders.
    //      Fees should be 0.1% and are guaranteed to be < 4%, the current standard for other protocols.
    IRevoBounty public revoBounty;
    uint256 public maxFeeNumerator = 40;
    uint256 public maxFeeDenominator = 1000;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'FarmBot: EXPIRED');
        _;
    }

    constructor(
        address _owner,
        address _stakingRewards,
	address _stakingToken,
        address _revoBounty,
        address _router,
	address[] memory _rewardsTokens,
	address[][2][] memory _paths,
        string memory _symbol
    ) Owned(_owner) {
        stakingRewards = IMoolaStakingRewards(_stakingRewards);

	for (uint i=0; i<_rewardsTokens.length; i++) {
	    rewardsTokens.push(IERC20(_rewardsTokens[i]));
	}

	require(
            _paths.length == _rewardsTokens.length,
	    "Parameters _paths and _rewardsTokens must have equal length"
	);
	paths = _paths;

        revoBounty = IRevoBounty(_revoBounty);

        stakingToken = IUniswapV2Pair(_stakingToken);
        stakingToken0 = IERC20(stakingToken.token0());
        stakingToken1 = IERC20(stakingToken.token1());


        symbol = _symbol;

        router = IUniswapV2Router02(_router);
    }

    function updateBounty(address _revoBounty) external onlyOwner {
        revoBounty = IRevoBounty(_revoBounty);
    }

    function updatePaths(address[][2][] memory _paths) external onlyOwner {
	paths = _paths;
    }

    function updateSlippage(uint256 _slippageNumerator, uint256 _slippageDenominator) external onlyOwner {
        slippageNumerator = _slippageNumerator;
        slippageDenominator = _slippageDenominator;
    }

    function getFpAmount(uint256 _lpAmount) public view returns (uint256) {
        if (lpTotalBalance == 0) {
            return _lpAmount;
        } else {
            return _lpAmount * totalSupply / lpTotalBalance;
        }
    }

    function getLpAmount(uint256 _fpAmount) public view returns (uint256) {
        if (totalSupply == 0) {
            return 0;
        } else {
            return _fpAmount * lpTotalBalance / totalSupply;
        }
    }

    function deposit(uint256 _lpAmount) public {
        bool transferSuccess = stakingToken.transferFrom(msg.sender, address(this), _lpAmount);
        require(transferSuccess, "Transfer failed, aborting deposit");

        uint256 _fpAmount = this.getFpAmount(_lpAmount);
        _mint(msg.sender, _fpAmount);
        lpTotalBalance += _lpAmount;
        investInFarm();
    }

    function withdrawAll() public {
        require(balanceOf[msg.sender] > 0, "Cannot withdraw zero balance");
        uint256 _lpAmount = getLpAmount(balanceOf[msg.sender]);
        withdraw(_lpAmount);
    }

    function withdraw(uint256 _lpAmount) public {
        // todo might need a lock on this
        uint256 _fpAmount = this.getFpAmount(_lpAmount);
        require(balanceOf[msg.sender] >= _fpAmount, "Cannot withdraw more than the total balance of the owner");

        uint256 tokenBalance = stakingToken.balanceOf(address(this));
        if (_lpAmount > tokenBalance) {
            stakingRewards.withdraw(_lpAmount - tokenBalance);
        }

        bool transferSuccess = stakingToken.transfer(msg.sender, _lpAmount);
        require(transferSuccess, "Transfer failed, aborting withdrawal");
        _burn(msg.sender, _fpAmount);
        lpTotalBalance -= _lpAmount;
    }

    function investInFarm() private {
        uint256 tokenBalance = stakingToken.balanceOf(address(this));
        require(tokenBalance > 0, "Cannot invest in farm because tokenBalance is 0");
        stakingToken.approve(address(stakingRewards), tokenBalance);
        stakingRewards.stake(tokenBalance);
    }

    // convenience method for anyone considering calling claimRewards (who may want to compare bounty to gas cost)
    // Annoyingly, the MoolaStakingRewards.earnedExternal method is not declared as a view, so we cannot declare this
    // method as a view itself.
    function previewBounty() external returns (TokenAmount[] memory) {
	uint[] memory _leftoverBalances = new uint[](rewardsTokens.length);
	for (uint i=0; i < rewardsTokens.length; i++) {
	    _leftoverBalances[i] = rewardsTokens[i].balanceOf(address(this));
	}

	// The MoolaStakingRewards contract treats the "native" reward token as fundamentally
	// different than the "external" ones, so we have to query the earned balance separately
	uint[] memory _interestEarned = new uint[](rewardsTokens.length);
	_interestEarned[0] = stakingRewards.earned(address(this));

	uint[] memory _externalEarned = stakingRewards.earnedExternal(address(this));
	require(_externalEarned.length == rewardsTokens.length - 1, "Incorrect amount of external rewards tokens");
	for (uint i=0; i < _externalEarned.length; i++) {
	    _interestEarned[i+1] = _externalEarned[i];
	}

        TokenAmount[] memory _rewardsTokenBalances = new TokenAmount[](rewardsTokens.length);
	for (uint i=0; i < rewardsTokens.length; i++) {
	    _rewardsTokenBalances[i] = TokenAmount(rewardsTokens[i], _interestEarned[i] + _leftoverBalances[i]);
	}

        return revoBounty.calculateFeeBounty(_rewardsTokenBalances);
    }

    // Figure out best-case scenario amount of token we can get and swap
    function swapForTokenInPool(address[] storage _swapPath, uint _startTokenBudget, IERC20 _startToken, uint _deadline) private returns (uint256) {
        if (_swapPath.length >= 2) {
            uint[] memory _expectedAmountsOut = router.getAmountsOut(_startTokenBudget, _swapPath);
            uint _expectedAmountOut = _expectedAmountsOut[_expectedAmountsOut.length - 1];
            _startToken.approve(address(router), _startTokenBudget);
            uint[] memory _swapResultAmounts = router.swapExactTokensForTokens(
                _startTokenBudget,
                _expectedAmountOut * slippageNumerator / slippageDenominator,
                _swapPath,
                address(this),
                _deadline
            );
            return _swapResultAmounts[_swapResultAmounts.length - 1];
        } else {
            return _startTokenBudget;
        }
    }

    function claimRewards(uint deadline) public ensure(deadline) {
        stakingRewards.getReward();

        // compute bounty for the caller
        uint256[] memory _tokenBalances = new uint256[](rewardsTokens.length);
	TokenAmount[] memory _interestAccrued = new TokenAmount[](rewardsTokens.length);

	for (uint i=0; i< rewardsTokens.length; i++) {
	    _tokenBalances[i] = rewardsTokens[i].balanceOf(address(this));
	    _interestAccrued[i] = TokenAmount(rewardsTokens[i], _tokenBalances[i]);
	}

	uint256[] memory _bountyAmounts = new uint256[](rewardsTokens.length);
        {  // block is to prevent 'stack too deep' compilation error.
	    TokenAmount[] memory _feeBounties = revoBounty.calculateFeeBounty(_interestAccrued);
	    for (uint i=0; i < _feeBounties.length; i++) {
		_bountyAmounts[i] = _feeBounties[i].amount;
		require(_bountyAmounts[i] <= maxFeeNumerator * _tokenBalances[i] / maxFeeDenominator, "Bounty amount too high");
	    }
        }

	uint256 _totalAmountToken0 = 0;
	uint256 _totalAmountToken1 = 0;
	for (uint i=0; i < _bountyAmounts.length; i++) {
	    uint256 _halfTokens = (_tokenBalances[i] - _bountyAmounts[i]) / 2;
	    _totalAmountToken0 += swapForTokenInPool(paths[i][0], _halfTokens, rewardsTokens[i], deadline);
	    _totalAmountToken1 += swapForTokenInPool(paths[i][1], _halfTokens, rewardsTokens[i], deadline);
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
            _totalAmountToken0 * slippageNumerator / slippageDenominator,
            _totalAmountToken1 * slippageNumerator / slippageDenominator,
            address(this),
            deadline
        );


        // How much LP we have to re-invest
        uint256 lpBalance = stakingToken.balanceOf(address(this));
        stakingToken.approve(address(stakingRewards), lpBalance);

        // Actually reinvest and adjust FP weight
        stakingRewards.stake(lpBalance);
        lpTotalBalance += lpBalance;

        // Send bounty to caller
	for (uint i=0; i < rewardsTokens.length; i++) {
	    rewardsTokens[i].transfer(msg.sender, _bountyAmounts[i]);
	}
        revoBounty.issueAdditionalBounty(msg.sender);
    }
}
