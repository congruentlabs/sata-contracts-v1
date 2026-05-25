# SATA Contracts V1

Solidity contracts for the Signata (SATA) token, airdrop, and the core
identity / rights contracts that power [Signata](https://sata.technology)
and [Veriswap](https://veriswap.io/).

The BEP20 token contract lives in a separate repo, forked from the Binance
implementation:
[sata-contracts-bsc-v1](https://github.com/congruentlabs/sata-contracts-bsc-v1).

## Stack

- Node.js 20 LTS (see [`.nvmrc`](.nvmrc))
- Hardhat 2.22.x + `@nomicfoundation/hardhat-toolbox` (ethers v6)
- OpenZeppelin Contracts 5.x
- Solidity 0.8.28, optimizer 200 runs, evm target `cancun`

## Setup

```bash
npm install
cp .env.example .env   # fill in only when deploying
```

`.env` is gitignored; never commit a real one.

## Compile / test / lint

```bash
npm run compile
npm test
npm run lint
```

Tests run against Hardhat's in-memory network with no extra configuration.

### Known gaps

The `SignataIdentity` and `SignataRight` test suites are currently
`describe.skip`'d — the pre-modernization versions were written against an
older ABI (5-arg `create`, mismatched `TXTYPE_CREATE_DIGEST`) and cannot pass
against the current contracts. Fresh hardhat + ethers v6 EIP-712 suites for
them are still TODO.

## Parked draft contracts

During modernization, several contracts that had never compiled cleanly were
renamed with a `.sol.wip` extension so hardhat ignores them. They either
reference undefined types, use removed Solidity keywords, or have malformed
imports:

| File | Reason |
|---|---|
| `contracts/Governor.sol.wip` | invalid `import "./SignataRight.json"`, uses removed `now` keyword |
| `contracts/SignataRightV2.sol.wip` | missing required ERC6150 hook overrides; empty `burnAuth()` body |
| `contracts/SignataRightV2-draft.sol.wip` | early draft, not wired up |
| `contracts/SignataNFTDrop.sol.wip` | references undefined `schemaId` (should be `dropData.schemaId`); empty claim body |
| `contracts/ClaimERC721.sol.wip` | depends on commented-out `TWBitMaps` library import |
| `contracts/swap/ISwap.sol.wip` | references undefined `Types.Order` / `TransferHandlerRegistry`; not imported anywhere |
| `scripts/deploy_veriswap_v1.js.wip` | references undefined `_protocolFeeWallet` / `_stakingToken`, wrong contract name |

These are kept in the tree (with `.wip` so the compiler ignores them) for
future triage — decide per-file whether to rescue or delete.

## Static analysis

```bash
npm run analyze
```

Requires [`slither`](https://github.com/crytic/slither) installed locally
(`pip3 install slither-analyzer`). Not currently wired into CI.

## Deployment

Populate the relevant variables in `.env`:

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
deploys `SignataIdentity` and `SignataRight`. Token deployment lives in
[`scripts/deploy_token_v1.js`](scripts/deploy_token_v1.js).

The initial token + airdrop sequence is:
`Token` → `Airdrop` → `Token.mintAirdrop(airdrop, amount)`.

### Verifying on Etherscan

```bash
npx hardhat verify --network sepolia <deployed-address> <constructor args...>
```

## Note on already-deployed contracts

The OZ 4 → OZ 5 migration changes bytecode and (in some cases) storage
layout. If a V1 contract is already deployed to mainnet, the new code in
this repo applies only to *future* deployments — it is **not** a
storage-compatible upgrade for the existing on-chain instances.
