// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "./IERC6150.sol";

// Note: the ERC-165 identifier for this interface is 0x4ac0aa46.
interface IERC6150Burnable is IERC6150 {
    /**
     * @notice Burn the `tokenId` token.
     * @dev Throws if the caller is not owner or approved.
     * @param tokenId The token to be burnt.
     */
    function safeBurn(uint256 tokenId) external;

    /**
     * @notice Batch burn tokens.
     * @dev Throws if the caller is not owner or approved for any token.
     * @param tokenIds The tokens to be burnt.
     */
    function safeBatchBurn(uint256[] memory tokenIds) external;
}
