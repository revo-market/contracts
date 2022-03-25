/**
 * Deployers for Revo.
 *
 * NOTE: for the first time you compile contracts with this repo,
 *  the typechain generated types will be missing and cause import errors.
 *  Since this script is used by our hardhat config (to add a 'deploy' task),
 *  this will block contract compilation!
 *
 *  As a workaround, for your first time compiling contracts, uncomment the empty export below, and comment out
 *    everything below it.
 *  (Yes, this is totally lame.)
 */

export default { }

// import revoFeeDeployer from './01-revo-fees/index'
// import mcUSDmcEURFarmDeployer from './02-mcusd-mceur-farm/index'
// import configureFarm from './03-configure-farm/index'
// import addLiquidity from './04-add-liquidity/index'

// export default {
//   'revo-fees': revoFeeDeployer,
//   'mcusd-mceur': mcUSDmcEURFarmDeployer,
//   'configure-farm': configureFarm,
//   'add-liquidity': addLiquidity
// }


