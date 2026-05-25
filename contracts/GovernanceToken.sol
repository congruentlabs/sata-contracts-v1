// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "./extensions/IUniswapV2Router02.sol";
import "./extensions/IUniswapV2Factory.sol";

/// @custom:security-contact support@signata.net
contract SignataDAO is ERC20, ERC20Burnable, Ownable, ERC20Permit, ERC20Votes {
    address constant UNISWAPROUTER = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    mapping(address => bool) public blacklist;
    mapping(address => bool) private isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    address public feeNativeReceiver;
    bool public swapping;
    uint256 public lastSwapTime;
    bool public tradingActive;
    bool public transferFeesEnabled = true;
    bool public antiSnipeEnabled = true;
    uint256 public feeAmount = 100; // 1% default

    uint256 launchedAt;

    event TaxesSwappedForNative(address recipient);
    event BoughtEarly(address indexed sniper);
    event ModifiedFee(uint256 oldAmount, uint256 newAmount);
    event FeeEnabled();
    event FeeDisabled();
    event TransferFeeEnabled();
    event TransferFeeDisabled();
    event FeesTaken(uint256 feesAmount);
    event ExcludedFromFees(address account, bool excluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    constructor(address _feeNativeReceiver)
        ERC20("Signata DAO", "dSATA")
        Ownable(msg.sender)
        ERC20Permit("Signata DAO")
    {
        feeNativeReceiver = _feeNativeReceiver;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(UNISWAPROUTER);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        isExcludedFromFees[msg.sender] = true;

        _mint(msg.sender, 50000000 * 10 ** decimals());
    }

    receive() external payable {}

    function setFeeReceiver(address newWallet) public onlyOwner {
        require(newWallet != address(0), "setFeeReceiver: cannot be set to 0 address");
        feeNativeReceiver = newWallet;
    }

    // OZ 5 collapses _beforeTokenTransfer / _afterTokenTransfer / _mint / _burn and the
    // formerly-virtual _transfer into the single _update hook. Mint/burn paths use
    // from == address(0) / to == address(0); we only apply fee + blacklist logic to true
    // transfers between two non-zero addresses.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        require(!blacklist[from], "_update: Sender is blacklisted");
        require(!blacklist[to], "_update: Recipient is blacklisted");

        if (value == 0) {
            super._update(from, to, 0);
            return;
        }

        if (!tradingActive) {
            require(isExcludedFromFees[from] || isExcludedFromFees[to], "Trading is not active.");
        }

        if (antiSnipeEnabled) {
            if (block.number <= (launchedAt + 1) &&
                to != uniswapV2Pair &&
                to != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
            ) {
                blacklist[to] = true;
                emit BoughtEarly(to);
            }
        }

        bool takeFee = (
            from == address(uniswapV2Pair) ||
            to == address(uniswapV2Pair) ||
            automatedMarketMakerPairs[from] ||
            automatedMarketMakerPairs[to]
        );

        if (
            !transferFeesEnabled ||
            swapping ||
            isExcludedFromFees[from] ||
            isExcludedFromFees[to]
        ) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 feesToTake = (value / 10000) * feeAmount;
            if (feesToTake > 0) {
                super._update(from, address(this), feesToTake);
                emit FeesTaken(feesToTake);
                value -= feesToTake;
            }
        }

        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function enableTransferFee() external onlyOwner {
        require(!transferFeesEnabled, "enableTransferFee: transfer fee already enabled");
        transferFeesEnabled = true;
        emit TransferFeeEnabled();
    }

    function disableTransferFee() external onlyOwner {
        require(transferFeesEnabled, "disableTransferFee: transfer fee already disabled");
        transferFeesEnabled = true;
        emit TransferFeeDisabled();
    }

    function modifyFee(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = feeAmount;
        feeAmount = newAmount;
        emit ModifiedFee(oldAmount, newAmount);
    }

    function enableTrading() external onlyOwner {
        tradingActive = true;
        antiSnipeEnabled = false;
        launchedAt = block.number;
    }

    function blacklistAccount(address account, bool isBlacklisted) public onlyOwner {
        blacklist[account] = isBlacklisted;
    }

    function excludedFromFees(address account) public view returns (bool) {
        return isExcludedFromFees[account];
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        isExcludedFromFees[account] = excluded;
        emit ExcludedFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool enabled) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, enabled);
    }

    function _setAutomatedMarketMakerPair(address pair, bool enabled) private {
        automatedMarketMakerPairs[pair] = enabled;
        emit SetAutomatedMarketMakerPair(pair, enabled);
    }

    function wouldPayFees(address toCheck) public view returns (bool) {
        return toCheck == address(uniswapV2Pair) || automatedMarketMakerPairs[toCheck] || !isExcludedFromFees[toCheck];
    }

    function withdrawCollectedFees() public onlyOwner {
        _transfer(address(this), msg.sender, balanceOf(address(this)));
    }

    function swapCollectedFees() public onlyOwner {
        swapping = true;
        uint256 tokenBalance = balanceOf(address(this));

        bool success;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenBalance);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenBalance,
            0,
            path,
            address(this),
            block.timestamp
        );

        (success,) = address(feeNativeReceiver).call{value: address(this).balance}("");

        lastSwapTime = block.timestamp;
        swapping = false;

        emit TaxesSwappedForNative(feeNativeReceiver);
    }
}
