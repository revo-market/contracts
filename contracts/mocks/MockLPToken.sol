// SPDX-License-Identifier: MIT

//pragma solidity =0.6.12;
pragma solidity >=0.5.0 <0.9.0;

import "./MockERC20.sol";

contract MockLPToken is MockERC20 {
    address public token0;
    address public token1;

    constructor(string memory name_, string memory symbol_, address _token0, address _token1) MockERC20(name_, symbol_) {
        token0 = _token0;
        token1 = _token1;
    }
}
