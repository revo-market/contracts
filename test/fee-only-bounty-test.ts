import {expect} from 'chai'

const {ethers} = require('hardhat')

describe('Unit tests for FeeOnlyBounty contract', async () => {
  it('fees can be accessed', async () => {
    const [owner] = await ethers.getSigners()
    const contractFactory = await ethers.getContractFactory('FeeOnlyBounty')
    const bountyContract = await contractFactory.deploy(
      await owner.getAddress(),  // owner
      4, // feeNumerator
      1000, // feeDenominator
    )
    const feeNumerator = await bountyContract.feeNumerator()
    expect(feeNumerator).to.equal(4)

    const feeDenominator = await bountyContract.feeDenominator()
    expect(feeDenominator).to.equal(1000)
  })
})

