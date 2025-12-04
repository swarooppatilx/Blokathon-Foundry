//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Diamond} from "src/Diamond.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {IDiamondLoupe} from "src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {IERC165} from "src/interfaces/IERC165.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {DigitalWillFacet} from "src/facets/utilityFacets/digitalWill/DigitalWillFacet.sol";
import {IDigitalWill} from "src/facets/utilityFacets/digitalWill/IDigitalWill.sol";

import {BaseScript} from "./Base.s.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is BaseScript {
    function run() public broadcaster {
        setUp();
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        DigitalWillFacet digitalWillFacet = new DigitalWillFacet();
        console.log("DiamondCutFacet deployed to: ", address(diamondCutFacet));
        console.log(
            "DiamondLoupeFacet deployed to: ",
            address(diamondLoupeFacet)
        );
        console.log("OwnershipFacet deployed to: ", address(ownershipFacet));
        console.log(
            "DigitalWillFacet deployed to: ",
            address(digitalWillFacet)
        );
        IDiamondCut.FacetCut[] memory _facetCuts = new IDiamondCut.FacetCut[](
            4
        );
        bytes4[] memory cutFunctionSelectors = new bytes4[](1);
        cutFunctionSelectors[0] = IDiamondCut.diamondCut.selector;
        _facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutFunctionSelectors
        });
        bytes4[] memory loupeFunctionSelectors = new bytes4[](5);
        loupeFunctionSelectors[0] = IDiamondLoupe.facets.selector;
        loupeFunctionSelectors[1] = IDiamondLoupe
            .facetFunctionSelectors
            .selector;
        loupeFunctionSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeFunctionSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeFunctionSelectors[4] = IERC165.supportsInterface.selector;

        _facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeFunctionSelectors
        });
        bytes4[] memory ownershipFunctionSelectors = new bytes4[](2);
        ownershipFunctionSelectors[0] = IERC173.owner.selector;
        ownershipFunctionSelectors[1] = IERC173.transferOwnership.selector;
        _facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipFunctionSelectors
        });
        bytes4[] memory digitalWillFunctionSelectors = new bytes4[](4);
        digitalWillFunctionSelectors[0] = IDigitalWill.setWill.selector;
        digitalWillFunctionSelectors[1] = IDigitalWill.ping.selector;
        digitalWillFunctionSelectors[2] = IDigitalWill
            .claimInheritance
            .selector;
        digitalWillFunctionSelectors[3] = IDigitalWill.getWillStatus.selector;
        _facetCuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(digitalWillFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: digitalWillFunctionSelectors
        });
        Diamond diamond = new Diamond(deployer, _facetCuts);
        console.log("Diamond deployed to: ", address(diamond));
    }
}
