# Contracts
Smart contracts for Revo, a DeFi platform that makes yield farming easy and profitable for everyone.

## Installation / setup
First install dependencies with yarn (just type `yarn` in the CLI from the project root and hit enter).

Next compile contracts, which also populates the typechain types (which are needed elsewhere).

For first-time setup, follow the instructions in `deploy/index.ts` to prevent compilation errors
due to missing generated types.

Then run this from the CLI: `yarn compile-contracts` . This will generate the typescript types for our contracts;
they will be saved to the `typechain` directory.

After initial setup, you should be able to use the "normal" deploy script without issues.

Note that after making changes to contracts, you will need to compile the contracts to update the `typechain` types,
then possibly update the deploy script before deploying (in particular, this will be necessary if you updated arguments
for the constructor for some contract in the deploy script).

## E2e tests
To run an e2e test script, first prepare two wallets on Alfajores according to the instructions in
`scripts/check-farm-bot-alfajores.ts` (at time of writing, this meant getting LP tokens for each one). Then you can run
the test script with `ts-node` as follows:
```
ALFAJORES_WALLET_PRIVATE_KEY=<fill this in> ALFAJORES_WALLET_PRIVATE_KEY_2=<fill this in too> node --require ts-node/register /Users/charlie/code/revo/contracts/./scripts/check-farm-bot-alfajores.ts
```
or with regular node by first building with `yarn build` and then running the compiled JS file.

## Deploying to Alfajores
1. Compile contracts with `yarn compile-contracts`
2. Deploy with `yarn deploy-contracts-alfajores --step {your_step_here}`

## Deploying to Mainnet
1. Compile contracts with `yarn compile-contracts`
2. Deploy with `yarn deploy-contracts-mainnet --step {your_step_here}`
