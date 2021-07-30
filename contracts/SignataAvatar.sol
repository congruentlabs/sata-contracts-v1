// SPDX-License-Identifier: MIT

pragma solidity 0.8.5;

import "./tokens/IERC165.sol";
import "./tokens/IERC721.sol";
import "./tokens/IERC721Enumerable.sol";
import "./tokens/IERC721Metadata.sol";
import "./tokens/IERC721Receiver.sol";
import "./tokens/IERC721Schema.sol";

import "./SignataIdentity.sol";
import "./SignataRight.sol";

import "./types/extensions/Address.sol";

contract SignataAvatar is IERC721Enumerable, IERC721Metadata {
    using Address for address;
    
    event MintAvatar(uint256 indexed avatarId, bytes avatar);
    
    event SetPrimary(address indexed identity, uint256 indexed avatarId);
    
    bytes4 private constant INTERFACE_ID_ERC165 = type(IERC165).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721 = type(IERC721).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE = type(IERC721Enumerable).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721_METADATA = type(IERC721Metadata).interfaceId;
    
    string private _name;
    string private _symbol;
    
    SignataIdentity private _signataIdentity;
    SignataRight private _signataRight;

    mapping(uint256 => address) private _avatarToOwner;
    mapping(address => uint256) private _ownerToPrimaryAvatar;
    mapping(address => uint256) private _ownerToAvatarBalance;
    mapping(uint256 => address) private _avatarToApprovedAddress;
    mapping(uint256 => string) private _avatarToURI;
    mapping(address => mapping (address => bool)) private  _ownerToOperatorStatuses;
    mapping(address => mapping(uint256 => uint256)) private _ownerToAvatars;
    mapping(uint256 => uint256) private _avatarToOwnersAvatarsIndex;
    uint256[] private _avatars;
    
    uint256 private immutable _mintingTokenSchema;

    constructor(
        string memory name_,
        string memory symbol_, 
        string memory minterSchemeURI_,
        address rootAdmin_,
        address signataIdentity_,
        address signataRight_
    ) {
        _name = name_;
        _symbol = symbol_;
        
        _signataIdentity = SignataIdentity(signataIdentity_);
        _signataRight = SignataRight(signataRight_);
        
        _mintingTokenSchema = _signataRight.mintSchema(
            rootAdmin_,
            true, 
            true, 
            minterSchemeURI_
        );
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == INTERFACE_ID_ERC165
            || interfaceId == INTERFACE_ID_ERC721
            || interfaceId == INTERFACE_ID_ERC721_ENUMERABLE
            || interfaceId == INTERFACE_ID_ERC721_METADATA;
    }
    
    function getMintingSchema() external view returns (uint256) {
        return _mintingTokenSchema;
    }

    function mintAvatar(address to, bytes calldata avatar) external returns (uint256) {
        require(
            avatar.length == 576,
            "SignataAvatar: Invalid avatar provided."
        );
        
        uint256 avatarId = uint256(keccak256(avatar));
        
        require(
            _avatarToOwner[avatarId] == address(0),
            "SignataAvatar: Avatar already exists."
        );
        
        address minter;
        
        if (msg.sender.isContract()) {
            minter = msg.sender;
        } else {
            minter = _signataIdentity.getIdentity(msg.sender);
            
            require(
                !_signataIdentity.isLocked(minter),
                "SignataRight: The sender's account is locked."
            );
        }
        
        require(
            _signataRight.holdsTokenOfSchema(minter, _mintingTokenSchema),
            "SignataRight: The sender's account is not authorised to mint Avatars."
        );
        
        address recipient;
        
        if (to.isContract()) {
            recipient = to;
        } else {
            recipient = _signataIdentity.getIdentity(to);
            
            require(
                !_signataIdentity.isLocked(minter),
                "SignataRight: The sender's account is locked."
            );
        }
        
        _avatars.push(avatarId);
        _avatarToOwner[avatarId] = recipient;

        uint256 ownerToAvatarsLength = _ownerToAvatarBalance[recipient];
        
        _ownerToAvatars[recipient][ownerToAvatarsLength] = avatarId;
        _avatarToOwnersAvatarsIndex[avatarId] = ownerToAvatarsLength;
        _ownerToAvatarBalance[recipient] += 1;
        
        require(
            _isSafeToTransfer(address(0), recipient, avatarId, ""),
            "SignataRight: must only transfer to ERC721Receiver implementers when recipient is a smart contract."
        );
        
        emit MintAvatar(avatarId, avatar);
        
        emit Transfer(address(0), to, avatarId);
        
        return avatarId;
    }
    
    function getPrimaryAvatar(address delegate) external view returns (uint256) {
        address owner;
        
        if (delegate.isContract()) {
            owner = delegate;
        } else {
            owner = _signataIdentity.getIdentity(delegate);
        }
        
        return _ownerToPrimaryAvatar[owner];
    }
    
    function setPrimaryAvatar(uint256 avatarId) external {
        address owner;
        
        if (msg.sender.isContract()) {
            owner = msg.sender;
        } else {
            owner = _signataIdentity.getIdentity(msg.sender);
            
            require(
                !_signataIdentity.isLocked(owner),
                "SignataRight: The recipient's account is locked."
            );
        }
        
        require(
            avatarId == 0 || _avatarToOwner[avatarId] != owner,
            "SignataAvatar: The sender does not own the avatar specified."
        );
        
        require(
            _ownerToPrimaryAvatar[owner] != avatarId,
            "SignataAvatar: The avatar specified is already set as primary for the owner."
        );
        
        _ownerToPrimaryAvatar[owner] = avatarId;
        
        emit SetPrimary(owner, avatarId);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        if (owner.isContract()) {
            return _ownerToAvatarBalance[owner];
        }
        
        return _ownerToAvatarBalance[_signataIdentity.getIdentity(owner)];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _avatarToOwner[tokenId];
        
        require(
            owner != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );
        
        if (owner.isContract()) {
            return owner;
        }
        
        return _signataIdentity.getDelegate(owner);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        require(
            _avatarToOwner[tokenId] != address(0), 
            "SignataRight: Token ID must correspond to an existing avatar."
        );

        return _avatarToURI[tokenId];
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = _avatarToOwner[tokenId];
        
        require(
            owner != address(0),
            "SignataRight: Token ID must correspond to an existing avatar."
        );
        
        require(
            to != owner, 
            "SignataRight: Approval is not required for the owner of the avatar."
        );
        
        address controller;
        
        if (owner.isContract()) {
            controller = owner;
        } else {
            controller = _signataIdentity.getDelegate(owner);
            
            require(
                to != controller, 
                "SignataRight: Approval is not required for the owner of the avatar."
            );
            
            require(
                !_signataIdentity.isLocked(controller),
                "SignataRight: The owner's account is locked."
            );
        }
            
        require(
            msg.sender == controller || isApprovedForAll(owner, msg.sender),
            "SignataRight: The sender is not authorised to provide approvals."
        );
        
        _avatarToApprovedAddress[tokenId] = to;
    
        emit Approval(controller, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(
            _avatarToOwner[tokenId] != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );

        return _avatarToApprovedAddress[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public override {
        address owner;
        
        require(
            operator != msg.sender, 
            "SignataRight: Self-approval is not required."
        );
        
        if (msg.sender.isContract()) {
            owner = msg.sender;
        } else {
            owner = _signataIdentity.getIdentity(msg.sender);
            
            require(
                operator != owner, 
                "SignataRight: Self-approval is not required."
            );
            
            require(
                !_signataIdentity.isLocked(owner),
                "SignataRight: The owner's account is locked."
            );
        }

        _ownerToOperatorStatuses[owner][operator] = approved;
        
        emit ApprovalForAll(owner, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        address owner_ = (owner.isContract())
            ? owner
            :_signataIdentity.getIdentity(msg.sender);
            
        return _ownerToOperatorStatuses[owner_][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        address owner;
        address recipient;
        
        require(
            _avatarToOwner[tokenId] != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );
        
        require(
            to != address(0), 
            "SignataRight: Transfers to the zero address are not allowed."
        );
        
        if (from.isContract()) {
            owner = from;
        } else {
            owner = _signataIdentity.getIdentity(from);
            
            require(
                !_signataIdentity.isLocked(owner),
                "SignataRight: The owner's account is locked."
            );
        }
        
        require(
            _avatarToOwner[tokenId] == owner,
            "SignataRight: The account specified does not hold the avatar corresponding to the Token ID provided."
        );
        

        require(
            msg.sender == owner || msg.sender == _avatarToApprovedAddress[tokenId] || _ownerToOperatorStatuses[owner][msg.sender],
            "SignataRight: The sender is not authorised to transfer this right."
        );

        if (to.isContract()) {
            recipient = to;
        } else {
            recipient = _signataIdentity.getIdentity(to);
            
            require(
                !_signataIdentity.isLocked(recipient),
                "SignataRight: The recipient's account is locked."
            );
        }
        
        if (_ownerToPrimaryAvatar[owner] == tokenId) {
            delete _ownerToPrimaryAvatar[owner];
            
            emit SetPrimary(owner, 0);
        }
        
        uint256 lastAvatarIndex = _ownerToAvatarBalance[owner] - 1;
        uint256 avatarIndex = _avatarToOwnersAvatarsIndex[tokenId];

        if (avatarIndex != lastAvatarIndex) {
            uint256 lastAvatarId = _ownerToAvatars[owner][lastAvatarIndex];

            _ownerToAvatars[owner][avatarIndex] = lastAvatarId;
            _avatarToOwnersAvatarsIndex[lastAvatarId] = avatarIndex;
        }

        delete _ownerToAvatars[owner][lastAvatarIndex];
        delete _avatarToOwnersAvatarsIndex[tokenId];
        
        uint256 length = _ownerToAvatarBalance[recipient];
        
        _ownerToAvatars[recipient][length] = tokenId;
        _avatarToOwnersAvatarsIndex[tokenId] = length;
        
        delete _avatarToApprovedAddress[tokenId];
        
        emit Approval(from, address(0), tokenId);

        _ownerToAvatarBalance[owner] -= 1;
        _ownerToAvatarBalance[recipient] += 1;
        _avatarToOwner[tokenId] = recipient;

        emit Transfer(from, to, tokenId);
        
        if (_ownerToAvatarBalance[recipient] == 1) {
            _ownerToPrimaryAvatar[recipient] = tokenId;
            
            emit SetPrimary(owner, tokenId);          
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        transferFrom(from, to, tokenId);
        
        require(
            _isSafeToTransfer(from, to, tokenId, _data),
            "SignataRight: must only transfer to ERC721Receiver implementers when recipient is a smart contract."
        );
    }
    
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        address holder;
        
        if (owner.isContract()) {
            holder = owner;
        } else {
            holder = _signataIdentity.getIdentity(owner);
        }
        
        require(
            index < _ownerToAvatarBalance[holder], 
            "SignataRight: The index provided is out of bounds for the owner specified."
        );
        
        return _ownerToAvatars[holder][index];
    }

    function totalSupply() public view override returns (uint256) {
        return _avatars.length;
    }

    function tokenByIndex(uint256 index) public view override returns (uint256) {
        require(
            index < _avatars.length, 
            "SignataRight: The index provided is out of bounds."
        );
        
        return _avatars[index];
    }
        
    function _isSafeToTransfer(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool)
    {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("SignataRight: must only transfer to ERC721Receiver implementers when recipient is a smart contract.");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}