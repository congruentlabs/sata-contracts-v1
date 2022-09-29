// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../openzeppelin/contracts/access/AccessControl.sol";

interface ISignataRight {
    function holdsTokenOfSchema(address holder, uint256 schemaId)
        external
        view
        returns (bool);
}

contract RegulatedUSD is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    ISignataRight public signataRight;
    uint256 public schemaId;

    constructor(ISignataRight _signataRight, uint256 _schemaId)
        ERC20("Regulated USD", "RUSD")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        signataRight = _signataRight;
        schemaId = _schemaId;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        // both parties must hold a specifc NFT type
        require(
            signataRight.holdsTokenOfSchema(from, schemaId) &&
                signataRight.holdsTokenOfSchema(to, schemaId),
            "RegulatedUSD: transfer not allowed"
        );
        super._beforeTokenTransfer(from, to, amount);
    }

    function updateSignataRight(ISignataRight _signataRight)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        signataRight = _signataRight;
    }

    function updateSchemaId(uint256 _schemaId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        schemaId = _schemaId;
    }
}
