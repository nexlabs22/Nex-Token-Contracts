// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NEXToken is ERC20, ERC20Votes, ERC20Permit, Ownable {
    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _whitelist;
    bool private _whitelistEnabled = false;

    mapping(address => bool) private _allowedStakingContracts;
    bool private _transferRestrictionsEnabled = false;

    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event Whitelisted(address indexed account);
    event Unwhitelisted(address indexed account);
    event WhitelistEnabled();
    event WhitelistDisabled();
    event StakingContractAdded(address indexed stakingContract);
    event StakingContractRemoved(address indexed stakingContract);
    event TransferRestrictionsEnabled();
    event TransferRestrictionsDisabled();

    constructor(
        address vestingContractAddress,
        address publicSaleAddress,
        address communityAddress,
        address treasuryAddress,
        address liquidityAddress
    ) ERC20("NEX Token", "NEX") ERC20Permit("NEX Token") Ownable(msg.sender) {
        uint256 initialSupply = 100_000_000 * 10 ** decimals();

        _mint(address(this), initialSupply);

        _transfer(address(this), vestingContractAddress, 78_000_000 * 10 ** decimals());
        _transfer(address(this), publicSaleAddress, 3_000_000 * 10 ** decimals());

        _transfer(address(this), communityAddress, 10_000_000 * 10 ** decimals());
        _transfer(address(this), treasuryAddress, 14_000_000 * 10 ** decimals());
        _transfer(address(this), liquidityAddress, 5_000_000 * 10 ** decimals());
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

    // Whitelist functions

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
     * @dev Enables the whitelist restriction.
     * Can only be called by the owner.
     */
    function enableWhitelist() external onlyOwner {
        _whitelistEnabled = true;
        emit WhitelistEnabled();
    }

    /**
     * @dev Disables the whitelist restriction.
     * Can only be called by the owner.
     */
    function disableWhitelist() external onlyOwner {
        _whitelistEnabled = false;
        emit WhitelistDisabled();
    }

    /**
     * @dev Checks if the whitelist is enabled.
     */
    function isWhitelistEnabled() external view returns (bool) {
        return _whitelistEnabled;
    }

    /**
     * @dev Adds an address to the allowed staking contracts.
     * Can only be called by the owner.
     */
    function addAllowedStakingContract(address stakingContract) external onlyOwner {
        _allowedStakingContracts[stakingContract] = true;
        emit StakingContractAdded(stakingContract);
    }

    /**
     * @dev Removes an address from the allowed staking contracts.
     * Can only be called by the owner.
     */
    function removeAllowedStakingContract(address stakingContract) external onlyOwner {
        _allowedStakingContracts[stakingContract] = false;
        emit StakingContractRemoved(stakingContract);
    }

    /**
     * @dev Checks if an address is an allowed staking contract.
     */
    function isAllowedStakingContract(address stakingContract) external view returns (bool) {
        return _allowedStakingContracts[stakingContract];
    }

    /**
     * @dev Enables transfer restrictions during cliff/vesting periods.
     * Can only be called by the owner.
     */
    function enableTransferRestrictions() external onlyOwner {
        _transferRestrictionsEnabled = true;
        emit TransferRestrictionsEnabled();
    }

    /**
     * @dev Disables transfer restrictions.
     * Can only be called by the owner.
     */
    function disableTransferRestrictions() external onlyOwner {
        _transferRestrictionsEnabled = false;
        emit TransferRestrictionsDisabled();
    }

    /**
     * @dev Checks if transfer restrictions are enabled.
     */
    function areTransferRestrictionsEnabled() external view returns (bool) {
        return _transferRestrictionsEnabled;
    }

    /**
     * @dev Mints new tokens to a specified address.
     * Can only be called by the owner.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Buyback and Burn function (Deflationary Mechanism)

    /**
     * @dev Burns tokens from the contract balance, implementing buyback and burn.
     * Can only be called by the owner.
     */
    function buybackAndBurn(uint256 amount) external onlyOwner {
        _burn(address(this), amount);
    }

    // The functions below are overrides required by Solidity for ERC20Votes

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        // Blacklist checks
        require(!_blacklist[from], "Sender is blacklisted");
        require(!_blacklist[to], "Recipient is blacklisted");

        // Whitelist checks (when enabled)
        if (_whitelistEnabled) {
            // Allow minting and burning even when whitelist is enabled
            if (from != address(0) && to != address(0)) {
                require(_whitelist[from], "Sender is not whitelisted");
                require(_whitelist[to], "Recipient is not whitelisted");
            }
        }

        // Transfer restrictions during cliff/vesting periods
        if (_transferRestrictionsEnabled) {
            // Allow transfers to allowed staking contracts
            if (!_allowedStakingContracts[to]) {
                require(from == address(0) || to == address(0), "Transfers restricted during cliff/vesting period");
            }
        }

        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
