import { DeployerFn } from "@ubeswap/hardhat-celo"
import {
  UbeswapFarmBot__factory,
  ERC20__factory
} from "../../typechain"
import { ethers } from "ethers"

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  const FARM_ADDRESS = "0xCB34fbfC3b9a73bc04D2eb43B62532c7918d9E81"
  const STAKING_TOKEN_ADDRESS = "0xf94fea0c87d2b357dc72b743b45a8cb682b0716e" // mcUSD-mcEUR LP address
  const COMPOUNDER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd"
  //const ROUTER_ADDRESS = "0xE3D8bd6Aed4F159bc8000a9cD47CffDb95F96121" // Ubeswap Router address

  // Get current LP balance
  const lpBalance = await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).balanceOf(COMPOUNDER_ADDRESS)

  console.log(lpBalance.toString())

  if (lpBalance.gt(ethers.BigNumber.from(0))) {
    // Approve farm to spend it
    await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).approve(FARM_ADDRESS, lpBalance)
    // Deposit LP
    await (await UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).deposit(lpBalance)).wait()
    // Withdraw it...
    //await (await UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).withdrawAll()).wait()
  }

  // TODO: Add initial liquidity to the cUSD-RFP pool
  // const fpBalance = await UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).balanceOf(COMPOUNDER_ADDRESS)

  return {}
}

export default main
