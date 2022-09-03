// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ClaimRight is Ownable {
    string public name = "Signata KYC Right Claim";
    IERC20 private signataToken;
    SignataRight private signataRight;
    SignataIdentity private signataIdentity;
    address private signingAuthority;
    uint256 public feeAmount = 10 * 1e18; // 10 SATA to start with

    mapping(uint256 => bool) public claimedRight;
    mapping(uint256 => bool) public cancelledClaim;

    event RightAssigned();
    event RightClaimed();
    event EmergencyRightClaimed();
    event ModifiedFee(uint256 oldAmount, uint256 newAmount);
    event FeesTaken(uint256 feesAmount);

    constructor(
        address _signataToken,
        address _signataRight,
        address _signataIdentity,
        address _signingAuthority,
        uint256 chainId
    ) {
        signataToken = IERC20(_signataToken);
        signataRight = SignataRight(_signataRight);
        signataIdentity = SignataIdentity(_signataIdentity);
        signingAuthority = _signingAuthority;

        //  _domainSeparator = keccak256(
        //     abi.encode(
        //         EIP712DOMAINTYPE_DIGEST,
        //         NAME_DIGEST,
        //         VERSION_DIGEST,
        //         chainId,
        //         this,
        //         SALT
        //     )
        // );
        
        // TODO: Mint a schema for the right
    }

    receive() external payable {}

    function claimRight(
        address identity,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        uint256 right
    )
        external
    {
        // TODO
        // 1. Collect the fee for claiming the right
        // 2. Validate the signature of the caller has been signed by signingAuthority
        // 2a. Check if it's already minted
        // 2b. Check if it's not cancelled
        // 3. Mint a Right if the signature is passed
        // 4. Flag the signature as exceuted so it can't be replayed

        // take the fee
        if (feeAmount > 0) {
            signataToken.transferFrom(msg.sender, address(this), feeAmount);
            emit FeesTaken(feeAmount);
        }
        // mint the right
        emit RightClaimed();
    }

    function cancelClaim(
        uint256 right
    )
        external onlyOwner
    {
        // TODO 
        emit EmergencyRightClaimed();
    }

    function modifyFee(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = feeAmount;
        feeAmount = newAmount;
        emit ModifiedFee(oldAmount, newAmount);
    }

    function withdrawCollectedFees() external onlyOwner {
        signataToken.transferFrom(address(this), msg.sender, signataToken.balanceOf(address(this)));
    }
}