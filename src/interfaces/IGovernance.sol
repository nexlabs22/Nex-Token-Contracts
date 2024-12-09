// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IGovernance {
    function getProposalStatus(uint256 proposalId) external view returns (bool approved);

    function createProposal(
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata callDatas
    ) external returns (uint256);

    function isProposalApproved(uint256 proposalId) external view returns (bool);
}
