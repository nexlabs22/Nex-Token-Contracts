// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Vesting.sol";
import "../src/NEXToken.sol";

contract VestingTest is Test {
    Vesting public vestingContract;
    NEXToken public nexToken;
    address public owner = address(0x1);
    address public beneficiary = address(0x2);

    function setUp() public {
        nexToken = new NEXToken();
        vestingContract = new Vesting();
        vm.startPrank(owner);
        nexToken.initialize(address(vestingContract));

        vestingContract.initialize(IERC20(address(nexToken)));
        vm.stopPrank();
    }

    function testCreateVestingSchedule() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.startPrank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);

        Vesting.VestingSchedule memory schedule = vestingContract.getVestingSchedule(beneficiary, 0);

        assertTrue(schedule.initialized);
        assertEq(schedule.beneficiary, beneficiary);
        assertEq(schedule.start, start);
        assertEq(schedule.cliff, start + cliffDuration);
        assertEq(schedule.duration, duration);
        assertEq(schedule.totalAmount, totalAmount);
        assertEq(schedule.released, 0);
        vm.stopPrank();
    }

    function testVestedBalance() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 15 days);
        uint256 vestedBeforeCliff = vestingContract.getVestedBalance(beneficiary);
        console.log("Vested Before Cliff:", vestedBeforeCliff);
        assertEq(vestedBeforeCliff, 0);

        vm.warp(start + 30 days);
        uint256 vestedAfterCliff = vestingContract.getVestedBalance(beneficiary);
        uint256 expectedVestedAfterCliff = (totalAmount * 30 days) / duration;
        console.log("Vested After Cliff:", vestedAfterCliff);
        console.log("Expected Vested After Cliff:", expectedVestedAfterCliff);
        assertEq(vestedAfterCliff, expectedVestedAfterCliff);

        vm.warp(start + duration);
        uint256 vestedAtEnd = vestingContract.getVestedBalance(beneficiary);
        console.log("Vested At End:", vestedAtEnd);
        assertEq(vestedAtEnd, totalAmount);
    }

    function testReleaseVestedTokens() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 90 days);

        uint256 timeElapsed = 90 days;
        uint256 vested = (totalAmount * timeElapsed) / duration;
        uint256 initialBeneficiaryBalance = nexToken.balanceOf(beneficiary);

        vm.prank(beneficiary);
        vestingContract.release(0);

        uint256 beneficiaryBalance = nexToken.balanceOf(beneficiary);
        assertEq(beneficiaryBalance - initialBeneficiaryBalance, vested);

        Vesting.VestingSchedule memory schedule = vestingContract.getVestingSchedule(beneficiary, 0);
        assertEq(schedule.released, vested);
    }

    function testReleaseBeforeCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 15 days);

        vm.prank(beneficiary);
        vm.expectRevert("Cliff period not reached");
        vestingContract.release(0);
    }

    function testInvalidVestingScheduleCreation() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 1_000_000_000 * 10 ** 18;

        vm.prank(owner);
        vm.expectRevert("Insufficient tokens in contract");
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);
    }

    function testGetVestingScheduleCount() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);

        assertEq(vestingContract.getVestingScheduleCount(beneficiary), 1);
    }

    function testReleaseUpdatesVestingSchedule() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        vestingContract.createVestingSchedule(beneficiary, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 90 days);

        uint256 timeElapsed = 90 days;
        uint256 vestedAmount = (totalAmount * timeElapsed) / duration;
        uint256 expectedVested = vestedAmount;

        assertEq(vestingContract.getVestedBalance(beneficiary), expectedVested);

        vm.prank(beneficiary);
        vestingContract.release(0);

        assertEq(nexToken.balanceOf(beneficiary), vestedAmount);

        Vesting.VestingSchedule memory schedule = vestingContract.getVestingSchedule(beneficiary, 0);
        assertEq(schedule.released, vestedAmount);
        assertEq(schedule.totalAmount - schedule.released, totalAmount - vestedAmount);

        vm.warp(start + duration);

        uint256 remainingVested = vestingContract.getVestedBalance(beneficiary);
        assertEq(remainingVested, totalAmount - vestedAmount);

        vm.prank(beneficiary);
        vestingContract.release(0);

        schedule = vestingContract.getVestingSchedule(beneficiary, 0);
        assertEq(schedule.released, totalAmount);

        assertEq(nexToken.balanceOf(beneficiary), totalAmount);
    }
}
