// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface ISignataIdentity {
    function getIdentity(address delegateKey) external view returns (address);
    function isLocked(address identity) external view returns (bool);
}