// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC6150.sol";
import "./interfaces/IERC5484.sol";
import "./interfaces/IERC5192.sol";
import "./interfaces/IERC6147.sol";
import "./ISignataIdentityV2.sol";

contract SignataRightV2 is IERC165, ERC6150, IERC5192, IERC5484, IERC6147, Ownable {
    using Counters for Counters.Counter;

    ISignataIdentityV2 public _signataIdentity;
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => bool) internal _locked;

    /// @dev A structure representing a token of guard address and expires
    /// @param guard address of guard role
    /// @param expirs UNIX timestamp, the guard could manage the token before expires
    struct GuardInfo {
        address guard;
        uint64 expires;
    }
    mapping(uint256 => GuardInfo) internal _guardInfo;
    mapping(uint256 => BurnAuth) internal _burnAuth;

    /**
     * @notice Emitted when the parent of `tokenId` token changed.
     * @param tokenId The token changed
     * @param oldParentId Previous parent token
     * @param newParentId New parent token
     */
    event ParentTransferred(
        uint256 tokenId,
        uint256 oldParentId,
        uint256 newParentId
    );
    error ErrLocked();
    
    modifier notLocked(uint256 tokenId) {
        if (_locked[tokenId]) revert ErrLocked();
        _;
    }

    constructor(ISignataIdentityV2 signataIdentity) ERC6150("Signata SBT Rights", "SATARIGHT") {
        _signataIdentity = signataIdentity;
    }

    function updateIdentityRegister(
        ISignataIdentityV2 newSignataIdentity
    ) external onlyOwner {
        _signataIdentity = newSignataIdentity;
    }

    function locked(
        uint256 tokenId
    ) external view returns (bool) {
        return _locked[tokenId];
    }

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
    function changeGuard(
        uint256 tokenId,
        address newGuard,
        uint64 expires
    ) public virtual {
        require(expires > block.timestamp, "ERC6147: invalid expires");
        _updateGuard(tokenId, newGuard, expires, false);
    }

    /// @notice Remove the guard and expires of the NFT
    ///         Only guard can remove its own guard role and expires
    /// @dev The guard address is set to 0 address
    ///      The expires is set to 0
    ///      Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to remove the guard and expires for
    function removeGuard(
        uint256 tokenId
    ) public virtual {
        _updateGuard(tokenId, address(0), 0, true);
    }

    /// @notice Get the guard address and expires of the NFT
    /// @dev The zero address indicates that there is no guard
    /// @param tokenId The NFT to get the guard address and expires for
    /// @return The guard address and expires for the NFT
    function guardInfo(
        uint256 tokenId
    ) public view virtual returns (address, uint64) {
        if (_guardInfo[tokenId].expires >= block.timestamp) {
            return (_guardInfo[tokenId].guard, _guardInfo[tokenId].expires);
        } else {
            return (address(0), 0);
        }
    }

    /// @notice Update the guard of the NFT
    /// @dev Delete function: set guard to 0 address and set expires to 0;
    ///      and update function: set guard to new address and set expires
    ///      Throws if `tokenId` is not valid NFT
    /// @param tokenId The NFT to update the guard address for
    /// @param newGuard The newGuard address
    /// @param expires UNIX timestamp, the guard could manage the token before expires
    /// @param allowNull Allow 0 address
    function _updateGuard(
        uint256 tokenId,
        address newGuard,
        uint64 expires,
        bool allowNull
    ) internal {
        (address guard, ) = guardInfo(tokenId);
        if (!allowNull) {
            require(
                newGuard != address(0),
                "ERC6147: new guard can not be null"
            );
        }
        if (guard != address(0)) {
            require(
                guard == msg.sender,
                "ERC6147: only guard can change it self"
            );
        } else {
            require(
                _isApprovedOrOwner(msg.sender, tokenId),
                "ERC6147: caller is not owner nor approved"
            );
        }

        if (guard != address(0) || newGuard != address(0)) {
            _guardInfo[tokenId] = GuardInfo(newGuard, expires);
            emit UpdateGuardLog(tokenId, newGuard, guard, expires);
        }
    }

    /// @notice Transfer the NFT and remove its guard and expires
    /// @dev The NFT is transferred to `to` and the guard address is set to 0 address
    ///      Throws if `tokenId` is not valid NFT
    /// @param from The address of the previous owner of the NFT
    /// @param to The address of NFT recipient
    /// @param tokenId The NFT to get transferred for
    function transferAndRemove(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        safeTransferFrom(from, to, tokenId);
        removeGuard(tokenId);
    }

    function burnAuth(
        uint256 tokenId
    ) external view override returns (BurnAuth) {
        return _burnAuth[tokenId];
    }

    /**
     * @notice Get total amount of children tokens under `parentId` token.
     * @dev If `parentId` is zero, it means get total amount of root tokens.
     * @return The total amount of children tokens under `parentId` token.
     */
    function childrenCountOf(
        uint256 parentId
    ) external view returns (uint256) {
        return childrenOf(parentId).length;
    }

    /**
     * @notice Get the token at the specified index of all children tokens under `parentId` token.
     * @dev If `parentId` is zero, it means get root token.
     * @return The token ID at `index` of all chlidren tokens under `parentId` token.
     */
    function childOfParentByIndex(
        uint256 parentId,
        uint256 index
    ) external view returns (uint256) {
        uint256[] memory children = childrenOf(parentId);
        return children[index];
    }

    /**
     * @notice Get the index position of specified token in the children enumeration under specified parent token.
     * @dev Throws if the `tokenId` is not found in the children enumeration.
     * If `parentId` is zero, means get root token index.
     * @param parentId The parent token
     * @param tokenId The specified token to be found
     * @return The index position of `tokenId` found in the children enumeration
     */
    function indexInChildrenEnumeration(
        uint256 parentId,
        uint256 tokenId
    ) external view returns (uint256) {
        require(parentOf(tokenId) == parentId, "wrong parent");
        return _getIndexInChildrenArray(tokenId);
    }

    /**
     * @notice Transfer parentship of `tokenId` token to a new parent token
     * @param newParentId New parent token id
     * @param tokenId The token to be changed
     */
    function transferParent(
        uint256 newParentId,
        uint256 tokenId
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC6150ParentTransferable: caller is not token owner nor approved"
        );
        if (newParentId != 0) {
            require(
                _exists(newParentId),
                "ERC6150ParentTransferable: newParentId doesn't exists"
            );
        }

        address owner = ownerOf(tokenId);
        uint256 oldParentId = parentOf(tokenId);
        _safeBurn(tokenId);
        _safeMintWithParent(owner, newParentId, tokenId);
        emit ParentTransferred(tokenId, oldParentId, newParentId);
    }

    /**
     * @notice Batch transfer parentship of `tokenIds` to a new parent token
     * @param newParentId New parent token id
     * @param tokenIds Array of token ids to be changed
     */
    function batchTransferParent(
        uint256 newParentId,
        uint256[] memory tokenIds
    ) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferParent(tokenIds[i], newParentId);
        }
    }
    
    /**
     * @notice Mint new parent tokens. Any caller can mint a parent token.
     * @param to Recipient of parent token
     * @param data Data to attach to token
     */
    function safeMintParent(
        address to,
        bytes calldata data,
        BurnAuth burnAuth_
    ) public {
        require(_signataIdentity.identityExists(to), "SignataRight::Recipient must be a registered Signata Identity.");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId, data);
        _burnAuth[tokenId] = burnAuth_;

        emit Issued(msg.sender, to, tokenId, burnAuth_);
    }

    /**
     * @notice Mint new leaf tokens. Only parents owners can mint underlying leaves.
     * @param to Recipient of leaf token
     * @param parentId Parent token ID
     */
    function safeMintLeaf(
        address to,
        uint256 parentId,
        BurnAuth burnAuth_
    ) public {
        require(_signataIdentity.identityExists(to), "SignataRight::Recipient must be a registered Signata Identity.");
        require(ownerOf(parentId) == msg.sender, "SignataRight::Only owner of the parent token can mint leaf tokens against it.");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMintWithParent(to, parentId, tokenId);
        _burnAuth[tokenId] = burnAuth_;

        emit Issued(msg.sender, to, tokenId, burnAuth_);
    }

    // function burnLeaf(uint256 tokenId) public {
    //     require(super.isLeaf(tokenId), "SignataRight::Token is not a leaf token.");
    //     uint256 parentId = parentOf(tokenId);
    //     require(ownerOf(parentId) == msg.sender, "SignataRight::Only the owner of the parent token can burn leaf tokens underneath it.");
    //     _burn(tokenId);
    // }

    // function burnParent(uint256 tokenId) public {
    //     require(super.isRoot(tokenId), "SignataRight::Token must be a parent token.");
    //     require(ownerOf(tokenId) == msg.sender, "SignataRight::Only the owner of the parent token can burn the parent token.");
        
    //     _burn(tokenId);
    // }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal override(ERC721)
    {
        require(!_locked[tokenId], "SignataRight::Token is locked");
        require(_signataIdentity.identityExists(to), "SignataRight::Recipient must be a registered Signata Identity.");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)   
        internal
        override(ERC721)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC6150)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}