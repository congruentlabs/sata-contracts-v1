// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SignataIdentity.sol";
import "./SignataRight.sol";
import "./ClaimRight.sol";

contract VeriswapERC20 is Ownable, ReentrancyGuard {
    SignataIdentity public signataIdentity;
    SignataRight public signataRight; // rights for checking schema ownership
    ClaimRight public claimRight; // claim rights for checking schema identifier for kyc

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
        bool requireKyc;
        States state;
    }

    bool public canSwap = true;

    mapping(address => AtomicSwap) public swaps;

    event SwapCreated(AtomicSwap swapData);
    event SwapExecuted(address creatorAddress);
    event SwapCancelled(address creatorAddress);
    event ExecutorModified(
        address creatorAddress,
        address oldExecutor,
        address newExecutor
    );
    event IdentityContractChanged(SignataIdentity newIdentity);
    event RightsContractChanged(SignataRight newRights);
    event ClaimRightContractChanged(ClaimRight newClaimRight);

    constructor(
        SignataIdentity _signataIdentity,
        SignataRight _signataRight,
        ClaimRight _kycClaimRight
    ) {
        signataIdentity = _signataIdentity;
        signataRight = _signataRight;
        claimRight = _kycClaimRight;
    }

    function createSwap(
        address _inputToken,
        uint256 _inputAmount,
        address _outputToken,
        uint256 _outputAmount,
        address _executor,
        bool _requireIdentity,
        bool _requireKyc
    ) public {
        if (_requireIdentity) {
            require(
                !signataIdentity.isLocked(msg.sender),
                "createSwap::creator must not be locked"
            );
            // don't check the executor yet, just in case they go and register after the fact.
        }
        if (_requireKyc) {
            require(
                signataRight.holdsTokenOfSchema(
                    msg.sender,
                    claimRight.schemaId()
                ),
                "executeSwap::Sender must have kyc nft"
            );
            // don't check the executor yet, just in case they go and kyc after the fact.
        }
        AtomicSwap memory swapToCheck = swaps[msg.sender];
        require(
            swapToCheck.state != States.OPEN,
            "createSwap::already have an open swap"
        );

        IERC20 inputToken = IERC20(_inputToken);

        // check allowance
        require(
            _inputAmount <= inputToken.allowance(msg.sender, address(this)),
            "createSwap::insufficient allowance"
        );

        // transfer into escrow
        require(
            inputToken.transferFrom(msg.sender, address(this), _inputAmount),
            "createSwap::transferFrom failed"
        );

        // store the details
        AtomicSwap memory newSwap = AtomicSwap({
            inputToken: _inputToken,
            inputAmount: _inputAmount,
            outputToken: _outputToken,
            outputAmount: _outputAmount,
            executor: _executor,
            creator: msg.sender,
            requireIdentity: _requireIdentity,
            requireKyc: _requireKyc,
            state: States.OPEN
        });
        swaps[msg.sender] = newSwap;

        emit SwapCreated(newSwap);
    }

    function executeSwap(address creatorAddress) external nonReentrant {
        require(canSwap, "executeSwap::swaps not enabled!");

        // check the state
        AtomicSwap memory swapToExecute = swaps[creatorAddress];

        require(
            swapToExecute.state == States.OPEN,
            "executeSwap::not an open swap"
        );
        require(
            swapToExecute.executor == msg.sender,
            "executeSwap::only the executor can call this function"
        );

        // check identities
        if (swapToExecute.requireIdentity == true) {
            require(
                !signataIdentity.isLocked(msg.sender),
                "executeSwap::Sender must not be locked"
            );
            require(
                !signataIdentity.isLocked(swapToExecute.executor),
                "executeSwap::Trader must not be locked"
            );
        }

        if (swapToExecute.requireKyc == true) {
            require(
                signataRight.holdsTokenOfSchema(
                    msg.sender,
                    claimRight.schemaId()
                ),
                "executeSwap::Sender must have kyc nft"
            );
            require(
                signataRight.holdsTokenOfSchema(
                    swapToExecute.executor,
                    claimRight.schemaId()
                ),
                "executeSwap::Trader must have kyc nft"
            );
        }

        IERC20 outputToken = IERC20(swapToExecute.outputToken);
        IERC20 inputToken = IERC20(swapToExecute.inputToken);

        swaps[swapToExecute.creator].state = States.CLOSED;

        // check allowance
        require(
            swapToExecute.outputAmount <=
                outputToken.allowance(msg.sender, address(this))
        );
        // send the input to the executor
        require(
            inputToken.transfer(
                swapToExecute.executor,
                swapToExecute.inputAmount
            )
        );
        // send the output to the creator
        require(
            outputToken.transferFrom(
                msg.sender,
                swapToExecute.creator,
                swapToExecute.outputAmount
            )
        );

        // send the parties their respective tokens
        emit SwapExecuted(creatorAddress);
    }

    function cancelSwap() external nonReentrant {
        AtomicSwap memory swapToCancel = swaps[msg.sender];
        require(
            swapToCancel.creator == msg.sender,
            "cancelSwap::not the creator"
        );
        require(
            swapToCancel.state == States.OPEN,
            "cancelSwap::not an open swap"
        );

        swaps[msg.sender].state = States.EXPIRED;

        // return the input back to the creator
        IERC20 inputToken = IERC20(swapToCancel.inputToken);
        require(
            inputToken.transfer(swapToCancel.creator, swapToCancel.inputAmount)
        );

        emit SwapCancelled(swapToCancel.creator);
    }

    function changeExecutor(address newExecutor) external {
        require(
            newExecutor != address(0),
            "changeExecutor::cannot set to 0 address"
        );
        AtomicSwap memory swapToChange = swaps[msg.sender];

        address oldExecutor = swaps[msg.sender].executor;

        require(
            newExecutor != oldExecutor,
            "changeExecutor::not different values"
        );
        require(
            swapToChange.creator == msg.sender,
            "changeExecutor::not the creator"
        );
        require(
            swapToChange.state == States.OPEN,
            "changeExecutor::not an open swap"
        );

        swaps[msg.sender].executor = newExecutor;

        emit ExecutorModified(msg.sender, oldExecutor, newExecutor);
    }

    function enableSwaps() external onlyOwner {
        canSwap = true;
    }

    function disableSwaps() external onlyOwner {
        canSwap = false;
    }

    function updateSignataIdentity(SignataIdentity newIdentity)
        external
        onlyOwner
    {
        signataIdentity = newIdentity;
        emit IdentityContractChanged(newIdentity);
    }

    function updateSignataRight(SignataRight newRights) external onlyOwner {
        signataRight = newRights;
        emit RightsContractChanged(newRights);
    }

    function updateClaimRight(ClaimRight newClaimRight) external onlyOwner {
        claimRight = newClaimRight;
        emit ClaimRightContractChanged(newClaimRight);
    }
}
