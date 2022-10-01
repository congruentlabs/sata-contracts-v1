// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./openzeppelin/contracts/access/Ownable.sol";

interface ISignataRight {
    function holdsTokenOfSchema(address holder, uint256 schemaId)
        external
        view
        returns (bool);
}

contract SignataWrappedToken is Ownable {
    using SafeERC20 for IERC20;
    ISignataRight public signataRight;
    uint256 public schemaId;

    string public name;
    string public symbol;
    uint8 public decimals;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    IERC20 public immutable token;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _token,
        ISignataRight _signataRight,
        uint256 _schemaId
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        token = IERC20(_token);
        signataRight = _signataRight;
        schemaId = _schemaId;
    }

    function deposit(uint256 amt) public {
        require(
            signataRight.holdsTokenOfSchema(msg.sender, schemaId),
            "deposit: sender doesn't hold right"
        );
        token.safeTransferFrom(msg.sender, address(this), amt);

        balanceOf[msg.sender] += amt;
        emit Deposit(msg.sender, amt);
    }

    function withdraw(uint256 wad) public {
        require(
            signataRight.holdsTokenOfSchema(msg.sender, schemaId),
            "withdraw: sender doesn't hold right"
        );
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        token.safeTransfer(msg.sender, wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public returns (bool) {
        require(balanceOf[src] >= wad);

        if (
            src != msg.sender && allowance[src][msg.sender] != type(uint256).max
        ) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }

    function updateSignataRight(ISignataRight _signataRight) public onlyOwner {
        signataRight = _signataRight;
    }

    function updateSchemaId(uint256 _schemaId) public onlyOwner {
        schemaId = _schemaId;
    }
}
