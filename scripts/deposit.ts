import {
  approve,
  deposit,
  getKit,
} from "../src/farm-bot-api"

/**
 * Deposit LP into farm bot
 *
 * To get LP, first swap for the underlying liquidity pool's staking tokens on Ubeswap, then stake the tokens in a
 *  liquidity pool.
 *
 *  Note that PRIVATE_KEY and LP_AMOUNT must be defined in your environment for this to work.
 */
async function main() {
  const kit = await getKit(process.env.PRIVATE_KEY!!)
  const amount = kit.web3.utils.toWei(process.env.LP_AMOUNT!!, 'ether')
  await approve(kit, amount)
  await deposit(kit, amount)
}

main().catch(console.error)
