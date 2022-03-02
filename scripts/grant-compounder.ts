import {getKit, grantCompounderRole} from "../src/farm-bot-api";


/**
 * Grant the compounder role.
 *
 * Requires process.env.OWNER_PRIVATE_KEY to be the private key of a wallet with the 'default admin' role for the
 *  farm bot.
 *
 * process.env.COMPOUNDER_ADDRESS should be the address you want to designate as a compounder
 */
async function main(){
  const kit = await getKit(process.env.ADMIN_PRIVATE_KEY!!)
  await grantCompounderRole(kit, process.env.COMPOUNDER_ADDRESS!!)
}

main().catch(console.error)
