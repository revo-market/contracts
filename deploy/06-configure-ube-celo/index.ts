import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoUbeswapSingleRewardFarmBot__factory, ERC20__factory } from "../../typechain"
import { doTx } from '../utils'
import { ethers } from "ethers"

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  const FARM_ADDRESS = "0xa2487190fCE90B2462102656478BA6Ad7F548F88"

  const COMPOUNDER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd"
  const COMPOUNDER_ROLE = await RevoUbeswapSingleRewardFarmBot__factory.connect(FARM_ADDRESS, deployer).COMPOUNDER_ROLE()

  await doTx(
    "Setting compounder role",
    RevoUbeswapSingleRewardFarmBot__factory.connect(FARM_ADDRESS, deployer).grantRole(
      COMPOUNDER_ROLE,
      COMPOUNDER_ADDRESS
    )
  )

  await doTx(
    'Update slippage',
    RevoUbeswapSingleRewardFarmBot__factory.connect(FARM_ADDRESS, deployer).updateSlippage(95, 100)
  )

  const STAKING_TOKEN_ADDRESS = "0xe7B5AD135fa22678F426A381C7748f6A5f2c9E6C" // UBE-CELO LP address

  const lpBalance = await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).balanceOf(COMPOUNDER_ADDRESS)

  if (lpBalance.gt(ethers.BigNumber.from(0))) {
    // Approve farm to spend it
    await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).approve(FARM_ADDRESS, lpBalance)
    // Deposit LP
    await (await RevoUbeswapSingleRewardFarmBot__factory.connect(FARM_ADDRESS, deployer).deposit(lpBalance)).wait()
  }

  return {}
}

export default main
