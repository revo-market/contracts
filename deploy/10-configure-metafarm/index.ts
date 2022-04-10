import { DeployerFn } from "@ubeswap/hardhat-celo"
import {
  StakingRewards__factory,
  MoolaStakingRewards__factory,
  ERC20__factory
} from "../../typechain"
import { doTx } from '../utils'
import { ethers } from "ethers"

const MOBI_ADDRESS = "0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B" // MOBI
const CELO_ADDRESS = "0x471ece3750da237f93b8e339c536989b8978a438" // CELO

const STAKING_REWARDS_ADDRESS = '0x939DC5033608Fae837f26C85f1616B6fF204fA20'
const MOOLA_STAKING_REWARDS_ADDRESS = '0x26B819D77CcaB96253F5756760EFE3D57dCccf14'

const AMOUNT_MOBI = ethers.BigNumber.from("1000000000000000000") // 1 MOBI
const AMOUNT_CELO = ethers.BigNumber.from("5000000000000000") // .005 CELO

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  await doTx(
    "Sending 1 MOBI to StakingRewards",
    ERC20__factory.connect(MOBI_ADDRESS, deployer).transfer(
      STAKING_REWARDS_ADDRESS,
      AMOUNT_MOBI
    )
  )

  await doTx(
    "Notifying StakingRewards of 1 MOBI reward",
    StakingRewards__factory.connect(STAKING_REWARDS_ADDRESS, deployer).notifyRewardAmount(
      AMOUNT_MOBI
    )
  )

  await doTx(
    "Sending .005 CELO to MoolaStakingRewards",
    ERC20__factory.connect(CELO_ADDRESS, deployer).transfer(
      MOOLA_STAKING_REWARDS_ADDRESS,
      AMOUNT_CELO
    )
  )

  await doTx(
    "Notifying MoolaStakingRewards of .005 MOBI reward",
    MoolaStakingRewards__factory.connect(MOOLA_STAKING_REWARDS_ADDRESS, deployer).notifyRewardAmount(
      AMOUNT_CELO
    )
  )

  return {}
}

export default main
