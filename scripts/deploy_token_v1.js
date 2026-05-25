const hre = require('hardhat');

const TWENTY_MIL = 20_000_000n * 10n ** 18n;
const FORTY_MIL = 40_000_000n * 10n ** 18n;

const main = async () => {
  const [deployer] = await hre.ethers.getSigners();

  const Token = await hre.ethers.getContractFactory('Token');

  // For testnet we mint everything to the deployer (40M reserve + 20M integration + 40M remainder).
  const token = await Token.deploy(
    'Signata',
    'SATA',
    deployer.address,
    FORTY_MIL,
    deployer.address,
    TWENTY_MIL,
    FORTY_MIL,
  );
  await token.waitForDeployment();
  console.log('Token:', await token.getAddress());
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
