pragma solidity ^0.8.0;

import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router01.sol";
import "./MockLPToken.sol";

contract MockRouter is IUniswapV2Router01 {
    MockLPToken lpToken;

    function factory() external override pure returns (address) {
        require(false, "Shouldn't use factory for mock router");
        return address(0);
    }
    uint mockLiquidity;
    function setMockLiquidity(uint _liquidity) public {
        mockLiquidity = _liquidity;
    }
    function setLPToken(address _lpToken) public {
        lpToken = MockLPToken(_lpToken);
    }
    bool public useMockStakingTokenAmounts;  // hack for backwards compatibility with tests that dont set liquidity amounts
    uint[2] stakingTokenAmounts;
    function setStakingTokenAmounts(uint[2] memory _stakingTokenAmounts) public {
        useMockStakingTokenAmounts = true;
        stakingTokenAmounts = _stakingTokenAmounts;
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
        if (useMockStakingTokenAmounts) {
            amountA = stakingTokenAmounts[0];
            amountB = stakingTokenAmounts[1];
        } else {
            amountA = amountADesired;
            amountB = amountBDesired;
        }
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        liquidity = mockLiquidity;
        lpToken.mint(msg.sender, mockLiquidity);
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
        lpToken.burn(msg.sender, liquidity);
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
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
        require(false, "Not implemented");
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
        require(amountIn > 0, "Cannot swap zero of token");
        MockERC20(path[0]).burn(msg.sender, amountIn);
        amounts = mockAmounts;
        MockERC20(path[path.length - 1]).mint(msg.sender, amounts[amounts.length - 1]);
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
