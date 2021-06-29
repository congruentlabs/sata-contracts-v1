const Util = require('ethereumjs-util');
const { accounts, privateKeys, contract, web3 } = require("@openzeppelin/test-environment");
const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const SignataIdentity = contract.fromArtifact("SignataIdentity");

const CHAINID = 1;
var IDENTITY_CONTRACT_ADDRESS;
var DOMAIN_SEPARATOR;

const EIP712DOMAINTYPE_DIGEST = '0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472';
const NAME_DIGEST = '0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f';
const VERSION_DIGEST = '0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6';
const SALT = '0x233cdb81615d25013bb0519fbe69c16ddc77f9fa6a9395bd2aecfdfc1c0896e3';
const TXTYPE_CREATE_DIGEST = '0x469a26f6afcc5806677c064ceb4b952f409123d7e70ab1fd0a51e86205b9937b';   
const TXTYPE_ROLLOVER_DIGEST = '0x3925a5eeb744076e798ef9df4a1d3e1d70bcca2f478f6df9e6f0496d7de53e1e';
const TXTYPE_UNLOCK_DIGEST = '0xd814812ff462bae7ba452aadd08061fe1b4bda9916c0c4a84c25a78985670a7b';
const TXTYPE_DESTROY_DIGEST = '0x21459c8977584463672e32d031e5caf426140890a0f0d2172da41491b70ef9f5';

const owner = accounts[0];
const i1 = accounts[1];
const d1 = accounts[2];
const s1 = accounts[3];
const i2 = accounts[4];
const d2 = accounts[5];
const s2 = accounts[6];
// const i3 = accounts[7];
const d3 = accounts[8];
const s3 = accounts[9];

const i1Private = privateKeys[1];
const d1Private = privateKeys[2];
const s1Private = privateKeys[3];
const i2Private = privateKeys[4];
const d2Private = privateKeys[5];
const s2Private = privateKeys[6];
// const i3Private = privateKeys[7];
const d3Private = privateKeys[8];
const s3Private = privateKeys[9];


var idContract;

/**
 * Leave the tests in the order specified, as they rely on the sequence
 * of events in the blocks.
 */
describe("Signata Identity Contract", function () {
  it("can be deployed", async function () {
    idContract = await SignataIdentity.new(CHAINID, { from: owner });

    IDENTITY_CONTRACT_ADDRESS = idContract.address;

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

	it("can create the first identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + d1.slice(2).padStart(64, '0')
        + s1.slice(2).padStart(64, '0'),
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

    const createReceipt = await idContract.create(v, r, s, d1, s1, { from: i1 });

    await expectEvent(createReceipt, 'Create', {
      identity: i1,
      delegateKey: d1,
      securityKey: s1
    });
	});
  
	it("can get delegate for identity", async function () {
    expect(await idContract.getDelegate(i1, { from: i1 })).to.equal(d1);
	});
  
	it("cannot get delegate for invalid identity", async function () {
    await expectRevert(idContract.getDelegate(i2, { from: i1 }), "SignataIdentity: The identity must exist.");
	});

	it("can get identity for delegate", async function () {
    expect(await idContract.getIdentity(d1, { from: i1 })).to.equal(i1);
	});

	it("cannot get identity for invalid delegate", async function () {
    await expectRevert(idContract.getIdentity(d2, { from: i1 }), "SignataIdentity: The delegate key provided is not linked to an existing identity.");
	});
  
	it("is not locked", async function () {
    expect(await idContract.isLocked(i1, { from: i1 })).to.equal(false);
	});

	it("can get lock count of 0", async function () {
    expect(await idContract.getLockCount(i1, { from: i1 })).to.be.bignumber.equal(new BN(0));
	});

	it("can get rollover count of 0", async function () {
    expect(await idContract.getRolloverCount(i1, { from: i1 })).to.be.bignumber.equal(new BN(0));
	});

	it("cannot create a duplicate identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + d2.slice(2).padStart(64, '0')
        + s2.slice(2).padStart(64, '0'),
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

    await expectRevert(idContract.create(v, r, s, d2, s2, { from: i1 }), "SignataIdentity: The identity must not already exist.");
	});

	it("cannot reuse a delegate key", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + d1.slice(2).padStart(64, '0')
        + s2.slice(2).padStart(64, '0'),
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

    await expectRevert(idContract.create(v, r, s, d1, s2, { from: i2 }), "SignataIdentity: Delegate key must not already be in use.");
	});
  
	it("must use distinct keys", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + d2.slice(2).padStart(64, '0')
        + d2.slice(2).padStart(64, '0'),
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

    await expectRevert(idContract.create(v, r, s, d2, d2, { from: i2 }), "SignataIdentity: Keys must be unique.");
	});

	it("cannot lock a nonexistant identity key", async function () {
    await expectRevert(idContract.lock(i2, { from: i2 }), "SignataIdentity: The identity must exist.");
	});

	it("cannot be locked with identity key", async function () {
    await expectRevert(idContract.lock(i1, { from: i1 }), "SignataIdentity: The sender is unauthorised to lock identity.");
	});
  
	it("can be locked with delegate key", async function () {
    await expectEvent(await idContract.lock(i1, { from: d1 }), 'Lock', { identity: i1 });
	});

	it("is first identity locked", async function () {
    expect(await idContract.isLocked(i1, { from: i1 })).to.equal(true);
	});
  
	it("cannot be locked while already locked with delegate key", async function () {
    await expectRevert(idContract.lock(i1, { from: d1 }), "SignataIdentity: The identity has already been locked.");
	});

	it("can destroy the first identity", async function () {
    const inputHash = web3.utils.sha3(TXTYPE_DESTROY_DIGEST, {encoding: 'hex'});

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const sig1 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(d1Private.slice(2), 'hex')
    );

    const delegateV = sig1.v;
    const delegateR = sig1.r;
    const delegateS = sig1.s;

    const sig2 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(s1Private.slice(2), 'hex')
    );

    const securityV = sig2.v;
    const securityR = sig2.r;
    const securityS = sig2.s;

    const destroyReceipt = await idContract.destroy(
      i1,
      delegateV,
      delegateR,
      delegateS,
      securityV,
      securityR,
      securityS,
      { from: i1 }
    );

    await expectEvent(destroyReceipt, 'Destroy', {
      identity: i1
    });
	});

	it("cannot lock a destroyed identity", async function () {
    await expectRevert(idContract.lock(i1, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});

	it("cannot unlock a destroyed identity", async function () {
    // this signature is just for testing, we need value data types for the contract call
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST,
      {encoding: 'hex'}
    );
    const { v, r, s } = Util.ecsign(
      Buffer.from(inputHash.slice(2), 'hex'),
      Buffer.from(s1Private.slice(2), 'hex')
    );

    await expectRevert(idContract.unlock(i1, v, r, s, v, r, s, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});

	it("cannot destroy a destroyed identity", async function () {
    // this signature is just for testing, we need value data types for the contract call
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST,
      {encoding: 'hex'}
    );
    const { v, r, s } = Util.ecsign(
      Buffer.from(inputHash.slice(2), 'hex'),
      Buffer.from(s1Private.slice(2), 'hex')
    );

    await expectRevert(idContract.destroy(i1, v, r, s, v, r, s, { from: i1 }), "SignataIdentity: The identity has already been destroyed.");
	});

  it("cannot rollover a destroyed identity", async function () {
    // this signature is just for testing, we need value data types for the contract call
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST,
      {encoding: 'hex'}
    );
    const { v, r, s } = Util.ecsign(
      Buffer.from(inputHash.slice(2), 'hex'),
      Buffer.from(s1Private.slice(2), 'hex')
    );

    await expectRevert(idContract.rollover(i1, v, r, s, v, r, s, i1, i1, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});

	it("cannot get delegate for a destroyed identity", async function () {
    await expectRevert(idContract.getDelegate(i1, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});

	it("cannot get lock count for a destroyed identity", async function () {
    await expectRevert(idContract.getLockCount(i1, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});

	it("cannot get rollover count for a destroyed identity", async function () {
    await expectRevert(idContract.getRolloverCount(i1, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});
  
	it("cannot check is locked for a destroyed identity", async function () {
    await expectRevert(idContract.isLocked(i1, { from: i1 }), "SignataIdentity: The identity has been destroyed.");
	});

	it("can create a second identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_CREATE_DIGEST
        + d2.slice(2).padStart(64, '0')
        + s2.slice(2).padStart(64, '0'),
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

    const createReceipt = await idContract.create(v, r, s, d2, s2, { from: i2 });

    await expectEvent(createReceipt, 'Create', {
      identity: i2,
      delegateKey: d2,
      securityKey: s2
    });
	});

  it("can lock second identity with security key", async function () {
    await expectEvent(await idContract.lock(i2, { from: s2 }), 'Lock', { identity: i2 });
	});

	it("is second identity locked", async function () {
    expect(await idContract.isLocked(i2, { from: i2 })).to.equal(true);
	});
  
	it("second identity lock count has incremented", async function () {
    expect(await idContract.getLockCount(i2, { from: i2 })).to.be.bignumber.equal(new BN(1));
	});
  
	it("cannot be locked while already locked with security key", async function () {
    await expectRevert(idContract.lock(i2, { from: s2 }), "SignataIdentity: The identity has already been locked.");
	});

  it("can unlock the second identity", async function () {
    const inputHash = web3.utils.sha3(TXTYPE_UNLOCK_DIGEST + "0x01".slice(2).padStart(64, '0'), {encoding: 'hex'});

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const sig1 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(d2Private.slice(2), 'hex')
    );

    const delegateV = sig1.v;
    const delegateR = sig1.r;
    const delegateS = sig1.s;

    const sig2 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(s2Private.slice(2), 'hex')
    );

    const securityV = sig2.v;
    const securityR = sig2.r;
    const securityS = sig2.s;

    const unlockReceipt = await idContract.unlock(
      i2,
      delegateV,
      delegateR,
      delegateS,
      securityV,
      securityR,
      securityS,
      { from: d2 }
    );

    await expectEvent(unlockReceipt, 'Unlock', {
      identity: i2
    });
	});

    //rollover

  it("can rollover the second identity", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_ROLLOVER_DIGEST
        + d3.slice(2).padStart(64, '0')
        + s3.slice(2).padStart(64, '0')
        + "0x00".slice(2).padStart(64, '0'), {encoding: 'hex'});

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const sig1 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(d2Private.slice(2), 'hex')
    );

    const delegateV = sig1.v;
    const delegateR = sig1.r;
    const delegateS = sig1.s;

    const sig2 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(s2Private.slice(2), 'hex')
    );

    const securityV = sig2.v;
    const securityR = sig2.r;
    const securityS = sig2.s;

    const rolloverReceipt = await idContract.rollover(
      i2,
      delegateV,
      delegateR,
      delegateS,
      securityV,
      securityR,
      securityS,
      d3,
      s3,
      { from: d2 }
    );

    await expectEvent(rolloverReceipt, 'Rollover', {
      identity: i2,
      delegateKey: d3,
      securityKey: s3,
    });
  });

  it("can lock second identity with third security key", async function () {
    await expectEvent(await idContract.lock(i2, { from: s3 }), 'Lock', { identity: i2 });
	});
  
  it("can rollover the second identity whilst locked", async function () {
    const inputHash = web3.utils.sha3(
      TXTYPE_ROLLOVER_DIGEST
        + d2.slice(2).padStart(64, '0')
        + s2.slice(2).padStart(64, '0')
        + "0x01".slice(2).padStart(64, '0'), {encoding: 'hex'});

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const sig1 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(d3Private.slice(2), 'hex')
    );

    const delegateV = sig1.v;
    const delegateR = sig1.r;
    const delegateS = sig1.s;

    const sig2 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(s3Private.slice(2), 'hex')
    );

    const securityV = sig2.v;
    const securityR = sig2.r;
    const securityS = sig2.s;

    const rolloverReceipt = await idContract.rollover(
      i2,
      delegateV,
      delegateR,
      delegateS,
      securityV,
      securityR,
      securityS,
      d2,
      s2,
      { from: d3 }
    );

    await expectEvent(rolloverReceipt, 'Rollover', {
      identity: i2,
      delegateKey: d2,
      securityKey: s2,
    });
  });


  it("can unlock the second identity again", async function () {
    const inputHash = web3.utils.sha3(TXTYPE_UNLOCK_DIGEST + "0x02".slice(2).padStart(64, '0'), {encoding: 'hex'});

    const hashToSign = web3.utils.sha3(
      '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
      {encoding: 'hex'}
    );

    const sig1 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(d2Private.slice(2), 'hex')
    );

    const delegateV = sig1.v;
    const delegateR = sig1.r;
    const delegateS = sig1.s;

    const sig2 = Util.ecsign(
      Buffer.from(hashToSign.slice(2), 'hex'),
      Buffer.from(s2Private.slice(2), 'hex')
    );

    const securityV = sig2.v;
    const securityR = sig2.r;
    const securityS = sig2.s;

    const unlockReceipt = await idContract.unlock(
      i2,
      delegateV,
      delegateR,
      delegateS,
      securityV,
      securityR,
      securityS,
      { from: d2 }
    );

    await expectEvent(unlockReceipt, 'Unlock', {
      identity: i2
    });
	});
});
