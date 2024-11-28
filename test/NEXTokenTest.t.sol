// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/NEXToken.sol";
import "../src/Vesting.sol";

contract NEXTokenTest is Test {
    NEXToken public nexToken;
    address public owner = address(0x1);
    address public user = address(0x2);
    address public stakingContract = address(0x3);
    address public vestingContract = address(0x4);

    function setUp() public {
        // Deploy NEXToken contract
        nexToken = new NEXToken();

        // Initialize NEXToken with vesting contract
        vm.prank(owner);
        nexToken.initialize(vestingContract);

        // Set staking contract
        vm.prank(owner);
        nexToken.setStakingContract(stakingContract);
    }

    function testInitialization() public view {
        // Verify total supply is minted
        assertEq(nexToken.totalSupply(), 100_000_000 * 10 ** 18);

        // Verify 92 million tokens are transferred to the vesting contract
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

        // Mint tokens to the user
        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        // Mock the vesting contract to simulate vesting behavior
        vm.mockCall(
            vestingContract,
            abi.encodeWithSelector(IVesting.getVestedBalance.selector, user),
            abi.encode(500 * 10 ** 18) // Only 500 tokens are vested
        );

        // Attempt transfer to a non-staking contract (should revert)
        vm.prank(user);
        vm.expectRevert("Transfer amount exceeds vested balance");
        nexToken.transfer(nonStakingContract, 100 * 10 ** 18);

        // Attempt transfer to the staking contract (should succeed)
        vm.prank(user);
        nexToken.transfer(stakingContract, 100 * 10 ** 18);

        // Validate staking contract received the tokens
        assertEq(nexToken.balanceOf(stakingContract), 100 * 10 ** 18);

        // Validate user balance after successful transfer to staking contract
        assertEq(nexToken.balanceOf(user), 900 * 10 ** 18);

        // Validate non-staking contract balance remains unchanged
        assertEq(nexToken.balanceOf(nonStakingContract), 0);
    }

    function testTransferRestrictedByVestingContract() public {
        // Mock vesting contract to return 500 vested tokens
        vm.mockCall(
            vestingContract,
            abi.encodeWithSelector(IVesting.getVestedBalance.selector, user),
            abi.encode(500 * 10 ** 18)
        );

        vm.prank(owner);
        nexToken.mint(user, 1_000 * 10 ** 18);

        vm.prank(user);
        vm.expectRevert("Transfer amount exceeds vested balance");
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
        vm.expectRevert("Transfer amount exceeds vested balance");
        nexToken.transfer(address(0x6), 1_000 * 10 ** 18);

        assertEq(nexToken.balanceOf(address(0x6)), 0);
    }

    function testInitializationWithInvalidVestingContract() public {
        NEXToken uninitializedToken = new NEXToken();

        address invalidVestingContract = address(0);

        vm.expectRevert("Vesting contract cannot be zero address");
        uninitializedToken.initialize(invalidVestingContract);
    }
}
