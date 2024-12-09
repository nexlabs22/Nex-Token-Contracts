// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/NEXToken.sol";
import "../src/Governance.sol";
import "../src/Treasury.sol";
import "../src/interfaces/IGovernance.sol";

contract TreasuryTest is Test {
    NEXToken public nexToken;
    Governance public governance;
    Treasury public treasury;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public vestingContract = address(0x4);

    uint256 public proposalThreshold;

    function setUp() public {
        nexToken = new NEXToken();

        vm.prank(owner);
        nexToken.initialize(vestingContract);

        vm.prank(owner);
        nexToken.mint(user1, 1000 * 1e18);

        vm.prank(owner);
        nexToken.mint(user2, 500 * 1e18);

        vm.prank(user1);
        nexToken.delegate(user1);

        vm.prank(user2);
        nexToken.delegate(user2);

        vm.roll(block.number + 1);

        governance = new Governance();

        vm.prank(owner);
        governance.initialize(nexToken, 1 days, proposalThreshold);

        treasury = new Treasury();

        vm.prank(owner);
        treasury.initialize(address(nexToken), address(governance));

        vm.prank(owner);
        nexToken.setTreasuryContract(address(treasury));

        vm.prank(owner);
        nexToken.mint(address(treasury), 5000 * 1e18);
    }

    function testCreateFundRequest() public {
        vm.startPrank(user1);

        uint256 amount = 100 * 1e18;
        address recipient = user2;
        string memory description = "Fund request for project X";

        uint256 proposalId = treasury.createFundRequest(amount, recipient, description);

        Treasury.FundRequest memory request = treasury.getFundRequest(0);
        assertEq(request.requestId, 0);
        assertEq(request.requester, user1);
        assertEq(request.amount, amount);
        assertEq(request.recipient, recipient);
        assertEq(request.executed, false);
        assertEq(request.proposalId, proposalId);

        Governance.Proposal memory proposal = governance.getProposal(proposalId);
        assertEq(proposal.id, proposalId);
        assertEq(proposal.description, description);
        assertEq(proposal.proposer, address(treasury));

        vm.stopPrank();
    }

    function testExecuteFundRequest() public {
        vm.warp(1000);

        vm.startPrank(user1);

        uint256 amount = 100 * 1e18;
        address recipient = user2;
        string memory description = "Fund request for project Y";

        uint256 proposalId = treasury.createFundRequest(amount, recipient, description);

        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        governance.vote(proposalId, true);

        vm.prank(user2);
        governance.vote(proposalId, true);

        Governance.Proposal memory proposal = governance.getProposal(proposalId);
        vm.roll(proposal.endBlock + 1);

        vm.prank(user1);
        governance.executeProposal(proposalId);

        proposal = governance.getProposal(proposalId);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Queued));
        assertTrue(proposal.timelockEnd > block.timestamp);

        vm.warp(block.timestamp + governance.timelockDuration() + 1);

        vm.prank(user1);
        governance.executeProposal(proposalId);

        proposal = governance.getProposal(proposalId);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Executed));

        Treasury.FundRequest memory request = treasury.getFundRequest(0);
        assertTrue(request.executed);

        uint256 recipientBalance = nexToken.balanceOf(recipient);
        assertEq(recipientBalance, (500 + 100) * 1e18);
    }

    function testExecuteFundRequestWithoutApproval() public {
        vm.startPrank(user1);

        uint256 amount = 100 * 1e18;
        address recipient = user2;
        string memory description = "Fund request for project Z";
        vm.stopPrank();

        uint256 proposalId = treasury.createFundRequest(amount, recipient, description);

        vm.roll(block.number + 1);

        vm.prank(user1);
        governance.vote(proposalId, false);
        vm.stopPrank();

        vm.prank(user2);
        governance.vote(proposalId, false);
        vm.stopPrank();

        Governance.Proposal memory proposal = governance.getProposal(proposalId);
        vm.roll(proposal.endBlock + 1);

        vm.prank(user1);
        vm.expectRevert("Proposal not approved");
        treasury.executeFundRequest(0);

        Treasury.FundRequest memory request = treasury.getFundRequest(0);
        assertFalse(request.executed);

        vm.stopPrank();
    }

    function testUnauthorizedGovernanceContractUpdate() public {
        vm.startPrank(user1);

        vm.expectRevert("Unauthorized");
        treasury.setGovernanceContract(address(0x123));

        vm.stopPrank();
    }

    function testAuthorizedGovernanceContractUpdate() public {
        vm.prank(address(governance));
        treasury.setGovernanceContract(address(governance));

        assertEq(address(treasury.governance()), address(governance));
    }

    function testCreateFundRequestWithZeroAmount() public {
        vm.startPrank(user1);

        uint256 amount = 0;
        address recipient = user2;
        string memory description = "Invalid fund request";

        vm.expectRevert("Amount must be greater than zero");
        treasury.createFundRequest(amount, recipient, description);

        vm.stopPrank();
    }

    function testCreateFundRequestWithZeroRecipient() public {
        vm.startPrank(user1);

        uint256 amount = 100 * 1e18;
        address recipient = address(0);
        string memory description = "Invalid fund request";

        vm.expectRevert("Recipient address cannot be zero");
        treasury.createFundRequest(amount, recipient, description);

        vm.stopPrank();
    }

    function testExecuteAlreadyExecutedFundRequest() public {
        vm.warp(1000);

        vm.startPrank(user1);

        uint256 amount = 100 * 1e18;
        address recipient = user2;
        string memory description = "Fund request for project Y";

        uint256 proposalId = treasury.createFundRequest(amount, recipient, description);

        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.prank(user1);
        governance.vote(proposalId, true);

        vm.prank(user2);
        governance.vote(proposalId, true);

        Governance.Proposal memory proposal = governance.getProposal(proposalId);
        vm.roll(proposal.endBlock + 1);

        vm.prank(user1);
        governance.executeProposal(proposalId);

        proposal = governance.getProposal(proposalId);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Queued));

        vm.warp(block.timestamp + governance.timelockDuration() + 1);

        vm.prank(user1);
        governance.executeProposal(proposalId);

        proposal = governance.getProposal(proposalId);
        assertEq(uint256(proposal.state), uint256(Governance.ProposalState.Executed));

        vm.prank(user1);
        vm.expectRevert("Request already executed");
        treasury.executeFundRequest(0);
    }

    function testTokenTransferFromTreasury() public {
        uint256 treasuryBalance = nexToken.balanceOf(address(treasury));
        console.log("Treasury balance before transfer:", treasuryBalance);
        assertEq(treasuryBalance, 5000 * 1e18);

        vm.prank(address(treasury));
        nexToken.transfer(user2, 100 * 1e18);

        treasuryBalance = nexToken.balanceOf(address(treasury));
        uint256 user2Balance = nexToken.balanceOf(user2);

        console.log("Treasury balance after transfer:", treasuryBalance);
        console.log("User2 balance after transfer:", user2Balance);

        assertEq(treasuryBalance, (5000 - 100) * 1e18);
        assertEq(user2Balance, (500 + 100) * 1e18);
    }
}
