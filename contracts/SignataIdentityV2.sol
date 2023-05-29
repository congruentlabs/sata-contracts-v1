// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ISignataIdentityV2.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
Contract Overview
The contract represents an identity management system where each address can have certain permissions (roles) assigned to it. The following storage mappings are used:

identityLockCount: Stores the number of times an identity has been locked.
identityDestroyed: Keeps track of whether an identity has been destroyed.
identityExists: Indicates whether an identity exists.
identityLocked: Tracks whether an identity is currently locked.
canLock: Specifies whether an address can lock a specific identity.
canUnlock: Specifies whether an address can unlock a specific identity.
canDestroy: Specifies whether an address can destroy a specific identity.
canDelegate: Specifies whether an address can delegate its permissions to another address.
The contract provides functions to create, destroy, lock, and unlock identities. It also allows adding and removing delegates who can perform actions on behalf of the identity.
*/
contract SignataIdentityV2 is ISignataIdentityV2 {
    using Counters for Counters.Counter;
    uint256 internal constant MAX_UINT256 = type(uint256).max;
    // storage
    mapping(address => Counters.Counter) public identityLockCount;
    mapping(address => bool) public identityDestroyed;
    mapping(address => bool) public identityExists;
    mapping(address => bool) public identityLocked;
    mapping(address => mapping(address => bool)) public canLock;
    mapping(address => mapping(address => bool)) public canUnlock;
    mapping(address => mapping(address => bool)) public canDestroy;
    mapping(address => mapping(address => bool)) public canDelegate;

    constructor() {}

    modifier exists(address identity) {
        require(
            identityExists[identity],
            "SignataIdentityV2: The identity must exist."
        );
        _;
    }

    modifier notDestroyed(address identity) {
        require(
            !identityDestroyed[identity],
            "SignataIdentityV2: The identity has been destroyed."
        );
        _;
    }

    modifier notLocked(address identity) {
        require(
            !identityLocked[identity],
            "SignataIdentityV2: The identity is locked."
        );
        _;
    }

    /**
    Identity Creation (create):

    The create function allows an address to create its identity if it doesn't already exist.
    It sets the identityExists flag to true for the calling address and assigns all roles (canLock, canUnlock, canDestroy, canDelegate) to itself.
    */
    function create() external {
        require(
            !identityExists[msg.sender],
            "SignataIdentityV2: The identity must not already exist."
        );

        identityExists[msg.sender] = true;

        // assigned all roles for self
        canLock[msg.sender][msg.sender] = true;
        canUnlock[msg.sender][msg.sender] = true;
        canDestroy[msg.sender][msg.sender] = true;
        canDelegate[msg.sender][msg.sender] = true;

        emit Create(msg.sender);
    }

    /**
    Identity Destruction (destroy):

    The destroy function allows an authorized address to destroy an existing identity.
    It checks whether the calling address has the authorization (canDestroy) to destroy the specified identity.
    If authorized, it sets the identityDestroyed flag to true for the specified identity and removes all roles assigned to it.
    It also clears the identityLockCount and identityLocked variables.
    */
    function destroy(address identity) external exists(identity) {
        require(
            identityDestroyed[identity] != true,
            "SignataIdentityV2: The identity has already been destroyed."
        );

        require(
            canDestroy[identity][msg.sender] == true,
            "SignataIdentityV2:Not authorized to destroy identity."
        );

        identityDestroyed[identity] = true;

        delete canLock[identity][identity];
        delete canUnlock[identity][identity];
        delete canDestroy[identity][identity];
        delete canDelegate[identity][identity];
        delete identityLockCount[identity];
        delete identityLocked[identity];

        emit Destroy(identity, msg.sender);
    }

    /**
    Identity Locking (lock):

    The lock function allows an authorized address to lock an existing, non-destroyed identity.
    It checks whether the calling address has the authorization (canLock) to lock the specified identity.
    If authorized, it sets the identityLocked flag to true and increments the identityLockCount for the specified identity.
    */
    function lock(
        address identity
    ) external exists(identity) notDestroyed(identity) notLocked(identity) {
        require(
            canLock[identity][msg.sender],
            "SignataIdentityV2:Not authorized to lock this identity."
        );

        identityLocked[identity] = true;
        identityLockCount[identity].increment();

        emit Lock(identity, msg.sender);
    }

    /**
    Identity Unlocking (unlock):

    The unlock function allows an authorized address to unlock an existing, non-destroyed identity.
    It checks whether the calling address has the authorization (canUnlock) to unlock the specified identity.
    If authorized, it sets the identityLocked flag to false for the specified identity.
    */
    function unlock(
        address identity
    ) external exists(identity) notDestroyed(identity) {
        require(
            identityLocked[identity],
            "SignataIdentityV2: The identity is already unlocked."
        );

        require(
            identityLockCount[identity].current() != MAX_UINT256,
            "SignataIdentityV2: The identity is permanently locked."
        );

        require(
            canUnlock[identity][msg.sender],
            "SignataIdentityV2:Not authorized to unlock this identity."
        );

        identityLocked[identity] = false;

        emit Unlock(identity, msg.sender);
    }

    /**
    Delegate Management (addDelegate):

    The addDelegate function allows an authorized address to add a delegate for a specific identity.
    It checks whether the calling address has the authorization (canDelegate) to delegate permissions.
    If authorized, it assigns the specified permissions (canLock, canUnlock, canDestroy, canDelegate) to the new delegate.
     */
    function addDelegate(
        address identity,
        address newDelegate,
        bool _canLock,
        bool _canUnlock,
        bool _canDestroy,
        bool _canDelegate
    ) external exists(identity) notDestroyed(identity) notLocked(identity) {
        require(
            canDelegate[identity][msg.sender],
            "SignataIdentityV2: Not authorized to delegate."
        );

        canLock[identity][newDelegate] = _canLock;
        canUnlock[identity][newDelegate] = _canUnlock;
        canDestroy[identity][newDelegate] = _canDestroy;
        canDelegate[identity][newDelegate] = _canDelegate;

        emit DelegateAdded(
            identity,
            newDelegate,
            msg.sender,
            _canLock,
            _canUnlock,
            _canDestroy,
            _canDelegate
        );
    }

    /**
    Delegate Management (removeDelegate):

    The removeDelegate function allows an authorized address to remove a delegate for a specific identity.
    It checks whether the calling address has the authorization (canDelegate) to remove the delegate.
    It deletes the delegate's permissions for the specified identity.
     */
    function removeDelegate(
        address identity,
        address delegateToRemove
    ) external exists(identity) notDestroyed(identity) notLocked(identity) {
        require(
            canDelegate[identity][msg.sender],
            "SignataIdentityV2: Not authorized to delete delegate."
        );

        require(
            identity != delegateToRemove,
            "SignataIdentityV2: Cannot remove self delegation"
        );

        delete canLock[identity][delegateToRemove];
        delete canUnlock[identity][delegateToRemove];
        delete canDestroy[identity][delegateToRemove];
        delete canDelegate[identity][delegateToRemove];

        emit DelegateRemoved(identity, delegateToRemove, msg.sender);
    }
}
