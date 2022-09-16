// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./tokens/IERC721Receiver.sol";
import "./openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ClaimRight is Ownable, IERC721Receiver, ReentrancyGuard {
    string public name;
    IERC20 private paymentToken;
    SignataRight private signataRight;
    SignataIdentity private signataIdentity;
    address private signingAuthority;
    uint256 public feeAmount = 100 * 1e18; // 100 SATA
    uint256 public schemaId;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    bool public collectNative = false;

    mapping(address => bytes32) public claimedRight;
    mapping(address => bool) public cancelledClaim;

    event EmergencyRightClaimed();
    event ModifiedFee(uint256 oldAmount, uint256 newAmount);
    event FeesTaken(uint256 feesAmount);
    event RightPurchased(address identity);
    event CollectNativeModified(bool newValue);
    event TokenModified(address newAddress);
    event PaymentTokenModified(address newToken);

    constructor(
        address _paymentToken,
        string memory _name
    ) {
        paymentToken = IERC20(_paymentToken);
        name = _name;
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

    function purchaseRight(
        address delegate
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
            emit FeesTaken(feeAmount);
        }
        // assign the right to the identity
        signataRight.mintRight(schemaId, delegate, false);

        emit RightPurchased(delegate);
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