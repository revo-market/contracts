//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "./RevoFarmBot.sol";

/**
 * RevoLPFarmBot is an abstract class suitable for use when implementing a Revo Farm Bot atop of
 * a farm whose staked token is a
 *
 *
 **/
contract RevoLPFarmBot is RevoFarmBot {
    constructor(
        address _owner,
        address _reserveAddress,
        address _stakingRewards,
        address _stakingToken,
        address _revoFees,
        address[] memory _rewardsTokens,
        string memory _symbol
    )
        RevoFarmBot(
            _owner,
            _reserveAddress,
            _stakingToken,
            _revoFees,
            _rewardsTokens,
            _symbol
        )
    {}

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
    }
}
