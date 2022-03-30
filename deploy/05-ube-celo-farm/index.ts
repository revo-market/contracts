import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoUbeswapSingleRewardFarmBot__factory } from "../../typechain"

const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {
  const OWNER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd" // Temporary owner, should change to multi-sig
  const RESERVE_ADDRESS = "0x99649aF776ff1b024F12e8Fe9dfA59A6c0b4bD9C" // Multi-sig owner
  const STAKING_REWARDS_ADDRESS = "0x295D6f96081fEB1569d9Ce005F7f2710042ec6a1" // StakingRewards address
  const STAKING_TOKEN_ADDRESS = "0xe7B5AD135fa22678F426A381C7748f6A5f2c9E6C" // UBE-CELO LP address
  const REVO_FEES_ADDRESS = "0x3b9ffc0ebb0164daf0c94f88df29a6e46e984d12" // RevoFees address
  const SWAP_ROUTER_ADDRESS = "0x7D28570135A2B1930F331c507F65039D4937f66c" // UbeswapMoolaRouter address
  const LIQUIDITY_ROUTER_ADDRESS = "0xe3d8bd6aed4f159bc8000a9cd47cffdb95f96121" // UniswapV2Router02 address
  const REWARDS_TOKENS = [
    "0x00be915b9dcf56a3cbe739d9b9c202ca692409ec", // UBE
  ]
  const SYMBOL = "RFP" // "Revo Farm Point". Same convention as Ubeswap's "ULP".

  const revoUbeswapSingleRewardFarmBot = await deployCreate2('RevoUbeswapSingleRewardFarmBot', {
    factory: RevoUbeswapSingleRewardFarmBot__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
      RESERVE_ADDRESS,
      STAKING_REWARDS_ADDRESS,
      STAKING_TOKEN_ADDRESS,
      REVO_FEES_ADDRESS,
      REWARDS_TOKENS,
      SWAP_ROUTER_ADDRESS,
      LIQUIDITY_ROUTER_ADDRESS,
      SYMBOL
    ]
  })

  return {
    RevoUbeswapSingleRewardFarmBot: revoUbeswapSingleRewardFarmBot.address,
  }
}

export default main
