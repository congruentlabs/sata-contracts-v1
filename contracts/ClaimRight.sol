// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./tokens/IERC721Receiver.sol";
import "./openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ClaimRight is Ownable, IERC721Receiver, ReentrancyGuard {
    string public name;
    IERC20 private paymentToken;
    SignataRight private signataRight;
    SignataIdentity private signataIdentity;
    address private signingAuthority;
    uint256 public feeAmount = 100 * 1e18; // 100 SATA to start with
    uint256 public schemaId;
    bytes32 public constant VERSION_DIGEST = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
    bytes32 public constant SALT = 0x03ea6995167b253ad0cf79271b4ddbacfb51c7a4fb2872207de8a19eb0cb724b;
    bytes32 public constant NAME_DIGEST = 0xfc8e166e81add347414f67a8064c94523802ae76625708af4cddc107b656844f;
    bytes32 public constant EIP712DOMAINTYPE_DIGEST = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472;
    bytes32 public constant TXTYPE_CLAIM_DIGEST = 0x8891c73a2637b13c5e7164598239f81256ea5e7b7dcdefd496a0acd25744091c;
    bytes32 public immutable domainSeparator;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    bool public collectNative = false;

    mapping(address => bytes32) public claimedRight;
    mapping(address => bool) public cancelledClaim;

    event EmergencyRightClaimed();
    event ModifiedFee(uint256 oldAmount, uint256 newAmount);
    event FeesTaken(uint256 feesAmount);
    event ClaimCancelled(address identity);
    event RightClaimed(address identity);
    event ClaimReset(address identity);
    event CollectNativeModified(bool newValue);
    event TokenModified(address newAddress);
    event PaymentTokenModified(address newToken);

    constructor(
        address _signataToken,
        address _signataRight,
        address _signataIdentity,
        address _signingAuthority,
        string memory _name
    ) {
        paymentToken = IERC20(_signataToken);
        signataRight = SignataRight(_signataRight);
        signataIdentity = SignataIdentity(_signataIdentity);
        signingAuthority = _signingAuthority;
        name = _name;

         domainSeparator = keccak256(
            abi.encode(
                EIP712DOMAINTYPE_DIGEST,
                NAME_DIGEST,
                VERSION_DIGEST,
                SALT
            )
        );
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
        schemaId = signataRight.mintSchema(address(this), false, true, _schemaURI);
    }

    function claimRight(
        address delegate,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        bytes32 salt
    )
        external
        nonReentrant
    {
        // take the fee
        if (feeAmount > 0 && !collectNative) {
            paymentToken.transferFrom(msg.sender, address(this), feeAmount);
            emit FeesTaken(feeAmount);
        }
        if (feeAmount > 0 && collectNative) {
            (bool success, ) = payable(address(this)).call{ value: feeAmount }(""); 
            require(success, "ClaimRight: Payment not received.");
        }

        // check if the right is already claimed
        require(!cancelledClaim[delegate], "ClaimRight: Claim cancelled");
        require(claimedRight[delegate] != salt, "ClaimRight: Already claimed");

        claimedRight[delegate] = salt;

        // validate the signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        TXTYPE_CLAIM_DIGEST,
                        delegate,
                        salt
                    )
                )
            )
        );

        address signerAddress = ecrecover(digest, sigV, sigR, sigS);
        require(signerAddress == signingAuthority, "ClaimRight: Invalid signature");

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
        claimedRight[delegate] = 0;
        cancelledClaim[delegate] = false;

        emit ClaimReset(delegate);
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

    function modifyCollectNative(
        bool _collectNative
    )
        external
        onlyOwner
    {
        require(collectNative != _collectNative, "ModifyCollectNative: Already set to this value");
        collectNative = _collectNative;
        emit CollectNativeModified(_collectNative);
    }

    function modifyPaymentToken(
        address newToken
    )
        external
        onlyOwner
    {
        require(address(paymentToken) != newToken, "ModifyPaymentToken: Already set to this value");
        paymentToken = IERC20(newToken);
        emit PaymentTokenModified(newToken);
    }

    function withdrawCollectedFees()
        external
        onlyOwner
    {
        paymentToken.transferFrom(address(this), msg.sender, paymentToken.balanceOf(address(this)));
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