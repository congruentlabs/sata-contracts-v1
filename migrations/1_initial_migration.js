const Migrations = artifacts.require("Migrations");
const SATAAirdropV1 = artifacts.require("SATAAirdropV1");
const SATAToken = artifacts.require("SATAToken");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(SATAToken, , arg, arg).then(function() {
    return deployer.deploy(SATAAirdropV1, SATAToken.address);
  });
};
