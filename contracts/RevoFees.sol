//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ubeswap-farming/contracts/Owned.sol";
import "./IRevoFees.sol";

contract RevoFees is Owned, IRevoFees {
    uint256 public compounderFeeNumerator;
    uint256 public compounderFeeDenominator;

    uint256 public reserveFeeNumerator;
    uint256 public reserveFeeDenominator;

    constructor(
        address _owner,
        uint256 _compounderFeeNumerator,
        uint256 _compounderFeeDenominator,
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator
    ) Owned(_owner) {
        compounderFeeNumerator = _compounderFeeNumerator;
        compounderFeeDenominator = _compounderFeeDenominator;
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
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

    function calculateFee(
        TokenAmount[] memory _interestAccrued,
        uint256 _feeNumerator,
        uint256 _feeDenominator
    ) private pure returns (TokenAmount[] memory output) {
        output = new TokenAmount[](_interestAccrued.length);
        for (uint256 idx = 0; idx < _interestAccrued.length; idx++) {
            uint256 _fee = (_interestAccrued[idx].amount * _feeNumerator) /
                _feeDenominator;
            output[idx] = TokenAmount(_interestAccrued[idx].token, _fee);
        }
    }

    function compounderBonus(TokenAmount[] memory _interestAccrued)
        external
        pure
        override
        returns (TokenAmount[] memory output)
    {
        return new TokenAmount[](0); // intentionally returns empty list
    }

    function compounderFee(TokenAmount[] memory _interestAccrued)
        external
        view
        override
        returns (TokenAmount[] memory output)
    {
        output = calculateFee(
            _interestAccrued,
            compounderFeeNumerator,
            compounderFeeDenominator
        );
    }

    function reserveFee(TokenAmount[] memory _interestAccrued)
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

    function issueCompounderBonus(address recipient) external pure override {
        return; // intentionally does nothing
    }

    function withdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    )
        external
        pure
        override
        returns (uint256 feeNumerator, uint256 feeDenominator)
    {
        // 0.25% (ignores interest earned for simplicity)
        feeNumerator = 25;
        feeDenominator = 10000;
    }
}
