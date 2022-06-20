//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./openzeppelin-solidity/contracts/SafeERC20.sol";

/*
* This contract allows you to send Celo to a contract, which is otherwise blocked (if you try it from your wallet, for instance).
*
* Meant for edge case debugging purposes-- where you want to try unsticking compounding by giving the farm bot some Celo, for instance.
*/
contract SendCelo {
    using SafeERC20 for IERC20;

    IERC20 public constant CELO = IERC20(0x471EcE3750Da237f93B8E339c536989b8978a438);

    function sendCelo(address _recipient, uint256 _amount) public {
        // remember to approve first
        CELO.transferFrom(msg.sender, _recipient, _amount);
    }
}
