//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "../sushiswap/interfaces/IMiniChefV2.sol";
import "./common/RevoUniswapStakingTokenStrategy.sol";
import "../openzeppelin-solidity/contracts/SafeERC20.sol";

/**
 * RevoSushiswapFarmBot is a farmbot:
 *   * that runs on top of an IMiniChefV2 farm
 *   * whose stakingToken is an IUniswapV2Pair ("LP")
 *   * that acquires LP constintuent tokens through swaps on an IUniswapV2Router02
 *   * that mints LP from constituent tokens through an IUniswapV2Router02
 *
 * This farmbot is suitable for use on top of Sushiswap yield farms
 **/
contract RevoSushiswapFarmBot is RevoUniswapStakingTokenStrategy {
    using SafeERC20 for IERC20;

    event SushiPidUpdated(address indexed by, uint256 sushiPid);

    IMiniChefV2 public stakingRewards;

    // MiniChefV2 maintains a lists of information on each pool/farm; sushiPid
    // is used as an index into these lists, and acts as an identifier for which
    // farm to perform operations against.
    uint256 public sushiPid;

    constructor(
        address _owner,
        address _reserveAddress,
        address _stakingRewards,
        address _stakingToken,
        address _revoFees,
        uint256 _sushiPid,
        address[] memory _rewardsTokens,
        address _router,
        string memory _symbol
    )
        RevoUniswapStakingTokenStrategy(
            _owner,
            _reserveAddress,
            _stakingToken,
            _revoFees,
            _rewardsTokens,
            _router,
            _router,
            _symbol
        )
    {
        stakingRewards = IMiniChefV2(_stakingRewards);
        sushiPid = _sushiPid;
    }

    function updateSushiPid(uint256 _sushiPid)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        sushiPid = _sushiPid;
        emit SushiPidUpdated(msg.sender, _sushiPid);
    }

    function _deposit(uint256 _lpAmount) internal override whenNotPaused {
        require(_lpAmount > 0, "Cannot invest in farm because lpAmount is 0");
        stakingToken.safeIncreaseAllowance(address(stakingRewards), _lpAmount);
        stakingRewards.deposit(sushiPid, _lpAmount, address(this));
    }

    function _withdraw(uint256 _lpAmount) internal override {
        stakingRewards.withdraw(sushiPid, _lpAmount, address(this));
    }

    function _claimRewards() internal override whenNotPaused {
        stakingRewards.harvest(sushiPid, address(this));
    }
}
