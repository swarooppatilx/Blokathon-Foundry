// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {DiamondFactory} from "../src/DiamondFactory.sol";

contract DeployFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory
        DiamondFactory factory = new DiamondFactory();

        console.log("DiamondFactory deployed to: ", address(factory));

        // Log facet implementations
        (
            address cutFacet,
            address loupeFacet,
            address ownership,
            address digitalWill
        ) = factory.getFacetImplementations();

        console.log("DiamondCutFacet: ", cutFacet);
        console.log("DiamondLoupeFacet: ", loupeFacet);
        console.log("OwnershipFacet: ", ownership);
        console.log("DigitalWillFacet: ", digitalWill);

        vm.stopBroadcast();
    }
}
