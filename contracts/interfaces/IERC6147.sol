// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

interface IERC6147 {

    /// Logged when the guard of an NFT is changed or expires is changed
    /// @notice Emitted when the `guard` is changed or the `expires` is changed
    ///         The zero address for `newGuard` indicates that there currently is no guard address
    event UpdateGuardLog(uint256 indexed tokenId, address indexed newGuard, address oldGuard, uint64 expires);
    
    /// @notice Owner, authorised operators and approved address of the NFT can set guard and expires of the NFT and
    ///         valid guard can modifiy guard and expires of the NFT
    ///         If the NFT has a valid guard role, the owner, authorised operators and approved address of the NFT
    ///         cannot modify guard and expires
    /// @dev The `newGuard` can not be zero address
    ///      The `expires` need to be valid
    ///      Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to get the guard address for
    /// @param newGuard The new guard address of the NFT
    /// @param expires UNIX timestamp, the guard could manage the token before expires
    function changeGuard(uint256 tokenId, address newGuard, uint64 expires) external;

    /// @notice Remove the guard and expires of the NFT
    ///         Only guard can remove its own guard role and expires
    /// @dev The guard address is set to 0 address
    ///      The expires is set to 0
    ///      Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to remove the guard and expires for
    function removeGuard(uint256 tokenId) external;
    
    /// @notice Transfer the NFT and remove its guard and expires
    /// @dev The NFT is transferred to `to` and the guard address is set to 0 address
    ///      Throws if `tokenId` is not valid NFT
    /// @param from The address of the previous owner of the NFT
    /// @param to The address of NFT recipient 
    /// @param tokenId The NFT to get transferred for
    function transferAndRemove(address from, address to, uint256 tokenId) external;

    /// @notice Get the guard address and expires of the NFT
    /// @dev The zero address indicates that there is no guard
    /// @param tokenId The NFT to get the guard address and expires for
    /// @return The guard address and expires for the NFT
   function guardInfo(uint256 tokenId) external view returns (address, uint64);   
}