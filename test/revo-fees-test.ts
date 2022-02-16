import {expect} from 'chai'
import {RevoFees} from "../typechain"

const {ethers} = require('hardhat')

describe('Unit tests for RevoFees contract', async () => {
  it('fees can be accessed', async () => {
    const [owner] = await ethers.getSigners()
    const contractFactory = await ethers.getContractFactory('RevoFees')
    const feeContract: RevoFees = await contractFactory.deploy(
      await owner.getAddress(),  // owner
      1, // compounderFeeNumerator
      1000, // compounderFeeDenominator
      2, // reserveFeeNumerator
      1001 // reserveFeeDenominator
    )
    expect(await feeContract.compounderFeeNumerator()).to.equal(1)
    expect(await feeContract.compounderFeeDenominator()).to.equal(1000)
    expect(await feeContract.reserveFeeNumerator()).to.equal(2)
    expect(await feeContract.reserveFeeDenominator()).to.equal(1001) // set this to weird amount to make sure it is not mixed up with compounder fee denominator
    const {feeNumerator: withdrawalFeeNumerator, feeDenominator: withdrawalFeeDenominator} = await feeContract.withdrawalFee(1, 1000)
    expect(withdrawalFeeNumerator).to.equal(25)
    expect(withdrawalFeeDenominator).to.equal(10000)
  })
})

