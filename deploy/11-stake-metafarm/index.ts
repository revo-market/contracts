import { DeployerFn } from "@ubeswap/hardhat-celo"
import {
  MoolaStakingRewards__factory,
  ERC20__factory
} from "../../typechain"
import { ContractTransaction } from "ethers"
import { ethers } from "ethers"

const STAKING_TOKEN_ADDRESS = '0x25938830fbd7619bf6cfcfdf5c37a22ab15a93ca' // mcUSD / mcUSD-mcEUR-FP liquidity pool

const MOOLA_STAKING_REWARDS_ADDRESS = '0x26B819D77CcaB96253F5756760EFE3D57dCccf14'

const AMOUNT_STAKING_TOKEN = ethers.BigNumber.from("1000000000000000") // .001 mcUSD / mcUSD-mcEUR-FP

function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

export const doTx = async (
  action: string,
  tx: Promise<ContractTransaction>
): Promise<void> => {
  console.log(`Performing ${action}...`);
  const result = await (await tx).wait();
  console.log(`${action} done at tx ${result.transactionHash}`);
};

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  await doTx(
    "Approving MoolaStakingRewards to spend .001 meta-liquidity",
    ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).approve(
      MOOLA_STAKING_REWARDS_ADDRESS,
      AMOUNT_STAKING_TOKEN
    )
  )

  await doTx(
    "Staking .001 meta-liquidity in MoolaStakingRewards",
    MoolaStakingRewards__factory.connect(MOOLA_STAKING_REWARDS_ADDRESS, deployer).stake(
      AMOUNT_STAKING_TOKEN
    )
  )

  await sleep(5000) // Wait 5s

  await doTx(
    "Getting rewards from MoolaStakingRewards",
    MoolaStakingRewards__factory.connect(MOOLA_STAKING_REWARDS_ADDRESS, deployer).getReward()
  )

  await doTx(
    "Withdrawing meta-liquidity from MoolaStakingRewards",
    MoolaStakingRewards__factory.connect(MOOLA_STAKING_REWARDS_ADDRESS, deployer).withdraw(
      AMOUNT_STAKING_TOKEN
    )
  )

  return {}
}

export default main
