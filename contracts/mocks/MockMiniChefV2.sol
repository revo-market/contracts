pragma solidity ^0.8.0;

import "../openzeppelin-solidity/contracts/IERC20.sol";
import "../sushiswap/interfaces/IMiniChefV2.sol";

contract MockMiniChefV2 is IMiniChefV2 {
    IERC20[] public rewardsTokens;

    IERC20 public stakingToken;

    constructor(
        address[] memory  _rewardsTokens,
        address _stakingToken
    ) {
	for (uint i=0; i<_rewardsTokens.length; i++) {
	    rewardsTokens.push(IERC20(_rewardsTokens[i]));
	}
    }

    // Views
    function poolLength() external override view returns (uint256) {
        // farm bot shouldn't need this
        require(false);
        return 0;
    }

    function userInfo(uint256 _pid, address _user) external override view returns (uint256, uint256) {
        // farm bot shouldn't need this
        require(false);
        return (0, 0);
    }

    uint256[] public amountEarned;
    function setAmountEarned(uint256[] memory _amountEarned) public {
        amountEarned = _amountEarned;
    }

    // Mutative
    mapping(address => uint256) public staked;
    function deposit(uint256 pid, uint256 amount, address to) external override {
        staked[to] += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 pid, uint256 amount, address to) external override {
        require(staked[msg.sender] >= amount);
        staked[msg.sender] -= amount;
        stakingToken.transfer(to, amount);
    }

    function harvest(uint256 pid, address to) external override {
	for (uint i=0; i<rewardsTokens.length; i++) {
	    rewardsTokens[i].transfer(to, amountEarned[i]);
	}
    }

    function updatePool(uint256 pid) external override returns (PoolInfo memory) {
	// farm bot shouldn't need this
	require(false);
	return PoolInfo({
	    allocPoint: 0,
	    lastRewardTime: 0,
	    accSushiPerShare: 0
	    });
    }

    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external override {
	// farm bot shouldn't need this
	require(false);
    }

    function emergencyWithdraw(uint256 pid, address to) external override {
	// farm bot shouldn't need this
	require(false);
    }
}
