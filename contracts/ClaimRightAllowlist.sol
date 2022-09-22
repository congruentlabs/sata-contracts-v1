// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./tokens/IERC721Receiver.sol";
import "./openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ClaimRightAllowlist is Ownable, IERC721Receiver, ReentrancyGuard {
    string public name;
    SignataRight public signataRight;
    SignataIdentity public signataIdentity;
    uint256 public schemaId;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    mapping(address => bool) public claimedRight;
    mapping(address => bool) public cancelledClaim;
    mapping(address => bool) public allowlist;

    event EmergencyRightClaimed();
    event ClaimCancelled(address identity);
    event RightClaimed(address identity);
    event ClaimReset(address identity);
    event TokenModified(address newAddress);

    constructor(
        address _signataRight,
        address _signataIdentity,
        string memory _name,
        address[] memory _allowlist
    ) {
        signataRight = SignataRight(_signataRight);
        signataIdentity = SignataIdentity(_signataIdentity);
        name = _name;
        for (uint256 i = 0; i < _allowlist.length; i++) {
            allowlist[_allowlist[i]] = true;
        }
    }

    receive() external payable {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        external
        pure
        returns (bytes4)
    {
        return _ERC721_RECEIVED;
    }

    function mintSchema(
        string memory _schemaURI
    ) external onlyOwner {
        schemaId = signataRight.mintSchema(address(this), true, true, _schemaURI);
    }

    function claimRight(
        address delegate
    )
        external
        nonReentrant
    {
        require(allowlist[delegate], "ClaimRight: Address not in allowlist");
        // check if the right is already claimed
        require(!cancelledClaim[delegate], "ClaimRight: Claim cancelled");
        require(!claimedRight[delegate], "ClaimRight: Already claimed");

        claimedRight[delegate] = true;

        // assign the right to the identity
        signataRight.mintRight(schemaId, delegate, false);

        emit RightClaimed(delegate);
    }

    function cancelClaim(
        address delegate
    )
        external onlyOwner
    {
        require(!cancelledClaim[delegate], "CancelClaim: Claim already cancelled");

        cancelledClaim[delegate] = true;

        emit ClaimCancelled(delegate);
    }

    function resetClaim(
        address delegate
    )
        external onlyOwner
    {
        claimedRight[delegate] = false;
        cancelledClaim[delegate] = false;

        emit ClaimReset(delegate);
    }
}