// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SATAAirdropV1 is Ownable {
  uint256 private airdropAmount;
  uint256 private reqEthBalance; // 100000000000000000 for 0.1 ETH
  IERC20 public immutable token;
  mapping (address => bool) public claimedAddresses;

  constructor(address _token, uint256 _airdropAmount, uint256 _minBalance) public {
    token = IERC20(_token);
    airdropAmount = _airdropAmount;
    reqEthBalance = _minBalance;
  }

  function endAirdrop(address recipient) external onlyOwner {
    require(token.balanceOf(address(this)) > 0, "Airdrop depleted.");
    // return the remaining tokens to the specified address
    token.transfer(recipient, token.balanceOf(address(this)));
  }

  function availableTokens() external view returns (uint256) {
    return token.balanceOf(address(this));
  }

  function claim() external {
    // claim eligibility checks
    require(token.balanceOf(address(this)) >= airdropAmount, "Airdrop depleted.");
    require(!claimedAddresses[msg.sender], "Airdrop already claimed.");
    require(msg.sender.balance >= reqEthBalance, "Invalid account."); // 0.1 ETH Required

    // add the requestor to the array
    claimedAddresses[msg.sender] = true;

    // send them tokens
    token.transfer(msg.sender, airdropAmount);
  }
}
