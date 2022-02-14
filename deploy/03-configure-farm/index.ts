import { DeployerFn } from "@ubeswap/hardhat-celo"
import { UbeswapFarmBot__factory, ERC20__factory } from "../../typechain"
import { ContractTransaction } from "ethers"
import ethers from "ethers"

export const doTx = async (
  action: string,
  tx: Promise<ContractTransaction>
): Promise<void> => {
  console.log(`Performing ${action}...`);
  const result = await (await tx).wait();
  console.log(`${action} done at tx ${result.transactionHash}`);
};

const main: DeployerFn<{}> = async ({
  deployer,
}) => {

  const FARM_ADDRESS = "0xc6686060A1BFa583566Ebca400A2C8771b20Cb8C"

  const COMPOUNDER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd"
  const COMPOUNDER_ROLE = await UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).COMPOUNDER_ROLE()

  await doTx(
    "Setting compounder role",
    UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).grantRole(
      COMPOUNDER_ROLE,
      COMPOUNDER_ADDRESS
    )
  )

  // Get current LP balance
  const STAKING_TOKEN_ADDRESS = "0xf94fea0c87d2b357dc72b743b45a8cb682b0716e" // mcUSD-mcEUR LP address
  const lpBalance = await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).balanceOf(COMPOUNDER_ADDRESS)

  if (lpBalance.gt(ethers.BigNumber2.from(0))) {
    // Approve farm to spend it
    await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).approve(FARM_ADDRESS, lpBalance)
    // Deposit LP
    await (await UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).deposit(lpBalance)).wait()
  }

  // Withdraw it...
  //await (await UbeswapFarmBot__factory.connect(FARM_ADDRESS, deployer).withdrawAll()).wait()

  return {}
}

export default main
