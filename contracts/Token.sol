// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
  bool private airdropMinted = false;

  constructor(
    string memory name_,
    string memory symbol_,
    address reserveAddress,
    uint256 reserveAmount,
    address integrationAddress,
    uint256 integrationAmount,
    uint256 remainderAmount
  )
    ERC20(name_, symbol_)
  {
    // allocate the reserves
    _mint(reserveAddress, reserveAmount);
    _mint(integrationAddress, integrationAmount);
    // allocate the remainder to the contract
    _mint(msg.sender, remainderAmount);
  }

  function mintAirdrop(address contractAddress, uint256 airdropAmount) external onlyOwner {
    require(!airdropMinted, "Airdrop already minted.");
    airdropMinted = true;
    _mint(contractAddress, airdropAmount);
  }
}
