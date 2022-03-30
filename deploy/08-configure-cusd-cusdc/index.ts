import { DeployerFn } from "@ubeswap/hardhat-celo"
import { RevoMobiusFarmBot__factory, ERC20__factory } from "../../typechain"
import { ContractTransaction } from "ethers"
import { ethers } from "ethers"


const MOBI_ADDRESS = "0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B"
const CELO_ADDRESS = "0x471ece3750da237f93b8e339c536989b8978a438"
const CUSD_ADDRESS = "0x765de816845861e75a25fca122bb6898b8b1282a"

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

  const FARM_ADDRESS = "0xdBebF6CDBB51dd36792565E60Ecd97f9Cd6AB7Ef"

  const COMPOUNDER_ADDRESS = "0x642abB1237009956BB67d0B174337D76F0455EDd"
  const COMPOUNDER_ROLE = await RevoMobiusFarmBot__factory.connect(FARM_ADDRESS, deployer).COMPOUNDER_ROLE()

  await doTx(
    "Compounding",
    RevoMobiusFarmBot__factory.connect(FARM_ADDRESS, deployer).compound(
      [
	[MOBI_ADDRESS, CELO_ADDRESS, CUSD_ADDRESS],
	[CELO_ADDRESS, CUSD_ADDRESS]
      ],
      [0,0],
      0,
      0,
      ethers.BigNumber.from(Date.now()).div(1000).add(300)
    )
  )

  return {}

  await doTx(
    "Setting compounder role",
    RevoMobiusFarmBot__factory.connect(FARM_ADDRESS, deployer).grantRole(
      COMPOUNDER_ROLE,
      COMPOUNDER_ADDRESS
    )
  )

  const STAKING_TOKEN_ADDRESS = "0x39b6F09ef97dB406ab78D869471adb2384C494E3" // cUSD-cUSDC LP

  const lpBalance = await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).balanceOf(COMPOUNDER_ADDRESS)

  if (lpBalance.gt(ethers.BigNumber.from(0))) {
    // Approve farm to spend it
    await ERC20__factory.connect(STAKING_TOKEN_ADDRESS, deployer).approve(FARM_ADDRESS, lpBalance)
    // Deposit LP
    await (await RevoMobiusFarmBot__factory.connect(FARM_ADDRESS, deployer).deposit(lpBalance)).wait()
  }

  return {}
}

export default main
