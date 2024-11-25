// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vesting is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    IERC20 public immutable token;

    struct VestingSchedule {
        bool initialized;
        address beneficiary;
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 totalAmount;
        uint256 released;
    }

    mapping(address => VestingSchedule[]) public vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount);

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = _token;
    }

    /**
     * @dev Create a vesting schedule for a beneficiary.
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 totalAmount
    ) external onlyOwner {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(duration > 0, "Duration must be > 0");
        require(totalAmount > 0, "Total amount must be > 0");
        require(duration >= cliffDuration, "Duration must be >= cliff duration");
        require(token.balanceOf(address(this)) >= totalAmount, "Insufficient tokens in contract");

        vestingSchedules[beneficiary].push(
            VestingSchedule({
                initialized: true,
                beneficiary: beneficiary,
                cliff: start + cliffDuration,
                start: start,
                duration: duration,
                totalAmount: totalAmount,
                released: 0
            })
        );

        emit VestingScheduleCreated(beneficiary, totalAmount);
    }

    /**
     * @dev Release vested tokens for the caller.
     */
    function release(uint256 scheduleIndex) external nonReentrant {
        require(scheduleIndex < vestingSchedules[msg.sender].length, "Invalid schedule index");
        VestingSchedule storage schedule = vestingSchedules[msg.sender][scheduleIndex];
        require(schedule.initialized, "No vesting schedule");
        require(block.timestamp >= schedule.cliff, "Cliff period not reached");

        uint256 vestedAmount = _vestedAmount(schedule);
        uint256 unreleased = vestedAmount - schedule.released;

        require(unreleased > 0, "No tokens to release");

        // Effects
        schedule.released += unreleased;

        // Interactions
        require(token.transfer(msg.sender, unreleased), "Token transfer failed");

        emit TokensReleased(msg.sender, unreleased);
    }

    /**
     * @dev Calculate the vested amount for a given schedule.
     */
    function _vestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.cliff) {
            return 0;
        } else if (currentTime >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            uint256 timeElapsed = currentTime - schedule.start;
            return (schedule.totalAmount * timeElapsed) / schedule.duration;
        }
    }

    /**
     * @dev Retrieve details of a specific vesting schedule.
     */
    function getVestingSchedule(address beneficiary, uint256 scheduleIndex)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[beneficiary][scheduleIndex];
    }

    /**
     * @dev Return the count of vesting schedules for a beneficiary.
     */
    function getVestingScheduleCount(address beneficiary) external view returns (uint256) {
        return vestingSchedules[beneficiary].length;
    }

    function getVestedBalance(address account) external view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < vestingSchedules[account].length; i++) {
            VestingSchedule memory schedule = vestingSchedules[account][i];
            uint256 vested = _vestedAmount(schedule);
            totalBalance += vested - schedule.released;
        }
        return totalBalance;
    }
}
