import {expect} from "chai"
import {FarmBot, MockERC20, MockLPToken, MockRevoBounty, MockRouter, MockMoolaStakingRewards} from "../typechain";

const {ethers} = require("hardhat")


describe('Farm bot tests', () => {
  let owner, reserve,
    token0Contract: MockERC20, token1Contract: MockERC20,
    lpTokenContract: MockLPToken,
    stakingRewardsContract: MockMoolaStakingRewards,
    routerContract: MockRouter,
    stakingToken0Address: string, stakingToken1Address: string,
    farmBotContract: FarmBot
  beforeEach(async () => {
    [owner, reserve] = await ethers.getSigners()
    const revoBountyFactory = await ethers.getContractFactory('MockRevoBounty')
    const bountyContract: MockRevoBounty = await revoBountyFactory.deploy()

    const erc20Factory = await ethers.getContractFactory('MockERC20')

    const rewardsToken0Contract: MockERC20 = await erc20Factory.deploy('Mock rewards token 0', 'RWD0')
    const rewardsToken1Contract: MockERC20 = await erc20Factory.deploy('Mock rewards token 1', 'RWD1')
    const rewardsToken2Contract: MockERC20 = await erc20Factory.deploy('Mock rewards token 2', 'RWD2')

    token0Contract = await erc20Factory.deploy('Mock token 0', 'T0')
    token1Contract = await erc20Factory.deploy('Mock token 1', 'T1')

    const lpFactory = await ethers.getContractFactory('MockLPToken')
    lpTokenContract = await lpFactory.deploy(
      'Mock staking token', // name
      'LP', // symbol
      token0Contract.address,
      token1Contract.address
    )

    const stakingRewardsFactory = await ethers.getContractFactory('MockMoolaStakingRewards')
    stakingRewardsContract = await stakingRewardsFactory.deploy(
      token0Contract.address, // rewards token
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      lpTokenContract.address
    )

    const routerFactory = await ethers.getContractFactory('MockRouter')
    routerContract = await routerFactory.deploy(lpTokenContract.address)

    // sanity check mock LP contract
    stakingToken0Address = await lpTokenContract.token0()
    expect(stakingToken0Address).to.equal(token0Contract.address)
    stakingToken1Address = await lpTokenContract.token1()
    expect(stakingToken1Address).to.equal(token1Contract.address)

    // sanity check rewards
    expect(await stakingRewardsContract.rewardsToken())
      .to.equal(token0Contract.address)
    expect(await stakingRewardsContract.stakingToken())
      .to.equal(lpTokenContract.address)

    const farmBotFactory = await ethers.getContractFactory('FarmBot')
    farmBotContract = await farmBotFactory.deploy(
      owner.address,
      reserve.address,
      stakingRewardsContract.address,
      lpTokenContract.address,
      bountyContract.address,
      routerContract.address,
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      [
        [[],[]],
        [[],[]],
        [[],[]]
      ],
      'FP'
    )
  })
  it('Able to deploy farm bot to local test chain', async () => {
    expect(!!farmBotContract.address).not.to.be.false
  })
})
