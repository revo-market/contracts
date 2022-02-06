pragma solidity ^0.8.0;

import "../openzeppelin-solidity/contracts/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address _account, uint _amount) public {
        _mint(_account, _amount);
    }
}
