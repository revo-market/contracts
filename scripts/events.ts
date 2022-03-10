import {
  getFarmBotContract,
  getKit,
} from "../src/farm-bot-api"

/**
 * Query for deposit events emitted by farm bot
 */
async function main() {
  const PRE_REVO_BLOCK_NUMBER = '11308824'
  const kit = await getKit(process.env.PRIVATE_KEY!!)
  const farmBot = getFarmBotContract(kit)
  const events = await farmBot.getPastEvents('Deposit', {fromBlock: PRE_REVO_BLOCK_NUMBER, toBlock: 'latest'})
  console.log(`num deposits: ${events.length}`)
  console.log(JSON.stringify(events.slice(0,5)))
}

main().catch(console.error)
