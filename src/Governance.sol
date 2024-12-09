// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Governance is OwnableUpgradeable {
    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Queued,
        Executed,
        Failed
    }

    struct Proposal {
        uint256 id;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 yesVotes;
        uint256 noVotes;
        address proposer;
        ProposalState state;
        uint256 timelockEnd;
        bytes[] callDatas;
        address[] targets;
        uint256[] values;
    }

    ERC20VotesUpgradeable public token;
    uint256 public proposalCount;
    uint256 public timelockDuration;
    uint256 public proposalThreshold;

    // Multi-Sig Variables
    uint256 public changeTimelockApprovalsCount;
    uint256 public newTimelockDuration;
    uint256 public changeTimelockApprovalsRequired;
    address[] public approvers;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public isApprover;
    mapping(address => bool) public hasApprovedChangeTimelock;

    event ProposalCreated(uint256 id, address proposer, string description);
    event Voted(uint256 proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 id);
    event ProposalQueued(uint256 id, uint256 timelockEnd);
    event ProposalFailed(uint256 id);
    event TimelockDurationChangeProposed(uint256 newDuration);
    event TimelockDurationChanged(uint256 newDuration);

    function initialize(ERC20VotesUpgradeable _token, uint256 _timelockDuration, uint256 _proposalThreshold)
        public
        initializer
    {
        __Ownable_init(msg.sender);
        token = _token;
        timelockDuration = _timelockDuration;
        proposalThreshold = _proposalThreshold;
    }

    /**
     * @dev Allows any eligible token holder to create a proposal.
     * Eligibility is determined by the proposal threshold.
     */
    function createProposal(
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata callDatas
    ) external returns (uint256) {
        uint256 proposerVotes = token.getPastVotes(msg.sender, block.number - 1);

        require(proposerVotes >= proposalThreshold, "Insufficient voting power to create proposal");
        require(targets.length == callDatas.length, "Mismatched proposal data");
        require(targets.length == values.length, "Mismatched proposal values");

        uint256 currentBlock = block.number;

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: description,
            startBlock: currentBlock,
            endBlock: currentBlock + 100,
            yesVotes: 0,
            noVotes: 0,
            proposer: msg.sender,
            state: ProposalState.Active,
            timelockEnd: 0,
            callDatas: callDatas,
            targets: targets,
            values: values
        });

        emit ProposalCreated(proposalCount, msg.sender, description);
        proposalCount++;
        return proposalCount - 1;
    }

    /**
     * @dev Vote on a proposal.
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.number >= proposal.startBlock, "Voting not started");
        require(block.number <= proposal.endBlock, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = token.getPastVotes(msg.sender, proposal.startBlock);
        uint256 quadraticWeight = sqrt(weight);

        if (support) {
            proposal.yesVotes += quadraticWeight;
        } else {
            proposal.noVotes += quadraticWeight;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, support, quadraticWeight);
    }

    /**
     * @dev Execute a proposal after the timelock period.
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.number > proposal.endBlock, "Voting has not ended");
        require(proposal.state != ProposalState.Executed, "Proposal already executed");

        // Transition from Active to Succeeded/Failed
        if (proposal.state == ProposalState.Active) {
            if (proposal.yesVotes > proposal.noVotes) {
                proposal.state = ProposalState.Succeeded;
            } else {
                proposal.state = ProposalState.Failed;
                emit ProposalFailed(proposalId);
                return;
            }
        }

        // Transition from Succeeded to Queued
        if (proposal.state == ProposalState.Succeeded) {
            proposal.state = ProposalState.Queued;
            proposal.timelockEnd = block.timestamp + timelockDuration;
            emit ProposalQueued(proposalId, proposal.timelockEnd);
            return;
        }

        // Transition from Queued to Executed
        if (proposal.state == ProposalState.Queued) {
            if (block.timestamp >= proposal.timelockEnd) {
                proposal.state = ProposalState.Executed;
                for (uint256 i = 0; i < proposal.targets.length; i++) {
                    (bool success,) = proposal.targets[i].call{value: proposal.values[i]}(proposal.callDatas[i]);
                    require(success, "Proposal execution failed");
                }
                emit ProposalExecuted(proposalId);
            } else {
                revert("Timelock not expired");
            }
        }
    }

    /**
     * @dev Multi-Signature function to propose a change to the timelock duration.
     */
    function proposeTimelockDurationChange(uint256 _newDuration) external {
        require(isApprover[msg.sender], "Not an approver");
        require(!hasApprovedChangeTimelock[msg.sender], "Already approved");

        if (changeTimelockApprovalsCount == 0) {
            newTimelockDuration = _newDuration;
            emit TimelockDurationChangeProposed(_newDuration);
        } else {
            require(newTimelockDuration == _newDuration, "Different duration proposed");
        }

        hasApprovedChangeTimelock[msg.sender] = true;
        changeTimelockApprovalsCount++;

        if (changeTimelockApprovalsCount >= changeTimelockApprovalsRequired) {
            timelockDuration = newTimelockDuration;
            emit TimelockDurationChanged(newTimelockDuration);
            // Reset approvals
            resetChangeTimelockApprovals();
        }
    }

    function resetChangeTimelockApprovals() internal {
        for (uint256 i = 0; i < approvers.length; i++) {
            hasApprovedChangeTimelock[approvers[i]] = false;
        }
        changeTimelockApprovalsCount = 0;
    }

    /**
     * @dev Set the list of approvers for multi-signature operations.
     */
    function setApprovers(address[] calldata _approvers) external onlyOwner {
        // Clear previous approvers
        for (uint256 i = 0; i < approvers.length; i++) {
            isApprover[approvers[i]] = false;
        }
        delete approvers;

        // Set new approvers
        for (uint256 i = 0; i < _approvers.length; i++) {
            isApprover[_approvers[i]] = true;
            approvers.push(_approvers[i]);
        }
        changeTimelockApprovalsRequired = _approvers.length / 2 + 1; // Majority required
    }

    /**
     * @dev Check if a proposal is approved (succeeded in voting).
     */
    function isProposalApproved(uint256 proposalId) external view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.yesVotes > proposal.noVotes)
            && (
                proposal.state == ProposalState.Succeeded || proposal.state == ProposalState.Queued
                    || proposal.state == ProposalState.Executed
            );
    }

    function getProposalStatus(uint256 proposalId) external view returns (ProposalState) {
        return proposals[proposalId].state;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
