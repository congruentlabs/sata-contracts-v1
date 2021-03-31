const { BN } = require("@openzeppelin/test-helpers");
const SATAAirdropV1 = artifacts.require("SATAAirdropV1");
const SATAToken = artifacts.require("SATAToken");
const {
  pointOneEth,
  tenThousand,
  tenMil,
  fortyMil,
  tokenName,
  tokenSymbol,
} = require("../migrations/constants");

module.exports = function (deployer) {
  var sataTokenInst;

  const contractAddr       = "0x042fc4EA3F836e1Ea5Dc4Fb70ec90DeD51c09ECa";
  const reserveAddr        = "0xd204ff1705AFFB1353F1f717D0486dccf3222473";
  const intAddr            = "0xd2C55cbcA4FC0467fca2d49BFe114515c8854220";

  deployer.deploy(
    SATAToken,
    tokenName,
    tokenSymbol,
    reserveAddr,
    new BN(fortyMil), // 40,000,000
    intAddr,
    new BN(tenMil), // 10,000,000
    new BN(fortyMil), // 40,000,000
    { from: contractAddr, overwrite: true }
  ).then((instance) => {
    sataTokenInst = instance;
    return deployer.deploy(
      SATAAirdropV1,
      SATAToken.address,
      new BN(tenThousand), // 10,000
      new BN(pointOneEth), // 0.1 ETH
      { from: contractAddr, overwrite: true }
    );
  }).then(() => {
    return sataTokenInst.mintAirdrop(
      SATAAirdropV1.address,
      new BN(tenMil) // 10,000,000
    );
  });
};
