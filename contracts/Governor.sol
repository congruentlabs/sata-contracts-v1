// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./openzeppelin/contracts/governance/Governor.sol";
import "./openzeppelin/contracts/governance/IGovernor.sol";
import "./openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "./openzeppelin/contracts/governance/compatibility/GovernorCompatibilityBravo.sol";
import "./openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "./openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "./openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "./SignataRight.json";

contract SignataGovernor is
    Governor,
    GovernorSettings,
    GovernorCompatibilityBravo,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    SignataRight public signataRight;
    uint256 public modifier1SchemaId;
    uint256 public modifier2SchemaId;
    uint256 public modifier1Multiplier = 200; // 2x default
    uint256 public modifier2Multiplier = 150; // 1.5x default

    bool public enableModifiers = true;
    uint256 public modifierExpiration = now + 365 days;

    constructor(
        IVotes _token,
        TimelockController _timelock,
        SignataRight _signataRight,
        uint256 _modifier1SchemaId,
        uint256 _modifier2SchemaId
    )
        Governor("Signata Governor")
        GovernorSettings(
            6545, /* 1 day */
            45818, /* 7 days */
            1
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {
        signataRight = _signataRight;
        modifier1SchemaId = _modifier1SchemaId;
        modifier2SchemaId = _modifier2SchemaId;
    }

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(Governor, IGovernor)
        returns (uint256)
    {
        if (enableModifiers && now < modifierExpiration) {
            if (signataRight.holdsTokenOfSchema(account, modifier1SchemaId)) {
                uint256 votes = super.getVotes(account, blockNumber);
                return (votes * modifier1Multiplier) / 100;
            } else if (
                signataRight.holdsTokenOfSchema(account, modifier2SchemaId)
            ) {
                uint256 votes = super.getVotes(account, blockNumber);
                return (votes * modifier2Multiplier) / 100;
            }
        }
        return super.getVotes(account, blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, IGovernor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, GovernorCompatibilityBravo, IGovernor)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, IERC165, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function changeSignataRight(SignataRight _signataRight)
        public
        onlyGovernance
    {
        signataRight = _signataRight;
    }

    function reinstateExpirationBlock() {
        modifierExpiration = now + 365 days;
    }

    function editModifiers(
        uint256 _modifier1SchemaId,
        uint256 _modifier2SchemaId,
        uint256 _modifier1Multiplier,
        uint256 _modifier2Multiplier,
        bool _enableModifiers
    ) public onlyGovernance {
        modifier1SchemaId = _modifier1SchemaId;
        modifier2SchemaId = _modifier2SchemaId;
        modifier1Multiplier = _modifier1Multiplier;
        modifier2Multiplier = _modifier2Multiplier;
        enableModifiers = _enableModifiers;
    }
}
