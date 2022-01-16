/**
 * We need to use the openzeppelin/test-environment specifically because it exposes access to
 * private keys of the accounts used in the testing. We need to access those private keys to be able
 * to digitally sign records as part of the rights management. This means we also need to use truffle
 * to run tests, because it depends on pulling in the abi definitions in the build folder. We will
 * use hardhat for network deployments, and truffle for unit tests. If hardhat with ethers can give
 * us exposure to the account private keys, or we find an alternate way to load in keys for testing
 * (with loaded balances) then we can consolidate the testing to use hardhat as well.
 */
const Util = require('ethereumjs-util');
const { accounts, privateKeys, contract, web3 } = require("@openzeppelin/test-environment");
const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const SignataIdentity = contract.fromArtifact("SignataIdentity");
const SignataRight = contract.fromArtifact("SignataRight");

const CHAINID = 1;
var IDENTITY_CONTRACT_ADDRESS;
var RIGHTS_CONTRACT_ADDRESS;
var DOMAIN_SEPARATOR;

const EIP712DOMAINTYPE_DIGEST = '0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472';
const NAME_DIGEST = '0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f';
const VERSION_DIGEST = '0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6';
const SALT = '0x233cdb81615d25013bb0519fbe69c16ddc77f9fa6a9395bd2aecfdfc1c0896e3';
const TXTYPE_CREATE_DIGEST = '0x469a26f6afcc5806677c064ceb4b952f409123d7e70ab1fd0a51e86205b9937b';   

const owner = accounts[0];
const identity1 = accounts[1];
const delegate1 = accounts[2];
const security1 = accounts[3];
const identity2 = accounts[4];
const delegate2 = accounts[5];
const security2 = accounts[6];
const identity3 = accounts[7];
const delegate3 = accounts[8];
const security3 = accounts[9];
const unboundId = accounts[10];
console.log(unboundId);

const i1Private = privateKeys[1];
const d1Private = privateKeys[2];
const s1Private = privateKeys[3];
const i2Private = privateKeys[4];
const d2Private = privateKeys[5];
const s2Private = privateKeys[6];
const i3Private = privateKeys[7];
const d3Private = privateKeys[8];
const s3Private = privateKeys[9];
const unboundPrivate = privateKeys[10];

var identityContract;
var rightsContract;

/**
 * Leave the tests in the order specified, as they rely on the sequence
 * of events in the blocks.
 */
describe("Signata Right Contract", function () {
  /**
   * IDENTITY CONTRACT SETUP TESTS
   * This replicates a lot of what the other identity contract tests do, we just do this again
   * so this test file is independent to the identity tests
   */
  it("can deploy the identity contract", async function () {
    identityContract = await SignataIdentity.new(CHAINID, { from: owner });

    IDENTITY_CONTRACT_ADDRESS = identityContract.address;

    DOMAIN_SEPARATOR = web3.utils.sha3(
      EIP712DOMAINTYPE_DIGEST 
        + NAME_DIGEST.slice(2) 
        + VERSION_DIGEST.slice(2) 
        + CHAINID.toString('16').padStart(64, '0') 
        + IDENTITY_CONTRACT_ADDRESS.slice(2).padStart(64, '0') 
        + SALT.slice(2), 
      {encoding: 'hex'}
    );

    expect(IDENTITY_CONTRACT_ADDRESS).to.not.be.empty;
    expect(DOMAIN_SEPARATOR).to.not.be.empty;
    // expect(await idContract.owner()).to.equal(owner);
  });

  it("can create the first test identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + delegate1.slice(2).padStart(64, '0')
        + security1.slice(2).padStart(64, '0'),
      {encoding: 'hex'}
    );

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const { r, s, v } = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(i1Private.slice(2), 'hex')
    );

    const createReceipt = await identityContract.create(v, r, s, delegate1, security1, { from: identity1 });

    await expectEvent(createReceipt, 'Create', {
      identity: identity1,
      delegateKey: delegate1,
      securityKey: security1
    });
  });

  it("can create the second test identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + delegate2.slice(2).padStart(64, '0')
        + security2.slice(2).padStart(64, '0'),
      {encoding: 'hex'}
    );

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const { r, s, v } = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(i2Private.slice(2), 'hex')
    );

    const createReceipt = await identityContract.create(v, r, s, delegate2, security2, { from: identity2 });

    await expectEvent(createReceipt, 'Create', {
      identity: identity2,
      delegateKey: delegate2,
      securityKey: security2
    });
  });

  it("can create the third test identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + delegate3.slice(2).padStart(64, '0')
        + security3.slice(2).padStart(64, '0'),
      {encoding: 'hex'}
    );

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const { r, s, v } = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(i3Private.slice(2), 'hex')
    );

    const createReceipt = await identityContract.create(v, r, s, delegate3, security3, { from: identity3 });

    await expectEvent(createReceipt, 'Create', {
      identity: identity3,
      delegateKey: delegate3,
      securityKey: security3
    });
  });

  /**
   * RIGHTS CONTRACT TESTS
   */

  it("can deploy the rights contract", async function () {
    rightsContract = await SignataRight.new(
      "RightsMinter",
      "RMINT",
      IDENTITY_CONTRACT_ADDRESS,
      "https://signata.net/schema/rightsminters.json", { from: owner }
    );

    RIGHTS_CONTRACT_ADDRESS = rightsContract.address;

    expect(await rightsContract.name()).to.equal("RightsMinter");
    expect(await rightsContract.symbol()).to.equal("RMINT");
  });

  it("can get the tokenURI for the minter", async () => {
    expect(await rightsContract.tokenURI(1)).to.equal("https://signata.net/schema/rightsminters.json");
  });

  it("can get the balance of the minter", async () => {
    expect(await rightsContract.balanceOf(RIGHTS_CONTRACT_ADDRESS)).to.be.bignumber.equal(new BN(1));
  });

  it("can get the owner of the minter", async () => {
    expect(await rightsContract.ownerOf(1)).to.equal(RIGHTS_CONTRACT_ADDRESS);
  });

  it("can mint a new schema as first delegate with transferable and revocable", async () => {
    const schemaReceipt = await rightsContract.mintSchema(
      delegate1,
      true,
      true,
      "https://foo.com/schema/admins.json",
      { from: delegate1 }
    );

    const uriHash = web3.utils.sha3("https://foo.com/schema/admins.json", { encoding: 'utf8' });

    await expectEvent(schemaReceipt, 'MintSchema', {
      schemaId: new BN(2),
      mintingRightId: new BN(2),
      uriHash
    });
  });

  it("can mint a new right as first delegate", async () => {
    const rightReceipt = await rightsContract.mintRight(
      2,
      delegate1,
      false,
      { from: delegate1 }
    );

    await expectEvent(rightReceipt, 'MintRight', {
      schemaId: new BN(2),
      rightId: new BN(3),
      unbound: false
    });
  });
  
  it("can mint a new right as first delegate to second delegate", async () => {
    const rightReceipt = await rightsContract.mintRight(
      2,
      delegate2,
      false,
      { from: delegate1 }
    );

    await expectEvent(rightReceipt, 'MintRight', {
      schemaId: new BN(2),
      rightId: new BN(4),
      unbound: false
    });
  });

  it("can mint an unbound right as first delegate to unbound identity", async () => {
    const rightReceipt = await rightsContract.mintRight(
      2,
      unboundId,
      true,
      { from: delegate1 }
    );

    await expectEvent(rightReceipt, 'MintRight', {
      schemaId: new BN(2),
      rightId: new BN(5),
      unbound: true
    });
  });
  
  it("can approve transferring the new right to the third identity", async () => {
    const approveReceipt = await rightsContract.approve(
      delegate3,
      4,
      { from: delegate2 }
    );

    await expectEvent(approveReceipt, 'Approval', {
      owner: delegate2,
      approved: delegate3,
      tokenId: new BN(4)
    });
  });

  it("can transfer the new right to the third identity", async () => {
    const transferReceipt = await rightsContract.transferFrom(
      delegate2,
      delegate3,
      4,
      { from: identity2 }
    );

    await expectEvent(transferReceipt, 'Transfer', {
      from: delegate2,
      to: delegate3,
      tokenId: new BN(4)
    });
  });

  it("can get the tokenURI for the first delegate", async () => {
    expect(await rightsContract.tokenURI(3, { from: delegate2 })).to.equal("https://foo.com/schema/admins.json");
  });

  it("can get the balance of the first identity", async () => {
    expect(await rightsContract.balanceOf(delegate1)).to.be.bignumber.equal(new BN(2));
  });

  it("can get the owner of the first identity", async () => {
    expect(await rightsContract.ownerOf(2)).to.equal(delegate1);
  });

  it("can mint a new schema as second delegate without transferable and revocable", async () => {
    const schemaReceipt = await rightsContract.mintSchema(
      delegate2,
      false,
      false,
      "https://bar.com/schema/admins.json",
      { from: delegate2 }
    );

    const uriHash = web3.utils.sha3("https://bar.com/schema/admins.json", { encoding: 'utf8' });

    await expectEvent(schemaReceipt, 'MintSchema', {
      schemaId: new BN(3),
      mintingRightId: new BN(6),
      uriHash
    });
  });

  it("can mint a new right as second delegate", async () => {
    const rightReceipt = await rightsContract.mintRight(
      3,
      delegate1,
      false,
      { from: delegate2 }
    );

    await expectEvent(rightReceipt, 'MintRight', {
      schemaId: new BN(3),
      rightId: new BN(7),
      unbound: false
    });
  });

  it("cannot transfer the second delegate non-transferable right", async () => {
    await expectRevert(rightsContract.transferFrom(
      delegate1,
      delegate2,
      7,
      { from: identity2 }),
      "SignataRight: This right is non-transferable."
    );
  });

  it("cannot transfer an unbound right", async () => {
    await expectRevert(rightsContract.transferFrom(
      unboundId,
      delegate2,
      5,
      { from: delegate1 }),
      "SignataIdentity: The delegate key provided is not linked to an existing identity."
    );
  });
  
  it("can revoke a right", async () => {
    const revokeReceipt = await rightsContract.revoke(
      3,
      { from: delegate1 }
    );

    await expectEvent(revokeReceipt, 'Revoke', {
      rightId: new BN(3)
    });
  });

  it("can revoke an unbound right", async () => {
    const revokeReceipt = await rightsContract.revoke(
      5,
      { from: delegate1 }
    );

    await expectEvent(revokeReceipt, 'Revoke', {
      rightId: new BN(5)
    });
  });

  it("cannot revoke a non-revocable right", async () => {
    await expectRevert(rightsContract.revoke(
      7,
      { from: identity2 }),
      "SignataRight: The right specified is not revocable."
    );
  });

  it("can retrieve total schemas", async () => {
    expect(await rightsContract.totalSchemas()).to.be.bignumber.equal(new BN(3));
  });
  
  it("can retrieve total supply", async () => {
    expect(await rightsContract.totalSupply()).to.be.bignumber.equal(new BN(7));
  });

  it("can retrieve minter of", async () => {
    expect(await rightsContract.minterOf(2)).to.equal(delegate1);
  });

  it("cannot retrieve minter of invalid schema", async () => {
    await expectRevert(rightsContract.minterOf(4), "SignataRight: Schema ID must correspond to an existing schema.");
  });
  
  it("can retrieve schema of", async () => {
    expect(await rightsContract.totalSchemas()).to.be.bignumber.equal(new BN(3));
  });

  it("can retrieve token by index", async () => {
    expect(await rightsContract.totalSchemas()).to.be.bignumber.equal(new BN(3));
  });
});
