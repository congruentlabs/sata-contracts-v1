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
    bool public swapping;
    uint256 public lastSwapTime;
    bool public tradingActive;
    bool public transferFeesEnabled = true;
    bool public antiSnipeEnabled = true;
    uint256 public feeAmount = 100; // 1% default

    // block number of opened trading
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

    constructor(address _feeNativeReceiver) ERC20("Signata DAO", "dSATA") ERC20Permit("Signata DAO") {
        feeNativeReceiver = _feeNativeReceiver;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(UNISWAPROUTER);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        isExcludedFromFees[msg.sender] = true;

        _mint(msg.sender, 50000000 * 10 ** decimals());
    }

    receive() external payable {}

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

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "_transfer: transfer from the zero address");
        require(to != address(0), "_transfer: transfer to the zero address");
        require(!blacklist[from], "_transfer: Sender is blacklisted");
        require(!blacklist[to], "_transfer: Recipient is blacklisted");

        if (amount == 0) {
            _executeTransfer(from, to, 0);
            return;
        }

        if (!tradingActive) {
            require(isExcludedFromFees[from] || isExcludedFromFees[to], "Trading is not active.");
        }

        // anti bot logic
        if (antiSnipeEnabled) {
            if (block.number <= (launchedAt + 1) && 
                to != uniswapV2Pair && 
                to != address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
            ) {
                blacklist[to] = true;
                emit BoughtEarly(to);
            }
        }
        
        bool takeFee;

        if (
            from == address(uniswapV2Pair) ||
            to == address(uniswapV2Pair) ||
            automatedMarketMakerPairs[from] ||
            automatedMarketMakerPairs[to]
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

        if (takeFee) {
            uint256 feesToTake = (amount / 10000) * feeAmount;
 
            if (feesToTake > 0) {
                _executeTransfer(from, address(this), feesToTake);
                emit FeesTaken(feesToTake);
            }
 
            amount -= feesToTake;
        }
        _executeTransfer(from, to, amount);
    }

    function _executeTransfer(address sender, address recipient, uint256 amount) private {
        super._transfer(sender, recipient, amount);
    }

    function wouldPayFees(address toCheck) public view returns (bool) {
        return toCheck == address(uniswapV2Pair) || automatedMarketMakerPairs[toCheck] || !isExcludedFromFees[toCheck];
    }

    function withdrawCollectedFees() public onlyOwner {
        super._transfer(address(this), msg.sender, balanceOf(address(this)));
    }

    function swapCollectedFees() public onlyOwner {
        swapping = true;
        uint256 tokenBalance = balanceOf(address(this));

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

        lastSwapTime = block.timestamp;
        swapping = false;
        
        emit TaxesSwappedForNative(feeNativeReceiver);
    }
}
