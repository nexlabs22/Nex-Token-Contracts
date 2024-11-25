// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title NEX Token Contract
 * @dev ERC20 token with minimal vesting awareness. Vesting is managed by the Vesting contract.
 */
contract NEXToken is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    uint256 private constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;

    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public vestingContract; // Address of the Vesting Contract
    address public stakingContract; // Address of the Staking Contract

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
        __ERC20_init("NEX Token", "NEX");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());

        _mint(address(this), TOTAL_SUPPLY);

        vestingContract = _vestingContract;

        _transfer(msg.sender, vestingContract, 92_000_000 * 10 ** 18);
    }

    /**
     * @dev Set the Vesting Contract address.
     */
    function setVestingContract(address _vestingContract) external onlyRole(ADMIN_ROLE) {
        require(_vestingContract != address(0), "Vesting contract cannot be zero address");
        vestingContract = _vestingContract;
        emit VestingContractUpdated(_vestingContract);
    }

    /**
     * @dev Set the Staking Contract address.
     */
    function setStakingContract(address _stakingContract) external onlyRole(ADMIN_ROLE) {
        require(_stakingContract != address(0), "Staking contract cannot be zero address");
        stakingContract = _stakingContract;
        emit StakingContractUpdated(_stakingContract);
    }

    /**
     * @dev Mint new tokens.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
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

    function setupVestingContract(address _vestingContract) external onlyOwner {
        require(_vestingContract != address(0), "Vesting contract cannot be zero address");
        require(vestingContract == address(0), "Vesting contract already set");

        vestingContract = _vestingContract;

        // Transfer 92,000,000 tokens to the vesting contract
        _transfer(address(this), _vestingContract, 92_000_000 * 10 ** 18);

        emit VestingContractUpdated(_vestingContract);
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
     * @dev Overrides the ERC20 _update function to enforce vesting restrictions.
     *      Allows transfers to the staking contract irrespective of vesting.
     * @param from Address tokens are transferred from.
     * @param to Address tokens are transferred to.
     * @param amount Amount of tokens being transferred.
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        super._update(from, to, amount);

        // Allow minting and burning without restrictions
        if (from == address(0) || to == address(0)) {
            return;
        }

        // Allow transfers to the staking contract irrespective of vesting
        if (to == stakingContract) {
            return;
        }

        // Skip checks for transfers from the contract itself
        if (from == address(this)) {
            return;
        }

        // Restrict blacklisted addresses
        require(!_blacklist[from] && !_blacklist[to], "Address is blacklisted");

        // Vesting restriction logic (only if vestingContract is set)
        if (vestingContract != address(0)) {
            IVesting vesting = IVesting(vestingContract);

            uint256 vestedBalance = vesting.getVestedBalance(from);
            require(amount <= vestedBalance, "Transfer amount exceeds vested balance");
        }

        // VestingSchedule storage schedule = vestingSchedules[from];

        // if (schedule.totalAmount > 0) {
        //     uint256 vested = _vestedAmount(schedule);
        //     uint256 released = schedule.amountReleased;
        //     uint256 balance = balanceOf(from);

        //     uint256 transferable = (balance + released) - (schedule.totalAmount - vested);

        //     // Allow the transfer if the amount is less than or equal to transferable tokens
        //     require(amount <= transferable, "Transfer amount exceeds available tokens");
        // }
    }

    uint256[50] private __gap; // Reserve storage gap for future upgrades
}

interface IVesting {
    function getVestedBalance(address account) external view returns (uint256);
}
