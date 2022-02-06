pragma solidity ^0.8.0;

import "./openzeppelin-solidity/contracts/IERC20.sol";

struct TokenAmount {
    IERC20 token;
    uint amount;
}

interface IRevoBounty {
    function calculateFeeBounty(TokenAmount[] calldata interestAccrued) external view returns (TokenAmount[] memory);
    function issueAdditionalBounty(address recipient) external;
}
