import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoMobiusFarmBot__factory } from "../../typechain"

const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {
  const OWNER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd" // Temporary owner, should change to multi-sig
  const RESERVE_ADDRESS = "0x99649aF776ff1b024F12e8Fe9dfA59A6c0b4bD9C" // Multi-sig owner
  const STAKING_TOKEN_ADDRESS = "0x39b6F09ef97dB406ab78D869471adb2384C494E3" // cUSD/cUSDC LP
  const REVO_FEES_ADDRESS = "0x3b9ffc0ebb0164daf0c94f88df29a6e46e984d12" // RevoFees address
  const LIQUIDITY_GAUGE_ADDRESS = "0xc96AeeaFF32129da934149F6134Aa7bf291a754E"
  const MINTER_ADDRESS = "0x5F0200CA03196D5b817E2044a0Bb0D837e0A7823"
  const ROUTER_ADDRESS = "0x7D28570135A2B1930F331c507F65039D4937f66c" // UbeswapMoolaRouter address
  const SWAP_ADDRESS = "0x9906589Ea8fd27504974b7e8201DF5bBdE986b03"
  const CELO_NATIVE_STAKING_TOKEN_INDEX = 0;
  const REWARDS_TOKENS = [
    "0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B", // MOBI
    "0x471ece3750da237f93b8e339c536989b8978a438"  // CELO
  ]
  const SYMBOL = "RFP" // "Revo Farm Point". Same convention as Ubeswap's "ULP".

  const revoMobiusFarmBot = await deployCreate2('RevoMobiusFarmBot', {
    factory: RevoMobiusFarmBot__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
      RESERVE_ADDRESS,
      STAKING_TOKEN_ADDRESS,
      REVO_FEES_ADDRESS,
      REWARDS_TOKENS,
      LIQUIDITY_GAUGE_ADDRESS,
      MINTER_ADDRESS,
      ROUTER_ADDRESS,
      SWAP_ADDRESS,
      CELO_NATIVE_STAKING_TOKEN_INDEX,
      SYMBOL
    ]
  })

  return {
    RevoMobiusFarmBot: revoMobiusFarmBot.address,
  }
}

export default main
