//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02SwapOnly.sol";


/**
 * UniswapRouter is a library containing helper functions for interacting with contracts implementing
 * the IUniswapV2Router02 interface, or subsets of its functionality.
 **/
library UniswapRouter {
    function swap(
        IUniswapV2Router02SwapOnly _router,
        address[] memory _path,
        uint256 _startTokenBudget,
        IERC20 _startToken,
        uint256 _minAmountOut,
        uint256 _deadline
    ) public returns (uint256) {
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

    /**
     * Swaps 
     **/
    function swapTokensForEqualAmounts(
        IUniswapV2Router02SwapOnly _router,
        uint256[] memory _tokenBalances,
        address[][2][] memory _paths,
	IERC20[] _startTokens,
        uint256[2][] memory _minAmountsOut,
        uint256 _deadline
    ) public returns(uint256, uint256) {
	uint256 _totalAmountToken0 = 0;
        uint256 _totalAmountToken1 = 0;
        for (uint256 i = 0; i < _tokenBalances.length; i++) {
            uint256 _halfTokens = _tokenBalances[i] / 2;
            _totalAmountToken0 += swap(
                _router,
                _paths[i][0],
                _halfTokens,
                rewardsTokens[i],
                _minAmountsOut[i][0],
                _deadline
            );
            _totalAmountToken1 += swap(
		_router,
                _paths[i][1],
                _halfTokens,
                rewardsTokens[i],
                _minAmountsOut[i][1],
                _deadline
            );
        }
	return (_totalAmountToken0, _totalAmountToken1);
    }

    function addLiquidity(
			  IUniswapV2Router02 router,
			  IERC20 token0,
			  IERC20 token1,
			  uint256 amount0Desired,
			  uint256 amount1Desired,
			  uint256 amount0Min,
			  uint256 amount1Min,
			  uint256 deadline,
			  ) public {
	// Approve the liquidity router to spend the bot's token0/token1
	token0.approve(address(router), amount0Desired);
	token1.approve(address(router), amount1Desired);

        // Actually add liquidity
	router.addLiquidity(
            address(token0),
            address(token1),
	    amount0Desired,
	    amount1Desired,
	    amount0Min,
	    amount1Min,
            address(this),
            _deadline
        );
    }
}
