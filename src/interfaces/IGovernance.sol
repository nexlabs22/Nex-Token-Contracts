// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IGovernance {
    function getProposalStatus(uint256 proposalId) external view returns (bool approved);
}
