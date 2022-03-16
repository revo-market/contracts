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

    function _deposit(uint256 _lpAmount)
}
