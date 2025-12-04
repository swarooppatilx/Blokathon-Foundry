// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockAavePool} from "src/mocks/MockAavePool.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployMockAavePool
 * @notice Deploys a mock Aave pool at the expected address for local testing
 * @dev This is for LOCAL TESTING ONLY - do not use in production
 */
contract DeployMockAavePool is Script {
    // The expected Aave V3 Pool address on Arbitrum
    address constant EXPECTED_POOL_ADDRESS =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    function run() external {
        vm.startBroadcast();

        // Check if something already exists at the address
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(EXPECTED_POOL_ADDRESS)
        }

        if (codeSize > 0) {
            console.log("Contract already exists at Aave pool address");
            console.log("Address:", EXPECTED_POOL_ADDRESS);
            vm.stopBroadcast();
            return;
        }

        // Deploy mock pool
        // Note: We can't deploy to a specific address on Anvil without using CREATE2
        // So we'll just deploy normally and the user needs to update the constant
        MockAavePool mockPool = new MockAavePool();

        console.log("===========================================");
        console.log("Mock Aave Pool deployed to:", address(mockPool));
        console.log("===========================================");
        console.log("");
        console.log("To use this mock pool, you need to:");
        console.log("1. Update AaveV3Base.sol constant:");
        console.log(
            "   AAVE_V3_POOL_ADDRESS = address(",
            address(mockPool),
            ");"
        );
        console.log("2. Rebuild contracts: forge build");
        console.log("3. Redeploy Diamond with new Aave facet");
        console.log("");
        console.log("Or better yet, use Arbitrum fork:");
        console.log("   anvil --fork-url https://arb1.arbitrum.io/rpc");

        vm.stopBroadcast();
    }
}
