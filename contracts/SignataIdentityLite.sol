// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/access/AccessControl.sol";

/*
This is the lite version of the Signata Identity contract. There is no delegate or security key, only the caller or a specified delegate address can make changes.
*/
contract SignataIdentityLite is AccessControl {
    IERC20 public identityToken;
    mapping(address => uint256) public _identityLockCount;
    mapping(address => uint256) public _identityRolloverCount;
    mapping(address => address) public _identityDelegate;
    mapping(address => bool) public _identityDestroyed;
    mapping(address => bool) public _identityExists;
    mapping(address => bool) public _identityLocked;

    uint256 public minimumBalance = 10e18;
    uint256 public nonHolderFee = 5e15; // 0.005 ETH

    bytes32 public constant DELEGATE_ROLE = keccak256("DELEGATE_ROLE");
    bytes32 public constant MODIFIER_ROLE = keccak256("MODIFIER_ROLE");

    mapping(address => bool) public _authorizedDelegates;
  
    constructor() {
        grantRole(keccak256("DEFAULT_ADMIN_ROLE"), msg.sender);
    }

    event Create(address indexed identity);
    event Destroy(address indexed identity);
    event Lock(address indexed identity);
    event Rollover(address indexed identity);
    event Unlock(address indexed identity);
    event DelegateSet(address indexed delegate);
    event NonHolderFeeUpdated(uint256 newAmount);
    event MinimumBalanceUpdated(uint256 newAmount);
    event NativeWithdrawn(address to);
    event IdentityTokenUpdated(address indexed newAddress);

    modifier isDelegateFor(address subject) {
        require(
            _identityDelegate[subject] == msg.sender,
            "SignataIdentityLite: Not the delegate address"
        );
        _;
    }

    modifier notLocked(address subject) {
        require(
            !_identityLocked[subject],
            "SignataIdentityLite: The identity must not be locked."
        );
        _;
    }

    modifier isLocked(address subject) {
        require(
            _identityLocked[subject],
            "SignataIdentityLite: The identity must be locked."
        );
        _;
    }

    modifier notDestroyed(address subject) {
        require(
            !_identityDestroyed[subject],
            "SignataIdentityLite: The identity must not be destroyed."
        );
        _;
    }

    modifier isIdentity(address subject) {
        require(
            _identityExists[subject],
            "SignataIdentityLite: The identity must exist."
        );
        _;
    }

    modifier notIdentity(address subject) {
        require(
            !_identityExists[subject],
            "SignataIdentityLite: The identity must not exist."
        );
        _;
    }

    modifier notReachedLimit(address subject) {
                require(
            _identityLockCount[subject] != type(uint256).max,
            "SignataIdentityLite: The identity is permanently locked."
        );
    _;
    }

    receive() external payable {}

    // create identity, charging native if they don't hold the identity token
    function create()
        external
        payable
    {
        require(
            !_identityExists[msg.sender],
            "SignataIdentityLite: The identity must not already exist."
        );

        bool takeFee = true;

        if (identityToken.balanceOf(msg.sender) > minimumBalance) {
            takeFee = false;
        }

        if (takeFee) {
            (bool success, ) = payable(address(this)).call{ value: nonHolderFee }(""); 
            require(success, "SignataIdentityLite: Payment not received.");
        }
        
        _identityExists[msg.sender] = true;
        _identityDelegate[msg.sender] = msg.sender; // self delegate to start with

        emit Create(msg.sender);
    }

    function createAsDelegate(address subject)
        external
        onlyRole(DELEGATE_ROLE)
        notIdentity(subject)
    {
        _identityExists[subject] = true;
        _identityDelegate[subject] = msg.sender;

        emit Create(subject);
    }

    function setDelegate(address delegate)
        external
        isIdentity(msg.sender)
        notLocked(msg.sender)
        notDestroyed(msg.sender)
    {
        require(
            hasRole(DELEGATE_ROLE, delegate),
            "SignataIdentityLite: Delegate address not assigned DELEGATE_ROLE."
        );
        _identityDelegate[msg.sender] = delegate;
        emit DelegateSet(delegate);
    }

    function lock()
        external
        isIdentity(msg.sender)
        notLocked(msg.sender)
        notDestroyed(msg.sender)
    {
        _identityLocked[msg.sender] = true;
        emit Lock(msg.sender);
    }

    function unlock()
        external
        isIdentity(msg.sender)
        notDestroyed(msg.sender)
        isLocked(msg.sender)
    {
        _identityLocked[msg.sender] = false;
        emit Unlock(msg.sender);
    }

    function destroy()
        external
        isIdentity(msg.sender)
        notDestroyed(msg.sender)
    {
        _identityDestroyed[msg.sender] = true;
        emit Destroy(msg.sender);
    }

    function delegateLock(address subject)
        external
        onlyRole(DELEGATE_ROLE)
        isIdentity(subject)
        notLocked(subject)
        notDestroyed(subject)
        isDelegateFor(subject)
    {
        _identityLocked[subject] = true;
        emit Lock(subject);
    }

    function delegateUnlock(address subject)
        external
        onlyRole(DELEGATE_ROLE)
        isIdentity(subject)
        isLocked(subject)
        notDestroyed(subject)
        isDelegateFor(subject)
    {
        _identityLocked[subject] = false;
        emit Unlock(subject);
    }

    function delegateDestroy(address subject)
        external
        onlyRole(DELEGATE_ROLE)
        isIdentity(subject)
        notDestroyed(subject)
        isDelegateFor(subject)
    {
        _identityDestroyed[subject] = true;
        emit Destroy(subject);
    }

    function updateIdentityToken(address newToken)
        external
        onlyRole(MODIFIER_ROLE)
    {
        identityToken = IERC20(newToken);
        emit IdentityTokenUpdated(newToken);
    }

    function withdraw(address to)
        external 
        onlyRole(MODIFIER_ROLE)
    {
        (bool success, ) = payable(to).call{ value: address(this).balance }("");
        require(success, "SignataIdentityLite: Withdraw failed.");
        emit NativeWithdrawn(to);
    }
    
    function updateMinimumBalance(uint256 newAmount)
        external 
        onlyRole(MODIFIER_ROLE)
    {
        minimumBalance = newAmount;
        emit MinimumBalanceUpdated(newAmount);
    }

    function updateNonHolderFee(uint256 newAmount)
        external 
        onlyRole(MODIFIER_ROLE)
    {
        nonHolderFee = newAmount;
        emit NonHolderFeeUpdated(newAmount);
    }
}