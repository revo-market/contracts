import { DeployerFn } from '@ubeswap/hardhat-celo';

/**
 * Deploy script for Revo contracts.
 *
 * NOTE: for the first time you compile contracts with this repo,
 *  the typechain generated types will be missing and cause import errors.
 *  Since this script is used by our hardhat config (to add a 'deploy' task),
 *  this will block contract compilation!
 *
 *  As a workaround, for your first time compiling contracts, uncomment the empty 'main' function below, and comment out
 *    everything below it.
 *  (Yes, this is totally lame.)
 */

// export const main: DeployerFn<any> = async() => {}  // uncomment for first-time contract compilation

import {FarmBot__factory, FeeOnlyBounty__factory} from "../typechain";
export const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {

  const ALFAJORES_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd" // Owner
  const STAKING_REWARDS_ADDRESS = "0x734913751D7390c32410eD2c71Bb1d8210d7570B" // StakingRewards
  const ROUTER_ADDRESS = "0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121" // Ubeswap Router
  const path0: string[] = [] // path0 should be empty since token0 == rewardsToken == cUSD
  const path1 = [
    "0x874069fa1eb16d44d622f2e0ca25eea172369bc1", // cUSD
    "0xf194afdf50b03e69bd7d057c1aa9e10c9954e4c9"  // CELO
  ]
  const revoBounty = await deployCreate2('FeeOnlyBounty_2', {
    factory: FeeOnlyBounty__factory,
    signer: deployer,
    args: [
      ALFAJORES_ADDRESS,
      1,
      1000
    ]
  })

  const farmBot = await deployCreate2('FarmBot_2', {
    factory: FarmBot__factory,
    signer: deployer,
    args: [
      ALFAJORES_ADDRESS, STAKING_REWARDS_ADDRESS, revoBounty.address, ROUTER_ADDRESS, path0, path1, 'cUSD_CELO_FP'
    ],
  })

  return {
    FarmBot: farmBot.address,
    RevoBounty: revoBounty.address,
  }
}
