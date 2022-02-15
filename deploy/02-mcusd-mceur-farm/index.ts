import { DeployerFn } from "@ubeswap/hardhat-celo"
import { UbeswapFarmBot__factory } from "../../typechain"

const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {
  const OWNER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd" // Temporary owner, should change to multi-sig
  const RESERVE_ADDRESS = "0x99649aF776ff1b024F12e8Fe9dfA59A6c0b4bD9C" // Multi-sig owner
  const STAKING_REWARDS_ADDRESS = "0x2Ca16986bEA18D562D26354b4Ff4C504F14fB01c" // MoolaStakingRewards address
  const STAKING_TOKEN_ADDRESS = "0xf94fea0c87d2b357dc72b743b45a8cb682b0716e" // mcUSD-mcEUR LP address
  const REVO_FEES_ADDRESS = "0xa8481Db4C3C7B4F3ce7E28076bD3d7E877f60B62" // RevoFees address
  const ROUTER_ADDRESS = "0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121" // Ubeswap Router address
  const REWARDS_TOKENS = [
    "0x471EcE3750Da237f93B8E339c536989b8978a438", // CELO
    "0x00be915b9dcf56a3cbe739d9b9c202ca692409ec", // UBE
    "0x17700282592d6917f6a73d0bf8accf4d578c131e", // MOO
  ]
  const SYMBOL = "RFP" // "Revo Farm Point". Same convention as Ubeswap's "ULP".

  const ubeswapFarmBot = await deployCreate2('UbeswapFarmBot', {
    factory: UbeswapFarmBot__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
      RESERVE_ADDRESS,
      STAKING_REWARDS_ADDRESS,
      STAKING_TOKEN_ADDRESS,
      REVO_FEES_ADDRESS,
      ROUTER_ADDRESS,
      REWARDS_TOKENS,
      SYMBOL
    ]
  })

  return {
    UbeswapFarmBot: ubeswapFarmBot.address,
  }
}

export default main
