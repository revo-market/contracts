import {ContractKit, newKit} from "@celo/contractkit";
import {WrapperCache} from "@celo/contractkit/lib/contract-cache";

import * as assert from "assert";
import BigNumber from "bignumber.js";

const FARM_BOT_ABI = require('../abis/farmBot.json')
const REVO_FP_BROKER_ABI = require('../abis/revoFPBroker.json')


const NODE_URL = 'https://forno.celo.org'
const LP_TOKEN_ADDRESS = '0xf94fea0c87d2b357dc72b743b45a8cb682b0716e' // mcUSD-mcEUR
export const FARM_BOT_ADDRESS = '0xCB34fbfC3b9a73bc04D2eb43B62532c7918d9E81'

export const REVO_FP_BROKER_ADDRESS = '0x97d0D4ae7841c9405A80fB8004dbA96123e076De'

interface Transaction {
  send: (sendParams: {
    from: string
    gas: number
    gasPrice?: number
  }) => Promise<{status: boolean, gasUsed: number}>
}

interface Call<Params, Return> {
  call: (callParams: Params) => Promise<Return>
}

export interface FarmBotContract {
  methods: {
    deposit: (amount: string) => Transaction
    withdraw: (amount: string) => Transaction
    compound: (paths: string[][][], minAmountsOut: number[][], deadline: BigNumber) => Transaction
    grantRole: (role: string, account: string) => Transaction
    approve: (spenderAddress: string, amount: string) => Transaction
    transferFrom: (from: string, to: string, amount: string) => Transaction

    stakingToken: () => Call<void, string>
    stakingToken0: () => Call<void, string>
    stakingToken1: () => Call<void, string>
    stakingRewards: () => Call<void, string>
    liquidityRouter: () => Call<void, string>
    getLpAmount: (fpAmount: string) => Call<void, string>
    COMPOUNDER_ROLE: () => Call<void, string>
  }
}

export interface LiquidityAmounts {
  amount0Desired: string
  amount1Desired: string
  amount0Min: string
  amount1Min: string
}

export interface RevoFPBrokerContract {
  methods: {
    getUniswapLPAndDeposit: (farmBotAddress: string, liquidityAmounts: LiquidityAmounts, deadline: BigNumber) => Transaction
    withdrawFPForStakingTokens: (farmBotAddress: string, fpAmount: string,
        amountAMin: string,
        amountBMin: string,
        deadline: BigNumber) => Transaction
  }
}

/**
 * Grant the compounder role to a recipient.
 *
 * Requires the wallet address of the sender to be an admin of the farm bot.
 *
 * @param kit
 * @param recipient
 * @param farmBotAddress
 */
export async function grantCompounderRole(kit: ContractKit, recipient?: string, farmBotAddress?: string): Promise<void> {
  const newCompounderAddress = recipient ?? kit.web3.eth.defaultAccount
  console.log('Granting compounder role to ' + newCompounderAddress)
  const farmBot = await getFarmBotContract(kit, farmBotAddress ?? FARM_BOT_ADDRESS)
  const role = await farmBot.methods.COMPOUNDER_ROLE().call()
  await farmBot.methods.grantRole(role, newCompounderAddress!!).send({
    from: kit.web3.eth.defaultAccount!!,
    gas: 1e5,
  })
}

export async function getKit(privateKey: string): Promise<ContractKit> {
  const kit = await newKit(NODE_URL)
  const account = kit.web3.eth.accounts.privateKeyToAccount(privateKey)
  kit.web3.eth.accounts.wallet.add(account)
  kit.web3.eth.defaultAccount = account.address
  console.log('Getting account with address ' + account.address)
  return kit
}

/**
 * Approve a wallet to spend the user's token
 *
 * Useful to prepare for depositing LP directly into farm
 *
 * @param kit
 * @param amount
 * @param tokenAddress: address of token to approve spending of
 * @param spenderAddress: address of spender to approve
 */
export async function approve(kit: ContractKit, amount: string, tokenAddress: string = LP_TOKEN_ADDRESS, spenderAddress: string = FARM_BOT_ADDRESS) {
  const walletAddress = kit.web3.eth.defaultAccount
  console.log(`Approving ${spenderAddress} to spend ${amount} of token ${tokenAddress} on behalf of ${walletAddress}`)
  assert.ok(walletAddress)
  const tokenContract = await (new WrapperCache(kit)).getErc20(tokenAddress)
  const approveTx = await tokenContract.approve(spenderAddress, amount).send({
    from: walletAddress,
    gas: 50000,
    gasPrice: 1000000000
  })
  return approveTx.waitReceipt()
}

export function getFarmBotContract(kit: ContractKit, farmBotAddress: string = FARM_BOT_ADDRESS): FarmBotContract {
  return new kit.web3.eth.Contract(FARM_BOT_ABI, farmBotAddress)
}

export function getRevoFPBrokerContract(kit: ContractKit): RevoFPBrokerContract {
  return new kit.web3.eth.Contract(REVO_FP_BROKER_ABI, REVO_FP_BROKER_ADDRESS)
}

export async function deposit(kit: ContractKit, amount: string) {
  // NOTE: this invests in a farm now!
  console.log(`depositing ${amount.toString()} for ${kit.web3.eth.defaultAccount} in farm bot at ${FARM_BOT_ADDRESS}`)
  const farmBotContract = getFarmBotContract(kit)
  assert.ok(kit.web3.eth.defaultAccount)
  return farmBotContract.methods.deposit(amount).send({
    from:kit.web3.eth.defaultAccount,
    gas: 1076506,
    gasPrice: 1000000000,
  })
}

export async function compound(kit: ContractKit, deadline?: BigNumber) {
  console.log(`Compounding with wallet ${kit.web3.eth.defaultAccount} for farm bot at ${FARM_BOT_ADDRESS}`)
  const farmBotContract = getFarmBotContract(kit)
  const CELO_ADDRESS = '0x471EcE3750Da237f93B8E339c536989b8978a438';
  const mcUSD_ADDRESS = '0x918146359264c492bd6934071c6bd31c854edbc3';
  const mcEUR_ADDRESS = '0xe273ad7ee11dcfaa87383ad5977ee1504ac07568';
  const UBE_ADDRESS = '0x00be915b9dcf56a3cbe739d9b9c202ca692409ec';
  const MOO_ADDRESS = '0x17700282592d6917f6a73d0bf8accf4d578c131e';
  const paths = [
    // from rewards token 0
    [
      // to staking token 0
      [CELO_ADDRESS, mcUSD_ADDRESS],
      // to staking token 1
      [CELO_ADDRESS, mcEUR_ADDRESS]
    ],
    // from rewards token 1
    [
      // to staking token 0
      [UBE_ADDRESS, CELO_ADDRESS, mcUSD_ADDRESS],
      // to staking token 1
      [UBE_ADDRESS, CELO_ADDRESS, mcEUR_ADDRESS]
    ],
    // from rewards token 2
    [
      // to staking token 0
      [MOO_ADDRESS, CELO_ADDRESS, mcUSD_ADDRESS],
      // to staking token 1
      [MOO_ADDRESS, CELO_ADDRESS, mcEUR_ADDRESS]
    ],
  ]
  const minAmountsOut = [[0, 0], [0, 0], [0, 0]] // todo eventually make this higher
  return farmBotContract.methods.compound(
    paths,
    minAmountsOut,
    deadline ?? new BigNumber(new Date().getTime()).dividedToIntegerBy(1000).plus(300)
  ).send({
    from: kit.web3.eth.defaultAccount!!,
    gas: 4e6,
  })
}

export async function withdraw(kit: ContractKit, amount: string) {
  console.log(`Withdrawing ${amount} RFP for ${kit.web3.eth.defaultAccount} from farm bot at ${FARM_BOT_ADDRESS}`)
  const farmBotContract = getFarmBotContract(kit)
  assert.ok(kit.web3.eth.defaultAccount)
  return farmBotContract.methods.withdraw(amount).send({
    from: kit.web3.eth.defaultAccount,
    gas: 1076506,
    gasPrice: 1000000000,
  })
}

export function getStakingRewardsContractAddress(farmBotContract: FarmBotContract): Promise<string> {
  return farmBotContract.methods.stakingRewards().call()
}
