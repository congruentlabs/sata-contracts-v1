// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./extensions/IERC20.sol";

contract GovernanceExchanger {
    address public immutable governanceToken;
    address public immutable utilityToken;

    address private immutable holdingAccount;

    uint256 private immutable endDate;

    constructor(address governanceToken_, address utilityToken_, address holdingAccount_) {
        governanceToken = governanceToken_;
        utilityToken = utilityToken_;
        holdingAccount = holdingAccount_;

        endDate = now + 14 days;
    }

    function exchange(uint256 amount) external {
        require(now <= endDate, "GovernanceExchanger::exchange: Exchange period has ended.");
        
        uint256 allowance = IERC20(utilityToken).allowance(msg.sender, address(this));
        
        require(allowance >= amount, "GovernanceExchanger::exchange: Token allowance too small.");

        uint256 oldTokenBalance = IERC20(utilityToken).balanceOf(account);

        require(oldTokenBalance >= amount, "GovernanceExchanger::exchange: Sender's balance must be greater than the amount requested.")
        require(IERC20(utilityToken).transferFrom(account, holdingAccount, amount), "GovernanceExchanger::exchange: Transfer of utility tokens failed.");
        require(IERC20(governanceToken).transfer(account, amount), "GovernanceExchanger::exchange: Transfer of governance tokens failed.");
        emit Exchanged(account, amount);
    }

    function withdrawGovernance() public {
      require(IERC20(governanceToken).transfer(holdingAccount, IERC20(governanceToken).balanceOf(address(this))), "GovernanceExchanger::withdrawGovernance: Withdraw failed.");
    }

    function withdrawUtility() public {
      require(IERC20(utilityToken).transfer(holdingAccount, IERC20(utilityToken).balanceOf(address(this))), "GovernanceExchanger::withdrawUtility: Withdraw failed.");
    }

    // This event is triggered whenever a call to #exchange succeeds.
    event Exchanged(address account, uint256 amount);
}