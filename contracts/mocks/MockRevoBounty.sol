pragma solidity ^0.8.0;

import "../IRevoBounty.sol";

contract MockRevoBounty is IRevoBounty {
    TokenAmount[] bounties;

    function addBounty(TokenAmount memory _tokenAmount) external {
        bounties.push(_tokenAmount);
    }

    function removeBounty() external {
        bounties.pop();
    }

    function calculateBountyFee(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return bounties;
    }

    function calculateReserveFee(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return bounties;
    }

    function issueAdditionalBounty(address recipient) external override {
        return;
    }
}
