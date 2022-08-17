// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract SignataIdentity {
    uint256 public constant MAX_UINT256 = type(uint256).max;
    
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)")
    bytes32 public constant EIP712DOMAINTYPE_DIGEST = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472;
    
    // keccak256("Signata")
    bytes32 public constant NAME_DIGEST = 0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f;
    
    // keccak256("1")
    bytes32 public constant VERSION_DIGEST = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
    
    bytes32 public constant SALT = 0x233cdb81615d25013bb0519fbe69c16ddc77f9fa6a9395bd2aecfdfc1c0896e3;
    
    // keccak256("SignataIdentityCreateTransaction(address delegateKey, address securityKey)")
    bytes32 public constant TXTYPE_CREATE_DIGEST = 0x469a26f6afcc5806677c064ceb4b952f409123d7e70ab1fd0a51e86205b9937b;   
    
    // keccak256("SignataIdentityRolloverTransaction(address identity, address newDelegateKey, address newSecurityKey, uint256 rolloverCount)")
    bytes32 public constant TXTYPE_ROLLOVER_DIGEST = 0x3925a5eeb744076e798ef9df4a1d3e1d70bcca2f478f6df9e6f0496d7de53e1e;
    
    // keccak256("SignataIdentityUnlockTransaction(uint256 lockCount)")
    bytes32 public constant TXTYPE_UNLOCK_DIGEST = 0xd814812ff462bae7ba452aadd08061fe1b4bda9916c0c4a84c25a78985670a7b;
    
    // keccak256("SignataIdentityDestroyTransaction()");
    bytes32 public constant TXTYPE_DESTROY_DIGEST = 0x21459c8977584463672e32d031e5caf426140890a0f0d2172da41491b70ef9f5;
    
    bytes32 public immutable _domainSeperator;
    
    // storage
    mapping(address => address) public _delegateKeyToIdentity;
    mapping(address => uint256) public _identityLockCount;
    mapping(address => uint256) public _identityRolloverCount;
    mapping(address => address) public _identityToSecurityKey;
    mapping(address => address) public _identityToDelegateKey;
    mapping(address => bool) public _identityDestroyed;
    mapping(address => bool) public _identityExists;
    mapping(address => bool) public _identityLocked;
    
    constructor(uint256 chainId) {
        _domainSeperator = keccak256(
            abi.encode(
                EIP712DOMAINTYPE_DIGEST,
                NAME_DIGEST,
                VERSION_DIGEST,
                chainId,
                this,
                SALT
            )
        );
    }
    
    event Create(address indexed identity, address indexed delegateKey, address indexed securityKey);
    event Destroy(address indexed identity);
    event Lock(address indexed identity);
    event Rollover(address indexed identity, address indexed delegateKey, address indexed securityKey);
    event Unlock(address indexed identity);
    
    function create(
        uint8 identityV, 
        bytes32 identityR, 
        bytes32 identityS, 
        address delegateKey, 
        address securityKey
    ) external {
        require(
            _delegateKeyToIdentity[delegateKey] == address(0),
            "SignataIdentity: Delegate key must not already be in use."
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeperator,
                keccak256(
                    abi.encode(
                        TXTYPE_CREATE_DIGEST,
                        delegateKey,
                        securityKey
                    )
                )
            )
        );
        
        address identity = ecrecover(digest, identityV, identityR, identityS);
        
        require(
            msg.sender == identity,
            "SignataIdentity: The identity to be created must match the address of the sender."
        );
        
        require(
            identity != delegateKey && identity != securityKey && delegateKey != securityKey,
            "SignataIdentity: Keys must be unique."
        );
        
        require(
            !_identityExists[identity],
            "SignataIdentity: The identity must not already exist."
        );
        
        _delegateKeyToIdentity[delegateKey] = identity;
        _identityToDelegateKey[identity] = delegateKey;
        _identityExists[identity] = true;
        _identityToSecurityKey[identity] = securityKey;
        
        emit Create(identity, delegateKey, securityKey);
    }
    
    function destroy(
        address identity,
        uint8 delegateV,
        bytes32 delegateR, 
        bytes32 delegateS,
        uint8 securityV,
        bytes32 securityR, 
        bytes32 securityS
    ) external {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has already been destroyed."
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeperator,
                keccak256(abi.encode(TXTYPE_DESTROY_DIGEST))
            )
        );
        
        address delegateKey = ecrecover(digest, delegateV, delegateR, delegateS);
        
        require(
            _identityToDelegateKey[identity] == delegateKey,
            "SignataIdentity: Invalid delegate key signature provided."
        );
        
        address securityKey = ecrecover(digest, securityV, securityR, securityS);
        
        require(
            _identityToSecurityKey[identity] == securityKey,
            "SignataIdentity: Invalid security key signature provided."
        );
        
        _identityDestroyed[identity] = true;
        
        delete _delegateKeyToIdentity[delegateKey];
        delete _identityLockCount[identity];
        delete _identityRolloverCount[identity];
        delete _identityToSecurityKey[identity];
        delete _identityToDelegateKey[identity];
        delete _identityLocked[identity];
        
        emit Destroy(identity);
    }
    
    function lock(address identity) external {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        require(
            !_identityLocked[identity],
            "SignataIdentity: The identity has already been locked."
        );
        
        require(
            msg.sender == _identityToDelegateKey[identity] || msg.sender == _identityToSecurityKey[identity],
            "SignataIdentity: The sender is unauthorised to lock identity."
        );
        
        _identityLocked[identity] = true;
        _identityLockCount[identity] += 1;
        
        emit Lock(identity);
    }
    
    function getDelegate(address identity)
        external
        view
        returns (address)
    {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        return _identityToDelegateKey[identity];
    }
    
    function getIdentity(address delegateKey) 
        external
        view 
        returns (address) 
    {
        address identity = _delegateKeyToIdentity[delegateKey];
        
        require(
            identity != address(0),
            "SignataIdentity: The delegate key provided is not linked to an existing identity."
        );
        
        return identity;
    }

    function getLockCount(address identity)
        external
        view
        returns (uint256) 
    {
         require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        return _identityLockCount[identity];
    }    
    
    function getRolloverCount(address identity)
        external
        view
        returns (uint256) 
    {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        return _identityRolloverCount[identity];
    }
    
    function isLocked(address identity)
        external
        view
        returns (bool) 
    {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        return _identityLocked[identity];
    }
    
    function rollover(
        address identity,
        uint8 delegateV, 
        bytes32 delegateR, 
        bytes32 delegateS, 
        uint8 securityV, 
        bytes32 securityR, 
        bytes32 securityS,
        address newDelegateKey, 
        address newSecurityKey
    ) 
        external 
    {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        require(
            identity != newDelegateKey && identity != newSecurityKey && newDelegateKey != newSecurityKey,
            "SignataIdentity: The keys must be unique."
        );
        
        require(
            _delegateKeyToIdentity[newDelegateKey] == address(0),
            "SignataIdentity: The new delegate key must not already be in use."
        );
        
        require(
            msg.sender == _identityToDelegateKey[identity] || msg.sender == _identityToSecurityKey[identity],
            "SignataIdentity: The sender is unauthorised to rollover the identity."
        );
        
        require(
            _identityRolloverCount[identity] != MAX_UINT256,
            "SignataIdentity: The identity has already reached the maximum number of rollovers allowed."
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeperator,
                keccak256(
                    abi.encode(
                        TXTYPE_ROLLOVER_DIGEST,
                        newDelegateKey,
                        newSecurityKey,
                        _identityRolloverCount[identity]
                    )
                )
            )
        );
        
        address delegateKey = ecrecover(digest, delegateV, delegateR, delegateS);
        
        require(
            _identityToDelegateKey[identity] == delegateKey,
            "SignataIdentity: Invalid delegate key signature provided."
        );
        
        address securityKey = ecrecover(digest, securityV, securityR, securityS);
        
        require(
            _identityToSecurityKey[identity] == securityKey,
            "SignataIdentity: Invalid delegate key signature provided."
        );
        
        delete _delegateKeyToIdentity[delegateKey];
        
        _delegateKeyToIdentity[newDelegateKey] = identity;
        _identityToDelegateKey[identity] = newDelegateKey;
        _identityToSecurityKey[identity] = newSecurityKey;
        _identityRolloverCount[identity] += 1;
        
        emit Rollover(identity, newDelegateKey, newSecurityKey);
    }
    
    function unlock(
        address identity,
        uint8 delegateV, 
        bytes32 delegateR, 
        bytes32 delegateS, 
        uint8 securityV, 
        bytes32 securityR, 
        bytes32 securityS
    ) 
        external 
    {
        require(
            _identityExists[identity],
            "SignataIdentity: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentity: The identity has been destroyed."
        );
        
        require(
            _identityLocked[identity],
            "SignataIdentity: The identity is already unlocked."
        );
        
        require(
            _identityLockCount[identity] != MAX_UINT256,
            "SignataIdentity: The identity is permanently locked."
        );
        
        require(
            msg.sender == _identityToDelegateKey[identity] || msg.sender == _identityToSecurityKey[identity],
            "SignataIdentity: The sender is unauthorised to unlock the identity."
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeperator,
                keccak256(
                    abi.encode(
                        TXTYPE_UNLOCK_DIGEST,
                        _identityLockCount[identity]
                    )
                )
            )
        );
        
        address delegateKey = ecrecover(digest, delegateV, delegateR, delegateS);
        
        require(
            _identityToDelegateKey[identity] == delegateKey,
            "SignataIdentity: Invalid delegate key signature provided."
        );
        
        address securityKey = ecrecover(digest, securityV, securityR, securityS);
        
        require(
            _identityToSecurityKey[identity] == securityKey,
            "SignataIdentity: Invalid security key signature provided."
        );
        
        _identityLocked[identity] = false;
        
        emit Unlock(identity);
    }
}