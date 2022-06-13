//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "../library/UniswapRouter.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02SwapOnly.sol";
import "./common/StakingTokenHolder.sol";
import "../openzeppelin-solidity/contracts/SafeERC20.sol";
import "../mobius/interfaces/ILiquidityGaugeV3.sol";
import "../mobius/interfaces/ISwap.sol";
import "../mobius/interfaces/IMinter.sol";

/**
 * RevoMobiusFarmBot is a farmbot appropriate for yield farms on Mobius.
 * The general strategy for reinvestment of rewards is somewhat complicated by the
 * fact that Mobius itself does not provide swap paths from the reward tokens to any
 * of the LP constituent tokens. All of its pools are between some Celo-native version
 * of a token, and a bridged version.
 *
 * RevoMobiusFarmBot takes the yield farming rewards and swaps *all* of them for the
 * Celo-native asset in the staked LP token, using a typical Uniswap router (e.g.,
 * Ubeswap's swap router). It then takes half of these Celo-native tokens and swaps
 * them directly for the bridged version using the liquidity pool that the yield farm
 * itself is built on.
 *
 * Mobius supports adding unequal amounts of LP constituent tokens when minting liquidity,
 * so the final swap mentioned above may not seem necessary. In certain cases where the
 * liquidity in the pool is particularly imbalanced however, Mobius may impose constraints
 * on the ratio of tokens provided when minting liquidity. As such, RevoMobiusFarmBot always
 * attempts to mint liquidity using equal-valued amounts of both LP constituent tokens.
 **/
contract RevoMobiusFarmBot is StakingTokenHolder {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken0;
    IERC20 public stakingToken1;

    IERC20[] public rewardsTokens;

    uint8 public celoNativeStakingTokenIndex;
    uint8 public bridgedStakingTokenIndex;

    IERC20 public celoNativeStakingToken;

    ILiquidityGaugeV3 public liquidityGauge; // The Mobius Liquidity Gauge that mints rewards
    IMinter public minter; // The Minter contract through which Mobius rewards are claimed
    IUniswapV2Router02SwapOnly public router; // A router capable of swapping reward for the stakingToken's Celo-native constituent asset
    ISwap public swap; // The Mobius Swap contract used to swap LP constituent tokens and mint/burn liquidity

    // ISwap's `addLiquidity` method requires a parameter located in calldata, but it must be computed dynamically, and thus cannot
    // be provided by the compounder. This private variable is used as a dynamic array that we can pass as calldata.
    uint256[] private amounts;

    constructor(
        address _owner,
        address _reserveAddress,
        address _stakingToken,
        address _revoFees,
        address[] memory _rewardsTokens,
        address _liquidityGauge,
        address _minter,
        address _router,
        address _swap,
        uint8 _celoNativeStakingTokenIndex,
        string memory _symbol
    )
        StakingTokenHolder(
            _owner,
            _reserveAddress,
            _stakingToken,
            _revoFees,
            _symbol
        )
    {
        liquidityGauge = ILiquidityGaugeV3(_liquidityGauge);
        router = IUniswapV2Router02SwapOnly(_router);
        swap = ISwap(_swap);
        minter = IMinter(_minter);

        stakingToken0 = IERC20(swap.getToken(0));
        stakingToken1 = IERC20(swap.getToken(1));

        for (uint256 i = 0; i < _rewardsTokens.length; i++) {
            rewardsTokens.push(IERC20(_rewardsTokens[i]));
        }

        require(
            _celoNativeStakingTokenIndex <= 1,
            "Index of Celo-native token in the LP must be 0 or 1"
        );
        celoNativeStakingTokenIndex = _celoNativeStakingTokenIndex;
        bridgedStakingTokenIndex = 1 - celoNativeStakingTokenIndex;

        if (celoNativeStakingTokenIndex == 0) {
            celoNativeStakingToken = stakingToken0;
        } else {
            celoNativeStakingToken = stakingToken1;
        }
    }

    function _deposit(uint256 _lpAmount) internal override whenNotPaused {
        require(_lpAmount > 0, "Cannot invest in farm because lpAmount is 0");
        stakingToken.safeIncreaseAllowance(address(liquidityGauge), _lpAmount);
        liquidityGauge.deposit(_lpAmount);
    }

    function _withdraw(uint256 _lpAmount) internal override {
        liquidityGauge.withdraw(_lpAmount);
    }

    function _claimRewards() internal whenNotPaused {
        minter.mint(address(liquidityGauge));
        liquidityGauge.claim_rewards(address(this));
    }

    function compound(
        address[][] memory _paths,
        uint256[] memory _minAmountsOut,
        uint256 _minSwapOut,
        uint256 _minLiquidity,
        uint256 _deadline
    ) external ensure(_deadline) onlyRole(COMPOUNDER_ROLE) whenNotPaused {
        // Important safety checks
        require(
            _paths.length == rewardsTokens.length,
            "Parameter _paths must have length equal to rewardsTokens"
        );
        require(
            _minAmountsOut.length == rewardsTokens.length,
            "Parameter _minAmountsOut must have length equal to rewardsTokens"
        );
        for (uint256 i = 0; i < _paths.length; i++) {
            require(
                _paths[i][0] == address(rewardsTokens[i]),
                "Invalid path start"
            );
            require(
                _paths[i][_paths[i].length - 1] ==
                    address(celoNativeStakingToken),
                "Each swap path must end with the Celo-native staking token"
            );
        }

        // Get native and external rewards
        _claimRewards();

        // Get the current balance of rewards tokens
        uint256[] memory _tokenBalances = new uint256[](rewardsTokens.length);
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            _tokenBalances[i] = rewardsTokens[i].balanceOf(address(this));
        }

        // Swap rewards for the Celo-native LP constituent token
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            UniswapRouter.swap(
                router,
                _paths[i],
                _tokenBalances[i],
                rewardsTokens[i],
                _minAmountsOut[i],
                _deadline
            );
        }

        uint256 halfCeloNativeStakingTokenBalance = celoNativeStakingToken
            .balanceOf(address(this)) / 2;

        // Take half the Celo-native staking token and swap it for the bridged version
        celoNativeStakingToken.safeIncreaseAllowance(
            address(swap),
            halfCeloNativeStakingTokenBalance
        );

        swap.swap(
            celoNativeStakingTokenIndex,
            bridgedStakingTokenIndex,
            halfCeloNativeStakingTokenBalance,
            _minSwapOut,
            _deadline
        );

        uint256 stakingToken0Balance = stakingToken0.balanceOf(address(this));
        uint256 stakingToken1Balance = stakingToken1.balanceOf(address(this));

        // Make sure the dynamic `amounts` variable is empty, then add the balances and mint liquidity
        delete amounts;
        amounts.push(stakingToken0Balance);
        amounts.push(stakingToken1Balance);

        stakingToken0.safeIncreaseAllowance(
            address(swap),
            stakingToken0Balance
        );
        stakingToken1.safeIncreaseAllowance(
            address(swap),
            stakingToken1Balance
        );
        swap.addLiquidity(amounts, _minLiquidity, _deadline);

        // Send fees and bonus, then deposit the remaining LP in the farm
        (
            uint256 lpEarnings,
            uint256 compounderFee,
            uint256 reserveFee
        ) = issuePerformanceFeesAndBonus();

        _deposit(lpEarnings);

        updateFpWeightAndInterestRate(lpEarnings);

        emit Compound(
            msg.sender,
            lpEarnings,
            lpTotalBalance,
            compounderFee,
            reserveFee
        );
    }
}
