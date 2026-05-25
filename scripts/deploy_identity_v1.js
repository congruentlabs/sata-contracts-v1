const hre = require('hardhat');

const main = async () => {
  const chainId = hre.network.config.chainId ?? (await hre.ethers.provider.getNetwork()).chainId;

  console.log('DEPLOYING SignataIdentity');
  const SignataIdentity = await hre.ethers.getContractFactory('SignataIdentity');
  const signataIdentity = await SignataIdentity.deploy(chainId);
  await signataIdentity.waitForDeployment();
  const idAddress = await signataIdentity.getAddress();
  console.log('SignataIdentity:', idAddress);

  console.log('DEPLOYING SignataRight');
  const SignataRight = await hre.ethers.getContractFactory('SignataRight');
  const signataRight = await SignataRight.deploy(
    'Signata Rights',
    'SATARIGHTS',
    idAddress,
    'https://schema.signata.net/v1/satarights.json',
  );
  await signataRight.waitForDeployment();
  console.log('SignataRight:', await signataRight.getAddress());
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
