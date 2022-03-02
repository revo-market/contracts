import {getKit, withdraw} from "../src/farm-bot-api"

/**
 * Withdraw RFP from Farm Bot (returns LP at the current exchange rate)
 *
 * Define in env:
 * - PRIVATE_KEY: private key of your address you wish to withdraw RFP from
 * - RFP_AMOUNT: amount to withdraw
 */
async function main(){
  const kit = await getKit(process.env.PRIVATE_KEY!!)
  const amount = kit.web3.utils.toWei(process.env.RFP_AMOUNT!!, 'ether')
  await withdraw(kit, amount)
}

main().catch(console.error)
