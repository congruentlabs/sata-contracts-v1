require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();

const {
  MAINNET_RPC_URL,
  SEPOLIA_RPC_URL,
  BSC_RPC_URL,
  MAINNET_PRIVATE_KEY,
  SEPOLIA_PRIVATE_KEY,
  BSC_PRIVATE_KEY,
  ETHERSCAN_API_KEY,
  BSCSCAN_API_KEY,
} = process.env;

const accountsFor = (pk) => (pk ? [pk] : []);

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.28',
    settings: {
      evmVersion: 'cancun',
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  networks: {
    hardhat: {},
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    sepolia: {
      url: SEPOLIA_RPC_URL || '',
      chainId: 11155111,
      accounts: accountsFor(SEPOLIA_PRIVATE_KEY),
    },
    mainnet: {
      url: MAINNET_RPC_URL || '',
      chainId: 1,
      accounts: accountsFor(MAINNET_PRIVATE_KEY),
    },
    bsc: {
      url: BSC_RPC_URL || 'https://bsc-dataseed1.binance.org/',
      chainId: 56,
      accounts: accountsFor(BSC_PRIVATE_KEY),
    },
  },
  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY || '',
      sepolia: ETHERSCAN_API_KEY || '',
      bsc: BSCSCAN_API_KEY || '',
    },
  },
  mocha: {
    timeout: 60000,
  },
};
