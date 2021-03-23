// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SATAToken is ERC20, Ownable {
  bool private airdropMinted = false;

  constructor(
    string memory name,
    string memory symbol,
    address reserveAddress,
    uint256 reserveAmount,
    address integrationAddress,
    uint256 integrationAmount,
    uint256 remainderAmount
  )
    ERC20(name, symbol)
    payable
  {
    // allocate the reserves
    _mint(reserveAddress, reserveAmount);
    _mint(integrationAddress, integrationAmount);
    // allocate the remainder to the contract
    _mint(msg.sender, remainderAmount);
  }

  function mintAirdrop(address contractAddress, uint256 airdropAmount) public onlyOwner { //10000000
    require(!airdropMinted, "Airdrop already minted.");
    airdropMinted = true;
    _mint(contractAddress, airdropAmount);
  }
}
