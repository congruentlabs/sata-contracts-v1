// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./SignataIdentity.sol";

contract AtomicSwapERC20 is Ownable {
    SignataIdentity public signataIdentity;
    struct Swap {
        uint256 timelock;
        uint256 erc20Value;
        address erc20Trader;
        address erc20ContractAddress;
        address withdrawTrader;
        bytes32 secretLock;
        bytes secretKey;
        bool checkIdentity;
    }

    enum States {
        INVALID,
        OPEN,
        CLOSED,
        EXPIRED
    }

    mapping (bytes32 => Swap) private swaps;
    mapping (bytes32 => States) private swapStates;

    event Open(bytes32 _swapID, address _withdrawTrader, bytes32 _secretLock);
    event Expire(bytes32 _swapID);
    event Close(bytes32 _swapID, bytes _secretKey);
    event IdentityContractChanged(SignataIdentity newIdentity);

    modifier onlyInvalidSwaps(bytes32 _swapID) {
        require(swapStates[_swapID] == States.INVALID);
        _;
    }

    modifier onlyOpenSwaps(bytes32 _swapID) {
        require(swapStates[_swapID] == States.OPEN);
        _;
    }

    modifier onlyClosedSwaps(bytes32 _swapID) {
        require(swapStates[_swapID] == States.CLOSED);
        _;
    }

    modifier onlyExpirableSwaps(bytes32 _swapID) {
        require(swaps[_swapID].timelock <= block.timestamp);
        _;
    }

    modifier onlyWithSecretKey(bytes32 _swapID, bytes memory _secretKey) {
        // TODO: Require _secretKey length to conform to the spec
        require(swaps[_swapID].secretLock == sha256(_secretKey));
        _;
    }

    constructor(SignataIdentity _signataIdentity) {
        signataIdentity = _signataIdentity;
    }

    function open(
        bytes32 _swapID,
        uint256 _erc20Value,
        address _erc20ContractAddress,
        address _withdrawTrader,
        bytes32 _secretLock,
        uint256 _timelock,
        bool _requireIdentity
    ) public onlyInvalidSwaps(_swapID) {
        require(swapStates[_swapID] == States.INVALID);
        if (_requireIdentity) {
            require(!signataIdentity.isLocked(msg.sender), "open::Sender must not be locked.");
            require(!signataIdentity.isLocked(_withdrawTrader), "open::Trader must not be locked.");
        }

        // Transfer value from the ERC20 trader to this contract.
        ERC20 erc20Contract = ERC20(_erc20ContractAddress);
        require(_erc20Value <= erc20Contract.allowance(msg.sender, address(this)));
        require(erc20Contract.transferFrom(msg.sender, address(this), _erc20Value));

        // Store the details of the swap.
        Swap memory swap = Swap({
            timelock: _timelock,
            erc20Value: _erc20Value,
            erc20Trader: msg.sender,
            erc20ContractAddress: _erc20ContractAddress,
            withdrawTrader: _withdrawTrader,
            secretLock: _secretLock,
            secretKey: new bytes(0),
            checkIdentity: _requireIdentity
        });
        swaps[_swapID] = swap;
        swapStates[_swapID] = States.OPEN;
        emit Open(_swapID, _withdrawTrader, _secretLock);
    }

    function close(bytes32 _swapID, bytes memory _secretKey) public onlyOpenSwaps(_swapID)
        onlyWithSecretKey(_swapID, _secretKey) {

        // Close the swap.
        Swap memory swap = swaps[_swapID];
        swaps[_swapID].secretKey = _secretKey;
        swapStates[_swapID] = States.CLOSED;

        if (swap.checkIdentity) {
            require(!signataIdentity.isLocked(swap.erc20Trader), "close::Account must not be locked.");
        }

        // Transfer the ERC20 funds from this contract to the withdrawing trader.
        ERC20 erc20Contract = ERC20(swap.erc20ContractAddress);
        require(erc20Contract.transfer(swap.withdrawTrader, swap.erc20Value));

        emit Close(_swapID, _secretKey);
    }

    function expire(bytes32 _swapID) public onlyOpenSwaps(_swapID) onlyExpirableSwaps(_swapID) {
        // Expire the swap.
        Swap memory swap = swaps[_swapID];
        swapStates[_swapID] = States.EXPIRED;

        // Transfer the ERC20 value from this contract back to the ERC20 trader.
        ERC20 erc20Contract = ERC20(swap.erc20ContractAddress);
        require(erc20Contract.transfer(swap.erc20Trader, swap.erc20Value));

        emit Expire(_swapID);
    }

    function check(bytes32 _swapID) public view returns (uint256 timelock, uint256 erc20Value,
        address erc20ContractAddress, address withdrawTrader, bytes32 secretLock) {
        Swap memory swap = swaps[_swapID];
        return (swap.timelock, swap.erc20Value, swap.erc20ContractAddress, swap.withdrawTrader, swap.secretLock);
    }

    function checkSecretKey(bytes32 _swapID) public view onlyClosedSwaps(_swapID) returns (bytes memory secretKey) {
        Swap memory swap = swaps[_swapID];
        return swap.secretKey;
    }

    function updateSignataIdentity(SignataIdentity newIdentity) public onlyOwner {
        signataIdentity = newIdentity;
        emit IdentityContractChanged(newIdentity);
    }
}