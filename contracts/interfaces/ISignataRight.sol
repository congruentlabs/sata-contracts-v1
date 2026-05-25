// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISignataRight {
    function mintSchema(
        address minter,
        bool schemaTransferable,
        bool schemaRevocable,
        string calldata schemaURI
    ) external returns (uint256);

    function mintRight(
        uint256 schemaId,
        address to,
        bool unbound
    ) external;

    function holdsTokenOfSchema(address holder, uint256 schemaId)
        external
        view
        returns (bool);
}
