// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./IERC721Enumerable.sol";
import "./IERC721Metadata.sol";

interface IERC721Schema is IERC721Enumerable, IERC721Metadata {
    
    function schemaOf(uint256 tokenId) external view returns (uint256 schemaId);

    function minterOf(uint256 schemaId) external view returns (address owner);
    
    function holdsTokenOfSchema(address holder, uint256 schemaId) external view returns (bool hasRight);
    
    function totalSchemas() external view returns (uint256 total);
    
    function totalMintedFor(uint256 schemaId) external view returns (uint256 total);

    function tokenOfSchemaByIndex(uint256 schema, uint256 index) external view returns (uint256 tokenId);
}