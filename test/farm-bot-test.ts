import {expect} from "chai"
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber} from "ethers";
import {UbeswapFarmBot, MockERC20, MockLPToken, MockRevoFees, MockRouter, MockMoolaStakingRewards, UbeswapFarmBot__factory} from "../typechain";

const {ethers} = require("hardhat")


describe('Farm bot tests', () => {
  let reserve: SignerWithAddress, investor: SignerWithAddress,
    feeContract: MockRevoFees,
    token0Contract: MockERC20, token1Contract: MockERC20,
    rewardsToken0Contract: MockERC20, rewardsToken1Contract: MockERC20, rewardsToken2Contract: MockERC20,
    lpTokenContract: MockLPToken,
    stakingRewardsContract: MockMoolaStakingRewards,
    routerContract: MockRouter,
    stakingToken0Address: string, stakingToken1Address: string,
    farmBotFactory: UbeswapFarmBot__factory
  beforeEach(async () => {
    [reserve, investor] = await ethers.getSigners()
    const revoBountyFactory = await ethers.getContractFactory('MockRevoFees')
    feeContract = await revoBountyFactory.deploy()

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

    farmBotFactory = await ethers.getContractFactory('UbeswapFarmBot')
  })
  it('Able to deploy farm bot to local test chain', async () => {
    const farmBotContract: UbeswapFarmBot = await farmBotFactory.deploy(
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

  xit('claimRewards: works with 1-pool swaps from rewards to staking tokens', async () => {
    const farmBotContract = (await farmBotFactory.deploy(
      reserve.address,
      stakingRewardsContract.address,
      lpTokenContract.address,
      feeContract.address,
      routerContract.address,
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      'FP'
    )).connect(investor)

    const paths: [string[], string[]][] = [
        [
          [rewardsToken0Contract.address, stakingToken0Address],
          [rewardsToken0Contract.address, stakingToken1Address]
        ],
        [
          [rewardsToken1Contract.address, stakingToken0Address],
          [rewardsToken1Contract.address, stakingToken1Address]
        ],
        [
          [rewardsToken2Contract.address, stakingToken0Address],
          [rewardsToken2Contract.address, stakingToken1Address]
        ]
      ]

    // prep investor
    await lpTokenContract.mint(investor.address, 1000)
    expect(await lpTokenContract.balanceOf(investor.address)).to.equal(1000)  // sanity check

    await lpTokenContract.connect(investor).approve(farmBotContract.address, 1000)
    await farmBotContract.deposit(1000)
    expect(await farmBotContract.balanceOf(investor.address)).to.equal(1000)

    // load rewards
    await stakingRewardsContract.setAmountEarnedExternal([1000, 1000, 1000])
    await rewardsToken0Contract.mint(stakingRewardsContract.address, 1000);
    await rewardsToken1Contract.mint(stakingRewardsContract.address, 1000)
    await rewardsToken2Contract.mint(stakingRewardsContract.address, 1000)

    // claim rewards
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(60)
    await farmBotContract.compound(
      paths,
      [[], []], // fixme add
      arbitraryDeadline
    )
  })
})
