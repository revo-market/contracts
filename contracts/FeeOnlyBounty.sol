pragma solidity ^0.8.0;

import "./ubeswap-farming/contracts/Owned.sol";
import "./IRevoBounty.sol";

contract FeeOnlyBounty is Owned, IRevoBounty {
    uint public feeNumerator;
    uint public feeDenominator;

    constructor(
        address _owner,
        uint _feeNumerator,
        uint _feeDenominator
    ) Owned(_owner) {
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
    }

    function updateFee(
        uint _feeNumerator,
        uint _feeDenominator
    ) external onlyOwner {
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
    }

    function calculateFeeBounty(TokenAmount[] memory _interestAccrued) external override view returns (TokenAmount[] memory output) {
        output = new TokenAmount[](_interestAccrued.length);
        for (uint idx = 0; idx < _interestAccrued.length; idx++) {
            uint _fee = _interestAccrued[idx].amount * feeNumerator / feeDenominator;
            output[idx] = TokenAmount(_interestAccrued[idx].token, _fee);
        }
        return output;
    }

    function issueAdditionalBounty(address recipient) external override {
      return; // intentionally does nothing
    }
}
