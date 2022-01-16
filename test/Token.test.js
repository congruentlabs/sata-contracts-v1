const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const { BN, expectRevert } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const Token = contract.fromArtifact("Token");
const SATAAirdropV1 = contract.fromArtifact("SATAAirdropV1");

const minEth             = "70000000000000000";
const ninePointNineOne   = "9910000000000000000";
const tenThousand        = "10000000000000000000000";
const tenMil             = "10000000000000000000000000";
const twentyMil          = "20000000000000000000000000";
const fortyMil           = "40000000000000000000000000";
const remainderBalance   = "49990000000000000000000000";
const nintyMil           = "90000000000000000000000000";
const hundredMil         = "100000000000000000000000000";
const tokenName          = "Signata";
const tokenSymbol        = "SATA";

const [
  owner,
  claimer1,
  claimer2,
  claimer3,
] = accounts;

const reserveAddr        = "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0";
const intAddr            = "0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b";

var token;
var airdropContract;

describe("Token Contract", function () {
  it("deployer is owner", async function () {
    token = await Token.new(
      tokenName,
      tokenSymbol,
      reserveAddr,
      new BN(fortyMil),
      intAddr,
      new BN(tenMil),
      new BN(fortyMil),
      { from: owner })
    expect(await token.owner()).to.equal(owner);
  });
  
  it("mints the reserve address", async function() {
    expect(await token.balanceOf(reserveAddr)).to.be.bignumber.equal(fortyMil);
  });

  it("mints the integration address", async function() {
    expect(await token.balanceOf(intAddr)).to.be.bignumber.equal(tenMil);
  });

  it("succesfully mints the remainder", async function() {
    expect(await token.totalSupply()).to.be.bignumber.equal(nintyMil);
  });
});

describe("Airdrop Contract", function () {
  it("deployer is owner", async function () {
    airdropContract = await SATAAirdropV1.new(
      token.address,
      new BN(tenThousand),
      new BN(pointOneEth),
      { from: owner })
    expect(await airdropContract.owner()).to.equal(owner);
  });

  it("can mint the airdrop", async function() {
    expect(await token.mintAirdrop(airdropContract.address, new BN(tenMil), { from: owner })).to.not.throw;
  });

  it("has minted the airdrop", async function() {
    expect(await token.balanceOf(airdropContract.address)).to.be.bignumber.equal(tenMil);
    expect(await token.totalSupply()).to.be.bignumber.equal(hundredMil); // 100,000,000
  });

  it("can retrieve the balance of the airdrop", async function() {
    expect(await airdropContract.availableTokens()).to.be.bignumber.equal(tenMil);
  });

  it("cannot mint the airdrop again", async function() {
    await expectRevert(token.mintAirdrop(
      airdropContract.address,
      new BN(tenMil),
      { from: owner }
    ), "Airdrop already minted.");
  });

  it("can claim airdrop with a valid account", async function() {
    expect(await airdropContract.claim({ from: claimer1 })).to.not.throw;
    expect(await token.balanceOf(claimer1)).to.be.bignumber.equal(tenThousand);
  });

  it("cannot repeat a claim", async function() {
    await expectRevert(airdropContract.claim({ from: claimer1 }), "Airdrop already claimed.");
  });

  it("cannot claim with inusfficient eth", async function() {
    await web3.eth.sendTransaction({
      from: claimer2,
      to: claimer1,
      value: ninePointNineOne,
    });
    await expectRevert(airdropContract.claim({ from: claimer2 }), "Invalid account.");
  });
  
  it("can end the airdrop and reclaim tokens", async function() {
    expect(await airdropContract.endAirdrop(reserveAddr, { from: owner })).to.not.throw;
  });
  
  it("cannot end the airdrop after airdrop depleted", async function() {
    await expectRevert(airdropContract.endAirdrop(
      reserveAddr,
      { from: owner }
    ), "Airdrop depleted.");
    expect(await token.balanceOf(airdropContract.address)).to.be.bignumber.equal("0");
    expect(await token.balanceOf(reserveAddr)).to.be.bignumber.equal(remainderBalance);    
  });

  it("cannot claim after airdrop depleted", async function() {
    await expectRevert(airdropContract.claim({ from: claimer3 }), "Airdrop depleted.");
  });
});
