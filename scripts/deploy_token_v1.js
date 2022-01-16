const { BN } = require("@openzeppelin/test-helpers");

const twentyMil          = "20000000000000000000000000";
const fortyMil           = "40000000000000000000000000";

const main = async () => {
  const [ deployer ] = await ethers.getAccounts();

  const SignataToken = await ethers.getContractFactory("Token");

  // originally we deployed this with the airdrop too, but we don't need to deploy that contract ever again.
  // we also deployed with multiple addresses for the allocations, but for future testnet deployments
  // we just mint everything to the deployer. We also deploy the full 100 mil tokens instead of the airdrop
  // having 10 mil separately.
  const signataIdentity = await SignataToken.deploy([
    "Signata",
    "SATA",
    deployer.address,
    new BN(fortyMil),
    deployer.address,
    new BN(twentyMil),
    new BN(fortyMil)
  ]);
  
  await signataIdentity.deployed();
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
