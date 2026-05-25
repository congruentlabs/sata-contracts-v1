# SATA Contracts V1

## Overview

This is the repository for the Signata (SATA) token, the Airdrop contract,
and the core identity / rights contracts that power [Signata](https://sata.technology)
and [Veriswap](https://veriswap.io/).

The BEP20 token contract lives in a separate repo, forked from the Binance
implementation: [sata-contracts-bsc-v1](https://github.com/congruentlabs/sata-contracts-bsc-v1).

> **Modernization in progress.** This repository was previously built with
> Truffle + OpenZeppelin Test Environment and targeted now-deprecated networks
> (Rinkeby/Ropsten, Moralis Speedy Nodes). It is being migrated to a Hardhat-only
> toolchain on OpenZeppelin Contracts 5.x. Several legacy/draft contracts have
> been parked with a `.wip` extension while migration is in flight — see git log.

## Requirements

- Node.js 20 LTS (see [`.nvmrc`](.nvmrc))
- npm 10+

## Setup

```bash
npm install
cp .env.example .env   # fill in RPC URLs and deployer key(s) only when deploying
```

`.env` is gitignored; never commit a real one.

## Compile

```bash
npm run compile
```

## Test

```bash
npm test
```

Tests run against Hardhat's in-memory network with no extra configuration.
Two legacy test suites (`SignataIdentity`, `SignataRight`) are currently
skipped — they were written against older contract ABIs and will be rewritten
in the Phase 4 cleanup pass.

## Static analysis

```bash
npm run analyze
```

Requires [`slither`](https://github.com/crytic/slither) installed locally
(`pip3 install slither-analyzer`). This script is currently not wired into CI.

## Deployment

Set the relevant variables in `.env` before deploying:

```env
SEPOLIA_RPC_URL=https://...
SEPOLIA_PRIVATE_KEY=0x...
ETHERSCAN_API_KEY=...
```

Then:

```bash
npm run deploy:sepolia    # Sepolia testnet
npm run deploy:mainnet    # Ethereum mainnet
npm run deploy:bsc        # BNB Smart Chain
```

The default deploy script ([`scripts/deploy_identity_v1.js`](scripts/deploy_identity_v1.js))
deploys `SignataIdentity` and `SignataRight`. Token / Veriswap deployment
scripts live alongside it; review and run with `npx hardhat run` as needed.

The initial token + airdrop sequence is:
`Token` → `Airdrop` → `Token.mintAirdrop(airdrop, amount)`.

## Verifying on Etherscan

```bash
npx hardhat verify --network sepolia <deployed-address> <constructor args...>
```
