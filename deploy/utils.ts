import { ContractTransaction } from "ethers"

// Various utility functions used by deployer scripts

export const sleep = (ms: number) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

export const doTx = async (
  action: string,
  tx: Promise<ContractTransaction>
): Promise<void> => {
  console.log(`Performing ${action}...`);
  const result = await (await tx).wait();
  console.log(`${action} done at tx ${result.transactionHash}`);
};
