//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ubeswap-farming/contracts/Owned.sol";
import "./IRevoFees.sol";

contract RevoFees is Owned, IRevoFees {
    uint256 public compounderFeeNumerator;
    uint256 public compounderFeeDenominator;

    uint256 public reserveFeeNumerator;
    uint256 public reserveFeeDenominator;

    uint256 public withdrawalFeeNumerator;
    uint256 public withdrawalFeeDenominator;

    constructor(
        address _owner,
        uint256 _compounderFeeNumerator,
        uint256 _compounderFeeDenominator,
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator,
        uint256 _withdrawalFeeNumerator,
        uint256 _withdrawalFeeDenominator
    ) Owned(_owner) {
        compounderFeeNumerator = _compounderFeeNumerator;
        compounderFeeDenominator = _compounderFeeDenominator;
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
        withdrawalFeeNumerator = _withdrawalFeeNumerator;
        withdrawalFeeDenominator = _withdrawalFeeDenominator;
    }

    function updateCompounderFee(
        uint256 _compounderFeeNumerator,
        uint256 _compounderFeeDenominator
    ) external onlyOwner {
        compounderFeeNumerator = _compounderFeeNumerator;
        compounderFeeDenominator = _compounderFeeDenominator;
    }

    function updateReserveFee(
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator
    ) external onlyOwner {
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
    }

    function updateWithdrawalFee(
        uint256 _withdrawalFeeNumerator,
        uint256 _withdrawalFeeDenominator
    ) external onlyOwner {
        withdrawalFeeNumerator = _withdrawalFeeNumerator;
        withdrawalFeeDenominator = _withdrawalFeeDenominator;
    }

    function compounderBonus(TokenAmount memory _interestAccrued)
        external
        pure
        override
        returns (TokenAmount[] memory output)
    {
        return new TokenAmount[](0); // intentionally returns empty list
    }

    function compounderFee(uint256 _interestAccrued)
        external
        view
        override
        returns (uint256)
    {
        return
            (_interestAccrued * compounderFeeNumerator) /
            compounderFeeDenominator;
    }

    function reserveFee(uint256 _interestAccrued)
        external
        view
        override
        returns (uint256)
    {
        return (_interestAccrued * reserveFeeNumerator) / reserveFeeDenominator;
    }

    function issueCompounderBonus(address recipient) external pure override {
        return; // intentionally does nothing
    }

    function withdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    )
        external
        view
        override
        returns (uint256 feeNumerator, uint256 feeDenominator)
    {
        // intentionally ignores interest earned for now
        feeNumerator = withdrawalFeeNumerator;
        feeDenominator = withdrawalFeeDenominator;
    }
}
