//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../farms/common/RevoUniswapStakingTokenStrategy.sol";

struct LiquidityAmounts {
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
}

/**
* RevoFPBroker helps users get FP directly from staking tokens (skipping the step where you get LP first).
*/
contract RevoFPBroker is Pausable, AccessControl {
    using SafeERC20 for IERC20;

    event RFPBrokerDeposit(
      address indexed farmBotAddress,
      address indexed depositorAddress,
      uint256 lpGained,
      uint256 fpGained
    );

    constructor(
        address _owner
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "FarmBot: EXPIRED");
        _;
    }

    /**
    * Get LP and deposit them into a farm bot.
    *
    * Works only for farm bots implementing RevoUniswapStakingTokenStrategy.
    *
    * @param _farmBotAddress: address of RevoUniswapStakingTokenStrategy contract
    * @param _liquidityAmounts: how much liquidity to add (grouped to avoid 'stack too deep' error)
    * @param _deadline: deadline to finish transaction by, in epoch seconds
    */
    function getUniswapLPAndDeposit(
        address _farmBotAddress,
        LiquidityAmounts calldata _liquidityAmounts,
        uint256 _deadline
    ) external ensure(_deadline) whenNotPaused {
        RevoUniswapStakingTokenStrategy _farmBot = RevoUniswapStakingTokenStrategy(_farmBotAddress);

        // take staking tokens from sender
        require(_liquidityAmounts.amount0Desired > 0, "amount0Desired must be greater than 0");
        require(_liquidityAmounts.amount1Desired > 0, "amount1Desired must be greater than 0");
        _farmBot.stakingToken0().safeTransferFrom(msg.sender, address(this), _liquidityAmounts.amount0Desired);
        _farmBot.stakingToken1().safeTransferFrom(msg.sender, address(this), _liquidityAmounts.amount1Desired);

        // add liquidity
        (uint256 _amount0Invested, uint256 _amount1Invested, uint256 _lpAmount) = UniswapRouter.addLiquidity(
            _farmBot.liquidityRouter(),
            _farmBot.stakingToken0(),
            _farmBot.stakingToken1(),
            _liquidityAmounts.amount0Desired,
            _liquidityAmounts.amount1Desired,
            _liquidityAmounts.amount0Min,
            _liquidityAmounts.amount1Min,
            _deadline
        );

        // send leftovers to investor
        uint256 _token0Leftover = _liquidityAmounts.amount0Desired - _amount0Invested;
        if (_token0Leftover > 0) {
            _farmBot.stakingToken0().safeTransfer(msg.sender, _token0Leftover);
        }
        uint256 _token1Leftover = _liquidityAmounts.amount1Desired - _amount1Invested;
        if (_token1Leftover > 0) {
            _farmBot.stakingToken1().safeTransfer(msg.sender, _token1Leftover);
        }

        // trade LP for FP
        _farmBot.stakingToken().safeIncreaseAllowance(_farmBotAddress, _lpAmount);
        uint256 _prevFPBalance = _farmBot.balanceOf(address(this));
        _farmBot.deposit(_lpAmount);
        uint256 _fpGained = _farmBot.balanceOf(address(this)) - _prevFPBalance;

        // send FP to investor
        IERC20(_farmBotAddress).safeTransfer(msg.sender, _fpGained);
        emit RFPBrokerDeposit(
            _farmBotAddress,
            msg.sender,
            _lpAmount,
            _fpGained
        );
    }

    /**
    * Withdraw from a farm bot and remove liquidity from the underlying pool.
    *
    * @param _farmBotAddress: address of the farm bot to withdraw from
    * @param _fpAmount: amount to withdraw
    * @param _amountAMin: minimum amount of staking token 0 (aka "token A") to receive in exchange
    * @param _amountBMin: minimum amount of staking token 1 (aka "token B") to receive in exchange
    * @param _deadline: time to finish by, in epoch seconds
    */
    function withdrawFPForStakingTokens(
        address _farmBotAddress,
        uint256 _fpAmount,
        uint256 _amountAMin,
        uint256 _amountBMin,
        uint256 _deadline
    ) external ensure(_deadline) whenNotPaused {
        require(_fpAmount > 0, "Cannot withdraw because _fpAmount is 0");
        IERC20(_farmBotAddress).safeTransferFrom(msg.sender, address(this), _fpAmount);
        RevoUniswapStakingTokenStrategy _farmBot = RevoUniswapStakingTokenStrategy(_farmBotAddress);
        uint256 _lpAmount = _farmBot.getLpAmount(_fpAmount);
        _farmBot.withdraw(_lpAmount);
        (uint256 _amountA, uint256 _amountB) = _farmBot.liquidityRouter().removeLiquidity(
            address(_farmBot.stakingToken0()),
            address(_farmBot.stakingToken1()),
            _lpAmount,
            _amountAMin,
            _amountBMin,
            address(this),
            _deadline
        );
        _farmBot.stakingToken0().safeTransfer(msg.sender, _amountA);
        _farmBot.stakingToken1().safeTransfer(msg.sender, _amountB);
    }
}
