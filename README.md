# contracts
Revo smart contracts.

## Installation
```
yarn
```

## E2e tests
To run an e2e test script, first prepare two wallets on Alfajores according to the instructions in
`scripts/check-farm-bot-alfajores.ts` (at time of writing, this meant getting LP tokens for each one). Then 
set `ALFAJORES_WALLET_PRIVATE_KEY` and `ALFAJORES_WALLET_PRIVATE_KEY_2` in your environment. Then you can run
the test script with `ts-node` as follows:
```
node --require ts-node/register /Users/charlie/code/revo/contracts/./scripts/check-farm-bot-alfajores.ts
```
or with regular node by first building with `yarn build` and then running the compiled JS file.

## Deploying to Alfajores
1. Fill out `scripts/deploy.ts` with the desired parameters
2. Compile contracts with `yarn compile-contracts`
3. Deploy with `yarn deploy-contracts-alfajores` 

## Deploying to Mainnet
TODO (not tested, should be similar to Alfajores deployment)
