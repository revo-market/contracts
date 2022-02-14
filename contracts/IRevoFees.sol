//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin-solidity/contracts/IERC20.sol";

struct TokenAmount {
    IERC20 token;
    uint256 amount;
}

interface IRevoFees {
    function compounderFee(TokenAmount[] calldata interestAccrued)
        external
        view
        returns (TokenAmount[] memory);

    function compounderBonus(TokenAmount[] calldata interestAccrued)
        external
        view
        returns (TokenAmount[] memory);

    function reserveFee(TokenAmount[] calldata interestAccrued)
        external
        view
        returns (TokenAmount[] memory);

    function withdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    ) external view returns (uint256 feeNumerator, uint256 feeDenominator);

    function issueCompounderBonus(address recipient) external;
}
