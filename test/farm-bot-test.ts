import {expect} from "chai"
import * as chai from 'chai'
import chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised)
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber} from "ethers";
import {
  RevoUbeswapFarmBot,
  MockERC20,
  MockLPToken,
  MockRevoFees,
  MockRouter,
  MockMoolaStakingRewards,
  RevoUbeswapFarmBot__factory,
} from "../typechain"

const {ethers} = require("hardhat")


describe('Farm bot tests', function() {
  this.timeout(5000)
  let deployer: SignerWithAddress, reserve: SignerWithAddress, compounder: SignerWithAddress, investor0: SignerWithAddress, investor1: SignerWithAddress,
    feeContract: MockRevoFees,
    token0Contract: MockERC20, token1Contract: MockERC20,
    rewardsToken0Contract: MockERC20, rewardsToken1Contract: MockERC20, rewardsToken2Contract: MockERC20,
    lpTokenContract: MockLPToken,
    stakingRewardsContract: MockMoolaStakingRewards,
    routerContract: MockRouter,
    stakingToken0Address: string, stakingToken1Address: string,
    farmBotFactory: RevoUbeswapFarmBot__factory
  beforeEach(async () => {
    [deployer, reserve, compounder, investor0, investor1] = await ethers.getSigners()
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
    routerContract = await routerFactory.deploy()
    await routerContract.setLPToken(lpTokenContract.address);

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

    farmBotFactory = await ethers.getContractFactory('RevoUbeswapFarmBot')
  })
  it('Able to deploy farm bot to local test chain', async () => {
    const farmBotContract: RevoUbeswapFarmBot = await farmBotFactory.deploy(
      deployer.address,
      reserve.address,
      stakingRewardsContract.address,
      lpTokenContract.address,
      feeContract.address,
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      routerContract.address,
      routerContract.address,
      'FP'
    )
    expect(!!farmBotContract.address).not.to.be.false
  })

  it('Admin role', async () => {
    const farmBotContract = (await farmBotFactory.deploy(
      deployer.address,
      reserve.address,
      stakingRewardsContract.address,
      lpTokenContract.address,
      feeContract.address,
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      routerContract.address,
      routerContract.address,
      'FP',
    ))

    const adminRole = await farmBotContract.DEFAULT_ADMIN_ROLE()
    expect(await farmBotContract.hasRole(adminRole, deployer.address)).to.be.true
    expect(await farmBotContract.hasRole(adminRole, compounder.address)).to.be.false

    const compounderRole = await farmBotContract.COMPOUNDER_ROLE()
    await farmBotContract.grantRole(compounderRole, compounder.address)

    await farmBotContract.connect(deployer).updateFees(feeContract.address)
    await expect(farmBotContract.connect(investor0).updateFees(feeContract.address)).rejectedWith('AccessControl')
    await expect(farmBotContract.connect(compounder).updateFees(feeContract.address)).rejectedWith('AccessControl')

    await farmBotContract.connect(deployer).updateReserveAddress(reserve.address)
    await expect(farmBotContract.connect(investor0).updateReserveAddress(investor0.address)).rejectedWith('AccessControl')
    await expect(farmBotContract.connect(compounder).updateReserveAddress(reserve.address)).rejectedWith('AccessControl')


    await farmBotContract.connect(deployer).updateSlippage(1, 100)
    await expect(farmBotContract.connect(investor0).updateSlippage(2, 100)).rejectedWith('AccessControl')
    await expect(farmBotContract.connect(compounder).updateSlippage(1, 100)).rejectedWith('AccessControl')
  })

  it('Compounder role', async () => {
    const farmBotContract = (await farmBotFactory.deploy(
      deployer.address,
      reserve.address,
      stakingRewardsContract.address,
      lpTokenContract.address,
      feeContract.address,
      [rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
      routerContract.address,
      routerContract.address,
      'FP',
    ))

    const compounderRole = await farmBotContract.COMPOUNDER_ROLE()
    expect(await farmBotContract.hasRole(compounderRole, compounder.address)).to.be.false

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
    const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
    await expect(farmBotContract.connect(compounder).compound(
      paths,
      [[0, 0], [0, 0], [0, 0]],
      arbitraryDeadline,
    )).to.be.rejectedWith('AccessControl')
    await farmBotContract.connect(deployer).grantRole(compounderRole, compounder.address)
    await expect(farmBotContract.connect(compounder).compound(
      paths,
      [[0, 0], [0, 0], [0, 0]],
      arbitraryDeadline,
    )).not.to.be.rejectedWith('AccessControl')
  })

  describe('Compound', () => {
    let farmBotContract: RevoUbeswapFarmBot, paths: [string[], string[]][]
    beforeEach(async () => {
      farmBotContract = (await farmBotFactory.deploy(
        deployer.address,
        reserve.address,
        stakingRewardsContract.address,
        lpTokenContract.address,
        feeContract.address,
	[rewardsToken0Contract.address, rewardsToken1Contract.address, rewardsToken2Contract.address],
        routerContract.address,
	routerContract.address,
        'FP',
      ))

      paths = [
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

      // load rewards
      await stakingRewardsContract.setAmountEarnedExternal([10, 10, 10])
      await rewardsToken0Contract.mint(stakingRewardsContract.address, 1000)
      await rewardsToken1Contract.mint(stakingRewardsContract.address, 1000)
      await rewardsToken2Contract.mint(stakingRewardsContract.address, 1000)

      // give compound role
      const compounderRole = await farmBotContract.COMPOUNDER_ROLE()
      await farmBotContract.connect(deployer).grantRole(compounderRole, compounder.address)

      // prep router mock
      await routerContract.setMockLiquidity(10)
      await routerContract.setMockAmounts([10, 10])
    })
    it('Single investor earns interest', async () => {
      await lpTokenContract.mint(investor0.address, 1000)
      expect(await lpTokenContract.balanceOf(investor0.address)).to.equal(1000)  // sanity check

      // invest
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getFpAmount(1000)).to.equal(1000)

      // compound
      const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10], [10, 10], [10, 10]],
        arbitraryDeadline
      )

      // check earnings
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1010)
    })
    it('Two investors share interest', async () => {
      await lpTokenContract.mint(investor0.address, 1000)
      await lpTokenContract.mint(investor1.address, 1000)

      // investor0 deposit
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.balanceOf(investor1.address)).to.equal(0)
      expect(await farmBotContract.getFpAmount(1000)).to.equal(1000)

      // investor1 deposit
      await lpTokenContract.connect(investor1).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor1).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.balanceOf(investor1.address)).to.equal(1000)

      // compound
      const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10], [10, 10], [10, 10]],
        arbitraryDeadline
      )

      // check earnings
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.balanceOf(investor1.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1005)
    })
    it('Early investor earns more', async () => {
      // investor0 deposit
      await lpTokenContract.mint(investor0.address, 1000)
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.balanceOf(investor1.address)).to.equal(0)
      expect(await farmBotContract.getFpAmount(1000)).to.equal(1000)

      // first compound
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10], [10, 10], [10, 10]],
        BigNumber.from(Date.now()).div(1000).add(600) // arbitrary
      )

      // check earnings after first compound
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1010)

      // investor1 deposit
      await lpTokenContract.mint(investor1.address, 1010)
      await lpTokenContract.connect(investor1).approve(farmBotContract.address, 1010)
      await farmBotContract.connect(investor1).deposit(1010)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.balanceOf(investor1.address)).to.equal(1000)  // since FP:LP ratio was 1010 when investor1 deposited

      // second compound
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10], [10, 10], [10, 10]],
        BigNumber.from(Date.now()).div(1000).add(600) // arbitrary
      )

      // check earnings after second compound
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.balanceOf(investor1.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1015)  // since 10 LPs were split between each investor with 1000 FPs, the value of 1000 FPs rose by 5
    })
    it('Works when a swap path is longer than 2', async () => {
      await lpTokenContract.mint(investor0.address, 1000)

      // invest
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getFpAmount(1000)).to.equal(1000)

      // compound
      const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
      await farmBotContract.connect(compounder).compound(
        [
          [
            [rewardsToken0Contract.address, rewardsToken1Contract.address, stakingToken0Address],
            [rewardsToken0Contract.address, stakingToken1Address]
          ],
          [
            [rewardsToken1Contract.address, stakingToken0Address],
            [rewardsToken1Contract.address, rewardsToken0Contract.address, stakingToken1Address]
          ],
          [
            [rewardsToken2Contract.address, rewardsToken1Contract.address, stakingToken0Address],
            [rewardsToken2Contract.address, rewardsToken0Contract.address, stakingToken1Address]
          ]
        ],
        [[10, 10], [10, 10], [10, 10]],
        arbitraryDeadline
      )

      // check earnings
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1010)
    })
    it('Rejects invalid compound paths', async () => {
      const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
      await expect(farmBotContract.connect(compounder).compound(
        [
          [
            [rewardsToken0Contract.address, stakingToken1Address], // bad (should end with stakingToken0Address)
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
        ],
        [[10, 10], [10, 10], [10, 10]],
        arbitraryDeadline
      )).rejectedWith('invalid path end')

      await expect(farmBotContract.connect(compounder).compound(
        [
          [
            [rewardsToken1Contract.address, stakingToken0Address], // bad (should start with rewardsToken0Contract.address)
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
        ],
        [[10, 10], [10, 10], [10, 10]],
        arbitraryDeadline
      )).rejectedWith('invalid path start')
    })
    it('Works when a reward token is also a staking token', async () => {
      farmBotContract = (await farmBotFactory.deploy(
        deployer.address,
        reserve.address,
        stakingRewardsContract.address,
        lpTokenContract.address,
        feeContract.address,
	[stakingToken0Address],
        routerContract.address,
	      routerContract.address,
        'FP',
      ))
      const compounderRole = await farmBotContract.COMPOUNDER_ROLE()
      await farmBotContract.grantRole(compounderRole, compounder.address)

      paths = [
        [[], [stakingToken0Address, stakingToken1Address]],
      ]

      await lpTokenContract.mint(investor0.address, 1000)

      // invest
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getFpAmount(1000)).to.equal(1000)

      // compound
      const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10]],
        arbitraryDeadline
      )

      // check earnings
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1010)
    })
    it('Sends correct fees to reserve, compounder', async () => {
      await lpTokenContract.mint(investor0.address, 1000)
      expect(await lpTokenContract.balanceOf(investor0.address)).to.equal(1000)  // sanity check

      // invest
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getFpAmount(1000)).to.equal(1000)

      // set fees
      await feeContract.connect(deployer).setCompounderFee(1)
      await feeContract.connect(deployer).setReserveFee(2)

      // set rewards
      await routerContract.setMockLiquidity(100)

      // compound
      const arbitraryDeadline = BigNumber.from(Date.now()).div(1000).add(600)
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10], [10, 10], [10, 10]],
        arbitraryDeadline
      )

      // check earnings
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1097)

      // sanity
      expect(compounder.address).not.to.be.equal(reserve.address)

      // check fees
      expect(await lpTokenContract.balanceOf(compounder.address)).to.equal(1)
      expect(await lpTokenContract.balanceOf(reserve.address)).to.equal(2)
    })
    it('handles case where one rewards token is depleted', async () => {
      await stakingRewardsContract.setAmountEarnedExternal([10, 10, 0])
      await lpTokenContract.mint(investor0.address, 1000)
      await lpTokenContract.connect(investor0).approve(farmBotContract.address, 1000)
      await farmBotContract.connect(investor0).deposit(1000)

      // compound
      await farmBotContract.connect(compounder).compound(
        paths,
        [[10, 10], [10, 10], [10, 10]],
        BigNumber.from(Date.now()).div(1000).add(600) // arbitrary
      )

      // check earnings after first compound
      expect(await farmBotContract.balanceOf(investor0.address)).to.equal(1000)
      expect(await farmBotContract.getLpAmount(1000)).to.equal(1010)
    })
    it('If rewards tokens left over (due to swap messiness), reinvested next time', async () => {
      // TODO
    })
  })
})
