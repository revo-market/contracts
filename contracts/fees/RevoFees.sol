//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../ubeswap-farming/contracts/Owned.sol";
import "./interfaces/IRevoFees.sol";

contract RevoFees is Owned, IRevoFees {
    // compounder fee: a performance fee (taken from farming rewards) to compensate someone who calls 'compound' method
    //  on a Revo Farm Bot. This is necessary because compounders incur gas costs and help users get compound interest
    //  (since the 'compound' method re-invests their farming rewards into the farm)
    uint256 public compounderFeeNumerator;
    uint256 public compounderFeeDenominator;

    // reserve fee: a performance fee (taken from farming rewards) sent to Revo reserves, to fund future development
    uint256 public reserveFeeNumerator;
    uint256 public reserveFeeDenominator;

    event CompounderFeeUpdated(
        address indexed by,
        uint256 compounderFeeNumerator,
        uint256 compounderFeeDenominator
    );
    event ReserveFeeUpdated(
        address indexed by,
        uint256 reserveFeeNumerator,
        uint256 reserveFeeDenominator
    );
    event WithdrawalFeeUpdated(
        address indexed by,
        uint256 withdrawalFeeNumerator,
        uint256 withdrawalFeeDenominator
    );
    event UseDynamicWithdrawalFeesUpdated(address indexed by, bool newValue);
    uint256 public withdrawalFeeNumerator;
    uint256 public withdrawalFeeDenominator;
    bool public useDynamicWithdrawalFees;

    constructor(
        address _owner,
        uint256 _compounderFeeNumerator,
        uint256 _compounderFeeDenominator,
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator,
        uint256 _withdrawalFeeNumerator,
        uint256 _withdrawalFeeDenominator,
        bool _useDynamicWithdrawalFees
    ) Owned(_owner) {
        require(
            _compounderFeeDenominator > 0 &&
                _reserveFeeDenominator > 0 &&
                _withdrawalFeeDenominator > 0,
            "Fee denoms must be >0"
        );
        compounderFeeNumerator = _compounderFeeNumerator;
        compounderFeeDenominator = _compounderFeeDenominator;
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
        withdrawalFeeNumerator = _withdrawalFeeNumerator;
        withdrawalFeeDenominator = _withdrawalFeeDenominator;
        useDynamicWithdrawalFees = _useDynamicWithdrawalFees;
    }

    function updateCompounderFee(
        uint256 _compounderFeeNumerator,
        uint256 _compounderFeeDenominator
    ) external onlyOwner {
        require(_compounderFeeDenominator > 0, "Denom must be >0");
        compounderFeeNumerator = _compounderFeeNumerator;
        compounderFeeDenominator = _compounderFeeDenominator;
        emit CompounderFeeUpdated(
            msg.sender,
            _compounderFeeNumerator,
            _compounderFeeDenominator
        );
    }

    function updateReserveFee(
        uint256 _reserveFeeNumerator,
        uint256 _reserveFeeDenominator
    ) external onlyOwner {
        require(_reserveFeeDenominator > 0, "Denom must be >0");
        reserveFeeNumerator = _reserveFeeNumerator;
        reserveFeeDenominator = _reserveFeeDenominator;
        emit ReserveFeeUpdated(
            msg.sender,
            _reserveFeeNumerator,
            _reserveFeeDenominator
        );
    }

    function updateWithdrawalFee(
        uint256 _withdrawalFeeNumerator,
        uint256 _withdrawalFeeDenominator
    ) external onlyOwner {
        require(_withdrawalFeeDenominator > 0, "Denom must be >0");
        withdrawalFeeNumerator = _withdrawalFeeNumerator;
        withdrawalFeeDenominator = _withdrawalFeeDenominator;
        emit WithdrawalFeeUpdated(
            msg.sender,
            _withdrawalFeeNumerator,
            _withdrawalFeeDenominator
        );
    }

    /**
     * Set a flag for whether dynamic withdrawal fees should be used.
     *
     * If true, only rewards earned in the last compounding interval will be counted towards fees.
     *
     * Otherwise, static withdrawal fees will be used.
     */
    function updateUseDynamicWithdrawalFees(bool _useDynamicWithdrawalFees)
        external
        onlyOwner
    {
        useDynamicWithdrawalFees = _useDynamicWithdrawalFees;
        emit UseDynamicWithdrawalFeesUpdated(
            msg.sender,
            _useDynamicWithdrawalFees
        );
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
     * If useDynamicWithdrawalFees is true, sets the fee to interest earned in the last compounding interval.
     *
     * (Note that there is a maximum fee set in the Farm Bot contract to protect
     *   users from unreasonably high withdrawal fees.)
     */
    function withdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    )
        external
        view
        override
        returns (uint256 feeNumerator, uint256 feeDenominator)
    {
        if (useDynamicWithdrawalFees && interestEarnedDenominator > 0) {
            feeNumerator = interestEarnedNumerator;
            feeDenominator = interestEarnedDenominator;
        } else {
            feeNumerator = withdrawalFeeNumerator;
            feeDenominator = withdrawalFeeDenominator;
        }
    }
}
