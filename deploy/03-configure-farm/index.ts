import { DeployerFn } from "@ubeswap/hardhat-celo"
import { UbeswapFarmBot__factory } from "../../typechain"
import { ContractTransaction } from "ethers"

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

  return {}
}

export default main
