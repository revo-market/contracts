pragma solidity ^0.8.0;

import "./ubeswap-farming/contracts/Owned.sol";
import "./IRevoBounty.sol";

contract FeeOnlyBounty is Owned, IRevoBounty {
    uint256 public bountyFeeNumerator;
    uint256 public bountyFeeDenominator;

    uint256 public reserveFeeNumerator;
    uint256 public reserveFeeDenominator;

    constructor(
        address _owner,
        uint256 _bountyFeeNumerator,
        uint256 _bountyFeeDenominator,
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator
    ) Owned(_owner) {
        bountyFeeNumerator = _bountyFeeNumerator;
        bountyFeeDenominator = _bountyFeeDenominator;
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
    }

    function updateBountyFee(
        uint256 _bountyFeeNumerator,
        uint256 _bountyFeeDenominator
    ) external onlyOwner {
        bountyFeeNumerator = _bountyFeeNumerator;
        bountyFeeDenominator = _bountyFeeDenominator;
    }

    function updateReserveFee(
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator
    ) external onlyOwner {
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
    }

    function calculateFee(
        TokenAmount[] memory _interestAccrued,
        uint256 _feeNumerator,
        uint256 _feeDenominator
    ) private view returns (TokenAmount[] memory output) {
        output = new TokenAmount[](_interestAccrued.length);
        for (uint256 idx = 0; idx < _interestAccrued.length; idx++) {
            uint256 _fee = (_interestAccrued[idx].amount * _feeNumerator) /
                _feeDenominator;
            output[idx] = TokenAmount(_interestAccrued[idx].token, _fee);
        }
    }

    function calculateAdditionalBountyFee(TokenAmount[] memory _interestAccrued)
	external
	view
	override
	returns (TokenAmount[] memory output)
    {
	return new TokenAmount[](0); // intentionally returns empty list
    }

    function calculateBountyFee(TokenAmount[] memory _interestAccrued)
        external
        view
        override
        returns (TokenAmount[] memory output)
    {
        output = calculateFee(
            _interestAccrued,
            bountyFeeNumerator,
            bountyFeeDenominator
        );
    }

    function calculateReserveFee(TokenAmount[] memory _interestAccrued)
        external
        view
        override
        returns (TokenAmount[] memory output)
    {
        output = calculateFee(
            _interestAccrued,
            reserveFeeNumerator,
            reserveFeeDenominator
        );
    }

    function issueAdditionalBounty(address recipient) external override {
        return; // intentionally does nothing
    }

    function calculateWithdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    )
        external
        view
        override
        returns (uint256 feeNumerator, uint256 feeDenominator)
    {
        // 0.25% (ignores interest earned for simplicity)
        feeNumerator = 25;
        feeDenominator = 10000;
    }
}
