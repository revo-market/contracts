import { ethers } from 'ethers'
import ABI from '../artifacts/contracts/ubeswap/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol/IUniswapV2Pair.json'

interface Balance {
  address: string
  balance: ethers.BigNumber
}

async function main() {
  const provider = new ethers.providers.JsonRpcProvider("https://forno.celo.org");
  const myContract = new ethers.Contract("0x25938830FBd7619bf6CFcFDf5C37A22AB15A93cA", ABI.abi, provider);

  let eventFilter = myContract.filters.Transfer()
  let events = await myContract.queryFilter(eventFilter)
  const balances: Record<string, ethers.BigNumber> = {}

  for (const event of events) {
    const fromAddress = event?.args?.from as string
    const toAddress = event?.args?.to as string
    const value = event?.args?.value as ethers.BigNumber

    if (!balances.hasOwnProperty(fromAddress)) {
      balances[fromAddress] = ethers.BigNumber.from(0).sub(value)
    } else {
      balances[fromAddress] = balances[fromAddress].sub(value)
    }

    if (!balances.hasOwnProperty(toAddress)) {
      balances[toAddress] = value
    } else {
      balances[toAddress] = balances[toAddress].add(value)
    }
  }
  const holderList: Array<Balance> = []
  for (const [address, balance] of Object.entries(balances)) {
    if (balance.gt(ethers.BigNumber.from(0))) {
      holderList.push({address, balance})
    }
  }
  holderList.sort((a,b) => b.balance.gt(a.balance) ? 1 : -1)
  for (const elem of holderList) {
    console.log(`${elem.address}: ${ethers.utils.formatEther(elem.balance)}`)
  }

}

main()
