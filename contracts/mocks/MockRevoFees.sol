pragma solidity ^0.8.0;

import "../IRevoBounty.sol";

contract MockRevoFees is IRevoFees {
    TokenAmount[] bonuses;

    function addBonus(TokenAmount memory _tokenAmount) external {
        bonuses.push(_tokenAmount);
    }

    function removeBonus() external {
        bonuses.pop();
    }

    function compounderFee(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return bonuses;
    }

    function compounderBonus(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return new TokenAmount[](0);
    }

    function reserveFee(TokenAmount[] calldata interestAccrued) external override view returns (TokenAmount[] memory) {
        return bonuses;
    }

    uint256 withdrawalFeeNumerator = 25;
    uint256 withdrawalFeeDenominator = 10000;
    function setWithdrawalFee(uint256 _feeNumerator, uint256 _feeDenominator) public {
        withdrawalFeeNumerator = _feeNumerator;
        withdrawalFeeDenominator = _feeDenominator;
    }

    function withdrawalFee(uint256 interestEarnedNumerator, uint256 interestEarnedDenominator) external view override returns (uint256 feeNumerator, uint256 feeDenominator) {
        feeNumerator = withdrawalFeeNumerator;
        feeDenominator = withdrawalFeeDenominator;
    }

    function issueCompounderBonus(address recipient) external override {
        return;
    }
}
