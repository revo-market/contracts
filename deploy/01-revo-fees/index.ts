import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoFees__factory } from "../../typechain"

const main: DeployerFn<{}> = async ({
  deployCreate2,
  deployer,
}) => {
  const OWNER_ADDRESS = "0x99649aF776ff1b024F12e8Fe9dfA59A6c0b4bD9C" // Multi-sig owner
  const COMPOUNDER_FEE_NUMERATOR = 1 // 0.1% fee goes to compounder
  const COMPOUNDER_FEE_DENOMINATOR = 1000
  const RESERVE_FEE_NUMERATOR = 0 // Set default reserve fee to 0.0%
  const RESERVE_FEE_DENOMINATOR = 1000

  const revoFees = await deployCreate2('RevoFees', {
    factory: RevoFees__factory,
    signer: deployer,
    args: [
      OWNER_ADDRESS,
      COMPOUNDER_FEE_NUMERATOR,
      COMPOUNDER_FEE_DENOMINATOR,
      RESERVE_FEE_NUMERATOR,
      RESERVE_FEE_DENOMINATOR
    ]
  })

  return {
    RevoFees: revoFees.address,
  }
}

export default main
