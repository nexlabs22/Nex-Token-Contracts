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

    /**
     * @dev Allows a requester to propose a fund usage request.
     * @param amount The amount of funds requested.
     * @param recipient The address to receive the funds.
     * @param description A description of the fund request.
     */
    function createFundRequest(uint256 amount, address recipient, string calldata description)
        external
        returns (uint256)
    {
        require(recipient != address(0), "Recipient address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory callDatas = new bytes[](1);

        targets[0] = address(this);
        values[0] = 0;
        callDatas[0] = abi.encodeWithSelector(this.executeFundRequest.selector, requestCount);

        (uint256 proposalId) = governance.createProposal(description, targets, values, callDatas);

        fundRequests[requestCount] = FundRequest({
            requestId: requestCount,
            requester: msg.sender,
            amount: amount,
            recipient: recipient,
            executed: false,
            proposalId: proposalId
        });

        emit FundRequestCreated(requestCount, msg.sender, amount, recipient, proposalId);
        requestCount++;

        return proposalId;
    }

    /**
     * @dev Executes an approved fund request.
     * @param requestId The ID of the fund request.
     */
    function executeFundRequest(uint256 requestId) external nonReentrant {
        FundRequest storage request = fundRequests[requestId];
        require(!request.executed, "Request already executed");
        require(request.amount > 0, "Invalid request amount");

        bool isApproved = governance.isProposalApproved(request.proposalId);
        require(isApproved, "Proposal not approved");

        request.executed = true;

        require(token.transfer(request.recipient, request.amount), "Token transfer failed");

        emit FundRequestExecuted(requestId, request.amount, request.recipient);
    }
}
