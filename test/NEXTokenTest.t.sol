// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/NEXToken.sol";
import "../src/Vesting.sol";
import "../src/interfaces/IVesting.sol";

contract NEXTokenTest is Test {
    NEXToken public nexToken;
    address public owner = address(0x1);
    address public user = address(0x2);
    address public stakingContract = address(0x3);
    address public vestingContract = address(0x4);

    function setUp() public {
        nexToken = new NEXToken();

        Vesting vesting = new Vesting();

        vm.prank(owner);
        vesting.initialize(IERC20(address(nexToken)));

        vestingContract = address(vesting);

        vm.prank(owner);
        nexToken.initialize(vestingContract);

        vm.prank(owner);
        nexToken.setStakingContract(stakingContract);
    }

    function testInitialization() public view {
        assertEq(nexToken.totalSupply(), 100_000_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(vestingContract), 92_000_000 * 10 ** 18);
    }

    function testMinting() public {
        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(user), 1_000 * 10 ** 18);
    }

    function testMintingRestrictedToOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        nexToken.mint(user, 1_000 * 10 ** 18);
    }

    function testBurning() public {
        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        nexToken.burn(500 * 10 ** 18);

        assertEq(nexToken.balanceOf(user), 500 * 10 ** 18);
    }

    function testSettingStakingContract() public {
        address newStakingContract = address(0x5);

        vm.prank(owner);
        nexToken.setStakingContract(newStakingContract);

        assertEq(nexToken.stakingContract(), newStakingContract);
    }

    function testStakingContractRestrictedToOwner() public {
        address newStakingContract = address(0x5);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        nexToken.setStakingContract(newStakingContract);
    }

    function testAddingToWhitelist() public {
        vm.prank(owner);
        nexToken.addToWhitelist(user);

        assertTrue(nexToken.isWhitelisted(user));
    }

    function testRemovingFromWhitelist() public {
        vm.prank(owner);
        nexToken.addToWhitelist(user);
        assertTrue(nexToken.isWhitelisted(user));

        vm.prank(owner);
        nexToken.removeFromWhitelist(user);
        assertFalse(nexToken.isWhitelisted(user));
    }

    function testAddingToBlacklist() public {
        vm.prank(owner);
        nexToken.addToBlacklist(user);

        assertTrue(nexToken.isBlacklisted(user));
    }

    function testRemovingFromBlacklist() public {
        vm.prank(owner);
        nexToken.addToBlacklist(user);
        assertTrue(nexToken.isBlacklisted(user));

        vm.prank(owner);
        nexToken.removeFromBlacklist(user);
        assertFalse(nexToken.isBlacklisted(user));
    }

    function testRestrictedTransferForBlacklistedAddress() public {
        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(owner);
        nexToken.addToBlacklist(user);

        vm.prank(user);
        vm.expectRevert("Address is blacklisted");
        nexToken.transfer(address(0x6), 100 * 10 ** 18);
    }

    function testTransferToStakingContract() public {
        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        nexToken.transfer(stakingContract, 1_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(stakingContract), 1_000 * 10 ** 18);
    }

    function testTransferToNonStakingContractDuringVesting() public {
        address nonStakingContract = address(0x7);

        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 1_000 * 10 ** 18;

        vm.prank(owner);
        IVesting(vestingContract).createVestingSchedule(user, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 15 days);

        vm.prank(address(vestingContract));
        nexToken.transfer(user, totalAmount);

        vm.prank(user);
        vm.expectRevert("Transfer amount exceeds available balance");
        nexToken.transfer(nonStakingContract, 100 * 10 ** 18);

        vm.prank(user);
        nexToken.transfer(stakingContract, 100 * 10 ** 18);

        assertEq(nexToken.balanceOf(stakingContract), 100 * 10 ** 18);

        assertEq(nexToken.balanceOf(user), totalAmount - 100 * 10 ** 18);
    }

    function testTransferRestrictedByVestingContract() public {
        vm.mockCall(
            vestingContract,
            abi.encodeWithSelector(IVesting.getVestedBalance.selector, user),
            abi.encode(500 * 10 ** 18)
        );

        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert("Transfer amount exceeds available balance");
        nexToken.transfer(address(0x6), 1_000 * 10 ** 18);

        vm.prank(user);
        nexToken.transfer(address(0x6), 500 * 10 ** 18);

        assertEq(nexToken.balanceOf(address(0x6)), 500 * 10 ** 18);
    }

    function testTransferWithNoVestedBalance() public {
        vm.mockCall(vestingContract, abi.encodeWithSelector(IVesting.getVestedBalance.selector, user), abi.encode(0));

        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert("Transfer amount exceeds available balance");
        nexToken.transfer(address(0x6), 1_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(address(0x6)), 0);
    }

    function testInitializationWithInvalidVestingContract() public {
        NEXToken uninitializedToken = new NEXToken();

        address invalidVestingContract = address(0);

        vm.expectRevert("Vesting contract cannot be zero address");
        uninitializedToken.initialize(invalidVestingContract);
    }

    function testTransferBetweenUsersWithoutVesting() public {
        address userA = address(0x10);
        address userB = address(0x11);

        vm.prank(owner);
        nexToken.mint(userA, 1_000 * 10 ** 18);

        uint256 lockedBalance = Vesting(vestingContract).getLockedBalance(userA);
        assertEq(lockedBalance, 0);

        vm.prank(userA);
        nexToken.transfer(userB, 500 * 10 ** 18);

        assertEq(nexToken.balanceOf(userA), 500 * 10 ** 18);
        assertEq(nexToken.balanceOf(userB), 500 * 10 ** 18);
    }

    function testTransferToStakingDuringCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        IVesting(vestingContract).createVestingSchedule(user, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 15 days);

        vm.prank(address(vestingContract));
        nexToken.transfer(user, totalAmount);

        vm.prank(user);
        nexToken.transfer(stakingContract, 50_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(stakingContract), 50_000 * 10 ** 18);
    }

    function testTransferToOthersDuringCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 180 days;
        uint256 totalAmount = 100_000 * 10 ** 18;

        vm.prank(owner);
        IVesting(vestingContract).createVestingSchedule(user, start, cliffDuration, duration, totalAmount);

        vm.warp(start + 15 days);

        vm.prank(address(vestingContract));
        nexToken.transfer(user, totalAmount);

        uint256 userBalance = nexToken.balanceOf(user);
        assertEq(userBalance, totalAmount);

        vm.prank(user);
        vm.expectRevert("Transfer amount exceeds available balance");
        nexToken.transfer(address(0x6), 10_000 * 10 ** 18);
    }
}
