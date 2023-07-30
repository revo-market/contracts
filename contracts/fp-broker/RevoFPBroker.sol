//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../farms/common/RevoUniswapStakingTokenStrategy.sol";
import "../library/UniswapRouter.sol";
import "../library/ArrayUtils.sol";

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
        uint256 token0Invested,
        uint256 token1Invested,
        uint256 lpGained,
        uint256 fpGained
    );

    event RFPBrokerWithdrawal(
        address indexed farmBotAddress,
        address indexed withdrawerAddress,
        uint256 fpBurned,
        uint256 lpGained,
        uint256 token0Gained,
        uint256 token1Gained
    );

    constructor(address _owner) {
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
        address _zapTokenAddress,
        uint256 _zapTokenAmount,
        address[] calldata _path0,
        address[] calldata _path1,
        LiquidityAmounts calldata _liquidityAmounts,
        uint256 _deadline
    ) external ensure(_deadline) whenNotPaused {
        // TODO update to start from a single zap token. We can do this by:
        //  1. taking the zap token address, zap token amount, and paths from zap token to staking tokens as params
        //  2. swapping zap token for staking tokens
        //  3. getting LP and depositing for FP the same way it is currently done
        //  4. with any leftover staking tokens, swap them back to zap token using reversed path params, and return to sender

        RevoUniswapStakingTokenStrategy _farmBot = RevoUniswapStakingTokenStrategy(
            _farmBotAddress
        );

        // take zap token from sender
        require(_zapTokenAmount > 0, "zapTokenAmount must be greater than 0");
        IERC20(_zapTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _zapTokenAmount
        );

        // swap zap token for equal value of staking tokens
        require(_path0.length == 0 || (_path0[0] == _zapTokenAddress && _path0[_path0.length - 1] == _farmBot.stakingToken0()), "_path0 invalid");
        require(_path1.length == 0 || (_path1[0] == _zapTokenAddress && _path1[_path1.length - 1] == _farmBot.stakingToken1()), "_path1 invalid");
        uint256 _amountToken0 = UniswapRouter.swap(
            _farmBot.swapRouter(),
            _path0,
            _zapTokenAmount / 2,
            IERC20(_zapTokenAddress),
            _liquidityAmounts.amount0Min,
            _deadline
        );
        uint256 _amountToken1 = UniswapRouter.swap(
            _farmBot.swapRouter(),
            _path1,
            _zapTokenAmount / 2,
            IERC20(_zapTokenAddress),
            _liquidityAmounts.amount1Min,
            _deadline
        );

        // add liquidity
        (
            uint256 _amount0Invested,
            uint256 _amount1Invested,
            uint256 _lpAmount
        ) = UniswapRouter.addLiquidity(
            _farmBot.liquidityRouter(),
            _farmBot.stakingToken0(),
            _farmBot.stakingToken1(),
            _amountToken0,
            _amountToken1,
            _liquidityAmounts.amount0Min,
            _liquidityAmounts.amount1Min,
            _deadline
        );

        // if leftovers, swap back to zap token and send back to investor
        uint256 _token0Leftover = _amountToken0 -
                    _amount0Invested;
        if (_token0Leftover > 0) {
            IERC20(_zapTokenAddress).safeTransfer(msg.sender, UniswapRouter.swap(
                _farmBot.swapRouter(),
                ArrayUtils.reverseArray(_path0),
                _token0Leftover,
                IERC20(_farmBot.stakingToken0()),
                0, // TODO consider setting a min amount somehow. Difficult because we won't know in advance how much staking token will be left over. Maybe some minimum exchange rate could be taken as a parameter.
                _deadline
            ));
        }
        uint256 _token1Leftover = _amountToken1 -
                    _amount1Invested;
        if (_token1Leftover > 0) {
            IERC20(_zapTokenAddress).safeTransfer(msg.sender, UniswapRouter.swap(
                _farmBot.swapRouter(),
                ArrayUtils.reverseArray(_path1),
                _token1Leftover,
                IERC20(_farmBot.stakingToken1()),
                0, // TODO consider setting a min amount somehow. Difficult because we won't know in advance how much staking token will be left over. Maybe some minimum exchange rate could be taken as a parameter.
                _deadline
            ));
        }

        // trade LP for FP
        _farmBot.stakingToken().safeIncreaseAllowance(
            _farmBotAddress,
            _lpAmount
        );
        uint256 _prevFPBalance = _farmBot.balanceOf(address(this));
        _farmBot.deposit(_lpAmount);
        uint256 _fpGained = _farmBot.balanceOf(address(this)) - _prevFPBalance;

        // send FP to investor
        IERC20(_farmBotAddress).safeTransfer(msg.sender, _fpGained);


        emit RFPBrokerDeposit( // TODO update event to include zap token address and amount
            _farmBotAddress,
            msg.sender,
            _amount0Invested,
            _amount1Invested,
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
        IERC20(_farmBotAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _fpAmount
        );
        RevoUniswapStakingTokenStrategy _farmBot = RevoUniswapStakingTokenStrategy(
            _farmBotAddress
        );
        uint256 _lpGained;
        {
            uint256 _lpAmount = _farmBot.getLpAmount(_fpAmount);
            uint256 _lpStartBalance = _farmBot.stakingToken().balanceOf(
                address(this)
            ); // should be 0 but just in case
            _farmBot.withdraw(_lpAmount);
            _lpGained =
                _farmBot.stakingToken().balanceOf(address(this)) -
                _lpStartBalance; // can't just use _lpAmount because there is a withdrawal fee
        }
        (uint256 _token0Gained, uint256 _token1Gained) = UniswapRouter
            .removeLiquidity(
            _farmBot.liquidityRouter(),
            _farmBot.stakingToken(),
            address(_farmBot.stakingToken0()),
            address(_farmBot.stakingToken1()),
            _lpGained,
            _amountAMin,
            _amountBMin,
            msg.sender,
            _deadline
        );
        emit RFPBrokerWithdrawal(
            _farmBotAddress,
            msg.sender,
            _fpAmount,
            _lpGained,
            _token0Gained,
            _token1Gained
        );
    }
}
