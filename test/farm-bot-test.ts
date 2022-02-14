import {expect} from "chai"
import {UbeswapFarmBot, MockERC20, MockLPToken, MockRevoFees, MockRouter, MockMoolaStakingRewards} from "../typechain";

const {ethers} = require("hardhat")


describe('Farm bot tests', () => {
  it('Able to deploy farm bot to local test chain', async () => {
    const [owner, reserve] = await ethers.getSigners()
    const revoFeesFactory = await ethers.getContractFactory('MockRevoFees')
    const feeContract: MockRevoFees = await revoFeesFactory.deploy()

    const erc20Factory = await ethers.getContractFactory('MockERC20')

    const rewardsToken0Contract: MockERC20 = await erc20Factory.deploy('Mock rewards token 0', 'RWD0')
    const rewardsToken1Contract: MockERC20 = await erc20Factory.deploy('Mock rewards token 1', 'RWD1')
    const rewardsToken2Contract: MockERC20 = await erc20Factory.deploy('Mock rewards token 2', 'RWD2')

    const token0Contract: MockERC20 = await erc20Factory.deploy('Mock token 0', 'T0')
    const token1Contract: MockERC20 = await erc20Factory.deploy('Mock token 1', 'T1')

    const lpFactory = await ethers.getContractFactory('MockLPToken')
    const lpTokenContract: MockLPToken = await lpFactory.deploy(
      'Mock staking token', // name
      'LP', // symbol
      token0Contract.address,
      token1Contract.address
    )

    const stakingRewardsFactory = await ethers.getContractFactory('MockMoolaStakingRewards')
    const stakingRewardsContract: MockMoolaStakingRewards = await stakingRewardsFactory.deploy(
      token0Contract.address, // rewards token
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      lpTokenContract.address
    )

    const routerFactory = await ethers.getContractFactory('MockRouter')
    const routerContract: MockRouter = await routerFactory.deploy(lpTokenContract.address)

    // sanity check mock LP contract
    const stakingToken0 = await lpTokenContract.token0()
    expect(stakingToken0).to.equal(token0Contract.address)
    const stakingToken1 = await lpTokenContract.token1()
    expect(stakingToken1).to.equal(token1Contract.address)

    // sanity check rewards
    expect(await stakingRewardsContract.rewardsToken())
      .to.equal(token0Contract.address)
    expect(await stakingRewardsContract.stakingToken())
      .to.equal(lpTokenContract.address)

    const farmBotFactory = await ethers.getContractFactory('UbeswapFarmBot')
    const farmBotContract: UbeswapFarmBot = await farmBotFactory.deploy(
      owner.address,
      reserve.address,
      stakingRewardsContract.address,
      lpTokenContract.address,
      feeContract.address,
      routerContract.address,
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      'FP'
    )

    expect(!!farmBotContract.address).not.to.be.false
  })
})
