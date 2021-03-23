const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const { BN, expectRevert } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const SATAToken = contract.fromArtifact("SATAToken");
const SATAAirdropV1 = contract.fromArtifact("SATAAirdropV1");
const [ owner, claimer1, claimer2, claimer3 ] = accounts;

var token;
var airdropContract;

describe("Token Contract", function () {
  it("deployer is owner", async function () {
    token = await SATAToken.new(
      "Signata",
      "SATA",
      "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
      new BN("40000000000000000000000000"), // 40,000,000
      "0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b",
      new BN("10000000000000000000000000"), // 10,000,000
      new BN("40000000000000000000000000"), // 40,000,000
      { from: owner })
    expect(await token.owner()).to.equal(owner);
  });
  
  it("mints the reserve address", async function() {
    expect(await token.balanceOf("0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0")).to.be.bignumber.equal("40000000000000000000000000");
  });

  it("mints the integration address", async function() {
    expect(await token.balanceOf("0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b")).to.be.bignumber.equal("10000000000000000000000000");
  });

  it("succesfully mints the remainder", async function() {
    expect(await token.totalSupply()).to.be.bignumber.equal("90000000000000000000000000");
  });
});

describe("Airdrop Contract", function () {
  it("deployer is owner", async function () {
    airdropContract = await SATAAirdropV1.new(
      token.address,
      new BN("1000000000000000000000"),
      new BN("100000000000000000"), // 0.1 ETH
      { from: owner })
    expect(await airdropContract.owner()).to.equal(owner);
  });

  it("can mint the airdrop", async function() {
    expect(await token.mintAirdrop(airdropContract.address, new BN("10000000000000000000000000"), { from: owner })).to.not.throw;
  });

  it("has minted the airdrop", async function() {
    expect(await token.balanceOf(airdropContract.address)).to.be.bignumber.equal("10000000000000000000000000");
    expect(await token.totalSupply()).to.be.bignumber.equal("100000000000000000000000000"); // 100,000,000
  });

  it("can retrieve the balance of the airdrop", async function() {
    expect(await airdropContract.availableTokens()).to.be.bignumber.equal("10000000000000000000000000");
  });

  it("cannot mint the airdrop again", async function() {
    await expectRevert(token.mintAirdrop(airdropContract.address, new BN("10000000000000000000000000"), { from: owner }), "Airdrop already minted.");
  });

  it("can claim airdrop with a valid account", async function() {
    expect(await airdropContract.claim({ from: claimer1 })).to.not.throw;
  });

  it("cannot repeat a claim", async function() {
    await expectRevert(airdropContract.claim({ from: claimer1 }), "Airdrop already claimed.");
  });

  it("cannot claim with inusfficient eth", async function() {
    await web3.eth.sendTransaction({
      from: claimer2,
      to: claimer1,
      value: '9910000000000000000',
    });
    await expectRevert(airdropContract.claim({ from: claimer2 }), "Invalid account.");
  });
  
  it("can end the airdrop and reclaim tokens", async function() {
    expect(await airdropContract.endAirdrop("0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0", { from: owner })).to.not.throw;
  });
  
  it("cannot end the airdrop after airdrop depleted", async function() {
    await expectRevert(airdropContract.endAirdrop(
      "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
      { from: owner }
    ), "Airdrop depleted.");
    expect(await token.balanceOf(airdropContract.address)).to.be.bignumber.equal("0");
    expect(await token.balanceOf("0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0")).to.be.bignumber.equal("49999000000000000000000000");    
  });

  it("cannot claim after airdrop depleted", async function() {
    await expectRevert(airdropContract.claim({ from: claimer3 }), "Airdrop depleted.");
  });

});
