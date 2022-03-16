//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02SwapOnly.sol";
import "../openzeppelin-solidity/contracts/SafeERC20.sol";

/**
 * UniswapRouter is a library containing helper functions for interacting with contracts implementing
 * the IUniswapV2Router02 interface, or subsets of its functionality.
 **/
library UniswapRouter {
    using SafeERC20 for IERC20;

    function swap(
        IUniswapV2Router02SwapOnly router,
        address[] memory path,
        uint256 startTokenBudget,
        IERC20 startToken,
        uint256 minAmountOut,
        uint256 deadline
    ) public returns (uint256) {
        if (path.length >= 2 && startTokenBudget > 0) {
            startToken.safeIncreaseAllowance(address(router), startTokenBudget);
            uint256[] memory _swapResultAmounts = router
                .swapExactTokensForTokens(
                    startTokenBudget,
                    minAmountOut,
                    path,
                    address(this),
                    deadline
                );
            return _swapResultAmounts[_swapResultAmounts.length - 1];
        } else {
            return startTokenBudget;
        }
    }

    /**
     * Swaps
     **/
    function swapTokensForEqualAmounts(
        IUniswapV2Router02SwapOnly router,
        uint256[] memory tokenBalances,
        address[][2][] memory paths,
        IERC20[] memory startTokens,
        uint256[2][] memory minAmountsOut,
        uint256 deadline
    ) public returns (uint256, uint256) {
        uint256 _totalAmountToken0 = 0;
        uint256 _totalAmountToken1 = 0;
        for (uint256 i = 0; i < tokenBalances.length; i++) {
            uint256 _halfTokens = tokenBalances[i] / 2;
            _totalAmountToken0 += swap(
                router,
                paths[i][0],
                _halfTokens,
                startTokens[i],
                minAmountsOut[i][0],
                deadline
            );
            _totalAmountToken1 += swap(
                router,
                paths[i][1],
                _halfTokens,
                startTokens[i],
                minAmountsOut[i][1],
                deadline
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
        uint256 deadline
    ) public {
        // Approve the liquidity router to spend the bot's token0/token1
        token0.safeApprove(address(router), amount0Desired);
        token1.safeApprove(address(router), amount1Desired);

        // Actually add liquidity
        router.addLiquidity(
            address(token0),
            address(token1),
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min,
            address(this),
            deadline
        );
    }
}