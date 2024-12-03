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

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 id, address proposer, string description);
    event Voted(uint256 proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 id);
    event ProposalQueued(uint256 id, uint256 timelockEnd);
    event ProposalFailed(uint256 id);

    function initialize(ERC20VotesUpgradeable _token, uint256 _timelockDuration) public initializer {
        __Ownable_init(msg.sender);
        token = _token;
        timelockDuration = _timelockDuration;
    }

    /**
     * @dev Create a new proposal.
     */
    function createProposal(
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata callDatas
    ) external returns (uint256) {
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

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.number > proposal.endBlock, "Voting has not ended");
        require(proposal.state != ProposalState.Executed, "Proposal already executed");

        if (proposal.state == ProposalState.Active) {
            if (proposal.yesVotes > proposal.noVotes) {
                proposal.state = ProposalState.Succeeded;
            } else {
                proposal.state = ProposalState.Failed;
                emit ProposalFailed(proposalId);
                return;
            }
        }

        if (proposal.state == ProposalState.Succeeded) {
            proposal.state = ProposalState.Queued;
            proposal.timelockEnd = block.timestamp + timelockDuration;
            emit ProposalQueued(proposalId, proposal.timelockEnd);
        }

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
