# SATA Contracts V1

## Overview

This is the repository for development of the Signata (SATA) token, including the initial
ERC20 token definition and the Airdrop contract for Eth accounts.

More information about the SATA token can be found at: [sata.technology](https://sata.technology)

## Test

### Environment Setup

Install truffle and the project dependencies:

``` bash
npm i -g truffle
npm install
```

### Running tests

Just run the test script to compile and run the test suite:

``` bash
npm run test
```

## Deployment

The initial contracts must be deployed in the sequence ERC20 -> Airdrop -> mintAirdrop()

The ERC20 contract will mint tokens into the defined addresses, and then leave a set amount for the airdrop.

The airdrop contract requires the SATA token contract to already be active to create it. Once created, then the mintAirdrop() function on the token contract can be invoked to mint the tokens for the airdrop.
