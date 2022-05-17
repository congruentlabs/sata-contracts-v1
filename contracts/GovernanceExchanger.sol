// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GovernanceExchanger is Ownable {
    address public immutable governanceToken;
    address public immutable utilityToken;
    address private immutable holdingAccount;
    uint256 private immutable endDate;

    // This event is triggered whenever a call to #exchange succeeds.
    event Exchanged(address account, uint256 amount);

    constructor(address governanceToken_, address utilityToken_, address holdingAccount_) {
        governanceToken = governanceToken_;
        utilityToken = utilityToken_;
        holdingAccount = holdingAccount_;

        endDate = block.timestamp + 3 days;
    }

    function exchange(uint256 amount) external {
        require(block.timestamp <= endDate, "GovernanceExchanger::exchange: Exchange period has ended.");
        
        uint256 allowance = IERC20(utilityToken).allowance(msg.sender, address(this));
        
        require(allowance >= amount, "GovernanceExchanger::exchange: Token allowance too small.");

        uint256 utilityTokenBalance = IERC20(utilityToken).balanceOf(msg.sender);

        require(utilityTokenBalance >= amount, "GovernanceExchanger::exchange: Sender's balance must be greater than or equal to the amount requested.");
        require(IERC20(utilityToken).transferFrom(msg.sender, holdingAccount, amount), "GovernanceExchanger::exchange: Transfer of utility tokens failed.");
        require(IERC20(governanceToken).transfer(msg.sender, amount), "GovernanceExchanger::exchange: Transfer of governance tokens failed.");
        emit Exchanged(msg.sender, amount);
    }

    function withdrawGovernance() public onlyOwner {
      require(IERC20(governanceToken).transfer(holdingAccount, IERC20(governanceToken).balanceOf(address(this))), "GovernanceExchanger::withdrawGovernance: Withdraw failed.");
    }

    function withdrawUtility() public onlyOwner {
      require(IERC20(utilityToken).transfer(holdingAccount, IERC20(utilityToken).balanceOf(address(this))), "GovernanceExchanger::withdrawUtility: Withdraw failed.");
    }
}