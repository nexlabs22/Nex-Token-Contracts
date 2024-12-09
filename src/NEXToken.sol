// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import {IVesting} from "./interfaces/IVesting.sol";

/**
 * @title NEX Token Contract
 * @dev ERC20 token with minimal vesting awareness. Vesting is managed by the Vesting contract.
 */
contract NEXToken is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC20VotesUpgradeable {
    uint256 private constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;

    address public vestingContract;
    address public stakingContract;
    address public treasuryContractAddress;

    // address public constant PUBLIC_SALE = 0xABC; // Replace with actual address
    // address public constant LIQUIDITY_POOL = 0x876; // Replace with actual address

    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _whitelist;

    event StakingContractUpdated(address indexed newStakingContract);
    event VestingContractUpdated(address indexed newVestingContract);
    event TokensBurned(address indexed account, uint256 amount);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event Whitelisted(address indexed account);
    event Unwhitelisted(address indexed account);

    function initialize(address _vestingContract) public initializer {
        require(_vestingContract != address(0), "Vesting contract cannot be zero address");

        __ERC20_init("NEX Token", "NEX");
        __ERC20Votes_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        _mint(address(this), TOTAL_SUPPLY);

        vestingContract = _vestingContract;
        emit VestingContractUpdated(_vestingContract);

        _transfer(address(this), vestingContract, 92_000_000 * 10 ** 18);
        // _transfer(address(this), publicSaleAddress, 3_000_000 * 10 ** 18); // 3%
        // _transfer(address(this), liquidityAddress, 5_000_000 * 10 ** 18); // 5%

        // uint256 remainingBalance = balanceOf(address(this));
        // require(remainingBalance == 0, "All tokens must be distributed");
    }

    /**
     * @dev Mint new tokens.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from the caller's account.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Adds an account to the whitelist.
     * Can only be called by the owner.
     */
    function addToWhitelist(address account) external onlyOwner {
        _whitelist[account] = true;
        emit Whitelisted(account);
    }

    /**
     * @dev Removes an account from the whitelist.
     * Can only be called by the owner.
     */
    function removeFromWhitelist(address account) external onlyOwner {
        _whitelist[account] = false;
        emit Unwhitelisted(account);
    }

    /**
     * @dev Checks if an account is whitelisted.
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _whitelist[account];
    }

    /**
     * @dev Adds an account to the blacklist.
     * Can only be called by the owner.
     */
    function addToBlacklist(address account) external onlyOwner {
        _blacklist[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Removes an account from the blacklist.
     * Can only be called by the owner.
     */
    function removeFromBlacklist(address account) external onlyOwner {
        _blacklist[account] = false;
        emit Unblacklisted(account);
    }

    /**
     * @dev Checks if an account is blacklisted.
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev Set the Treasury Contract address.
     */
    function setTreasuryContract(address _treasuryContract) external onlyOwner {
        require(_treasuryContract != address(0), "Treasury contract cannot be zero address");
        treasuryContractAddress = _treasuryContract;
    }

    /**
     * @dev Set the Staking Contract address.
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Staking contract cannot be zero address");
        stakingContract = _stakingContract;
        emit StakingContractUpdated(_stakingContract);
    }

    /**
     * @dev Overrides the ERC20 _update function to enforce vesting restrictions.
     *      Allows transfers to the staking contract irrespective of vesting.
     * @param from Address tokens are transferred from.
     * @param to Address tokens are transferred to.
     * @param amount Amount of tokens being transferred.
     */
    function _update(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, amount);

        if (from == address(0) || to == address(0)) {
            return;
        }

        if (to == stakingContract) {
            return;
        }

        if (from == address(this) || from == vestingContract) {
            return;
        }

        if (from == treasuryContractAddress) {
            return;
        }

        require(!_blacklist[from] && !_blacklist[to], "Address is blacklisted");

        if (vestingContract != address(0)) {
            IVesting vesting = IVesting(vestingContract);

            uint256 lockedBalance = vesting.getLockedBalance(from);

            uint256 totalBalance = balanceOf(from);

            // uint256 transferableBalance = totalBalance - lockedBalance;

            // Calculate the transferable (vested) balance with underflow protection
            uint256 transferableBalance;
            if (totalBalance > lockedBalance) {
                transferableBalance = totalBalance - lockedBalance;
            } else {
                transferableBalance = 0;
            }

            require(amount <= transferableBalance, "Transfer amount exceeds available balance");
        }
    }

    uint256[50] private __gap;
}
