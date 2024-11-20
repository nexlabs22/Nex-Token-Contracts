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

    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event Whitelisted(address indexed account);
    event Unwhitelisted(address indexed account);
    event WhitelistEnabled();
    event WhitelistDisabled();
}
