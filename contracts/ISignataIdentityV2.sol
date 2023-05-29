// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISignataIdentityV2 {
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

    function create() external;
    function destroy(address identity) external;
    function lock(address identity) external;
    function unlock(address identity) external;
    function addDelegate(
        address identity,
        address newDelegate,
        bool canLock,
        bool canUnlock,
        bool canDestroy,
        bool canDelegate
    ) external;
    function removeDelegate(address identity, address delegateToRemove) external;

    function identityLockCount(address) external view returns (uint256);
    function identityDestroyed(address) external view returns (bool);
    function identityExists(address) external view returns (bool);
    function identityLocked(address) external view returns (bool);
    function canLock(address, address) external view returns (bool);
    function canUnlock(address, address) external view returns (bool);
    function canDestroy(address, address) external view returns (bool);
    function canDelegate(address, address) external view returns (bool);
}