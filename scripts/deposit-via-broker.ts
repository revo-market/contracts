import {
  approve,
  getFarmBotContract,
  getKit,
  getRevoFPBrokerContract,
  REVO_FP_BROKER_ADDRESS
} from "../src/farm-bot-api";
import BigNumber from "BigNumber.js";

async function main(){
  const kit = await getKit(process.env.PRIVATE_KEY!!)
  const farmBotAddress = process.env.FARM_BOT_ADDRESS!!
  const farmBot = getFarmBotContract(kit, farmBotAddress)
  const stakingToken0Address = await farmBot.methods.stakingToken0().call()
  const stakingToken1Address = await farmBot.methods.stakingToken1().call()
  const amount0Desired = kit.web3.utils.toWei(process.env.TOKEN_0_AMOUNT!!, 'ether')
  const amount1Desired = kit.web3.utils.toWei(process.env.TOKEN_1_AMOUNT!!, 'ether')
  await approve(kit, amount0Desired, stakingToken0Address, REVO_FP_BROKER_ADDRESS)
  await approve(kit, amount1Desired, stakingToken1Address, REVO_FP_BROKER_ADDRESS)
  const liquidityAmounts = {
    amount0Desired,
    amount1Desired,
    amount0Min: '0',
    amount1Min: '0'
  }
  const fpBroker = getRevoFPBrokerContract(kit)
  const deadline = new BigNumber(Date.now()).dividedToIntegerBy(1000).plus(600)
  await fpBroker.methods.getUniswapLPAndDeposit(farmBotAddress, liquidityAmounts, deadline).send({
    from: kit.web3.eth.defaultAccount!!,
    gas: 1e7
  })

  await fpBroker.methods.withdrawFPForStakingTokens(farmBotAddress, process.env.FP_AMOUNT!!, '0', '0', deadline)
}

main()
  .then(() => {console.log('done')})
  .catch(console.error)
