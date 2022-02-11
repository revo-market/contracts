
# Contributing

Thank you for your interest in contributing to the Revo contracts! ⚡

# Development

## Engineering standards

Code merged into the `main` branch of this repository should adhere to high standards of correctness and maintainability. 
Use your best judgment when applying these standards.  If code is in the critical path, will be frequently visited, or 
makes large architectural changes, consider following all the standards.

- Have at least one engineer approve of large code refactorings
- At least manually test small code changes, prefer automated tests
- Thoroughly unit test
- If something breaks, add automated tests so it doesn't break again
- Add integration tests for new pages or flows
- Verify that all CI checks pass before merging

## Guidelines

The following points should help guide your development:

- Security: the contracts are safe to use
- Reproducibility: anyone can compile the contracts
  - Avoid adding steps to the development/build processes
  - Do not add tasks to `hardhat.config.ts` that depend on contracts having already compiled (since the hardhat config must compile FIRST for the contracts to compile)
- Decentralization: anyone can interact with the contracts
  - Avoid limiting access to critical functions (e.g. only allowing the deployer of a contract to trigger re-investment of rewards)

## Finding a first issue

Start with issues with the label
[`good first issue`](https://github.com/revo-market/contracts/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22).
