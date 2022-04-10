import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoUbeswapFarmBot__factory } from "../../typechain"
import { doTx } from '../utils'

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  const FARM_ADDRESS = "0xc6686060A1BFa583566Ebca400A2C8771b20Cb8C"

  const COMPOUNDER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd"
  const COMPOUNDER_ROLE = await RevoUbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).COMPOUNDER_ROLE()

  await doTx(
    "Setting compounder role",
    RevoUbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).grantRole(
      COMPOUNDER_ROLE,
      COMPOUNDER_ADDRESS
    )
  )

  return {}
}

export default main
