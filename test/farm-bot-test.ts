import {expect} from "chai"
import {FarmBot, MockERC20, MockLPToken, MockRevoBounty, MockRouter, MockStakingRewardsSingleToken} from "../typechain";

const {ethers} = require("hardhat")


describe('Farm bot tests', () => {
  it('does stuff', async () => {
    const [owner] = await ethers.getSigners()
    const revoBountyFactory = await ethers.getContractFactory('MockRevoBounty')
    const bountyContract: MockRevoBounty = await revoBountyFactory.deploy()

    const erc20Factory = await ethers.getContractFactory('MockERC20')
    // const rewardsTokenContract: MockERC20 = await erc20Factory.deploy('Mock rewards token', 'RWD')
    const token0Contract: MockERC20 = await erc20Factory.deploy('Mock token 0', 'T0')
    const token1Contract: MockERC20 = await erc20Factory.deploy('Mock token 1', 'T1')

    const lpFactory = await ethers.getContractFactory('MockLPToken')
    const lpTokenContract: MockLPToken = await lpFactory.deploy(
      'Mock staking token', // name
      'LP', // symbol
      token0Contract.address,
      token1Contract.address
    )

    const stakingRewardsFactory = await ethers.getContractFactory('MockStakingRewardsSingleToken')
    const stakingRewardsContract: MockStakingRewardsSingleToken = await stakingRewardsFactory.deploy(
      token0Contract.address, // rewards token
      lpTokenContract.address
    )

    const routerFactory = await ethers.getContractFactory('MockRouter')
    const routerContract: MockRouter = await routerFactory.deploy(lpTokenContract.address)

    // sanity check mock LP contract
    const stakingToken0 = await lpTokenContract.token0()
    expect(stakingToken0).to.equal(token0Contract.address)
    const stakingToken1 = await lpTokenContract.token1()
    expect(stakingToken1).to.equal(token1Contract.address)

    // sanity check rewards contract
    expect(await stakingRewardsContract.rewardsToken()) // fixme getting 0 address here!
      .to.equal(token0Contract.address)
    expect(await stakingRewardsContract.stakingToken()).to.equal(lpTokenContract.address)

    const farmBotFactory = await ethers.getContractFactory('FarmBot')
    const farmBotContract: FarmBot = await farmBotFactory.deploy( // fixme 'transaction reverted without a reason string' error here
      owner.address,
      stakingRewardsContract.address,
      bountyContract.address,
      routerContract.address,
      [token0Contract.address], // path0
      [token0Contract.address, token1Contract.address], // path1
      'FP'
    )

    expect(1).to.equal(1)
    expect(farmBotContract.address).not.to.be.false
  })
})
