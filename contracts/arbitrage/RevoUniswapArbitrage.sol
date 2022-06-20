//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "../openzeppelin-solidity/contracts/ERC20.sol";
import "../openzeppelin-solidity/contracts/SafeERC20.sol";
import "../fp-broker/RevoFPBroker.sol";
import "../ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Router02SwapOnly.sol";
import "../library/UniswapRouter.sol";
import "../farms/common/RevoUniswapStakingTokenStrategy.sol";

struct Case1Arguments {
    address[][2] paths;
    uint256[2] amountsOutMin;
    address[] zapPath;
    uint256 minZapTokenOut;
    uint256 minAmountStakingToken0;
    uint256 minAmountStakingToken1;
    address zapToken;
    uint256 amountZapToken;
    address farmBotAddress;
    address brokerAddress;
    uint256 deadline;
}

struct Case2Arguments {
    address[][2] paths;
    uint256[2] amountsOutMin;
    address[] zapPath;
    uint256 minFpOut;
    uint256 minZapTokenOut;
    uint256 minAmountStakingToken0;
    uint256 minAmountStakingToken1;
    address zapToken;
    uint256 amountZapToken;
    address farmBotAddress;
    address brokerAddress;
    uint256 deadline;
}

/**
 * RevoUniswapArbitrage is an almost-stateless contract capable of atomic arbitrage on RFPs that inherit
 * from RevoUniswapStakingTokenStrategy. See the (extensive) docstrings below for information on how to
 * execute arbitrage attempts. The only reason this contract is stateful (and not a library contract) is
 * so that tokens may be recovered in the case of rounding errors or accidental transfers to this address.
 **/
contract RevoUniswapArbitrage is Pausable, AccessControl {
    using SafeERC20 for IERC20;

    constructor(address _owner) {
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "RevoUniswapArbitrage: EXPIRED");
        _;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // This contract should not hold any tokens. However, in the case of rounding errors, or
    // if tokens are for some reason sent directly to this contract, this method allows
    // an admin to recover lost funds.
    function collectDust(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _tokenBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, _tokenBalance);
    }

    /**
     * Attempts to perform "Case 1" arbitrage. This is profitable when the cost of swapping for RFP
     * is greater than the cost of minting LP from scratch and depositing it for FP. This method attempts to:
     *
     *  * Take some initial ERC20 token and swap equal parts of it for the tokens comprising the LP within some RFP (stakingToken0 / stakingToken1).
     *  * Use stakingToken0 and stakingToken1 to mint LP.
     *  * Deposit that LP into a farm, minting new RFP.
     *  * Swap the resulting RFP for the original ERC20 token.
     *
     * If the final swap results in enough of the original ERC20 token, according to some user-defined threshold, the function will send the tokens to
     * the caller, otherwise it will revert. This means that, subject to the values provided for function parameters, a successful (non-reverting)
     * call to this function guarantees the caller a profit.
     *
     * There are several constraints on the input parameters and preconditions for calling this function.
     * Before calling this function, the caller must approve this contract to spend _args.amountZapToken of _args.zapToken.
     * _args.paths[0][-1] must be equal to stakingToken0 in _args.farmBotAddress, and _args.paths[1][-1] must be equal to stakingToken1
     * in _args.farmBotAddress, to ensure that the initial pair of swaps actually swap for the correct staking tokens. Likewise,
     * _args.paths[0][0] and _args.paths[1][0] must both be equal to _args.zapToken, to ensure that swaps actually begin with the
     * token provided by the caller.
     *
     * The path provided for the final swap from RFP back to the starting token must also begin with _args.farmBotAddress and end with
     * _args.zapToken, for similar reasons to the above.
     *
     * On success, this function will always send at least _args.minZapTokenOut to the caller. Due to how LP is minted, some of the RFP's
     * stakingToken0 and stakingToken1 obtained from the initial set of swaps may be left over. If this happens, these will be sent
     * back to the caller as well.
     *
     * @param _args {Case1Arguments} A struct containing required arguments
     * @param _args.paths {address[][2]} An array of two arrays, each representing a path to use for the initial set of swaps
     * @param _args.amountsOutMin {uint256[2]} An array of two values, representing the minimum amount out for each of the two initial swaps
     * @param _args.zapPath {uint256[]} An array representing the path to use for the swap from RFP back to the original zap token
     * @param _args.minZapTokenOut {uint256} The minimum amount of the zap token to receive for arbitrage to be successful
     * @param _args.minAmountStakingToken0 {uint256} Minimum amount of stakingToken0 to use when minting liquidity
     * @param _args.minAmountStakingToken1 {uint256} Minimum amount of stakingToken1 to use when minting liquidity
     * @param _args.zapToken {address} The token to use to perform arbitrage
     * @param _args.amountZapToken {uint256} The amount of the zap token to use for this arbitrage attempt
     * @param _args.farmBotAddress {address} The address of the RFP used in this arbitrage attempt
     * @param _args.brokerAddress {address} The address of the broker contract used to mint RFP
     * @param _args.deadline {uint256} Deadline by which the execution must complete
     **/
    function doCase1Arbitrage(Case1Arguments calldata _args)
        external
        ensure(_args.deadline)
        whenNotPaused
        returns (uint256)
    {
        RevoUniswapStakingTokenStrategy _farmBot = RevoUniswapStakingTokenStrategy(
                _args.farmBotAddress
            );

        require(
            _args.zapToken == _args.zapPath[_args.zapPath.length - 1],
            "RevoUniswapArbitrage: Zap path does not end with zapToken"
        );
        require(
            _args.farmBotAddress == _args.zapPath[0],
            "RevoUniswapArbitrage: Zap path does not start with RFP"
        );
        require(
            _args.paths[0][_args.paths[0].length - 1] ==
                address(_farmBot.stakingToken0()),
            "RevoUniswapArbitrage: Swap path 0 does not end with stakingToken0"
        );
        require(
            _args.paths[1][_args.paths[1].length - 1] ==
                address(_farmBot.stakingToken1()),
            "RevoUniswapArbitrage: Swap path 1 does not end with stakingToken1"
        );
        require(
            _args.paths[0][0] == _args.zapToken,
            "RevoUniswapArbitrage: Swap path 0 does not start with zapToken"
        );
        require(
            _args.paths[1][0] == _args.zapToken,
            "RevoUniswapArbitrage: Swap path 1 does not start with zapToken"
        );

        // Since the contract may already be holding some staking tokens, some bookkeeping is necessary to know how much we can spend
        // Due to a tricky edge case where the zap token may be one of the liquidity tokens, we have to set the initial liquidity token
        // balance before transferring the caller's zap token.
        uint256[] memory _liquidityTokenBalances = new uint256[](2);
        uint256[2] memory _initialLiquidityTokenBalances = [
            _farmBot.stakingToken0().balanceOf(address(this)),
            _farmBot.stakingToken1().balanceOf(address(this))
        ];

        // Get start token from sender, swap both halves for stakingToken0 and stakingToken1
        IERC20(_args.zapToken).safeTransferFrom(
            msg.sender,
            address(this),
            _args.amountZapToken
        );
        uint256 _halfStartTokens = _args.amountZapToken / 2;

        for (uint256 i = 0; i < _args.paths.length; i++) {
            IERC20 _liquidityToken = IERC20(
                _args.paths[i][_args.paths[i].length - 1]
            );

            _liquidityTokenBalances[i] = UniswapRouter.swap(
                _farmBot.swapRouter(),
                _args.paths[i],
                _halfStartTokens,
                IERC20(_args.zapToken),
                _args.amountsOutMin[i],
                _args.deadline
            );

            // Pre-approve the broker to spend the liquidity constituent token we swapped for
            _liquidityToken.safeIncreaseAllowance(
                _args.brokerAddress,
                _liquidityTokenBalances[i]
            );
        }

        LiquidityAmounts memory _liquidityAmounts = LiquidityAmounts(
            _liquidityTokenBalances[0],
            _liquidityTokenBalances[1],
            _args.minAmountStakingToken0,
            _args.minAmountStakingToken1
        );

        uint256 _initialFpBalance = IERC20(_args.farmBotAddress).balanceOf(
            address(this)
        );
        // Mint FP using the broker; the broker will send this contract some FP and any remaining stakingToken0 and stakingToken1.
        // any stakingToken0 and stakingToken1 returned by the broker should be sent back to the sender
        RevoFPBroker(_args.brokerAddress).getUniswapLPAndDeposit(
            _args.farmBotAddress,
            _liquidityAmounts,
            _args.deadline
        );

        // Swap the RFP for the original starting token. The caller specifies the minimum deisred amount in _args.minZapTokenOut.
        // Since the swap will fail if the output amount is below this value, the caller is guaranteed a profit if _args.minZapTokenOut
        // is greater than _args.amountZapToken and the function returns.
        uint256 _amountZapTokenOut = UniswapRouter.swap(
            _farmBot.swapRouter(),
            _args.zapPath,
            IERC20(_args.farmBotAddress).balanceOf(address(this)) -
                _initialFpBalance,
            IERC20(_args.farmBotAddress),
            _args.minZapTokenOut,
            _args.deadline
        );

        // Extra safety check; should not be strictly necessary if the swap router is honest
        require(
            _amountZapTokenOut >= _args.minZapTokenOut,
            "RevoUniswapArbitrage: Arbitrage is not profitable"
        );

        // Send original token back to sender, along with any constituent LP tokens that went unused by the broker
        IERC20(_args.zapToken).safeTransfer(msg.sender, _amountZapTokenOut);
        for (uint256 i = 0; i < _args.paths.length; i++) {
            IERC20 _liquidityToken = IERC20(
                _args.paths[i][_args.paths[i].length - 1]
            );
            uint256 _amountReturnedLiquidityToken = IERC20(_liquidityToken)
                .balanceOf(address(this)) - _initialLiquidityTokenBalances[i];
            if (_amountReturnedLiquidityToken > 0) {
                _liquidityToken.safeTransfer(
                    msg.sender,
                    _amountReturnedLiquidityToken
                );
            }
        }
        return _amountZapTokenOut;
    }

    /**
     * Attempts to perform "Case 2" arbitrage. This is profitable when the cost of swapping for RFP
     * is less than the cost of minting LP from scratch and depositing it for FP. This method attempts to:
     *
     *  * Take some initial ERC20 token and swap it for RFP.
     *  * Burn the RFP in exchange for the underlying LP.
     *  * Burn the LP for the constituent LP tokens (stakingToken0 and stakingToken1).
     *  * Swap the resulting constituent LP tokens for the initial ERC20 token.
     *
     * If the final swaps result in enough of the original ERC20 token, according to some user-defined threshold, the function will send the tokens to
     * the caller, otherwise it will revert. This means that, subject to the values provided for function parameters, a successful (non-reverting)
     * call to this function guarantees the caller a profit.
     *
     * There are several constraints on the input parameters and preconditions for calling this function.
     * Before calling this function, the caller must approve this contract to spend _args.amountZapToken of _args.zapToken.
     * _args.paths[0][0] must be equal to stakingToken0 in _args.farmBotAddress, and _args.paths[1][0] must be equal to stakingToken1
     * in _args.farmBotAddress, to ensure that the final pair of swaps actually swaps from the staking tokens. Likewise,
     * _args.paths[0][-1] and _args.paths[1][-1] must both be equal to _args.zapToken, to ensure that swaps actually end with the
     * token provided by the caller.
     *
     * The path provided for the initial swap to RFP back to the starting token must also begin with _args.zapToken and end with
     * _args.farmBotAddress, for similar reasons to the above.
     *
     * On success, this function will always send at least _args.minZapTokenOut to the caller.
     *
     * @param _args {Case2Arguments} A struct containing required arguments
     * @param _args.paths {address[][2]} An array of two arrays, each representing a path to use for the final set of swaps
     * @param _args.amountsOutMin {uint256[2]} An array of two values, representing the minimum amount out for each of the two final swaps
     * @param _args.zapPath {uint256[]} An array representing the path to use for the initial swap from the zap token to RFP
     * @param _args.minFpOut {uint256} The minimum amount of RFP to receive for the initial swap
     * @param _args.minZapTokenOut {uint256} The minimum amount of the zap token to receive for arbitrage to be successful
     * @param _args.minAmountStakingToken0 {uint256} Minimum amount of stakingToken0 to receive when burning liquidity
     * @param _args.minAmountStakingToken1 {uint256} Minimum amount of stakingToken1 to receive when burning liquidity
     * @param _args.zapToken {address} The token to use to perform arbitrage
     * @param _args.amountZapToken {uint256} The amount of the zap token to use for this arbitrage attempt
     * @param _args.farmBotAddress {address} The address of the RFP used in this arbitrage attempt
     * @param _args.brokerAddress {address} The address of the broker contract used to burn RFP
     * @param _args.deadline {uint256} Deadline by which the execution must complete
     **/
    function doCase2Arbitrage(Case2Arguments calldata _args)
        external
        ensure(_args.deadline)
        whenNotPaused
        returns (uint256)
    {
        RevoUniswapStakingTokenStrategy _farmBot = RevoUniswapStakingTokenStrategy(
                _args.farmBotAddress
            );
        require(
            _args.zapToken == _args.zapPath[0],
            "RevoUniswapArbitrage: Zap path does not start with zapToken"
        );
        require(
            _args.farmBotAddress == _args.zapPath[_args.zapPath.length - 1],
            "RevoUniswapArbitrage: Zap path does not end with RFP"
        );
        require(
            _args.paths[0][0] == address(_farmBot.stakingToken0()),
            "RevoUniswapArbitrage: Swap path 0 does not start with stakingToken0"
        );
        require(
            _args.paths[1][0] == address(_farmBot.stakingToken1()),
            "RevoUniswapArbitrage: Swap path 1 does not start with stakingToken1"
        );
        require(
            _args.paths[0][_args.paths[0].length - 1] == _args.zapToken,
            "RevoUniswapArbitrage: Swap path 0 does not end with zapToken"
        );
        require(
            _args.paths[1][_args.paths[1].length - 1] == _args.zapToken,
            "RevoUniswapArbitrage: Swap path 1 does not end with zapToken"
        );

        // Since the contract may already be holding some staking tokens, some bookkeeping is necessary to know how much we can spend
        // Due to a tricky edge case where the zap token may be one of the liquidity tokens, we have to set the initial liquidity token
        // balance before transferring the caller's zap token.
        uint256 _initialStakingToken0Balance = _farmBot
            .stakingToken0()
            .balanceOf(address(this));
        uint256 _initialStakingToken1Balance = _farmBot
            .stakingToken1()
            .balanceOf(address(this));

        // Get start token from sender, swap it for RFP
        IERC20(_args.zapToken).safeTransferFrom(
            msg.sender,
            address(this),
            _args.amountZapToken
        );

        uint256 _amountFpOut = UniswapRouter.swap(
            _farmBot.swapRouter(),
            _args.zapPath,
            _args.amountZapToken,
            IERC20(_args.zapToken),
            _args.minFpOut,
            _args.deadline
        );

        // Burn FP and LP for stakingToken0 and stakingToken1 using the broker
        IERC20(_args.farmBotAddress).safeIncreaseAllowance(
            _args.brokerAddress,
            _amountFpOut
        );
        RevoFPBroker(_args.brokerAddress).withdrawFPForStakingTokens(
            _args.farmBotAddress,
            _amountFpOut,
            _args.minAmountStakingToken0,
            _args.minAmountStakingToken1,
            _args.deadline
        );

        uint256[2] memory _amountStakingTokens = [
            _farmBot.stakingToken0().balanceOf(address(this)) -
                _initialStakingToken0Balance,
            _farmBot.stakingToken1().balanceOf(address(this)) -
                _initialStakingToken1Balance
        ];

        // Swap stakingToken0 and stakingToken1 for the zap token
        uint256 _zapTokenBalance = 0;
        for (uint256 i = 0; i < _args.paths.length; i++) {
            _zapTokenBalance += UniswapRouter.swap(
                _farmBot.swapRouter(),
                _args.paths[i],
                _amountStakingTokens[i],
                IERC20(_args.paths[i][0]),
                _args.amountsOutMin[i],
                _args.deadline
            );
        }

        require(
            _zapTokenBalance > _args.minZapTokenOut,
            "RevoUniswapArbitrage: Arbitrage is not profitable"
        );

        IERC20(_args.zapToken).safeTransfer(msg.sender, _zapTokenBalance);
        return _zapTokenBalance;
    }
}
