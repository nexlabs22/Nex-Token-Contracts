// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IVesting {
    function getVestedBalance(address account) external view returns (uint256);

    function getLockedBalance(address beneficiary) external view returns (uint256);

    function createVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 totalAmount
    ) external;
}
