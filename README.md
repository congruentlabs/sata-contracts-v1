# SATA Contracts V1

## Overview

This is the repository for development of the Signata (SATA) token, including the initial ERC20 token definition and the Airdrop contract for Eth accounts.

More information about the SATA token, project, and whitepaper can be found at: [sata.technology](https://sata.technology)

The ERC20 token contract is an extension of [OpenZeppelin](https://openzeppelin.com/)'s ERC20 contract. We've extended this to facilitate the Airdrop and minting of tokens specific to our project needs.

This repository will house the first suite of contracts that utilise the SATA token, including for the first releases of the IdGAF. The V1 moniker is just added to the name in case we make a drastic change and need to shift to a V2 later down the track.

## Test

### Environment Setup

Install Node v12 on your machine. We develop on Windows but other platforms shouldn't be a problem.

On Windows make sure you're using PowerShell (I'd recommend Windows Terminal).

Install truffle globally and the project dependencies:

``` bash
npm i -g truffle
npm install

# with python3 installed already, and if you're going to run static analysis:
pip3 install slither-analyzer
```

Restart PowerShell as well, just to make sure Truffle is available on the system path.

### Running tests

The test suite leans heavily on OpenZeppelin's testing tools. The tools run ganache-cli in the background, allowing for the test network to run deterministically.

Just run the `test` script to compile and execute the test suite:

``` bash
npm run test
```

In some rare cases the first test will fail because of a race condition problem. Try running the tests again to confirm that it's not a race condition problem.

### Running static analysis

To view static analysis of the project, run:

```bash
npm run analyze
```

This will run `slither` on the project. Note that as we're using OpenZeppelin, a set of warnings will be shown for the OpenZeppelin contracts which we can ignore.

Currently there is a single warning from slither for our contracts that we are ignoring, as the token transfer events do not need the return values captured in the contract:

``` text
SATAAirdropV1.endAirdrop(address) (Airdrop.sol#19-23) ignores return value by token.transfer(recipient,token.balanceOf(address(this))) (Airdrop.sol#22)
SATAAirdropV1.claim() (Airdrop.sol#29-40) ignores return value by token.transfer(msg.sender,airdropAmount) (Airdrop.sol#39)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
```

## Deployment

The initial contracts must be deployed in the sequence ERC20 -> Airdrop -> mintAirdrop()

The ERC20 contract will mint tokens into the defined addresses, and then leave a set amount for the airdrop.

The airdrop contract requires the SATA token contract to already be active to create it. Once created, then the mintAirdrop() function on the token contract can be invoked to mint the tokens for the airdrop.

### Ropsten

In the project directory create `.secret` containing the testing wallet seed phrase, and `.infura` containing the Infura project ID for the test account.

Then run:

``` bash
npm run deploy-ropsten
```

and truffle will execute the `migrations/` scripts.

### Mainnet

Run:

``` bash
npm run deploy-mainnet
```
