import { DeployerFn } from "@ubeswap/hardhat-celo"
import { StakingRewards__factory } from "../../typechain"
import { MoolaStakingRewards__factory } from "../../typechain"
import { ContractTransaction } from "ethers"

const OWNER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd" // Temporary owner, should change to multi-sig
const REWARDS_DISTRIBUTION_ADDRESS = OWNER_ADDRESS
const STAKING_TOKEN_ADDRESS = '0x25938830fbd7619bf6cfcfdf5c37a22ab15a93ca' // mcUSD / mcUSD-mcEUR-FP liquidity pool

const MOBI_ADDRESS = "0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B" // MOBI
const CELO_ADDRESS = "0x471ece3750da237f93b8e339c536989b8978a438" // CELO

export const doTx = async (
  action: string,
  tx: Promise<ContractTransaction>
): Promise<void> => {
  console.log(`Performing ${action}...`);
  const result = await (await tx).wait();
  console.log(`${action} done at tx ${result.transactionHash}`);
};

const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {

  // Deploy base-most StakingRewards contract (pays MOBI)
  const stakingRewards = await deployCreate2('StakingRewards', {
    factory: StakingRewards__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
      REWARDS_DISTRIBUTION_ADDRESS,
      MOBI_ADDRESS,
      STAKING_TOKEN_ADDRESS
    ]
  })

  // Deploy second-level, multi-reward MoolaStakingRewards contract (pays CELO, MOBI by extension)
  const moolaStakingRewards = await deployCreate2('MoolaStakingRewards', {
    factory: MoolaStakingRewards__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
      REWARDS_DISTRIBUTION_ADDRESS,
      CELO_ADDRESS,
      stakingRewards.address,
      [MOBI_ADDRESS],
    ]
  })

  return {
    stakingRewards: stakingRewards.address,
    moolaStakingRewards: moolaStakingRewards.address
  }
}

export default main
