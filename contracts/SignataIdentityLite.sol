// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/*
This is the lite version of the 
*/
contract SignataIdentityLite {
    uint256 private constant MAX_UINT256 = type(uint256).max;
    
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)")
    bytes32 private constant EIP712DOMAINTYPE_DIGEST = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472;
    
    // keccak256("Signata")
    bytes32 private constant NAME_DIGEST = 0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f;
    
    // keccak256("1")
    bytes32 private constant VERSION_DIGEST = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    bytes32 private constant SALT = 0x233cdb81615d25013bb0519fbe69c16ddc77f9fa6a9395bd2aecfdfc1c0896e3;
    
    bytes32 private immutable _domainSeperator;
    
    // storage
    mapping(address => uint256) public _identityLockCount;
    mapping(address => uint256) public _identityRolloverCount;
    mapping(address => bool) public _identityDestroyed;
    mapping(address => bool) public _identityExists;
    mapping(address => bool) public _identityLocked;
    mapping(address => address) public _identityDelegate;
    
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
    
    event Create(address indexed identity);
    event Destroy(address indexed identity);
    event Lock(address indexed identity);
    event Rollover(address indexed identity);
    event Unlock(address indexed identity);
    
    function create() external {
        require(
            !_identityExists[msg.sender],
            "SignataIdentityLite: The identity must not already exist."
        );
        
        _identityExists[msg.sender] = true;
        
        emit Create(msg.sender);
    }
    
    function setDelegate(address delegate) external {

        _identityDelegate[msg.sender] = delegate;
    }
    
    function destroy() external {
        require(
            _identityExists[msg.sender],
            "SignataIdentityLite: The identity must exist."
        );
        
        require(
            !_identityDestroyed[msg.sender],
            "SignataIdentityLite: The identity has already been destroyed."
        );
        
        _identityDestroyed[msg.sender] = true;
        
        
        emit Destroy(msg.sender);
    }
    
    function lock() external {
        require(
            _identityExists[msg.sender],
            "SignataIdentityLite: The identity must exist."
        );
        
        require(
            !_identityDestroyed[msg.sender],
            "SignataIdentityLite: The identity has been destroyed."
        );
        
        require(
            !_identityLocked[msg.sender],
            "SignataIdentityLite: The identity has already been locked."
        );
        
        _identityLocked[msg.sender] = true;
        _identityLockCount[msg.sender] += 1;
        
        emit Lock(msg.sender);
    }

    function unlock()
        external 
    {
        require(
            _identityExists[msg.sender],
            "SignataIdentityLite: The identity must exist."
        );
        
        require(
            !_identityDestroyed[msg.sender],
            "SignataIdentityLite: The identity has been destroyed."
        );
        
        require(
            _identityLocked[msg.sender],
            "SignataIdentityLite: The identity is already unlocked."
        );
        
        require(
            _identityLockCount[msg.sender] != MAX_UINT256,
            "SignataIdentityLite: The identity is permanently locked."
        );

        require(
            _identityDelegate[msg.sender],
            "SignataIdentityLite: Not the delegate address."
        );

        _identityLocked[msg.sender] = false;
        
        emit Unlock(msg.sender);
    }

    function getLockCount(address identity)
        external
        view
        returns (uint256) 
    {
         require(
            _identityExists[identity],
            "SignataIdentityLite: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentityLite: The identity has been destroyed."
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
            "SignataIdentityLite: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentityLite: The identity has been destroyed."
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
            "SignataIdentityLite: The identity must exist."
        );
        
        require(
            !_identityDestroyed[identity],
            "SignataIdentityLite: The identity has been destroyed."
        );
        
        return _identityLocked[identity];
    }
}