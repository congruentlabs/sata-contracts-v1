const hre = require("hardhat");

const main = async () => {
  const Veriswap = await ethers.getContractFactory("Veriswap");

  console.log("DEPLOYING Veriswap")

  const veriswap = await Veriswap.deploy(
    30, // protocol fee
    7, // protocol fee light
    _protocolFeeWallet,
    10, // rebate scale
    100, // rebate max
    _stakingToken,
    '0x6B47e26A52a9B5B467b98142E382c081eA97B0fc'
  );
  
  await veriswap.deployed();

  console.log(veriswap.address);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })