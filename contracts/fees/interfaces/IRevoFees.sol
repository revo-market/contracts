//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../../openzeppelin-solidity/contracts/IERC20.sol";

struct TokenAmount {
    IERC20 token;
    uint256 amount;
}

interface IRevoFees {
    function compounderFee(uint256 _interestAccrued)
        external
        view
        returns (uint256);

    function compounderBonus(TokenAmount calldata interestAccrued)
        external
        view
        returns (TokenAmount[] memory);

    function reserveFee(uint256 _interestAccrued)
        external
        view
        returns (uint256);

    function withdrawalFee(
        uint256 interestEarnedNumerator,
        uint256 interestEarnedDenominator
    ) external view returns (uint256 feeNumerator, uint256 feeDenominator);

    function issueCompounderBonus(address recipient) external;
}
