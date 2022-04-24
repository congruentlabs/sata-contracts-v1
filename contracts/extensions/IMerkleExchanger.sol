// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import "./IMerkleDistributor.sol";

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleExchanger is IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function oldToken() external view returns (address);
}