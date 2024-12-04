// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Governance.sol";
import "../src/NEXToken.sol";

contract GovernanceTest is Test {
    Governance public governance;
    NEXToken public nexToken;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x5);
    address public vestingContract = address(0x4);

    uint256 public proposalThreshold;

    function setUp() public {
        nexToken = new NEXToken();

        vm.prank(owner);
        nexToken.initialize(vestingContract);

        vm.prank(owner);
        nexToken.mint(user1, 1000 * 10 ** 18);

        vm.prank(owner);
        nexToken.mint(user2, 400 * 10 ** 18);

        vm.prank(owner);
        nexToken.mint(user3, 600 * 10 ** 18);

        vm.prank(user1);
        nexToken.delegate(user1);

        vm.prank(user2);
        nexToken.delegate(user2);

        vm.prank(user3);
        nexToken.delegate(user3);

        vm.roll(block.number + 1);

        governance = new Governance();
        proposalThreshold = 500 * 10 ** 18; // Set proposal threshold to 500 tokens

        vm.prank(owner);
        governance.initialize(nexToken, 1 days, proposalThreshold);
    }

    function testProposalCreation() public {
        vm.prank(user1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory callDatas = new bytes[](1);

        governance.createProposal("Proposal 1", targets, values, callDatas);

        Governance.Proposal memory proposal = governance.getProposal(0);
        assertEq(proposal.id, 0);
        assertEq(proposal.description, "Proposal 1");
        assertEq(proposal.proposer, user1);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Active));
    }

    function testProposalCreationBelowThreshold() public {
        vm.prank(user2);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory callDatas = new bytes[](1);

        vm.expectRevert("Insufficient voting power to create proposal");
        governance.createProposal("Proposal 2", targets, values, callDatas);
    }

    function testExecuteProposalSuccess() public {
        MockTarget mockTarget = new MockTarget();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory callDatas = new bytes[](1);

        targets[0] = address(mockTarget);
        values[0] = 0;
        callDatas[0] = abi.encodeWithSignature("setValue(uint256)", 42);

        vm.prank(user1);
        governance.createProposal("Set value to 42 in MockTarget", targets, values, callDatas);

        Governance.Proposal memory proposal = governance.getProposal(0);
        uint256 startBlock = proposal.startBlock;

        vm.roll(startBlock + 1);
        vm.prank(user1);
        governance.vote(0, true);

        vm.prank(user2);
        governance.vote(0, true);

        vm.prank(user3);
        governance.vote(0, true);

        vm.roll(proposal.endBlock + 1);

        vm.prank(user1);
        governance.executeProposal(0);

        proposal = governance.getProposal(0);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Queued));
        assertTrue(proposal.timelockEnd > block.timestamp);

        vm.warp(block.timestamp + governance.timelockDuration() + 1);

        vm.prank(user1);
        governance.executeProposal(0);

        proposal = governance.getProposal(0);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Executed));

        uint256 value = mockTarget.value();
        assertEq(value, 42);
    }

    function testMultiSigTimelockChange() public {
        vm.prank(owner);
        address[] memory approvers = new address[](3);
        approvers[0] = user1;
        approvers[1] = user2;
        approvers[2] = user3;
        governance.setApprovers(approvers);

        vm.prank(user1);
        governance.proposeTimelockDurationChange(2 days);

        vm.prank(user2);
        governance.proposeTimelockDurationChange(2 days);

        uint256 newTimelockDuration = governance.timelockDuration();
        assertEq(newTimelockDuration, 2 days);
    }

    function testMultiSigTimelockChangeInsufficientApprovals() public {
        vm.prank(owner);
        address[] memory approvers = new address[](3);
        approvers[0] = user1;
        approvers[1] = user2;
        approvers[2] = user3;
        governance.setApprovers(approvers);

        vm.prank(user1);
        governance.proposeTimelockDurationChange(2 days);

        uint256 currentTimelockDuration = governance.timelockDuration();
        assertEq(currentTimelockDuration, 1 days);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

// MockTarget contract for testing proposal execution
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}
