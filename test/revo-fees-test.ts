import {expect} from 'chai'
import * as chai from 'chai'
import chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)
import {RevoFees} from "../typechain"
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

const {ethers} = require('hardhat')

describe('Unit tests for RevoFees contract', async () => {
  let feeContract: RevoFees, owner: SignerWithAddress, nonOwner: SignerWithAddress
  beforeEach(async () => {
    [owner, nonOwner] = (await ethers.getSigners())
    const contractFactory = await ethers.getContractFactory('RevoFees')
    feeContract = await contractFactory.deploy(
      await owner.getAddress(),  // owner
      1, // compounderFeeNumerator
      1000, // compounderFeeDenominator
      2, // reserveFeeNumerator
      1001, // reserveFeeDenominator
      25, // withdrawalFeeNumerator
      10000, // withdrawalFeeDenominator
      false // useDynamicWithdrawalFees
    )
  })
  it('fees can be accessed', async () => {
    expect(await feeContract.compounderFeeNumerator()).to.equal(1)
    expect(await feeContract.compounderFeeDenominator()).to.equal(1000)
    expect(await feeContract.reserveFeeNumerator()).to.equal(2)
    expect(await feeContract.reserveFeeDenominator()).to.equal(1001) // set this to weird amount to make sure it is not mixed up with compounder fee denominator
    const {feeNumerator: withdrawalFeeNumerator, feeDenominator: withdrawalFeeDenominator} = await feeContract.withdrawalFee(1, 1000)
    expect(withdrawalFeeNumerator).to.equal(25)
    expect(withdrawalFeeDenominator).to.equal(10000)
  })
  it('useDynamicWithdrawalFee: enables dynamic withdrawal fees', async () => {
    await feeContract.connect(owner).updateUseDynamicWithdrawalFees(true)
    const {feeNumerator: dynamicWithdrawalFeeNumerator, feeDenominator: dynamicWithdrawalFeeDenominator} = await feeContract.withdrawalFee(1, 1000)
    expect(dynamicWithdrawalFeeNumerator).to.equal(1)
    expect(dynamicWithdrawalFeeDenominator).to.equal(1000)
  })
  it('setters can only be used by owner', async () => {
    await expect(feeContract.connect(nonOwner).updateUseDynamicWithdrawalFees(true)).rejectedWith('contract owner')
    await expect(feeContract.connect(nonOwner).updateCompounderFee(2, 100)).rejectedWith('contract owner')
    await expect(feeContract.connect(nonOwner).updateReserveFee(3,100)).rejectedWith('contract owner')
    await expect(feeContract.connect(nonOwner).updateWithdrawalFee(4,100)).rejectedWith('contract owner')

    await feeContract.connect(owner).updateUseDynamicWithdrawalFees(true)
    expect(await feeContract.useDynamicWithdrawalFees()).to.be.true
    await feeContract.connect(owner).updateCompounderFee(2, 100)
    expect(await feeContract.compounderFeeNumerator()).to.equal(2)
    expect(await feeContract.compounderFeeDenominator()).to.equal(100)
    await feeContract.connect(owner).updateReserveFee(3,100)
    expect(await feeContract.reserveFeeNumerator()).to.equal(3)
    expect(await feeContract.reserveFeeDenominator()).to.equal(100)
    await feeContract.connect(owner).updateWithdrawalFee(4,100)
    expect(await feeContract.withdrawalFeeNumerator()).to.equal(4)
    expect(await feeContract.withdrawalFeeDenominator()).to.equal(100)
  })
})

