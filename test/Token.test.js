const { expect } = require('chai');
const { ethers } = require('hardhat');

const tokenName = 'Signata';
const tokenSymbol = 'SATA';

const tenMil = 10_000_000n * 10n ** 18n;
const fortyMil = 40_000_000n * 10n ** 18n;
const ninetyMil = 90_000_000n * 10n ** 18n;
const hundredMil = 100_000_000n * 10n ** 18n;
const tenThousand = 10_000n * 10n ** 18n;
const remainderBalance = 49_990_000n * 10n ** 18n;
const minEth = 70_000_000_000_000_000n; // 0.07 ETH
const ninePointNineOne = 9_910_000_000_000_000_000n;

describe('Token + Airdrop', function () {
  let owner;
  let reserveAddr;
  let intAddr;
  let claimer1;
  let claimer2;
  let claimer3;
  let token;
  let airdrop;

  before(async () => {
    const signers = await ethers.getSigners();
    [owner, , , claimer1, claimer2, claimer3] = signers;
    reserveAddr = signers[1].address;
    intAddr = signers[2].address;
  });

  describe('Token Contract', function () {
    it('deploys with owner', async function () {
      const Token = await ethers.getContractFactory('Token');
      token = await Token.deploy(
        tokenName,
        tokenSymbol,
        reserveAddr,
        fortyMil,
        intAddr,
        tenMil,
        fortyMil,
      );
      await token.waitForDeployment();
      expect(await token.owner()).to.equal(owner.address);
    });

    it('mints the reserve address', async function () {
      expect(await token.balanceOf(reserveAddr)).to.equal(fortyMil);
    });

    it('mints the integration address', async function () {
      expect(await token.balanceOf(intAddr)).to.equal(tenMil);
    });

    it('mints the remainder to owner', async function () {
      expect(await token.totalSupply()).to.equal(ninetyMil);
    });
  });

  describe('Airdrop Contract', function () {
    it('deploys with owner', async function () {
      const Airdrop = await ethers.getContractFactory('SATAAirdropV1');
      airdrop = await Airdrop.deploy(
        await token.getAddress(),
        tenThousand,
        minEth,
      );
      await airdrop.waitForDeployment();
      expect(await airdrop.owner()).to.equal(owner.address);
    });

    it('can mint the airdrop', async function () {
      await expect(token.mintAirdrop(await airdrop.getAddress(), tenMil)).to.not
        .be.reverted;
    });

    it('has minted the airdrop', async function () {
      expect(await token.balanceOf(await airdrop.getAddress())).to.equal(
        tenMil,
      );
      expect(await token.totalSupply()).to.equal(hundredMil);
    });

    it('can retrieve the balance of the airdrop', async function () {
      expect(await airdrop.availableTokens()).to.equal(tenMil);
    });

    it('cannot mint the airdrop again', async function () {
      await expect(
        token.mintAirdrop(await airdrop.getAddress(), tenMil),
      ).to.be.revertedWith('Airdrop already minted.');
    });

    it('can claim airdrop with a valid account', async function () {
      await expect(airdrop.connect(claimer1).claim()).to.not.be.reverted;
      expect(await token.balanceOf(claimer1.address)).to.equal(tenThousand);
    });

    it('cannot repeat a claim', async function () {
      await expect(airdrop.connect(claimer1).claim()).to.be.revertedWith(
        'Airdrop already claimed.',
      );
    });

    it('cannot claim with insufficient eth', async function () {
      // drain claimer2 below the 0.07 ETH threshold; leave just enough for gas
      const balance = await ethers.provider.getBalance(claimer2.address);
      const keep = ethers.parseEther('0.05'); // < minEth (0.07)
      const gasReserve = ethers.parseEther('0.01');
      await claimer2.sendTransaction({
        to: claimer1.address,
        value: balance - keep - gasReserve,
      });
      await expect(airdrop.connect(claimer2).claim()).to.be.revertedWith(
        'Invalid account.',
      );
    });

    it('can end the airdrop and reclaim tokens', async function () {
      await expect(airdrop.endAirdrop(reserveAddr)).to.not.be.reverted;
    });

    it('cannot end the airdrop after airdrop depleted', async function () {
      await expect(airdrop.endAirdrop(reserveAddr)).to.be.revertedWith(
        'Airdrop depleted.',
      );
      expect(await token.balanceOf(await airdrop.getAddress())).to.equal(0n);
      expect(await token.balanceOf(reserveAddr)).to.equal(remainderBalance);
    });

    it('cannot claim after airdrop depleted', async function () {
      await expect(airdrop.connect(claimer3).claim()).to.be.revertedWith(
        'Airdrop depleted.',
      );
    });
  });
});
