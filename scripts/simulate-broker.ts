import {getFarmBotContract, getKit} from "../src/farm-bot-api";
import BigNumber from "bignumber.js";
const ERC20_ABI = require('../abis/erc20.json')
const ROUTER_ABI = require('../abis/router.json')


async function getConfig() {
  const investorKit = await getKit(process.env.PRIVATE_KEY!!)
  const farmBotAddress = process.env.FARM_BOT_ADDRESS!!
  const fpAmount = investorKit.web3.utils.toWei(process.env.FP_AMOUNT!!)
  const brokerKit = await getKit(process.env.PRIVATE_KEY_2!!)
  return {
    investorKit,
    farmBotAddress,
    fpAmount,
    brokerKit
  }
}

async function simulateWithdraw(){
  // Script version of broker-mediated withdrawal, for testing.
  //  1. approve one 'broker' wallet to spend an 'investor' wallet's FP,
  //  2. as the broker wallet, take all the same steps RevoFPBroker does to withdraw and split into staking tokens
  // NOTE: does a REAL withdrawal of funds (only called "simulate" because it doesn't use the broker smart contract)

  const {investorKit, farmBotAddress, fpAmount, brokerKit} = await getConfig()
  let farmBot = getFarmBotContract(investorKit, farmBotAddress)

  // investor step 0: approve broker to spend FP
  console.log(`Approving broker to spend FP`)
  const investorAddress = investorKit.web3.eth.defaultAccount!!;
  const brokerAddress = brokerKit.web3.eth.defaultAccount!!;
  await farmBot.methods.approve(brokerAddress, fpAmount).send({
    from: investorAddress,
    gas: 1e6
  })

  // broker step 1: take FP
  console.log(`Broker step 1: take FP (investorAddress: ${investorAddress}, brokerAddress: ${brokerAddress})`)
  farmBot = getFarmBotContract(brokerKit, farmBotAddress)
  await farmBot.methods.transferFrom(
    investorAddress,
    brokerAddress,
    fpAmount
  ).send({
    from: brokerAddress,
    gas: 1e6
  })

  // broker step 2: withdraw from farm bot
  console.log(`Broker step 2: withdraw from farm bot`)
  const lpAmount = await farmBot.methods.getLpAmount(fpAmount).call()
  await farmBot.methods.withdraw(lpAmount).send({
    from: brokerAddress,
    gas: 1e6
  })

  // broker step 3: remove liquidity
  await removeLiquidity()
}

async function removeLiquidity() {
  const {brokerKit, farmBotAddress, fpAmount, investorKit} = await getConfig()

  const farmBot = getFarmBotContract(brokerKit, farmBotAddress)
  const lpAmount = await farmBot.methods.getLpAmount(fpAmount).call()

  const brokerAddress = brokerKit.web3.eth.defaultAccount!!
  console.log(`Broker step 3: remove liquidity`)
  const stakingTokenAddress = await farmBot.methods.stakingToken().call()
  const stakingToken = new brokerKit.web3.eth.Contract(ERC20_ABI, stakingTokenAddress)
  const routerAddress = await farmBot.methods.liquidityRouter().call()
  console.log(`Approving router (address ${routerAddress}) to spend ${lpAmount} of staking token at ${stakingTokenAddress}`)
  await stakingToken.methods.approve(routerAddress, lpAmount).send({
    from: brokerAddress,
    gas: 1e6
  })
  const router = new brokerKit.web3.eth.Contract(ROUTER_ABI, routerAddress)
  const deadline = new BigNumber(Date.now()).dividedToIntegerBy(1000).plus(600)
  const token0Address = await farmBot.methods.stakingToken0().call()
  const token1Address = await farmBot.methods.stakingToken1().call()
  console.log(`token0: ${token0Address}, token1: ${token1Address}`)
  const token0Min = '0'
  const token1Min = '0'
  console.log(`Removing ${lpAmount} LP`)
  await router.methods.removeLiquidity(
    token0Address,
    token1Address,
    lpAmount,
    token0Min,
    token1Min,
    investorKit.web3.eth.defaultAccount!!, // sending directly to investor
    deadline
  ).send({
    from: brokerAddress,
    gas: 1e6
  })
}

simulateWithdraw()
  .then(() => {console.log('done')})
  .catch(console.error)
