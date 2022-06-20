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

// export default { }

import revoFeeDeployer from './01-revo-fees/index'
import mcUSDmcEURFarmDeployer from './02-mcusd-mceur-farm/index'
import ubeCeloFarmDeployer from './05-ube-celo-farm/index'
import ubeCeloFarmConfigure from './06-configure-ube-celo/index'
import configureFarm from './03-configure-farm/index'
import addLiquidity from './04-add-liquidity/index'
import cusdCusdcFarmDeployer from './07-cusd-cusdc-farm/index'
import cusdCusdcFarmConfigure from './08-configure-cusd-cusdc/index'
import mcUSDmcEURMetaFarmDeployer from './09-mcusd-mceur-metafarm/index'
import configureMetaFarm from './10-configure-metafarm/index'
import stakeMetaFarm from './11-stake-metafarm/index'
import deployUniswapArbitrage from './12-arbitrage/index'
import testArbitrage from './13-test-arbitrage/index'

export default {
  'revo-fees': revoFeeDeployer,
  'mcusd-mceur': mcUSDmcEURFarmDeployer,
  'ube-celo': ubeCeloFarmDeployer,
  'configure-ube-celo': ubeCeloFarmConfigure,
  'configure-farm': configureFarm,
  'add-liquidity': addLiquidity,
  'cusd-cusdc': cusdCusdcFarmDeployer,
  'configure-cusd-cusdc': cusdCusdcFarmConfigure,
  'mcusd-mceur-metafarm': mcUSDmcEURMetaFarmDeployer,
  'configure-metafarm': configureMetaFarm,
  'stake-metafarm': stakeMetaFarm,
  'deploy-uniswap-arbitrage': deployUniswapArbitrage,
  'test-arbitrage': testArbitrage
}


