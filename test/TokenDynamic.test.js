const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const TokenDynamic = contract.fromArtifact("TokenDynamic");
const {
  tenMil,
  twentyMil,
} = require("../migrations/constants");

const [
  owner,
  supplyController1,
  supplyController2,
] = accounts;

var token;

describe("Dynamic Token Contract", () => {
  it("deployer is owner", async () => {
    token = await TokenDynamic.new(
      supplyController1,
      new BN(tenMil),
      { from: owner })
    expect(await token.owner()).to.equal(owner);
    expect(await token.balanceOf(owner)).to.be.bignumber.equal(tenMil);
  });

  it("cannot mint or burn after deploy", async () => {
    await expectRevert(token.mint(owner, tenMil, { from: owner }), "Supply Control Disabled.");
    await expectRevert(token.burn(owner, tenMil, { from: owner }), "Supply Control Disabled.");
  });
  
  it("cannot change supply mode without being the supply controller", async () => {
    await expectRevert(token.enableSupplyControl({ from: owner }), "Not Supply Controller.");
    await expectRevert(token.enableSupplyControl({ from: supplyController2 }), "Not Supply Controller.");

    await expectRevert(token.disableSupplyControl({ from: owner }), "Not Supply Controller.");
    await expectRevert(token.disableSupplyControl({ from: supplyController2 }), "Not Supply Controller.");
  });

  it("can enable supply control mode", async () => {
    const enableReceipt = await token.enableSupplyControl({ from: supplyController1 });

    await expectEvent(enableReceipt, 'SupplyControlChanged', { changedTo: true });
  });
  
  it("can mint and burn tokens", async () => {
    expect(await token.mint(owner, tenMil, { from: owner })).to.not.throw;
    expect(await token.balanceOf(owner)).to.be.bignumber.equal(twentyMil);

    expect(await token.burn(owner, tenMil, { from: owner })).to.not.throw;
    expect(await token.balanceOf(owner)).to.be.bignumber.equal(tenMil);
  });
  
  it("cannot mint and burn tokens with the supply controller", async () => {
    await expectRevert(token.mint(owner, tenMil, { from: supplyController1 }), "caller is not the owner");
    await expectRevert(token.burn(owner, tenMil, { from: supplyController1 }), "caller is not the owner");

    await expectRevert(token.mint(owner, tenMil, { from: supplyController2 }), "caller is not the owner");
    await expectRevert(token.mint(owner, tenMil, { from: supplyController2 }), "caller is not the owner");
  });

  it("can disable supply control mode", async () => {
    const disableReceipt = await token.disableSupplyControl({ from: supplyController1 });

    await expectEvent(disableReceipt, 'SupplyControlChanged', { changedTo: false });
  });

  it("cannot mint or burn after disabling again", async () => {
    await expectRevert(token.mint(owner, tenMil, { from: owner }), "Supply Control Disabled.");
    await expectRevert(token.burn(owner, tenMil, { from: owner }), "Supply Control Disabled.");
  });

  it('can change supply controller', async () => {
    const changeReceipt = await token.changeSupplyController(supplyController2, { from: supplyController1 });

    await expectEvent(changeReceipt, 'SupplyControllerChanged', { oldController: supplyController1, newController: supplyController2 });
  })

  it("can enable supply control mode as second controller", async () => {
    const enableReceipt = await token.enableSupplyControl({ from: supplyController2 });

    await expectEvent(enableReceipt, 'SupplyControlChanged', { changedTo: true });
  });
  
  it("can mint and burn tokens", async () => {
    expect(await token.mint(owner, tenMil, { from: owner })).to.not.throw;
    expect(await token.balanceOf(owner)).to.be.bignumber.equal(twentyMil);

    expect(await token.burn(owner, tenMil, { from: owner })).to.not.throw;
    expect(await token.balanceOf(owner)).to.be.bignumber.equal(tenMil);
  });
  
  it("cannot mint and burn tokens with the supply controllers", async () => {
    await expectRevert(token.mint(owner, tenMil, { from: supplyController1 }), "caller is not the owner");
    await expectRevert(token.burn(owner, tenMil, { from: supplyController1 }), "caller is not the owner");

    await expectRevert(token.mint(owner, tenMil, { from: supplyController2 }), "caller is not the owner");
    await expectRevert(token.mint(owner, tenMil, { from: supplyController2 }), "caller is not the owner");
  });

  it("can disable supply control mode as second controller", async () => {
    const disableReceipt = await token.disableSupplyControl({ from: supplyController2 });

    await expectEvent(disableReceipt, 'SupplyControlChanged', { changedTo: false });
  });

  it("cannot mint or burn after disabling again", async () => {
    await expectRevert(token.mint(owner, tenMil, { from: owner }), "Supply Control Disabled.");
    await expectRevert(token.burn(owner, tenMil, { from: owner }), "Supply Control Disabled.");
  });
});