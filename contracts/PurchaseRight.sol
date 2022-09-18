// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./tokens/IERC721Receiver.sol";
import "./openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PurchaseRight is Ownable, IERC721Receiver, ReentrancyGuard {
    string public name;
    IERC20 public paymentToken;
    SignataRight public signataRight;
    SignataIdentity public signataIdentity;
    uint256 public feeAmount = 100 * 1e18;
    uint256 public schemaId;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    bool public collectNative = false;
    bool public purchasesEnabled = true;

    event ModifiedFee(uint256 oldAmount, uint256 newAmount);
    event FeesTaken(uint256 feesAmount);
    event RightPurchased(address identity);
    event CollectNativeModified(bool newValue);
    event TokenModified(address newAddress);
    event PaymentTokenModified(address newToken);
    event PurchasesEnabledModified(bool newValue);

    constructor(
        address _paymentToken,
        address _signataRight,
        address _signataIdentity,
        string memory _name
    ) {
        paymentToken = IERC20(_paymentToken);
        signataRight = SignataRight(_signataRight);
        signataIdentity = SignataIdentity(_signataIdentity);
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
        require(purchasesEnabled, "PurchaseRight: Purchases not enabled");
        // take the fee
        if (feeAmount > 0 && !collectNative) {
            paymentToken.transferFrom(msg.sender, address(this), feeAmount);
            emit FeesTaken(feeAmount);
        }
        if (feeAmount > 0 && collectNative) {
            (bool success, ) = payable(address(this)).call{ value: feeAmount }(""); 
            require(success, "PurchaseRight: Payment not received");
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

    function modifyPurchasesEnabled(
        bool _purchasedEnabled
    )
        external
        onlyOwner
    {
        require(purchasesEnabled != _purchasedEnabled, "ModifyPurchasesEnabled: Already set to this value");
        purchasesEnabled = _purchasedEnabled;
        emit PurchasesEnabledModified(_purchasedEnabled);
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