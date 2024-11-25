// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/NEXToken.sol";
import "../src/Vesting.sol";

contract VestingTest is Test {
    NEXToken public nexToken;
    Vesting public vestingContract;
    address public owner = address(0x1);
    address public beneficiary = address(0x2);

    function setUp() public {
        // Deploy NEXToken and Vesting contracts
        nexToken = new NEXToken();
        vestingContract = new Vesting(IERC20(address(nexToken)));

        // Step 1: Initialize the NEXToken contract with the correct `owner`
        vm.prank(owner);
        nexToken.initialize();

        // Step 2: Verify `owner` has the `DEFAULT_ADMIN_ROLE` after initialization
        bool isAdmin = nexToken.hasRole(nexToken.ADMIN_ROLE(), owner);
        console.log("Is owner admin after initialization: ", isAdmin);
        require(isAdmin, "Owner does not have ADMIN_ROLE");

        // Step 3: Set the Vesting Contract as the admin
        vm.prank(owner);
        nexToken.setVestingContract(address(vestingContract));

        // Step 4: Transfer tokens to the vesting contract
        vm.prank(owner);
        nexToken.setupVestingContract(address(vestingContract));
    }

    function testCreateVestingSchedule() public {
        uint256 start = block.timestamp;
        uint256 cliff = 30 days;
        uint256 duration = 180 days;
        uint256 amount = 10_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliff, duration, amount);

        Vesting.VestingSchedule memory schedule = vestingContract.getVestingSchedule(beneficiary, 0);

        assertTrue(schedule.initialized);
        assertEq(schedule.cliff, start + cliff);
        assertEq(schedule.duration, duration);
        assertEq(schedule.totalAmount, amount);
    }

    function testVestedAmount() public {
        uint256 start = block.timestamp;
        uint256 cliff = 30 days;
        uint256 duration = 180 days;
        uint256 amount = 10_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliff, duration, amount);

        // Fast forward to halfway through the vesting period
        vm.warp(start + 90 days);

        uint256 vested = vestingContract.getVestedBalance(beneficiary);
        assertEq(vested, 5_000 * 10 ** 18);
    }

    function testReleaseVestedTokens() public {
        uint256 start = block.timestamp;
        uint256 cliff = 30 days;
        uint256 duration = 180 days;
        uint256 amount = 10_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliff, duration, amount);

        // Fast forward to halfway through the vesting period
        vm.warp(start + 90 days);

        vm.prank(beneficiary);
        vestingContract.release(0);

        assertEq(nexToken.balanceOf(beneficiary), 5_000 * 10 ** 18);
    }

    function testVestingRestrictions() public {
        uint256 start = block.timestamp;
        uint256 cliff = 30 days;
        uint256 duration = 180 days;
        uint256 amount = 10_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliff, duration, amount);

        // Before cliff, no tokens should be releasable
        vm.warp(start + 15 days);
        uint256 vested = vestingContract.getVestedBalance(beneficiary);
        assertEq(vested, 0);

        vm.prank(beneficiary);
        vm.expectRevert("Cliff period not reached");
        vestingContract.release(0);
    }
}
