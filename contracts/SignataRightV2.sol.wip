// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ISignataIdentityV2.sol";
import "./ERC6150AccessControl.sol";
import "./ERC6150ParentTransferable.sol";
import "./interfaces/IERC5192.sol";
import "./interfaces/IERC6147.sol";
import "./interfaces/IERC5484.sol";

contract SignataRightV2 is
    ERC6150AccessControl,
    ERC6150ParentTransferable,
    IERC5192,
    IERC6147,
    IERC5484
{
    ISignataIdentityV2 public _signataIdentity;
    mapping(uint256 => uint256) private _parentOf;
    mapping(uint256 => uint256[]) private _childrenOf;
    mapping(uint256 => uint256) private _indexInChildrenArray;
    mapping(uint256 => bool) internal _locked;

    /// @dev A structure representing a token of guard address and expires
    /// @param guard address of guard role
    /// @param expirs UNIX timestamp, the guard could manage the token before expires
    struct GuardInfo {
        address guard;
        uint64 expires;
    }
    mapping(uint256 => GuardInfo) internal _guardInfo;

    error ErrLocked();

    modifier notLocked(uint256 tokenId) {
        if (_locked[tokenId]) revert ErrLocked();
        _;
    }

    constructor(address signataIdentity) ERC6150("Signata Right", "SATARIGHT") {
        _signataIdentity = ISignataIdentityV2(signataIdentity);
    }

    function locked(uint256 tokenId) external view override returns (bool) {
        return _locked[tokenId];
    }

    function burnAuth(
        uint256 tokenId
    ) external view override returns (BurnAuth) {
        // return _locked[tokenId];
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
    function removeGuard(uint256 tokenId) public virtual {
        _updateGuard(tokenId, address(0), 0, true);
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

    /// @notice Check the guard address
    /// @dev The zero address indicates there is no guard
    /// @param tokenId The NFT to check the guard address for
    /// @return The guard address
    function _checkGuard(uint256 tokenId) internal view returns (address) {
        (address guard, ) = guardInfo(tokenId);
        address sender = _msgSender();
        if (guard != address(0)) {
            require(
                guard == sender,
                "ERC6147: sender is not guard of the token"
            );
            return guard;
        } else {
            return address(0);
        }
    }

    /// @dev Before transferring the NFT, need to check the guard address
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        address guard;
        address new_from = from;
        if (from != address(0)) {
            guard = _checkGuard(tokenId);
            new_from = ownerOf(tokenId);
        }
        if (guard == address(0)) {
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        }
        _transfer(new_from, to, tokenId);
    }

    /// @dev Before safe transferring the NFT, need to check the guard address
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override(ERC721, IERC721) {
        address guard;
        address new_from = from;
        if (from != address(0)) {
            guard = _checkGuard(tokenId);
            new_from = ownerOf(tokenId);
        }
        if (guard == address(0)) {
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        }
        _safeTransfer(from, to, tokenId, _data);
    }

    /// @dev When burning, delete `token_guard_map[tokenId]`
    /// This is an internal function that does not check if the sender is authorized to operate on the token.
    function _burn(uint256 tokenId) internal virtual override {
        (address guard, ) = guardInfo(tokenId);
        super._burn(tokenId);
        delete _guardInfo[tokenId];
        emit UpdateGuardLog(tokenId, address(0), guard, 0);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC6150, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Get the parent token of `tokenId` token.
     * @param tokenId The child token
     * @return parentId The Parent token found
     */
    function parentOf(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC6150, IERC6150)
        returns (uint256 parentId)
    {
        _requireMinted(tokenId);
        parentId = _parentOf[tokenId];
    }

    /**
     * @notice Get the children tokens of `tokenId` token.
     * @param tokenId The parent token
     * @return childrenIds The array of children tokens
     */
    function childrenOf(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC6150, IERC6150)
        returns (uint256[] memory childrenIds)
    {
        if (tokenId > 0) {
            _requireMinted(tokenId);
        }
        childrenIds = _childrenOf[tokenId];
    }

    /**
     * @notice Check the `tokenId` token if it is a root token.
     * @param tokenId The token want to be checked
     * @return Return `true` if it is a root token; if not, return `false`
     */
    function isRoot(
        uint256 tokenId
    ) public view virtual override(ERC6150, IERC6150) returns (bool) {
        _requireMinted(tokenId);
        return _parentOf[tokenId] == 0;
    }

    /**
     * @notice Check the `tokenId` token if it is a leaf token.
     * @param tokenId The token want to be checked
     * @return Return `true` if it is a leaf token; if not, return `false`
     */
    function isLeaf(
        uint256 tokenId
    ) public view virtual override(ERC6150, IERC6150) returns (bool) {
        _requireMinted(tokenId);
        return _childrenOf[tokenId].length == 0;
    }
}
