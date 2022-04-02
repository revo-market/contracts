import {expect} from 'chai'
import * as chai from 'chai'
import chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised)
import {MockERC20, MockFarmBot, MockLPToken, MockRouter, RevoFPBroker} from "../typechain"
import {BigNumber} from "ethers";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

const {ethers} = require('hardhat')

describe('RevoFPBroker tests', () => {
  let owner: SignerWithAddress,
    depositor: SignerWithAddress,
    revoFPBroker: RevoFPBroker,
    token0: MockERC20,
    token1: MockERC20,
    stakingToken: MockLPToken,
    router: MockRouter,
    farmBot: MockFarmBot

  beforeEach(async () => {
    [owner, depositor] = await ethers.getSigners()
    const brokerFactory = await ethers.getContractFactory('RevoFPBroker')
    revoFPBroker = await brokerFactory.deploy(
      await owner.getAddress(),  // owner
    )
    const mockERC20Factory = await ethers.getContractFactory('MockERC20')
    token0 = await mockERC20Factory.deploy('token0', 'T0')
    token1 = await mockERC20Factory.deploy('token1', 'T1')
    const mockLPFactory = await ethers.getContractFactory('MockLPToken')
    stakingToken = await mockLPFactory.deploy('mockLP', 'MLP', token0.address, token1.address)
    const mockRouterFactory = await ethers.getContractFactory('MockRouter')
    router = await mockRouterFactory.deploy()
    await router.setLPToken(stakingToken.address)
    const mockFarmBotFactory = await ethers.getContractFactory("MockFarmBot")
    farmBot = await mockFarmBotFactory.deploy(
      router.address,
      router.address,
      stakingToken.address
    )
    await token0.mint(depositor.address, 10)
    await token1.mint(depositor.address, 10)
  })

  it('able to deposit LP in a farm bot', async () => {
    await token0.connect(depositor).approve(revoFPBroker.address, 10)
    await token1.connect(depositor).approve(revoFPBroker.address, 10)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await router.setMockLiquidity(5)
    await revoFPBroker.connect(depositor).getUniswapLPAndDeposit(
      farmBot.address,
      {
        amount0Desired: 10,
        amount1Desired: 10,
        amount0Min: 9,
        amount1Min: 9,
      },
      arbitraryDeadline
    )

    // should spend staking tokens
    const token0Balance = await token0.balanceOf(depositor.address)
    expect(token0Balance).to.equal(0)
    const token1Balance = await token1.balanceOf(depositor.address)
    expect(token1Balance).to.equal(0)

    // should get FP tokens
    const fpBalance = await farmBot.balanceOf(depositor.address);
    expect(fpBalance).to.equal(5)
  })
  it('returns leftover token0 if slippage occurs', async () => {
    await token0.connect(depositor).approve(revoFPBroker.address, 10)
    await token1.connect(depositor).approve(revoFPBroker.address, 10)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await router.setMockLiquidity(5)
    await router.setStakingTokenAmounts([9, 10])
    await revoFPBroker.connect(depositor).getUniswapLPAndDeposit(
      farmBot.address,
      {
        amount0Desired: 10,
        amount1Desired: 10,
        amount0Min: 9,
        amount1Min: 9,
      },
      arbitraryDeadline
    )
    // should get leftovers back
    const token0Balance = await token0.balanceOf(depositor.address)
    expect(token0Balance).to.equal(1)

    // should spend token1
    const token1Balance = await token1.balanceOf(depositor.address)
    expect(token1Balance).to.equal(0)

    // should get FP
    const lpBalance = await farmBot.balanceOf(depositor.address)
    expect(lpBalance).to.equal(5)
  })

  it('returns leftover token0 if slippage occurs', async () => {
    await token0.connect(depositor).approve(revoFPBroker.address, 10)
    await token1.connect(depositor).approve(revoFPBroker.address, 10)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await router.setMockLiquidity(5)
    await router.setStakingTokenAmounts([10, 9])
    await revoFPBroker.connect(depositor).getUniswapLPAndDeposit(
      farmBot.address,
      {
        amount0Desired: 10,
        amount1Desired: 10,
        amount0Min: 9,
        amount1Min: 9,
      },
      arbitraryDeadline
    )
    // should get leftovers back
    const token1Balance = await token1.balanceOf(depositor.address)
    expect(token1Balance).to.equal(1)

    // should spend token0
    const token0Balance = await token0.balanceOf(depositor.address)
    expect(token0Balance).to.equal(0)

    // should get FP
    const lpBalance = await farmBot.balanceOf(depositor.address)
    expect(lpBalance).to.equal(5)
  })
})

