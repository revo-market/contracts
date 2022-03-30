// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// Incomplete, but should suffice
interface IMinter {
    function mint(address gauge_addr) external;

    function mint_many(address[8] memory gauge_addrs) external;

    function mint_for(address gauge_addr, address _for) external;

    function toggle_approve_mint(address minting_user) external;
}
