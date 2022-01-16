require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

const { task } = require('hardhat/config');
const fs = require('fs');
const mainnetMnemonic = fs.readFileSync(".secret").toString().trim();
const bscMainMnemonic = fs.readFileSync(".secret-bsc").toString().trim();
const testnetMnemonic = fs.readFileSync(".secret-test").toString().trim();
const urls = JSON.parse(fs.readFileSync(".urls.json").toString());

task("accounts", "list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.10"
      },
      {
        version: "0.8.0"
      }
    ],
    settings: {
      optimizer: {
        enabled: true
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    rinkeby: {
      url: urls.rinkeby,
      chainId: 4,
      gasPrice: 20000000000,
      accounts: { mnemonic: testnetMnemonic }
    },
    ropsten: {
      url: urls.ropsten,
      chainId: 3,
      gasPrice: 20000000000,
      accounts: { mnemonic: testnetMnemonic }
    },
    mainnet: {
      url: urls.mainnet,
      chainId: 1,
      gasPrice: 50000000000, // don't forget to check the etherscan gas price before deployment
      accounts: { mnemonic: mainnetMnemonic }
    },
    bscTestnet: {
      url: urls.bscTestnet,
      chainId: 97,
      gasPrice: 20000000000,
      accounts: { mnemonic: testnetMnemonic }
    },
    bscMainnet: {
      url: urls.bscMainnet,
      chainId: 56,
      gasPrice: 20000000000,
      accounts: { mnemonic: bscMainMnemonic }
    }
  }
};
