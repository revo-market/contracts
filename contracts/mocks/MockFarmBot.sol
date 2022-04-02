pragma solidity ^0.8.0;

import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02SwapOnly.sol";
import "./MockLPToken.sol";

/**
* MockFarmBot has the bare minimum functionality of a farm bot for testing RevoFPBroker.
*/
contract MockFarmBot is MockERC20 {
    IUniswapV2Router02SwapOnly public swapRouter; // address to use for router that handles swaps
    IUniswapV2Router02 public liquidityRouter; // address to use for router that handles minting liquidity

    IERC20 public stakingToken0; // LP token0
    IERC20 public stakingToken1; // LP token1
    MockLPToken public stakingToken;

    constructor(
        address _swapRouterAddress,
        address _liquidityRouterAddress,
        address _stakingTokenAddress
    ) MockERC20("Mock farm bot", "MRFP") {
        swapRouter = IUniswapV2Router02SwapOnly(_swapRouterAddress);
        liquidityRouter = IUniswapV2Router02(_liquidityRouterAddress);
        stakingToken = MockLPToken(_stakingTokenAddress);
        stakingToken0 = IERC20(stakingToken.token0());
        stakingToken1 = IERC20(stakingToken.token1());
    }

    function getFpAmount(uint256 _lpAmount) public view returns (uint256) {
        return _lpAmount;
    }

    function getLpAmount(uint256 _fpAmount) public view returns (uint256) {
        return _fpAmount;
    }

    function deposit(uint256 _lpAmount) public {
        stakingToken.transferFrom(msg.sender, address(this), _lpAmount);
        mint(msg.sender, getFpAmount(_lpAmount));
    }
}
