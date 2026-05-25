const { ethers } = require('hardhat');

// Hardhat's default in-memory network derives accounts from this mnemonic
// at m/44'/60'/0'/0/N. Keeping it in one place so tests that need raw private
// keys (for EIP-712 ecsign) and tests that need signers stay in sync.
const HARDHAT_MNEMONIC =
  'test test test test test test test test test test test junk';

const wallet = (index) => {
  const path = `m/44'/60'/0'/0/${index}`;
  const w = ethers.HDNodeWallet.fromPhrase(HARDHAT_MNEMONIC, undefined, path);
  return w.connect(ethers.provider);
};

const getAccounts = async (n = 20) => {
  const wallets = [];
  for (let i = 0; i < n; i++) wallets.push(wallet(i));
  return wallets;
};

module.exports = { getAccounts, wallet, HARDHAT_MNEMONIC };
