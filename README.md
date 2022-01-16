# SATA Contracts V1

## Overview

This is the repository for development of the Signata (SATA) token, including the initial ERC20 token definition and the Airdrop contract for Eth accounts.

More information about the SATA token, project, and whitepaper can be found at: [sata.technology](https://sata.technology)

The ERC20 token contract is an extension of [OpenZeppelin](https://openzeppelin.com/)'s ERC20 contract. We've extended this to facilitate the Airdrop and minting of tokens specific to our project needs.

This repository also stores the core identity contracts for SATA and [Veriswap](https://veriswap.io/).

The BEP20 token contract is stored in a separate repo as we forked it from the Binance BEP20 implementation: [sata-contracts-bsc-v1](https://github.com/congruentlabs/sata-contracts-bsc-v1)

## Test

### Environment Setup

Install Node LTS on your machine. We develop on Windows but other platforms shouldn't be a problem.

On Windows make sure you're using PowerShell (I'd recommend Windows Terminal).

Install truffle globally and the project dependencies (if you want to keep truffle local to the repo, change the npm scripts to 'npx truffle ...' instead):

``` bash
npm i -g truffle
npm install

# with python3 installed already, and if you're going to run static analysis:
pip3 install slither-analyzer
```

Restart PowerShell as well, just to make sure Truffle is available on the system path.

### Running tests

The test suite leans heavily on OpenZeppelin's testing tools. OZ's test environment by default has an expectation of using truffle compiled contracts, so we have to compile them with truffle for testing but compile them with hardhat for deployment. Yes, it's messy, and we need it consolidated to hardhat if we can later.

If you change any of the contracts or are running tests for the first time, run:

``` bash
npm run test:compile
```

Otherwise just run:

``` bash
npm run test
```

Running the compile option every time is harmless, it just wastes your own time waiting for truffle to recompile every time.

### Running static analysis

To view static analysis of the project, run:

```bash
npm run analyze
```

Note: this is currently broken, we need to troubleshoot

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

### Deployment Environment Setup

Create 3 files in the project directory. `.secret`, `.secret-test`, and `.urls.json`. In the secret files put the respective wallet seed (only do this on a hardened deployment machine). In the JSON file, fill it like the following example, substituting `{key}` with the API key from Moralis.

We're using Moralis because the public testnet nodes have performance problems. We also use this over Infura because we can deploy BSC and other future networks under the same keys.

``` json
{ 
  "rinkeby": "https://speedy-nodes-nyc.moralis.io/{key}/eth/rinkeby",
  "ropsten": "https://speedy-nodes-nyc.moralis.io/{key}/eth/ropsten",
  "mainnet": "https://speedy-nodes-nyc.moralis.io/{key}/eth/mainnet",
  "bscTestnet": "https://speedy-nodes-nyc.moralis.io/{key}/bsc/testnet",
  "bscMainnet": "https://bsc-dataseed1.binance.org/"
}
```

### Rinkeby

We don't use Ropsten for testing any more as partners are preferring Rinkeby.

``` bash
npm run deploy:rinkeby
```

### ETH Mainnet

``` bash
npm run deploy:mainnet
```

