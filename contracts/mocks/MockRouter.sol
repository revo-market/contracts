pragma solidity ^0.8.0;

import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router01.sol";

contract MockRouter is IUniswapV2Router01 {
    function factory() external override pure returns (address) {
        require(false, "Shouldn't use factory for mock router");
        return address(0);
    }
    uint mockLiquidity;
    function setMockLiquidity(uint _liquidity) public {
        mockLiquidity = _liquidity;
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = mockLiquidity;
    }
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override returns (uint amountA, uint amountB) {
        amountA = amountAMin;
        amountB = amountBMin;
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amountA, uint amountB) {
        amountA = amountAMin;
        amountB = amountBMin;
    }
    uint[] mockAmounts;
    function setMockAmounts(uint[] memory amounts) public {
        mockAmounts = new uint[](amounts.length);
        for (uint idx = 0; idx < amounts.length; idx++) {
            mockAmounts[idx] = amounts[idx];
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        return mockAmounts;
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        return mockAmounts;
    }

    function quote(uint amountA, uint reserveA, uint reserveB) external override pure returns (uint amountB){
        amountB = reserveB / reserveA * amountA;
    }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external override pure returns (uint amountOut){
        return reserveOut / reserveIn * amountIn;
    }
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external override pure returns (uint amountIn){
        return reserveIn / reserveOut * amountOut;
    }
    function getAmountsOut(uint amountIn, address[] calldata path) external override view returns (uint[] memory amounts){
        return mockAmounts;
    }
    function getAmountsIn(uint amountOut, address[] calldata path) external override view returns (uint[] memory amounts){
        return mockAmounts;
    }
}
