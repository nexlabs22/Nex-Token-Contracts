// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IVesting {
    function getVestedBalance(address account) external view returns (uint256);
}
