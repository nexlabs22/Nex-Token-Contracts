// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGovernance} from "./interfaces/IGovernance.sol";

/**
 * @title Treasury Contract
 * @dev Allows governance token holders to control a community treasury, approving or rejecting the use of funds.
 */
contract Treasury is Initializable, ReentrancyGuardUpgradeable {
    IERC20 public token;
    IGovernance public governance;

    struct FundRequest {
        uint256 requestId;
        address requester;
        uint256 amount;
        address recipient;
        bool executed;
        uint256 proposalId;
    }

    uint256 public requestCount;
    mapping(uint256 => FundRequest) public fundRequests;

    event FundRequestCreated(
        uint256 indexed requestId, address indexed requester, uint256 amount, address recipient, uint256 proposalId
    );
    event FundRequestExecuted(uint256 indexed requestId, uint256 amount, address recipient);

    /**
     * @dev Initializes the contract with the token and governance contract addresses.
     */
    function initialize(address _token, address _governanceContract) external initializer {
        __ReentrancyGuard_init();

        require(_token != address(0), "Token address cannot be zero");
        require(_governanceContract != address(0), "Governance contract address cannot be zero");

        token = IERC20(_token);
        governance = IGovernance(_governanceContract);
    }
}
