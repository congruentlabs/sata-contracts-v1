// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./tokens/IERC165.sol";
import "./tokens/IERC721.sol";
import "./tokens/IERC721Enumerable.sol";
import "./tokens/IERC721Metadata.sol";
import "./tokens/IERC721Receiver.sol";
import "./tokens/IERC721Schema.sol";

import "./SignataIdentity.sol";
import "./types/extensions/Address.sol";

contract SignataRight is IERC721Schema {
    using Address for address;
    
    event MintSchema(uint256 indexed schemaId, uint256 indexed mintingRightId, bytes32 indexed uriHash);
    
    event MintRight(uint256 indexed schemaId, uint256 indexed rightId, bool indexed unbound);
    
    event Revoke(uint256 indexed rightId);
    
    uint256 private constant MAX_UINT256 = type(uint256).max;
    
    bytes4 private constant INTERFACE_ID_ERC165 = type(IERC165).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721 = type(IERC721).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE = type(IERC721Enumerable).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721_METADATA = type(IERC721Metadata).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC721_SCHEMA = type(IERC721Schema).interfaceId;

    string private _name;
    string private _symbol;
    SignataIdentity private _signataIdentity;
    
    // Schema Storage
    mapping(uint256 => uint256) private _schemaToRightBalance;
    mapping(uint256 => mapping(uint256 => uint256)) private _schemaToRights;
    mapping(uint256 => bool) _schemaRevocable;
    mapping(uint256 => bool) _schemaTransferable;
    mapping(uint256 => string) private _schemaToURI;
    mapping(bytes32 => uint256) private _uriHashToSchema;
    mapping(uint256 => uint256) private _schemaToMintingRight;
    mapping(address => mapping(uint256 => uint256)) _ownerToSchemaBalance;
    uint256 private _schemasTotal;
    
    // Rights Storage
    mapping(uint256 => address) private _rightToOwner;
    mapping(address => uint256) private _ownerToRightBalance;
    mapping(uint256 => address) private _rightToApprovedAddress;
    mapping(uint256 => bool) private _rightToRevocationStatus;
    mapping(uint256 => uint256) private _rightToSchema;
    mapping(address => mapping (address => bool)) private _ownerToOperatorStatuses;
    mapping(address => mapping(uint256 => uint256)) private _ownerToRights;
    mapping(uint256 => uint256) _rightToOwnerRightsIndex;
    uint256 private _rightsTotal;
    
    constructor(
        string memory name_, 
        string memory symbol_,
        address signataIdentity_,
        string memory mintingSchemaURI_
    ) {
        address thisContract = address(this);
        bytes32 uriHash = keccak256(bytes(mintingSchemaURI_));

        _name = name_;
        _symbol = symbol_;

        _signataIdentity = SignataIdentity(signataIdentity_);

        _schemaToRightBalance[1] = 1;
        _schemaToRights[1][0] = 1;
        _schemaRevocable[1] = false;
        _schemaTransferable[1] = true;
        _schemaToURI[1] = mintingSchemaURI_;
        _uriHashToSchema[uriHash] = 1;
        _schemaToMintingRight[1] = 1;
        _ownerToSchemaBalance[thisContract][1] = 1;
        _schemasTotal = 1;

        _rightToOwner[1] = thisContract;
        _ownerToRightBalance[thisContract] = 1;
        _rightToSchema[1] = 1;
        _ownerToRights[thisContract][0] = 1;
        _rightToOwnerRightsIndex[1] = 0;
        _rightsTotal = 1;
        
        emit MintSchema(1, 1, uriHash);
        
        emit MintRight(1, 1, false);
        
        emit Transfer(address(0), thisContract, 1);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == INTERFACE_ID_ERC165
            || interfaceId == INTERFACE_ID_ERC721
            || interfaceId == INTERFACE_ID_ERC721_ENUMERABLE
            || interfaceId == INTERFACE_ID_ERC721_METADATA
            || interfaceId == INTERFACE_ID_ERC721_SCHEMA;
    }
    
    function mintSchema(
        address minter,
        bool schemaTransferable, 
        bool schemaRevocable, 
        string calldata schemaURI
    ) external returns (uint256) {
        require(
            _schemasTotal != MAX_UINT256,
            "SignataRight: Maximum amount of schemas already minted."
        );
        
        require(
            _rightsTotal != MAX_UINT256,
            "SignataRight: Maximum amount of rights already minted."
        );
        
        bytes32 uriHash = keccak256(bytes(schemaURI));
        
        require(
            _uriHashToSchema[uriHash] == 0,
            "SignataRight: The URI provided for the schema is not unique."
        );
        
        address recipient;
        
        if (minter.isContract()) {
            recipient = minter;
        } else {
            recipient = _signataIdentity.getIdentity(minter);
            
            require(
                !_signataIdentity.isLocked(recipient),
                "SignataRight: The sender's account is locked."
            );
        }
        
        _rightsTotal += 1;
        _rightToOwner[_rightsTotal] = recipient;
        _rightToSchema[_rightsTotal] = 1;
        
        uint256 schemaToRightsLength = _schemaToRightBalance[1];

        _schemaToRights[1][schemaToRightsLength] = _rightsTotal;
        _schemaToRightBalance[1] += 1;
        _ownerToSchemaBalance[recipient][1] += 1;

        uint256 ownerToRightsLength = _ownerToRightBalance[recipient];
        
        _ownerToRights[recipient][ownerToRightsLength] = _rightsTotal;
        _rightToOwnerRightsIndex[_rightsTotal] = ownerToRightsLength;
        _ownerToRightBalance[recipient] += 1;
        
        _schemasTotal += 1;
        _schemaToMintingRight[_schemasTotal] = _rightsTotal;
        _schemaToURI[_schemasTotal] = schemaURI;
        _uriHashToSchema[uriHash] = _schemasTotal;
        _schemaTransferable[_schemasTotal] = schemaTransferable;
        _schemaRevocable[_schemasTotal] = schemaRevocable;
        
        require(
            _isSafeToTransfer(address(0), recipient, _rightsTotal, ""),
            "SignataRight: must only transfer to ERC721Receiver implementers when recipient is a smart contract."
        );
        
        emit MintRight(1, _rightsTotal, false);
        
        emit Transfer(address(0), minter, _rightsTotal);
        
        emit MintSchema(_schemasTotal, _rightsTotal, uriHash);
        
        return _schemasTotal;
    }
    
    function mintRight(uint256 schemaId, address to, bool unbound) external {
        require(
            _rightsTotal != MAX_UINT256,
            "SignataRight: Maximum amount of tokens already minted."
        );
        
        require(
            _schemaToMintingRight[schemaId] != 0,
            "SignataRight: Schema ID must correspond to an existing schema."
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
            minter == _rightToOwner[_schemaToMintingRight[schemaId]],
            "SignataRight: The sender is not the minter for the schema specified."
        );
        
        address recipient;
        
        if (to.isContract()) {
            recipient = to;
        } else if (unbound == true) {
            recipient = to;
        } else {
            recipient = _signataIdentity.getIdentity(to);
        }
        
        _rightsTotal += 1;
        _rightToOwner[_rightsTotal] = recipient;
        _rightToSchema[_rightsTotal] = schemaId;
        
        uint256 schemaToRightsLength = _schemaToRightBalance[schemaId];

        _schemaToRights[schemaId][schemaToRightsLength] = _rightsTotal;
        _schemaToRightBalance[schemaId] += 1;
        _ownerToSchemaBalance[recipient][schemaId] += 1;

        uint256 ownerToRightsLength = _ownerToRightBalance[recipient];
        
        _ownerToRights[recipient][ownerToRightsLength] = _rightsTotal;
        _rightToOwnerRightsIndex[_rightsTotal] = ownerToRightsLength;
        _ownerToRightBalance[recipient] += 1;
        
        require(
            _isSafeToTransfer(address(0), recipient, _rightsTotal, ""),
            "SignataRight: must only transfer to ERC721Receiver implementers when recipient is a smart contract."
        );
        
        emit MintRight(schemaId, _rightsTotal, unbound);
        
        emit Transfer(address(0), to, _rightsTotal);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        if (owner.isContract()) {
            return _ownerToRightBalance[owner];
        }
        
        return _ownerToRightBalance[_signataIdentity.getIdentity(owner)];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _rightToOwner[tokenId];
        
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
            _rightToOwner[tokenId] != address(0), 
            "SignataRight: Token ID must correspond to an existing right."
        );

        return _schemaToURI[_rightToSchema[tokenId]];
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = _rightToOwner[tokenId];
        
        require(
            owner != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );
        
        require(
            to != owner, 
            "SignataRight: Approval is not required for the owner of the right."
        );
        
        address controller;
        
        if (owner.isContract()) {
            controller = owner;
        } else {
            controller = _signataIdentity.getDelegate(owner);
            
            require(
                to != controller, 
                "SignataRight: Approval is not required for the owner of the right."
            );
            
            require(
                !_signataIdentity.isLocked(owner),
                "SignataRight: The owner's account is locked."
            );
        }
            
        require(
            msg.sender == controller || isApprovedForAll(owner, msg.sender),
            "SignataRight: The sender is not authorised to provide approvals."
        );
        
        _rightToApprovedAddress[tokenId] = to;
    
        emit Approval(controller, to, tokenId);
    }
    
    function revoke(uint256 tokenId) external {
        require(
            _rightToOwner[tokenId] != address(0),
            "SignataRight: Right ID must correspond to an existing right."
        );
        
        uint256 schemaId = _rightToSchema[tokenId];
        
        require(
            _schemaRevocable[schemaId],
            "SignataRight: The right specified is not revocable."
        );
        
        address minter = _rightToOwner[_schemaToMintingRight[schemaId]];
        
        address controller;
        
        if (minter.isContract()) {
            controller = minter;
        } else {
            controller = _signataIdentity.getDelegate(minter);
            
            require(
                !_signataIdentity.isLocked(minter),
                "SignataRight: The minter's account is locked."
            );
        }
            
        require(
            msg.sender == controller,
            "SignataRight: The sender is not authorised to revoke the right."
        );
        
        _rightToRevocationStatus[tokenId] = true;

        _ownerToSchemaBalance[_rightToOwner[tokenId]][schemaId] -= 1;
    
        emit Revoke(tokenId);        
    }
    
    function isRevoked(uint256 tokenId) external view returns (bool) {
        require(
            _rightToOwner[tokenId] != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );
        
        return _rightToRevocationStatus[tokenId];
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(
            _rightToOwner[tokenId] != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );

        return _rightToApprovedAddress[tokenId];
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
        require(
            _rightToOwner[tokenId] != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );
        
        uint256 schemaId = _rightToSchema[tokenId];
        
        require(
            _schemaTransferable[schemaId],
            "SignataRight: This right is non-transferable."
        );
        
        require(
            !_rightToRevocationStatus[tokenId],
            "SignataRight: This right has been revoked."
        );
        
        require(
            to != address(0), 
            "SignataRight: Transfers to the zero address are not allowed."
        );
        
        address owner;
        
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
            _rightToOwner[tokenId] == owner,
            "SignataRight: The account specified does not hold the right corresponding to the Token ID provided."
        );
        

        require(
            msg.sender == owner || msg.sender == _rightToApprovedAddress[tokenId] || _ownerToOperatorStatuses[owner][msg.sender],
            "SignataRight: The sender is not authorised to transfer this right."
        );
        
        address recipient;

        if (to.isContract()) {
            recipient = to;
        } else {
            recipient = _signataIdentity.getIdentity(to);
            
            require(
                !_signataIdentity.isLocked(recipient),
                "SignataRight: The recipient's account is locked."
            );
        }
        
        uint256 lastRightIndex = _ownerToRightBalance[owner] - 1;
        uint256 rightIndex = _rightToOwnerRightsIndex[tokenId];

        if (rightIndex != lastRightIndex) {
            uint256 lastTokenId = _ownerToRights[owner][lastRightIndex];

            _ownerToRights[owner][rightIndex] = lastTokenId;
            _rightToOwnerRightsIndex[lastTokenId] = rightIndex;
        }

        delete _ownerToRights[owner][lastRightIndex];
        delete _rightToOwnerRightsIndex[tokenId];
        
        _ownerToSchemaBalance[owner][schemaId] -= 1;
        
        uint256 length = _ownerToRightBalance[recipient];
        
        _ownerToRights[recipient][length] = tokenId;
        _rightToOwnerRightsIndex[tokenId] = length;
        
        _rightToApprovedAddress[tokenId] = address(0);
        
        emit Approval(from, address(0), tokenId);

        _ownerToRightBalance[owner] -= 1;
        _ownerToRightBalance[recipient] += 1;
        _rightToOwner[tokenId] = recipient;
        
        _ownerToSchemaBalance[recipient][schemaId] += 1;

        emit Transfer(from, to, tokenId);
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
            index < _ownerToRightBalance[holder], 
            "SignataRight: The index provided is out of bounds for the owner specified."
        );
        
        return _ownerToRights[holder][index];
    }

    function totalSupply() public view override returns (uint256) {
        return _rightsTotal;
    }

    function tokenByIndex(uint256 index) public view override returns (uint256) {
        require(
            index < _rightsTotal, 
            "SignataRight: The index provided is out of bounds."
        );
        
        return index + 1;
    }
    
    function schemaOf(uint256 tokenId) external view override returns (uint256) {
        require(
            _rightToOwner[tokenId] != address(0),
            "SignataRight: Token ID must correspond to an existing right."
        );

        return _rightToSchema[tokenId];    
    }

    function minterOf(uint256 schemaId) external view override returns (address) {
        uint256 mintingToken = _schemaToMintingRight[schemaId];
        
        require(
            mintingToken != 0,
            "SignataRight: Schema ID must correspond to an existing schema."
        );
        
        address owner = _rightToOwner[mintingToken];

        if (owner.isContract()) {
            return owner;
        }
        
        return _signataIdentity.getDelegate(owner);        
    }
    
    function holdsTokenOfSchema(address holder, uint256 schemaId) external view override returns (bool) {
        require(
            _schemaToMintingRight[schemaId] != 0,
            "SignataRight: Schema ID must correspond to an existing schema."
        );
        
        address owner;

        if (owner.isContract()) {
            owner = holder;
        } else {
            owner = _signataIdentity.getIdentity(holder);
        }
        
        return _ownerToSchemaBalance[owner][schemaId] > 0;
    }
    
    function totalSchemas() external view override returns (uint256) {
        return _schemasTotal;
    }
    
    function totalMintedFor(uint256 schemaId) external view override returns (uint256) {
        require(
            _schemaToMintingRight[schemaId] != 0,
            "SignataRight: Schema ID must correspond to an existing schema."
        );
        
        return _schemaToRightBalance[schemaId];
    }

    function tokenOfSchemaByIndex(uint256 schemaId, uint256 index) external view override returns (uint256) {
        require(
            _schemaToMintingRight[schemaId] != 0,
            "SignataRight: Schema ID must correspond to an existing schema."
        );
        
        require(
            index < _schemaToRightBalance[schemaId], 
            "SignataRight: The index provided is out of bounds for the owner specified."
        );
        
        return _schemaToRights[schemaId][index];       
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