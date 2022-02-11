import {expect} from "chai"
import {
  MockERC20,
  MockLPToken,
  MockRevoBounty,
  MockRouter,
  MockMoolaStakingRewards,
  FarmBot__factory
} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

const {ethers} = require("hardhat")


describe('Farm bot tests', () => {
  let owner: SignerWithAddress, reserve: SignerWithAddress,
    bountyContract: MockRevoBounty,
    token0Contract: MockERC20, token1Contract: MockERC20,
    rewardsToken0Contract: MockERC20, rewardsToken1Contract: MockERC20, rewardsToken2Contract: MockERC20,
    lpTokenContract: MockLPToken,
    stakingRewardsContract: MockMoolaStakingRewards,
    routerContract: MockRouter,
    stakingToken0Address: string, stakingToken1Address: string,
    farmBotFactory: FarmBot__factory
  beforeEach(async () => {
    [owner, reserve] = await ethers.getSigners()
    const revoBountyFactory = await ethers.getContractFactory('MockRevoBounty')
    bountyContract = await revoBountyFactory.deploy()

    const erc20Factory = await ethers.getContractFactory('MockERC20')

    rewardsToken0Contract = await erc20Factory.deploy('Mock rewards token 0', 'RWD0')
    rewardsToken1Contract = await erc20Factory.deploy('Mock rewards token 1', 'RWD1')
    rewardsToken2Contract = await erc20Factory.deploy('Mock rewards token 2', 'RWD2')

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

    farmBotFactory = await ethers.getContractFactory('FarmBot')
  })
  it('Able to deploy farm bot to local test chain', async () => {
    const farmBotContract = await farmBotFactory.deploy(
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
    expect(!!farmBotContract.address).not.to.be.false
  })

  it('')
})
