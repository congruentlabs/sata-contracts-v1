const hre = require("hardhat");

const main = async () => {
  const SignataIdentity = await ethers.getContractFactory("SignataIdentity");
  const SignataRight = await ethers.getContractFactory("SignataRight");

  console.log("DEPLOYING SignataIdentity")

  const signataIdentity = await SignataIdentity.deploy(hre.network.config.chainId);
  
  await signataIdentity.deployed();

  console.log(signataIdentity.address);

  console.log("DEPLOYING SignataRight");

  const signataRight = await SignataRight.deploy(
    "Signata Rights",
    "SATARIGHTS",
    signataIdentity.address,
    "https://schema.signata.net/v1/satarights.json"
  );
  
  await signataRight.deployed();

  console.log(signataRight.address);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })