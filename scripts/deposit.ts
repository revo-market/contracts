import {
  approve,
  deposit,
  getKit,
} from "../src/farm-bot-api"

async function main() {
  const kit = await getKit(process.env.PRIVATE_KEY!!)
  const amount = kit.web3.utils.toWei('0.1', 'ether')
  await approve(kit, amount)
  await deposit(kit, amount)
}

main().catch(console.error)
