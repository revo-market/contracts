import {
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
  const fpAmount = kit.web3.utils.toWei(process.env.FP_AMOUNT!!)
  console.log(`Approving broker at ${REVO_FP_BROKER_ADDRESS} to spend ${fpAmount} of RFP ${farmBotAddress}`)
  await farmBot.methods.approve(REVO_FP_BROKER_ADDRESS, fpAmount).send({
    from: kit.web3.eth.defaultAccount!!,
    gas: 1e6
  })
  const fpBroker = getRevoFPBrokerContract(kit)
  const deadline = new BigNumber(Date.now()).dividedToIntegerBy(1000).plus(600)
  console.log(`Withdrawing ${fpAmount} RFP for staking tokens`)
  await fpBroker.methods.withdrawFPForStakingTokens(farmBotAddress, fpAmount, '0', '0', deadline
  ).send({
    from: kit.web3.eth.defaultAccount!!,
    gas: 1e6
  })
}

main()
  .then(() => {console.log('done')})
  .catch(console.error)
