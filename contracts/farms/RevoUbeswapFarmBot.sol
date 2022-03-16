//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "../openzeppelin-solidity/contracts/ERC20.sol";
import "../ubeswap-farming/interfaces/IMoolaStakingRewards.sol";
import "./common/RevoUniswapStakingTokenStrategy.sol";

contract RevoUbeswapFarmBot is RevoUniswapStakingTokenStrategy {
    using SafeERC20 for IERC20;

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
        require(_lpAmount > 0, "Cannot invest in farm because _lpAmount is 0");
        stakingToken.safeApprove(address(stakingRewards), _lpAmount);
        stakingRewards.stake(_lpAmount);
    }

    function _withdraw(uint256 _lpAmount) internal override {
        stakingRewards.withdraw(_lpAmount);
    }

    function _claimRewards() internal override whenNotPaused {
        stakingRewards.getReward();
    }
}
