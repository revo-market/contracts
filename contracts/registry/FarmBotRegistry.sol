// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "../openzeppelin-solidity/contracts/Ownable.sol";


interface ILP {
    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IFarm {
    function stakingToken() external view returns (address);
}

contract FarmBotRegistry is Ownable {
    event FarmInfo(
        address indexed stakingAddress,
        bytes32 indexed farmName,
        address indexed lpAddress
    );
    event LPInfo(
        address indexed lpAddress,
        address indexed token0Address,
        address indexed token1Address
    );
    event FarmData(
        address indexed stakingAddress,
        uint256 indexed tvlUSD,
        uint256 indexed rewardsUSDPerYear
    );

    constructor() {}

    function addFarmInfo(bytes32 farmName, IFarm farm) public onlyOwner {
        ILP lp = ILP(farm.stakingToken());
        emit FarmInfo(address(farm), farmName, address(lp));
        emit LPInfo(address(lp), lp.token0(), lp.token1());
    }

    function updateFarmData(
        address farm,
        uint256 tvlUSD,
        uint256 rewardsUSDPerYear
    ) public onlyOwner {
        emit FarmData(farm, tvlUSD, rewardsUSDPerYear);
    }
}
