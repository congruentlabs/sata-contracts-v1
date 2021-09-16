// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenDynamic is ERC20, Ownable {
  bool private supplyControlEnabled = false;
  address private supplyController;

  event SupplyControlChanged(bool changedTo);
  event SupplyControllerChanged(address indexed oldController, address indexed newController);

  constructor(address supplyController_, uint256 initialSupply)
    ERC20("Signata", "SATA")
  {
    supplyController = supplyController_;
    super._mint(msg.sender, initialSupply);
  }

  function changeSupplyController(address newSupplyController) public virtual {
    require(msg.sender == supplyController, "Not Authorized.");

    supplyController = newSupplyController;

    emit SupplyControllerChanged(msg.sender, newSupplyController);
  }

  function enableSupplyControl() public virtual {
    require(msg.sender == supplyController, "Not Supply Controller.");
    require(!supplyControlEnabled, "Supply Control Already Enabled.");

    supplyControlEnabled = true;

    emit SupplyControlChanged(true);
  }

  function disableSupplyControl() public virtual {
    require(msg.sender == supplyController, "Not Supply Controller.");
    require(supplyControlEnabled, "Supply Control Already Disabled.");

    supplyControlEnabled = false;
    
    emit SupplyControlChanged(false);
  }

  function mint(address account, uint256 amount) public virtual onlyOwner {
    require(supplyControlEnabled, "Supply Control Disabled.");

    super._mint(account, amount);
  }

  function burn(address account, uint256 amount) public virtual onlyOwner {
    require(supplyControlEnabled, "Supply Control Disabled.");

    super._burn(account, amount);
  }
}
