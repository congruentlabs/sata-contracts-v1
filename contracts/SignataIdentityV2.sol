// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SignataIdentityV2 {
    uint256 public constant MAX_UINT256 = type(uint256).max;
    // storage
    mapping(address => uint256) public identityLockCount;
    mapping(address => bool) public identityDestroyed;
    mapping(address => bool) public identityExists;
    mapping(address => bool) public identityLocked;
    mapping(address => mapping(address => bool)) public canLock;
    mapping(address => mapping(address => bool)) public canUnlock;
    mapping(address => mapping(address => bool)) public canDestroy;
    mapping(address => mapping(address => bool)) public canDelegate;

    constructor() {}

    event Create(address indexed identity);
    event Destroy(address indexed identity, address indexed sender);
    event Lock(address indexed identity, address indexed sender);
    event Unlock(address indexed identity, address indexed sender);
    event DelegateAdded(
        address indexed identity,
        address indexed newDelegate,
        address indexed sender,
        bool canLock,
        bool canUnlock,
        bool canDestroy,
        bool canDelegate
    );
    event DelegateRemoved(
        address indexed identity,
        address indexed removedDelegate,
        address sender
    );

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

    function destroy(address identity) external exists(identity) {
        require(
            !identityDestroyed[identity],
            "SignataIdentityV2: The identity has already been destroyed."
        );

        require(
            canDestroy[identity][msg.sender],
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

    function lock(
        address identity
    ) external exists(identity) notDestroyed(identity) notLocked(identity) {
        require(
            canLock[identity][msg.sender],
            "SignataIdentityV2:Not authorized to lock this identity."
        );

        identityLocked[identity] = true;
        identityLockCount[identity] += 1;

        emit Lock(identity, msg.sender);
    }

    function unlock(
        address identity
    ) external exists(identity) notDestroyed(identity) {
        require(
            identityLocked[identity],
            "SignataIdentityV2: The identity is already unlocked."
        );

        require(
            identityLockCount[identity] != MAX_UINT256,
            "SignataIdentityV2: The identity is permanently locked."
        );

        require(
            canUnlock[identity][msg.sender],
            "SignataIdentityV2:Not authorized to unlock this identity."
        );

        identityLocked[identity] = false;

        emit Unlock(identity, msg.sender);
    }

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

    function removeDelegate(
        address identity,
        address delegateToRemove
    ) external exists(identity) notDestroyed(identity) notLocked(identity) {
        require(
            canDelegate[identity][msg.sender],
            "SignataIdentityV2: Not authorized to delete delegate."
        );

        delete canLock[identity][delegateToRemove];
        delete canUnlock[identity][delegateToRemove];
        delete canDestroy[identity][delegateToRemove];
        delete canDelegate[identity][delegateToRemove];

        emit DelegateRemoved(identity, delegateToRemove, msg.sender);
    }
}
