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
  const reserveAddr        = "0xce95DAde44E7307bAA616C77EF446915633dD9Ab";
  const intAddr            = "0xC34504f0195F00914a1A3b5Adf142b015F174125";
  const contractAddr       = "0xc441601696DF5ce0922224248AD96AB956D3B1Ae";

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
