import {getKit, grantCompounderRole} from "../src/farm-bot-api";


async function main(){
  const kit = await getKit(process.env.OWNER_PRIVATE_KEY!!)
  await grantCompounderRole(kit, process.env.COMPOUNDER_ADDRESS!!)
}

main().catch(console.error)
