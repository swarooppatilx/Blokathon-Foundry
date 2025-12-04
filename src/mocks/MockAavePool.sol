// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/**
 * @title MockAavePool
 * @notice Simple mock of Aave V3 Pool for local testing
 * @dev This is a minimal implementation for testing purposes only
 */
contract MockAavePool {
    mapping(address => DataTypes.ReserveData) private reserves;
    mapping(address => mapping(address => uint256)) private deposits;

    event Supply(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint16 indexed referralCode
    );

    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Supply tokens to the mock pool
     * @param asset The address of the underlying asset
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Referral code (unused in mock)
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        // Transfer tokens from sender to this pool
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Track the deposit
        deposits[asset][onBehalfOf] += amount;

        emit Supply(asset, msg.sender, onBehalfOf, amount, referralCode);
    }

    /**
     * @notice Withdraw tokens from the mock pool
     * @param asset The address of the underlying asset
     * @param amount The amount to be withdrawn
     * @param to The address that will receive the underlying
     * @return The final amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        require(deposits[asset][msg.sender] >= amount, "Insufficient balance");

        // Update the deposit tracking
        deposits[asset][msg.sender] -= amount;

        // Transfer tokens back
        IERC20(asset).transfer(to, amount);

        emit Withdraw(asset, msg.sender, to, amount);

        return amount;
    }

    /**
     * @notice Get reserve data (mock implementation)
     * @param asset The address of the underlying asset
     * @return The reserve data
     */
    function getReserveData(
        address asset
    ) external view returns (DataTypes.ReserveData memory) {
        // Return mock data - in a real implementation this would have proper aToken address
        DataTypes.ReserveData memory data = reserves[asset];

        // If not initialized, return empty struct
        // In production you'd deploy an aToken and set it here
        return data;
    }

    /**
     * @notice Get the user's deposit balance
     * @param asset The address of the underlying asset
     * @param user The user address
     * @return The user's balance
     */
    function getUserBalance(
        address asset,
        address user
    ) external view returns (uint256) {
        return deposits[asset][user];
    }

    /**
     * @notice Initialize a reserve (for testing)
     * @param asset The address of the underlying asset
     * @param aTokenAddress The address of the corresponding aToken
     */
    function initReserve(address asset, address aTokenAddress) external {
        reserves[asset].aTokenAddress = aTokenAddress;
        reserves[asset].id = uint16(uint160(asset) % type(uint16).max);
    }
}
