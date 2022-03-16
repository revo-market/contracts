//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "./RevoFarmBot.sol";
import "../../library/UniswapRouter.sol";
import "../../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02SwapOnly.sol";
import "../../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";

/**
 * RevoUniswapStakingTokenStrategy is an abstract class suitable for use when implementing a RevoFarmBot atop of
 * a farm whose staked token implements IUniswapV2Pair02. The reward tokens are swapped
 * for the LP constituent tokens through a contract implementing IUniswapV2Router02, and
 * liquidity is minted through calls to an IUniswapV2Router02 contract, though not
 * necessarily the same one used for swaps.
 *
 * This is a common enough use-case such that an intermediate abstract base class is justified.
 * In particular, this applies to both Sushiswap and Ubeswap, regardless of the underlying farm.
 **/
abstract contract RevoUniswapStakingTokenStrategy is RevoFarmBot {
    event LiquidityRouterUpdated(
        address indexed by,
        address indexed routerAddress
    );
    event SwapRouterUpdated(address indexed by, address indexed routerAddress);

    IUniswapV2Router02SwapOnly public swapRouter; // address to use for router that handles swaps
    IUniswapV2Router02 public liquidityRouter; // address to use for router that handles minting liquidity

    IERC20 public stakingToken0; // LP token0
    IERC20 public stakingToken1; // LP token1

    constructor(
        address _owner,
        address _reserveAddress,
        address _stakingToken,
        address _revoFees,
        address[] memory _rewardsTokens,
        address _swapRouter,
        address _liquidityRouter,
        string memory _symbol
    )
        RevoFarmBot(
            _owner,
            _reserveAddress,
            _stakingToken,
            _revoFees,
            _rewardsTokens,
            _symbol
        )
    {
        swapRouter = IUniswapV2Router02SwapOnly(_swapRouter);
        liquidityRouter = IUniswapV2Router02(_liquidityRouter);

        stakingToken0 = IERC20(IUniswapV2Pair(address(stakingToken)).token0());
        stakingToken1 = IERC20(IUniswapV2Pair(address(stakingToken)).token1());
    }

    function updateLiquidityRouterAddress(address _liquidityRouter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        liquidityRouter = IUniswapV2Router02(_liquidityRouter);
        emit LiquidityRouterUpdated(msg.sender, _liquidityRouter);
    }

    function updateSwapRouterAddress(address _swapRouter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        swapRouter = IUniswapV2Router02SwapOnly(_swapRouter);
        emit SwapRouterUpdated(msg.sender, _swapRouter);
    }

    /**
     * The _paths parameter represents a list of paths to use when swapping each rewards token to token0/token1 of the LP.
     *  Each top-level entry represents a pair of paths for each rewardsToken.
     *
     * Example:
     *  // string token names used in place of addresses for readability
     *  rewardsTokens = ['cUSD', 'Celo', 'UBE']
     *  stakingTokens = ['cEUR', 'MOO']
     *  paths = [
     *    [ // paths from cUSD to staking tokens
     *      ['cUSD', 'cEUR'], // order matters here (need first staking token first)
     *      ['cUSD', 'mcUSD', 'MOO']
     *    ],
     *    [ // paths from Celo to staking tokens
     *      ...
     *    ],
     *    [ // paths from UBE to staking tokens
     *      ...
     *    ]
     *  ]
     *
     * The _minAmountsOut parameter represents a list of minimum amounts for token0/token1 we expect to receive when swapping
     *  each rewardsToken. If we do not receive at least this much of token0/token1 for some swap, the transaction will revert.
     * If a path corresponding to some swap has length < 2, the minimum amount specified for that swap will be ignored.
     */
    function compound(
        address[][2][] memory _paths,
        uint256[2][] memory _minAmountsOut,
        uint256 _deadline
    ) external ensure(_deadline) onlyRole(COMPOUNDER_ROLE) whenNotPaused {
        require(
            _paths.length == rewardsTokens.length,
            "Parameter _paths must have length equal to rewardsTokens"
        );
        require(
            _minAmountsOut.length == rewardsTokens.length,
            "Parameter _minAmountsOut must have length equal to rewardsTokens"
        );

        // Get rewards from farm
        _claimRewards();

        // Swap rewards tokens for equal value of LP tokens
        (uint256 _amountToken0, uint256 _amountToken1) = UniswapRouter
            .swapTokensForEqualAmounts(
                swapRouter,
                getRewardsTokensBalances(),
                _paths,
                rewardsTokens,
                _minAmountsOut,
                _deadline
            );

        // Mint LP
        UniswapRouter.addLiquidity(
            liquidityRouter,
            stakingToken0,
            stakingToken1,
            _amountToken0,
            _amountToken1,
            (_amountToken0 * slippageNumerator) / slippageDenominator,
            (_amountToken1 * slippageNumerator) / slippageDenominator,
            _deadline
        );

        // Send fees, then deposit the LP in the farm
        investAllAndSendFees();
    }
}
