pragma solidity ^0.8.0;

import "./ubeswap-farming/contracts/Owned.sol";
import "./IRevoBounty.sol";

contract FeeOnlyBounty is Owned, IRevoBounty {
    uint public bountyFeeNumerator;
    uint public bountyFeeDenominator;

    uint public reserveFeeNumerator;
    uint public reserveFeeDenominator;

    constructor(
        address _owner,
        uint _bountyFeeNumerator,
        uint _bountyFeeDenominator,
	uint _reserveFeeNumerator,
        uint _reserveFeeDenominator
    ) Owned(_owner) {
        bountyFeeNumerator = _bountyFeeNumerator;
        bountyFeeDenominator = _bountyFeeDenominator;
	reserveFeeNumerator = _reserveFeeNumerator;
	reserveFeeDenominator = _reserveFeeDenominator;
    }

    function updateBountyFee(
        uint _bountyFeeNumerator,
        uint _bountyFeeDenominator
    ) external onlyOwner {
        bountyFeeNumerator = _bountyFeeNumerator;
        bountyFeeDenominator = _bountyFeeDenominator;
    }

    function updateReserveFee(
        uint _reserveFeeNumerator,
        uint _reserveFeeDenominator
    ) external onlyOwner {
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
    }

    function calculateFee(
        TokenAmount[] memory _interestAccrued,
	uint _feeNumerator,
	uint _feeDenominator
    ) private view returns (TokenAmount[] memory output) {
	output = new TokenAmount[](_interestAccrued.length);
        for (uint idx = 0; idx < _interestAccrued.length; idx++) {
            uint _fee = _interestAccrued[idx].amount * _feeNumerator / _feeDenominator;
            output[idx] = TokenAmount(_interestAccrued[idx].token, _fee);
        }
    }

    function calculateBountyFee(TokenAmount[] memory _interestAccrued) external override view returns (TokenAmount[] memory output) {
	output = calculateFee(_interestAccrued, bountyFeeNumerator, bountyFeeDenominator);
    }

    function calculateReserveFee(TokenAmount[] memory _interestAccrued) external override view returns (TokenAmount[] memory output) {
	output = calculateFee(_interestAccrued, reserveFeeNumerator, reserveFeeDenominator);
    }

    function issueAdditionalBounty(address recipient) external override {
      return; // intentionally does nothing
    }
}
