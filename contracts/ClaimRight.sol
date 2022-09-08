// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ClaimRight is Ownable {
    string public name;
    IERC20 private signataToken;
    SignataRight private signataRight;
    SignataIdentity private signataIdentity;
    address private signingAuthority;
    uint256 public feeAmount = 10 * 1e18; // 10 SATA to start with
    uint256 public schemaId;
    bytes32 public constant VERSION_DIGEST = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
    bytes32 public constant SALT = 0x03ea6995167b253ad0cf79271b4ddbacfb51c7a4fb2872207de8a19eb0cb724b;
    bytes32 public constant NAME_DIGEST = 0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f;
    bytes32 public constant EIP712DOMAINTYPE_DIGEST = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472;
    bytes32 public constant TXTYPE_CLAIM_DIGEST = 0x8891c73a2637b13c5e7164598239f81256ea5e7b7dcdefd496a0acd25744091c;
    bytes32 public immutable domainSeparator;

    mapping(address => bool) public claimedRight;
    mapping(address => bool) public cancelledClaim;

    event RightAssigned();
    event RightClaimed();
    event EmergencyRightClaimed();
    event ModifiedFee(uint256 oldAmount, uint256 newAmount);
    event FeesTaken(uint256 feesAmount);
    event ClaimCancelled(address identity);
    event RightClaimed(uint256 right, address identity);
    event ClaimReset(address identity);

    constructor(
        address _signataToken,
        address _signataRight,
        address _signataIdentity,
        address _signingAuthority,
        uint256 chainId,
        string memory _name,
        string memory _schemaURI
    ) {
        signataToken = IERC20(_signataToken);
        signataRight = SignataRight(_signataRight);
        signataIdentity = SignataIdentity(_signataIdentity);
        signingAuthority = _signingAuthority;
        name = _name;

        schemaId = signataRight.mintSchema(address(this), true, true, _schemaURI);

         domainSeparator = keccak256(
            abi.encode(
                EIP712DOMAINTYPE_DIGEST,
                NAME_DIGEST,
                VERSION_DIGEST,
                chainId,
                this,
                SALT
            )
        );
    }

    receive() external payable {}

    function claimRight(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint256 nonce
    )
        external
    {
        // take the fee
        if (feeAmount > 0) {
            signataToken.transferFrom(msg.sender, address(this), feeAmount);
            emit FeesTaken(feeAmount);
        }

        // check if the right is already claimed
        require(!claimedRight[identity], "ClaimRight: Right already claimed");
        require(!cancelledClaim[identity], "ClaimRight: Claim cancelled");

        claimedRight[identity] = true;

        // validate the signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        TXTYPE_CLAIM_DIGEST,
                        identity
                    )
                )
            )
        );

        address signerAddress = ecrecover(digest, sigV, sigR, sigS);
        require(signerAddress == signingAuthority, "ClaimRight: Invalid signature");

        // assign the right to the identity
        signataRight.mintRight(schemaId, identity, false);

        emit RightClaimed(nonce, identity);
    }

    function cancelClaim(
        address identity
    )
        external onlyOwner
    {
        require(!claimedRight[identity], "ClaimRight: Right already claimed");
        require(!cancelledClaim[identity], "ClaimRight: Claim already cancelled");

        cancelledClaim[identity] = true;

        emit ClaimCancelled(identity);
    }

    function resetClaim(
        address identity
    )
        external onlyOwner
    {
        claimedRight[identity] = false;
        cancelledClaim[identity] = false;

        emit ClaimReset(identity);
    }
    
    function updateSigningAuthority(
        address _signingAuthority
    )
        external onlyOwner
    {
        signingAuthority = _signingAuthority;
    }

    function modifyFee(
        uint256 newAmount
    )
        external
        onlyOwner
    {
        uint256 oldAmount = feeAmount;
        feeAmount = newAmount;
        emit ModifiedFee(oldAmount, newAmount);
    }

    function withdrawCollectedFees()
        external
        onlyOwner
    {
        signataToken.transferFrom(address(this), msg.sender, signataToken.balanceOf(address(this)));
    }

    function withdrawNative()
        external
        onlyOwner
        returns (bool)
    {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        return success;
    }
}