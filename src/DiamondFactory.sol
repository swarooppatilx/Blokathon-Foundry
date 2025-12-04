// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DiamondFactory
    @author BLOK Capital DAO
    @notice Factory contract for deploying Diamond proxy instances with standard facets
    @dev Deploys pre-configured Diamond instances with DiamondCut, Loupe, Ownership, and DigitalWill facets

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {Diamond} from "./Diamond.sol";
import {IDiamondCut} from "./facets/baseFacets/cut/IDiamondCut.sol";
import {DiamondCutFacet} from "./facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "./facets/baseFacets/ownership/OwnershipFacet.sol";
import {DigitalWillFacet} from "./facets/utilityFacets/digitalWill/DigitalWillFacet.sol";
import {IDigitalWill} from "./facets/utilityFacets/digitalWill/IDigitalWill.sol";

contract DiamondFactory {
    // ============================================================================
    // Events
    // ============================================================================

    /// @notice Emitted when a new Diamond is deployed
    /// @param diamond The address of the deployed Diamond
    /// @param owner The owner of the Diamond
    /// @param deployer The address that deployed the Diamond
    event DiamondDeployed(
        address indexed diamond,
        address indexed owner,
        address indexed deployer
    );

    // ============================================================================
    // State Variables
    // ============================================================================

    /// @notice Base implementation addresses for facets
    address public immutable diamondCutFacet;
    address public immutable diamondLoupeFacet;
    address public immutable ownershipFacet;
    address public immutable digitalWillFacet;

    /// @notice Array of all deployed diamonds
    address[] public deployedDiamonds;

    /// @notice Mapping to check if an address is a deployed diamond
    mapping(address => bool) public isDiamond;

    /// @notice Mapping from owner to their diamonds
    mapping(address => address[]) public ownerDiamonds;

    // ============================================================================
    // Constructor
    // ============================================================================

    /// @notice Deploy the factory and create base facet implementations
    constructor() {
        // Deploy base facet implementations
        diamondCutFacet = address(new DiamondCutFacet());
        diamondLoupeFacet = address(new DiamondLoupeFacet());
        ownershipFacet = address(new OwnershipFacet());
        digitalWillFacet = address(new DigitalWillFacet());
    }

    // ============================================================================
    // External Functions
    // ============================================================================

    /// @notice Deploy a new Diamond with standard facets
    /// @param owner The owner of the new Diamond
    /// @return diamond The address of the deployed Diamond
    function deployDiamond(address owner) public returns (address diamond) {
        require(owner != address(0), "DiamondFactory: Invalid owner");

        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // DiamondCut facet
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupe facet
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Ownership facet
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.owner.selector;
        ownershipSelectors[1] = OwnershipFacet.transferOwnership.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        // DigitalWill facet
        bytes4[] memory digitalWillSelectors = new bytes4[](4);
        digitalWillSelectors[0] = IDigitalWill.setWill.selector;
        digitalWillSelectors[1] = IDigitalWill.ping.selector;
        digitalWillSelectors[2] = IDigitalWill.claimInheritance.selector;
        digitalWillSelectors[3] = IDigitalWill.getWillStatus.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: digitalWillFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: digitalWillSelectors
        });

        // Deploy the Diamond
        diamond = address(new Diamond(owner, cuts));

        // Record deployment
        deployedDiamonds.push(diamond);
        isDiamond[diamond] = true;
        ownerDiamonds[owner].push(diamond);

        emit DiamondDeployed(diamond, owner, msg.sender);
    }

    /// @notice Deploy a new Diamond for the caller
    /// @return diamond The address of the deployed Diamond
    function deployDiamondForSelf() external returns (address diamond) {
        return deployDiamond(msg.sender);
    }

    // ============================================================================
    // View Functions
    // ============================================================================

    /// @notice Get the total number of deployed diamonds
    /// @return The count of deployed diamonds
    function getDiamondCount() external view returns (uint256) {
        return deployedDiamonds.length;
    }

    /// @notice Get all deployed diamond addresses
    /// @return Array of diamond addresses
    function getAllDiamonds() external view returns (address[] memory) {
        return deployedDiamonds;
    }

    /// @notice Get diamonds owned by a specific address
    /// @param owner The owner address
    /// @return Array of diamond addresses owned by the address
    function getDiamondsForOwner(
        address owner
    ) external view returns (address[] memory) {
        return ownerDiamonds[owner];
    }

    /// @notice Get the count of diamonds owned by an address
    /// @param owner The owner address
    /// @return The count of diamonds owned
    function getDiamondCountForOwner(
        address owner
    ) external view returns (uint256) {
        return ownerDiamonds[owner].length;
    }

    /// @notice Get facet implementation addresses
    /// @return cutFacet Address of DiamondCutFacet
    /// @return loupeFacet Address of DiamondLoupeFacet
    /// @return ownership Address of OwnershipFacet
    /// @return digitalWill Address of DigitalWillFacet
    function getFacetImplementations()
        external
        view
        returns (
            address cutFacet,
            address loupeFacet,
            address ownership,
            address digitalWill
        )
    {
        return (
            diamondCutFacet,
            diamondLoupeFacet,
            ownershipFacet,
            digitalWillFacet
        );
    }
}
