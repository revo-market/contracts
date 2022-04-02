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
    investor: SignerWithAddress,
    revoFPBroker: RevoFPBroker,
    token0: MockERC20,
    token1: MockERC20,
    stakingToken: MockLPToken,
    router: MockRouter,
    farmBot: MockFarmBot

  beforeEach(async () => {
    [owner, investor] = await ethers.getSigners()
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
  })

  it('able to deposit LP in a farm bot', async () => {
    await token0.mint(investor.address, 10)
    await token1.mint(investor.address, 10)
    await token0.connect(investor).approve(revoFPBroker.address, 10)
    await token1.connect(investor).approve(revoFPBroker.address, 10)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await router.setMockLiquidity(5)
    await revoFPBroker.connect(investor).getUniswapLPAndDeposit(
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
    const token0Balance = await token0.balanceOf(investor.address)
    expect(token0Balance).to.equal(0)
    const token1Balance = await token1.balanceOf(investor.address)
    expect(token1Balance).to.equal(0)

    // should get FP tokens
    const fpBalance = await farmBot.balanceOf(investor.address);
    expect(fpBalance).to.equal(5)
  })
  it('returns leftover token0 if slippage occurs', async () => {
    await token0.mint(investor.address, 10)
    await token1.mint(investor.address, 10)
    await token0.connect(investor).approve(revoFPBroker.address, 10)
    await token1.connect(investor).approve(revoFPBroker.address, 10)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await router.setMockLiquidity(5)
    await router.setStakingTokenAmounts([9, 10])
    await revoFPBroker.connect(investor).getUniswapLPAndDeposit(
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
    const token0Balance = await token0.balanceOf(investor.address)
    expect(token0Balance).to.equal(1)

    // should spend token1
    const token1Balance = await token1.balanceOf(investor.address)
    expect(token1Balance).to.equal(0)

    // should get FP
    const fpBalance = await farmBot.balanceOf(investor.address)
    expect(fpBalance).to.equal(5)
  })

  it('returns leftover token0 if slippage occurs', async () => {
    await token0.mint(investor.address, 10)
    await token1.mint(investor.address, 10)
    await token0.connect(investor).approve(revoFPBroker.address, 10)
    await token1.connect(investor).approve(revoFPBroker.address, 10)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await router.setMockLiquidity(5)
    await router.setStakingTokenAmounts([10, 9])
    await revoFPBroker.connect(investor).getUniswapLPAndDeposit(
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
    const token1Balance = await token1.balanceOf(investor.address)
    expect(token1Balance).to.equal(1)

    // should spend token0
    const token0Balance = await token0.balanceOf(investor.address)
    expect(token0Balance).to.equal(0)

    // should get FP
    const fpBalance = await farmBot.balanceOf(investor.address)
    expect(fpBalance).to.equal(5)
  })

  it('able to withdraw', async () => {
    await farmBot.connect(investor).approve(revoFPBroker.address, 5)
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await farmBot.mint(investor.address, 5)
    await stakingToken.mint(farmBot.address, 5)

    // kinda dumb but mock router requires this to be able to burn LP in exchange for the underlying tokens
    await token0.mint(router.address, 5)
    await token1.mint(router.address, 5)

    await revoFPBroker.connect(investor).withdrawFPForStakingTokens(
      farmBot.address,
      5,
      5,
      5,
      arbitraryDeadline
    )
    // should spend FP
    const fpBalance = await farmBot.balanceOf(investor.address)
    expect(fpBalance).to.equal(0)

    // // should get staking tokens
    const token0Balance = await token0.balanceOf(investor.address)
    expect(token0Balance).to.equal(5)
    const token1Balance = await token1.balanceOf(investor.address)
    expect(token1Balance).to.equal(5)
  })
})

