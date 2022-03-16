//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "../openzeppelin-solidity/contracts/SafeERC20.sol";
import "../ubeswap-farming/interfaces/IMoolaStakingRewards.sol";

/**
 * MoolaStakingRewards is a library containing helper functions for interacting with contracts
 * implementing the IMoolaStakingRewards interface.
 **/
library MoolaStakingRewards {
    using SafeERC20 for IERC20;

    function deposit(
        IMoolaStakingRewards stakingRewards,
        IERC20 stakingToken,
        uint256 lpAmount
    ) public {
        require(lpAmount > 0, "Cannot invest in farm because lpAmount is 0");
        stakingToken.safeApprove(address(stakingRewards), lpAmount);
        stakingRewards.stake(lpAmount);
    }

    function withdraw(IMoolaStakingRewards stakingRewards, uint256 lpAmount)
        public
    {
        stakingRewards.withdraw(lpAmount);
    }

    function claimRewards(IMoolaStakingRewards stakingRewards) public {
        stakingRewards.getReward();
    }
}
