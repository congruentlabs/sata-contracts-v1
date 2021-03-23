const { BN } = require("@openzeppelin/test-helpers");
const SATAAirdropV1 = artifacts.require("SATAAirdropV1");
const SATAToken = artifacts.require("SATAToken");

module.exports = function (deployer) {
  var sataTokenInst;

  deployer.deploy(
    SATAToken,
    "Signata",
    "SATA",
    "0xce95DAde44E7307bAA616C77EF446915633dD9Ab",
    new BN("40000000000000000000000000"), // 40,000,000
    "0xC34504f0195F00914a1A3b5Adf142b015F174125",
    new BN("10000000000000000000000000"), // 10,000,000
    new BN("40000000000000000000000000"), // 40,000,000
    { from: '0xc441601696DF5ce0922224248AD96AB956D3B1Ae', overwrite: true }
  ).then((instance) => {
    sataTokenInst = instance;
    return deployer.deploy(
      SATAAirdropV1,
      SATAToken.address,
      new BN("1000000000000000000000"), // 1,000
      new BN("100000000000000000"), // 0.1 ETH
      { from: '0xc441601696DF5ce0922224248AD96AB956D3B1Ae', overwrite: true }
    );
  }).then(() => {
    return sataTokenInst.mintAirdrop(
      SATAAirdropV1.address,
      new BN("10000000000000000000000000") // 10,000,000
    );
  });
};
