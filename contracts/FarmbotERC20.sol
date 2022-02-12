//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "./openzeppelin-solidity/contracts/IERC20.sol";
import "./ubeswap/contracts/uniswapv2/libraries/SafeMath.sol";

contract FarmbotERC20 is IERC20 {
    using SafeMathUniswap for uint256;

    string public constant name = "Farmbot FP Token";
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public override totalSupply; // total number of "Farm Points" issued by Farm Bot
    mapping(address => uint256) public override balanceOf; // maps address to "Farm Point" balances.
    // FP balances ONLY changes on deposits/withdrawals, NOT when FarmBot claims rewards. This helps save gas.
    // NOTE: the thing that DOES change is the VALUE of an FP relative to an LP token

    mapping(address => mapping(address => uint256)) public override allowance;

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(
                value
            );
        }
        _transfer(from, to, value);
        return true;
    }
}
