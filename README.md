# SATA Contracts V1

## Overview

This is the repository for development of the Signata (SATA) token, including the initial
ERC20 token definition and the Airdrop contract for Eth accounts.

More information about the SATA token can be found at: [sata.technology](https://sata.technology)

Most of the initial contracts are derived from [OpenZeppelin](https://openzeppelin.com/). We've made
most of our changes to support our use case.

This repository will house the first suite of contracts that utilise the SATA token, including for
the first releases of the IdGAF. The V1 moniker is just added to the name in case we make a drastic
change and need to shift to a V2 later down the track (but we'll try to avoid that).

## Test

### Environment Setup

Install Node v12 on your machine. We develop on Windows but other platforms shouldn't be a problem.

On Windows make sure you're using PowerShell (I'd recommend Windows Terminal).

Install truffle globally and the project dependencies:

``` bash
npm i -g truffle
npm install
```

Restart PowerShell as well, just to make sure Truffle is available on the system path.

### Running tests

Just run the `test` script to compile and execute the test suite:

``` bash
npm run test
```

## Deployment

The initial contracts must be deployed in the sequence ERC20 -> Airdrop -> mintAirdrop()

The ERC20 contract will mint tokens into the defined addresses, and then leave a set amount for the airdrop.

The airdrop contract requires the SATA token contract to already be active to create it. Once created, then the mintAirdrop() function on the token contract can be invoked to mint the tokens for the airdrop.

### Ropsten

In the project directory create `.secret` containing the testing wallet seed phrase, and `.infura` containing the
Infura project ID for the test account.

Then run:

``` bash
npm run deploy-ropsten
```

and truffle will execute the `migrations/` scripts.

### Mainnet

TBC - but this will be the same as Ropsten but with more rigor and control over the executing wallet.
