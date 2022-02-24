//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ubeswap-farming/contracts/Owned.sol";
import "./IRevoFees.sol";

contract RevoFees is Owned, IRevoFees {
    // compounder fee: a performance fee (taken from farming rewards) to compensate someone who calls 'compound' method
    //  on a Revo Farm Bot. This is necessary because compounders incur gas costs and help users get compound interest
    //  (since the 'compound' method re-invests their farming rewards into the farm)
    uint256 public compounderFeeNumerator;
    uint256 public compounderFeeDenominator;

    // reserve fee: a performance fee (taken from farming rewards) sent to Revo reserves, to fund future development
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

    /*
     * Check what the bonus will be for calling 'compound' on a Revo Farm Bot.
     *
     * In the future, bonuses may be issued to compounders that are not taken as performance fees. (Could be governance
     *   tokens, or issued from a community fund.) This may help us lower or eliminate the compounder fee.
     */
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

    /*
     * Issue the bonus for calling 'compound' on a Revo Farm Bot.
     */
    function issueCompounderBonus(address recipient) external pure override {
        return; // intentionally does nothing
    }

    /*
     * Check the fee for withdrawing funds from a Revo Farm Bot.
     *
     * Withdrawal fees are used to prevent bad actors from depositing right before 'compound' is called, then withdrawing
     *   right after and taking some of the rewards. (Withdrawal fee should be >= the interest gained from the last time
     *   'compound' was called.)
     *
     * Takes the interest earned the last time 'compound' was called as a parameter. This makes it possible to have dynamic
     *   withdrawal fees.
     *
     * (Note that there is a maximum fee set in the Farm Bot contract to protect
     *   users from unreasonably high withdrawal fees.)
     */
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
