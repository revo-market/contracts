import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoUniswapArbitrage__factory } from "../../typechain"

const OWNER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd" // Temporary owner, should change to multi-sig

const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {

  // Deploy RevoUniswapArbitrage
  const revoUniswapArbitrage = await deployCreate2('RevoUniswapArbitrage', {
    factory: RevoUniswapArbitrage__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
    ]
  })

  return {
    revoUniswapArbitrage: revoUniswapArbitrage.address,
  }
}

export default main
