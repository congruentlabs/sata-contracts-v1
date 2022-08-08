// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/access/Ownable.sol";

abstract contract IdentityStandard {
    mapping(address => uint256) public _identityLockCount;
    mapping(address => uint256) public _identityRolloverCount;
    mapping(address => address) public _identityDelegate;
    mapping(address => bool) public _identityDestroyed;
    mapping(address => bool) public _identityExists;
    mapping(address => bool) public _identityLocked;

    modifier notLocked() {
        require(!_identityLocked[msg.sender], "SignataIdentity: The identity must not be locked.");
        _;
    }

    modifier notDestroyed() {
        require(!_identityDestroyed[msg.sender], "SignataIdentity: The identity must not be destroyed.");
        _;
    }

    modifier identityExists() {
        require(_identityExists[msg.sender], "SignataIdentity: The identity must exist.");
        _;
    }
}

/*
This is the lite version of the Signata Identity contract. There is no delegate or security key, only the caller or a specified delegate address can make changes.
*/
contract SignataIdentityLite is Ownable, IdentityStandard {
    IERC20 public signataToken;
  
    constructor() {}

    receive() external payable {}

    event Create(address indexed identity);
    event Destroy(address indexed identity);
    event Lock(address indexed identity);
    event Rollover(address indexed identity);
    event Unlock(address indexed identity);
    event DelegateSet(address indexed delegate);

    function create() external payable {
        require(
            !_identityExists[msg.sender],
            "SignataIdentityLite: The identity must not already exist."
        );

        bool takeFee = true;

        if (signataToken.balanceOf(msg.sender) > 10e18) {
            takeFee = false;
        }

        if (takeFee) {
            (bool success, ) = payable(address(this)).transfer(msg.sender), 10e18);
        }
        
        _identityExists[msg.sender] = true;
        s
        emit Create(msg.sender);
    }
    
    function setDelegate(address delegate) external identityExists notLocked notDestroyed {
        _identityDelegate[msg.sender] = delegate;

        emit DelegateSet(delegate);
    }
    
    function destroy() external identityExists notDestroyed {        
        _identityDestroyed[msg.sender] = true;
        
        emit Destroy(msg.sender);
    }
    
    function lock() external identityExists notLocked notDestroyed {        
        _identityLocked[msg.sender] = true;
        _identityLockCount[msg.sender] += 1;
        
        emit Lock(msg.sender);
    }

    function unlock() external identityExists notDestroyed {
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

    function updateSignataToken(address newToken) external onlyOwner {
        signataToken = newToken;
    }

    function withdrawEth(address to) external onlyOwner {
        (bool success, ) = payable(recipient).transfer(address(this).balance);
    }
}