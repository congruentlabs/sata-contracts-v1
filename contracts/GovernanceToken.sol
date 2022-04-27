// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./extensions/IUniswapV2Router02.sol";
import "./extensions/IUniswapV2Factory.sol";

/// @custom:security-contact support@signata.net
contract SignataDAO is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, ERC20Permit, ERC20Votes {
    address constant UNISWAPROUTER = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    mapping (address => bool) public blacklist;
    mapping (address => bool) private isExcludedFromFees;
    mapping (address => bool) public automatedMarketMakerPairs;
    
    address public feeNativeReceiver;
    bool private swapping;
    uint256 public lastSwapTime;
    bool public tradingActive;
    bool public buyFeeEnabled = true;
    bool public sellFeeEnabled = true;
    bool public transferFeesEnabled = true;
    uint256 public buyFee = 100; // 1% default
    uint256 public sellFee = 100; // 1% default
    uint256 public swapTokensAtAmount = (25000 * 1e18); // 0.05% of the 50 mil total supply

    // block number of opened trading
    uint256 launchedAt;

    event TaxesSwappedForNative(address recipient);
    event BoughtEarly(address indexed sniper);
    event ModifiedSwapTokensAtAmount(uint256 oldAmount, uint256 newAmount);
    event ModifiedBuyFee(uint256 oldAmount, uint256 newAmount);
    event ModifiedSellFee(uint256 oldAmount, uint256 newAmount);
    event BuyFeeEnabled();
    event SellFeeEnabled();
    event BuyFeeDisabled();
    event SellFeeDisabled();
    event TransferFeeEnabled();
    event TransferFeeDisabled();
    event ExcludedFromFees(address account, bool excluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    constructor(address _feeNativeReceiver) ERC20("Signata DAO", "dSATA") ERC20Permit("Signata DAO") {
        feeNativeReceiver = _feeNativeReceiver;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(UNISWAPROUTER);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        isExcludedFromFees[msg.sender] = true;
        automatedMarketMakerPairs[_uniswapV2Router] = true;

        _mint(msg.sender, 50000000 * 10 ** decimals());
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function setFeeReceiver(address newWallet) public onlyOwner {
        require(newWallet != address(0), "setFeeReceiver: cannot be set to 0 address");
        feeNativeReceiver = newWallet;
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
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

    function enableBuyFee() external onlyOwner {
        require(!buyFeeEnabled, "enableBuyFee: buy fee already enabled");
        buyFeeEnabled = true;
        emit BuyFeeEnabled();
    }

    function disableBuyFee() external onlyOwner {
        require(buyFeeEnabled, "disableBuyFee: buy fee already disabled");
        buyFeeEnabled = false;
        emit BuyFeeDisabled();
    }

    function enableSellFee() external onlyOwner {
        require(!sellFeeEnabled, "enableSellFee: sell fee already enabled");
        sellFeeEnabled = true;
        emit SellFeeEnabled();
    }

    function disableSellFee() external onlyOwner {
        require(sellFeeEnabled, "disableSellFee: sell fee already disabled");
        sellFeeEnabled = false;
        emit SellFeeDisabled();
    }

    function modifySwapTokensAmount(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = swapTokensAtAmount;
        swapTokensAtAmount = newAmount;
        emit ModifiedSwapTokensAtAmount(oldAmount, newAmount);
    }

    function modifyBuyFee(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = buyFee;
        buyFee = newAmount;
        emit ModifiedBuyFee(oldAmount, newAmount);
    }

    function modifySellFee(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = sellFee;
        sellFee = newAmount;
        emit ModifiedSellFee(oldAmount, newAmount);
    }

    function enableTrading() external onlyOwner {
        tradingActive = true;
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


    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "_transfer: transfer from the zero address");
        require(to != address(0), "_transfer: transfer to the zero address");
        require(!blacklist[from], "_transfer: Sender is blacklisted");
        require(!blacklist[to], "_transfer: Recipient is blacklisted");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (!tradingActive) {
            require(isExcludedFromFees[from] || isExcludedFromFees[to], "Trading is not active.");
        }

        // anti bot logic
        if (block.number <= (launchedAt + 1) && 
            to != uniswapV2Pair && 
            to != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
        ) {
            blacklist[to] = true;
            emit BoughtEarly(to);
        }
        
        if (
            !automatedMarketMakerPairs[from] && // no swap on remove liquidity step 1 or DEX buy
            from != address(uniswapV2Router) && // no swap on remove liquidity step 2
            from != owner() &&
            to != owner() &&
            !swapping &&
        ) {
            swapping = true;

            _executeSwap(tokenBalance);

            lastSwapTime = block.timestamp;
            swapping = false;
        }

        bool takeFee;

        if (
            from == address(uniswapV2Pair) ||
            to == address(uniswapV2Pair) ||
            automatedMarketMakerPairs[to] ||
            automatedMarketMakerPairs[from]
        ) {
            takeFee = true;
        }

        if (
            !transferFeesEnabled ||
            swapping ||
            isExcludedFromFees[from] ||
            isExcludedFromFees[to]
        ) {
            takeFee = false;
        }

        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            uint256 feesToTake;
            
            if (automatedMarketMakerPairs[to] && sellFeeEnabled) { // on sell
                feesToTake = (amount * sellFee) / 10000;
            } else if (automatedMarketMakerPairs[from] && buyFeeEnabled) { // on buy
                feesToTake = (amount * buyFee) / 10000;
            }
 
            if (feesToTake > 0) {
                super._transfer(from, address(this), feesToTake);
            }
 
            amount -= feesToTake;
        }
        super._transfer(from, to, amount);
    }

    function _executeSwap() private {
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance <= 0 || tokenBalance < swapTokensAtAmount) {
            return;
        }
        bool success;

        // swap the tokens to native via uniswap
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenBalance);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenBalance,
            0, // accept any amount of native
            path,
            address(this),
            block.timestamp
        );

        (success,) = address(feeNativeReceiver).call{value: address(this).balance}("");
        emit TaxesSwappedForNative(feeNativeReceiver);
    }
}