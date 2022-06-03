// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./SignataIdentity.sol";

contract VeriswapERC20 is Ownable {
    SignataIdentity public signataIdentity;

    enum States {
        INVALID,
        OPEN,
        CLOSED,
        EXPIRED
    }

    struct AtomicSwap {
      address inputToken;
      uint256 inputAmount;
      address outputToken;
      uint256 outputAmount;
      address executor;
      address creator;
      bool requireIdentity;
      States state;
    }

    bool public canSwap;

    mapping (address => AtomicSwap) public swaps;

    event SwapCreated(AtomicSwap swapData);
    event SwapExecuted(address creatorAddress);
    event SwapCancelled(address creatorAddress);
    event ExecutorModified(address creatorAddress, address oldExecutor, address newExecutor);
    event IdentityContractChanged(SignataIdentity newIdentity);

    constructor(SignataIdentity _signataIdentity) {
        signataIdentity = _signataIdentity;
    }

    function createSwap(
      address _inputToken,
      uint256 _inputAmount,
      address _outputToken,
      uint256 _outputAmount,
      address _executor,
      bool _requireIdentity
    ) public {
        if (_requireIdentity) {
            require(!signataIdentity.isLocked(msg.sender), "open::creator must not be locked.");
            // don't check the executor yet, just in case they go and register after the fact.
        }
        AtomicSwap memory swapToCheck = swaps[msg.sender];
        require(swapToCheck.state != States.OPEN, "createSwap::already have an open swap.");

        IERC20 inputToken = IERC20(_inputToken);

        // check allowance
        require(_inputAmount <= inputToken.allowance(msg.sender, address(this)));

        // transfer into escrow
        require(inputToken.transferFrom(msg.sender, address(this), _inputAmount));

        // store the details
        AtomicSwap memory newSwap = AtomicSwap({
          inputToken: _inputToken,
          inputAmount: _inputAmount,
          outputToken: _outputToken,
          outputAmount: _outputAmount,
          executor: _executor,
          creator: msg.sender,
          requireIdentity: _requireIdentity,
          state: States.OPEN
        });
        swaps[msg.sender] = newSwap;

        emit SwapCreated(newSwap);
    }

    function executeSwap(address creatorAddress) public {
      require(canSwap, "executeSwap::swaps not enabled!");

      // check the state
      AtomicSwap memory swapToExecute = swaps[creatorAddress];

      require(swapToExecute.state == States.OPEN, "executeSwap::not an open swap.");
      require(swapToExecute.executor == msg.sender, "executeSwap::only the executor can call this function.");

      // check identities
      if (swapToExecute.requireIdentity == true) {
        require(!signataIdentity.isLocked(msg.sender), "executeSwap::Sender must not be locked.");
        require(!signataIdentity.isLocked(swapToExecute.executor), "executeSwap::Trader must not be locked.");
      }

      IERC20 outputToken = IERC20(swapToExecute.outputToken);
      IERC20 inputToken = IERC20(swapToExecute.inputToken);

      swaps[swapToExecute.creator].state = States.CLOSED;

      // check allowance
      require(swapToExecute.outputAmount <= outputToken.allowance(msg.sender, address(this)));
      // send the input to the executor
      require(inputToken.transfer(swapToExecute.executor, swapToExecute.inputAmount));
      // send the output to the creator
      require(outputToken.transfer(swapToExecute.creator, swapToExecute.outputAmount));

      // send the parties their respective tokens
      emit SwapExecuted(creatorAddress);
    }

    function cancelSwap() public {
      AtomicSwap memory swapToCancel = swaps[msg.sender];
      require(swapToCancel.creator == msg.sender, "cancelSwap::not the creator.");
      require(swapToCancel.state == States.OPEN, "cancelSwap::not an open swap.");

      swaps[msg.sender].state = States.EXPIRED;

      // return the input back to the creator
      IERC20 inputToken = IERC20(swapToCancel.inputToken);
      require(inputToken.transfer(swapToCancel.creator, swapToCancel.inputAmount));

      emit SwapCancelled(swapToCancel.creator);
    }

    function changeExecutor(address newExecutor) public {
      require(newExecutor != address(0), "changeExecutor::cannot set to 0 address!");
      AtomicSwap memory swapToChange = swaps[msg.sender];

      address oldExecutor = swaps[msg.sender].executor;

      require(newExecutor != oldExecutor, "changeExecutor::not different values!");
      require(swapToChange.creator == msg.sender, "changeExecutor::not the creator!");
      require(swapToChange.state == States.OPEN, "changeExecutor::not an open swap!");

      swaps[msg.sender].executor = newExecutor;

      emit ExecutorModified(msg.sender, oldExecutor, newExecutor);
    }

    function enableSwaps() public onlyOwner { canSwap = true; }
    function disableSwaps() public onlyOwner { canSwap = false; }
    
    function updateSignataIdentity(SignataIdentity newIdentity) public onlyOwner {
        signataIdentity = newIdentity;
        emit IdentityContractChanged(newIdentity);
    }

    // function open(
    //     bytes32 _swapID,
    //     uint256 _erc20Value,
    //     address _erc20ContractAddress,
    //     address _withdrawTrader,
    //     bytes32 _secretLock,
    //     uint256 _timelock,
    //     bool _requireIdentity
    // ) public onlyInvalidSwaps(_swapID) {
    //     require(swapStates[_swapID] == States.INVALID);
    //     if (_requireIdentity) {
    //         require(!signataIdentity.isLocked(msg.sender), "open::Sender must not be locked.");
    //         require(!signataIdentity.isLocked(_withdrawTrader), "open::Trader must not be locked.");
    //     }

    //     // Transfer value from the ERC20 trader to this contract.
    //     ERC20 erc20Contract = ERC20(_erc20ContractAddress);
    //     require(_erc20Value <= erc20Contract.allowance(msg.sender, address(this)));
    //     require(erc20Contract.transferFrom(msg.sender, address(this), _erc20Value));

    //     // Store the details of the swap.
    //     Swap memory swap = Swap({
    //         timelock: _timelock,
    //         erc20Value: _erc20Value,
    //         erc20Trader: msg.sender,
    //         erc20ContractAddress: _erc20ContractAddress,
    //         withdrawTrader: _withdrawTrader,
    //         secretLock: _secretLock,
    //         secretKey: new bytes(0),
    //         checkIdentity: _requireIdentity
    //     });
    //     swaps[_swapID] = swap;
    //     swapStates[_swapID] = States.OPEN;
    //     emit Open(_swapID, _withdrawTrader, _secretLock);
    // }

    // function close(bytes32 _swapID, bytes memory _secretKey) public onlyOpenSwaps(_swapID)
    //     onlyWithSecretKey(_swapID, _secretKey) {

    //     // Close the swap.
    //     Swap memory swap = swaps[_swapID];
    //     swaps[_swapID].secretKey = _secretKey;
    //     swapStates[_swapID] = States.CLOSED;

    //     if (swap.checkIdentity) {
    //         require(!signataIdentity.isLocked(swap.erc20Trader), "close::Account must not be locked.");
    //     }

    //     // Transfer the ERC20 funds from this contract to the withdrawing trader.
    //     ERC20 erc20Contract = ERC20(swap.erc20ContractAddress);
    //     require(erc20Contract.transfer(swap.withdrawTrader, swap.erc20Value));

    //     emit Close(_swapID, _secretKey);
    // }

    // function expire(bytes32 _swapID) public onlyOpenSwaps(_swapID) onlyExpirableSwaps(_swapID) {
    //     // Expire the swap.
    //     Swap memory swap = swaps[_swapID];
    //     swapStates[_swapID] = States.EXPIRED;

    //     // Transfer the ERC20 value from this contract back to the ERC20 trader.
    //     ERC20 erc20Contract = ERC20(swap.erc20ContractAddress);
    //     require(erc20Contract.transfer(swap.erc20Trader, swap.erc20Value));

    //     emit Expire(_swapID);
    // }

    // function check(bytes32 _swapID) public view returns (uint256 timelock, uint256 erc20Value,
    //     address erc20ContractAddress, address withdrawTrader, bytes32 secretLock) {
    //     Swap memory swap = swaps[_swapID];
    //     return (swap.timelock, swap.erc20Value, swap.erc20ContractAddress, swap.withdrawTrader, swap.secretLock);
    // }

    // function checkSecretKey(bytes32 _swapID) public view onlyClosedSwaps(_swapID) returns (bytes memory secretKey) {
    //     Swap memory swap = swaps[_swapID];
    //     return swap.secretKey;
    // }
}