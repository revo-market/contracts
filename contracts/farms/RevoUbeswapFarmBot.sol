//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "../library/MoolaStakingRewards.sol";
import "../ubeswap-farming/interfaces/IMoolaStakingRewards.sol";
import "./common/RevoUniswapStakingTokenStrategy.sol";


contract RevoUbeswapFarmBot is RevoUniswapStakingTokenStrategy {

    IMoolaStakingRewards public stakingRewards;

    constructor(
        address _owner,
        address _reserveAddress,
        address _stakingRewards,
        address _stakingToken,
        address _revoFees,
        address[] memory _rewardsTokens,
        address _swapRouter,
        address _liquidityRouter,
        string memory _symbol
    )
        RevoUniswapStakingTokenStrategy(
            _owner,
            _reserveAddress,
            _stakingToken,
            _revoFees,
            _rewardsTokens,
            _swapRouter,
            _liquidityRouter,
            _symbol
        )
    {
        stakingRewards = IMoolaStakingRewards(_stakingRewards);
    }

    function _deposit(uint256 _lpAmount) internal override whenNotPaused {
        MoolaStakingRewards.deposit(stakingRewards, stakingToken, _lpAmount);
    }

    function _withdraw(uint256 _lpAmount) internal override {
        MoolaStakingRewards.withdraw(stakingRewards, _lpAmount);
    }

    function _claimRewards() internal override whenNotPaused {
        MoolaStakingRewards.claimRewards(stakingRewards);
    }
}
