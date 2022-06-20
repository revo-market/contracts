import { DeployerFn } from "@ubeswap/hardhat-celo"
import {
  RevoUniswapArbitrage__factory,
  ERC20__factory
} from "../../typechain"
import { doTx } from '../utils'
import { ethers } from "ethers"

const AMOUNT_ZAP_TOKEN = ethers.BigNumber.from("100000000000000000") // .1 mcUSD
const ARBITRAGE_ADDRESS = '0x3E5E5e4509b00E8D4B196C2Ba29C8418074f6CB6' // RevoUniswapArbitrage contract address
const MCUSD_ADDRESS = '0x918146359264c492bd6934071c6bd31c854edbc3' // mcUSD
const MCEUR_ADDRESS = '0xE273Ad7ee11dCfAA87383aD5977EE1504aC07568' // mcEUR
const RFP_ADDRESS = '0xCB34fbfC3b9a73bc04D2eb43B62532c7918d9E81' // mcUSD / mcEUR RFP
const BROKER_ADDRESS = '0x97d0D4ae7841c9405A80fB8004dbA96123e076De' // RevoFPBroker contract address

const MIN_AMOUNT_ZAP_TOKEN = ethers.BigNumber.from("50000000000000000") // .05 mcUSD

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  await doTx(
    "Approving RevoUniswapArbitrage to spend .1 mcUSD",
    ERC20__factory.connect(MCUSD_ADDRESS, deployer).approve(
      ARBITRAGE_ADDRESS,
      AMOUNT_ZAP_TOKEN
    )
  )

  await doTx(
    "Attempting Case 1 arbitrage",
    RevoUniswapArbitrage__factory.connect(ARBITRAGE_ADDRESS, deployer).doCase1Arbitrage(
      {
	paths: [
	  [MCUSD_ADDRESS],
	  [MCUSD_ADDRESS, MCEUR_ADDRESS]
	],
	amountsOutMin: [0,0],
	zapPath: [RFP_ADDRESS, MCUSD_ADDRESS],
	minZapTokenOut: MIN_AMOUNT_ZAP_TOKEN,
	minAmountStakingToken0: 0,
	minAmountStakingToken1: 0,
	zapToken: MCUSD_ADDRESS,
	amountZapToken: AMOUNT_ZAP_TOKEN,
	farmBotAddress: RFP_ADDRESS,
	brokerAddress: BROKER_ADDRESS,
	deadline: Math.floor(+new Date() / 1000) + 100
      }
    )
  )

  await doTx(
    "Approving RevoUniswapArbitrage to spend .1 mcUSD",
    ERC20__factory.connect(MCUSD_ADDRESS, deployer).approve(
      ARBITRAGE_ADDRESS,
      AMOUNT_ZAP_TOKEN
    )
  )

  await doTx(
    "Attempting Case 2 arbitrage",
    RevoUniswapArbitrage__factory.connect(ARBITRAGE_ADDRESS, deployer).doCase2Arbitrage(
      {
	paths: [
	  [MCUSD_ADDRESS],
	  [MCEUR_ADDRESS, MCUSD_ADDRESS]
	],
	amountsOutMin: [0,0],
	zapPath: [MCUSD_ADDRESS, RFP_ADDRESS],
	minFpOut: 0,
	minZapTokenOut: MIN_AMOUNT_ZAP_TOKEN,
	minAmountStakingToken0: 0,
	minAmountStakingToken1: 0,
	zapToken: MCUSD_ADDRESS,
	amountZapToken: AMOUNT_ZAP_TOKEN,
	farmBotAddress: RFP_ADDRESS,
	brokerAddress: BROKER_ADDRESS,
	deadline: Math.floor(+new Date() / 1000) + 100
      }
    )
  )
  return {}
}

export default main
