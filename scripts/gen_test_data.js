const web3 = require('web3');
const Util = require('ethereumjs-util');

const CHAINID = 4;
var IDENTITY_CONTRACT_ADDRESS = '0xb24e28a4b7fed6d59d3bd06af586f02fddfa6385';
const EIP712DOMAINTYPE_DIGEST = '0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472';
const NAME_DIGEST = '0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f';
const VERSION_DIGEST = '0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6';
const SALT = '0x233cdb81615d25013bb0519fbe69c16ddc77f9fa6a9395bd2aecfdfc1c0896e3';
const TXTYPE_CREATE_DIGEST = '0x469a26f6afcc5806677c064ceb4b952f409123d7e70ab1fd0a51e86205b9937b';   
const TXTYPE_ROLLOVER_DIGEST = '0x3925a5eeb744076e798ef9df4a1d3e1d70bcca2f478f6df9e6f0496d7de53e1e';
const TXTYPE_UNLOCK_DIGEST = '0xd814812ff462bae7ba452aadd08061fe1b4bda9916c0c4a84c25a78985670a7b';
const TXTYPE_DESTROY_DIGEST = '0x21459c8977584463672e32d031e5caf426140890a0f0d2172da41491b70ef9f5';

const DOMAIN_SEPARATOR = web3.utils.sha3(
  EIP712DOMAINTYPE_DIGEST 
    + NAME_DIGEST.slice(2) 
    + VERSION_DIGEST.slice(2) 
    + CHAINID.toString('16').padStart(64, '0') 
    + IDENTITY_CONTRACT_ADDRESS.slice(2).padStart(64, '0') 
    + SALT.slice(2), 
  {encoding: 'hex'}
);

const inputHash = web3.utils.sha3(
  TXTYPE_CREATE_DIGEST
    + '0xce95dade44e7307baa616c77ef446915633dd9ab'.slice(2).padStart(64, '0')
    + '0xc34504f0195f00914a1a3b5adf142b015f174125'.slice(2).padStart(64, '0'),
  {encoding: 'hex'}
);

const hashToSign = web3.utils.sha3(
  '0x19' + '01' + DOMAIN_SEPARATOR.slice(2) + inputHash.slice(2),
  {encoding: 'hex'}
);

const { r, s, v } = Util.ecsign(
  Buffer.from(hashToSign.slice(2), 'hex'),
  Buffer.from('0x9a62c90e6229cc35ef07382f9ba10253ed12d173842a0baec33c19e3aafd8a8f'.slice(2), 'hex')
);

console.log(r.toString('hex'));
console.log(s.toString('hex'));
console.log(v);



const schemaReceipt = await rightsContract.mintSchema(
  '0xce95DAde44E7307bAA616C77EF446915633dD9Ab',
  true,
  true,
  "https://foo.com/schema/admins.json",
  { from: delegate1 }
);

// const rightReceipt = await rightsContract.mintRight(
//   2,
//   delegate1,
//   false,
//   { from: delegate1 }
// );
