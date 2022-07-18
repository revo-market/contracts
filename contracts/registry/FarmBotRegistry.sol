// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "../openzeppelin-solidity/contracts/AccessControl.sol";


interface ILP {
    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IFarmBot {
    function stakingToken() external view returns (address);
}

contract FarmBotRegistry is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event FarmBotInfo(
        address indexed farmBotAddress,
        bytes32 indexed farmName,
        address indexed lpAddress,
        bool indexed isMetaFarm
    );
    event LPInfo(
        address indexed lpAddress,
        address indexed token0Address,
        address indexed token1Address
    );
    event FarmBotData(
        address indexed farmBotAddress,
        uint256 indexed tvlUSD,
        uint256 indexed rewardsUSDPerYear
    );
    event GrantRole(
        address indexed by,
        address indexed newRoleRecipient,
        bytes32 role
    );

    function grantRole(bytes32 role, address account)
        public
        virtual
        override
        onlyRole(getRoleAdmin(role))
        {
        super.grantRole(role, account);
        emit GrantRole(msg.sender, account, role);
    }

    constructor(address _owner) {
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        emit GrantRole(msg.sender, _owner, DEFAULT_ADMIN_ROLE);
    }

    function addFarmInfo(bytes32 farmName, IFarmBot farmBot, bool isMetaFarm) public onlyRole(OPERATOR_ROLE) {
        ILP lp = ILP(farmBot.stakingToken());
        emit FarmBotInfo(address(farmBot), farmName, address(lp), isMetaFarm);
        emit LPInfo(address(lp), lp.token0(), lp.token1());
    }

    function updateFarmData(
        address farm,
        uint256 tvlUSD,
        uint256 rewardsUSDPerYear
    ) public onlyRole(OPERATOR_ROLE) {
        emit FarmBotData(farm, tvlUSD, rewardsUSDPerYear);
    }
}
