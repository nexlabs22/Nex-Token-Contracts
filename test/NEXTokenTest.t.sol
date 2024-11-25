// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/NEXToken.sol";
import "../src/Vesting.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NEXTokenTest is Test {
    NEXToken public nexToken;
    Vesting public vestingContract;
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public user = address(0x3);
    address public stakingContract = address(0x4);

    function setUp() public {
        // Deploy NEXToken and Vesting contracts
        nexToken = new NEXToken();
        vestingContract = new Vesting(IERC20(address(nexToken)));

        // Initialize NEXToken contract
        vm.prank(owner);
        nexToken.initialize();
        vm.prank(owner);
        nexToken.setVestingContract(address(vestingContract));
        vm.prank(owner);
        nexToken.setStakingContract(stakingContract);

        // Grant admin role
        vm.prank(owner);
        nexToken.grantRole(nexToken.ADMIN_ROLE(), admin);

        // // Transfer some tokens to the vesting contract
        // vm.prank(owner);
        // nexToken.transferToVesting(50_000 * 10 ** 18);
    }

    function testMintingAndBurning() public {
        vm.prank(admin);
        nexToken.mint(user, 1_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(user), 1_000 * 10 ** 18);

        vm.prank(user);
        nexToken.burn(500 * 10 ** 18);

        assertEq(nexToken.balanceOf(user), 500 * 10 ** 18);
    }

    function testSetStakingContract() public {
        address newStakingContract = address(0x5);

        vm.prank(admin);
        nexToken.setStakingContract(newStakingContract);

        assertEq(nexToken.stakingContract(), newStakingContract);
    }

    function testWhitelistAndBlacklist() public {
        vm.prank(owner);
        nexToken.addToWhitelist(user);

        assertTrue(nexToken.isWhitelisted(user));

        vm.prank(owner);
        nexToken.removeFromWhitelist(user);

        assertFalse(nexToken.isWhitelisted(user));

        vm.prank(owner);
        nexToken.addToBlacklist(user);

        assertTrue(nexToken.isBlacklisted(user));

        vm.prank(owner);
        nexToken.removeFromBlacklist(user);

        assertFalse(nexToken.isBlacklisted(user));
    }

    function testRestrictedTransfer() public {
        vm.prank(admin);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert("Address is blacklisted");
        nexToken.transfer(address(0x6), 100 * 10 ** 18);

        vm.prank(owner);
        nexToken.addToBlacklist(user);

        vm.prank(user);
        vm.expectRevert("Address is blacklisted");
        nexToken.transfer(address(0x6), 100 * 10 ** 18);
    }

    function testTransferToStakingContract() public {
        vm.prank(admin);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        nexToken.transfer(stakingContract, 1_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(stakingContract), 1_000 * 10 ** 18);
    }
}
