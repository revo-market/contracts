//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;H

import "hardhat/console.sol";

import "./IMoolaStakingRewards.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUbeswapRouter.sol";
import "./ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./IRevoFees.sol";
import "./IRevoFarmBot.sol";
import "./openzeppelin-solidity/contracts/ERC20.sol";
import "./openzeppelin-solidity/contracts/AccessControl.sol";
import "./openzeppelin-solidity/contracts/SafeERC20.sol";
import "./openzeppelin-solidity/contracts/Pausable.sol";

contract UbeswapFarmBot is RevoFarmBot{

    IMoolaStakingRewards public stakingRewards;

    IERC20 public stakingToken0; // LP token0
    IERC20 public stakingToken1; // LP token1

    // The router that handles swaps may not be capable of also minting liquidity; in this case, we need
    // dedicated routers for each function. In particular, this is true when swapping Moola mTokens using
    // Ubeswap's Moola router.
    IUbeswapRouter public swapRouter; // address to use for router that handles swaps
    IUniswapV2Router02 public liquidityRouter; // address to use for router that handles minting liquidity

    constructor(
        address _owner,
        address _reserveAddress,
        address _stakingRewards,
        address _stakingToken,
        address _revoFees,
        address _swapRouter,
        address _liquidityRouter,
        address[] memory _rewardsTokens,
        string memory _symbol
    ) RevoFarmBot(_owner, _reserveAddress, _stakingToken, _revoFees, _rewardsTokens, _symbol) {
        stakingRewards = IMoolaStakingRewards(_stakingRewards);

        stakingToken0 = IUniswapV2Pair(address(stakingToken).token0());
        stakingToken1 = IUniswapV2Pair(address(stakingToken).token1());


        swapRouter = IUbeswapRouter(_swapRouter);
        liquidityRouter = IUniswapV2Router02(_liquidityRouter);
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
            _startToken.safeIncreaseAllowance(
                address(swapRouter),
                _startTokenBudget
            );
            uint256[] memory _swapResultAmounts = swapRouter
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

        // Approve the liquidity router to spend the bot's token0/token1
        stakingToken0.approve(address(liquidityRouter), _totalAmountToken0);
        stakingToken1.approve(address(liquidityRouter), _totalAmountToken1);

        // Actually add liquidity
        liquidityRouter.addLiquidity(
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

	investAllAndSendFees();
    }
}
