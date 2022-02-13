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

    function calculateAdditionalBountyFee(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return new TokenAmount[](0);
    }

    function calculateReserveFee(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return bounties;
    }

    uint256 withdrawalFeeNumerator = 25;
    uint256 withdrawalFeeDenominator = 10000;
    function setWithdrawalFee(uint256 _feeNumerator, uint256 _feeDenominator) public {
        withdrawalFeeNumerator = _feeNumerator;
        withdrawalFeeDenominator = _feeDenominator;
    }

    function calculateWithdrawalFee(uint256 interestEarnedNumerator, uint256 interestEarnedDenominator) external view override returns (uint256 feeNumerator, uint256 feeDenominator) {
        feeNumerator = withdrawalFeeNumerator;
        feeDenominator = withdrawalFeeDenominator;
    }

    function issueAdditionalBounty(address recipient) external override {
        return;
    }
}
