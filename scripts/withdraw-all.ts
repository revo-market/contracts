import {getKit, withdrawAll} from "../src/farm-bot-api"

/**
 * Withdraw entire balance of RFP from Farm Bot (returns LP at the current exchange rate)
 *
 * Define in env:
 * - PRIVATE_KEY: private key of your address you wish to withdraw RFP from
 */
async function main(){
  const kit = await getKit(process.env.PRIVATE_KEY!!)
  await withdrawAll(kit)
}

main().catch(console.error)
