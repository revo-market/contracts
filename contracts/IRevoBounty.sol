pragma solidity ^0.8.0;

import "./openzeppelin-solidity/contracts/IERC20.sol";

struct TokenAmount {
    IERC20 token;
    uint256 amount;
}

interface IRevoBounty {
    function calculateBountyFee(TokenAmount[] calldata interestAccrued)
        external
        view
        returns (TokenAmount[] memory);

    function calculateReserveFee(TokenAmount[] calldata interestAccrued)
        external
        view
        returns (TokenAmount[] memory);

    function calculateWithdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    ) external view returns (uint256 feeNumerator, uint256 feeDenominator);

    function issueAdditionalBounty(address recipient) external;
}
