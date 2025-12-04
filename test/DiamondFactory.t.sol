// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DiamondFactory} from "../src/DiamondFactory.sol";
import {Diamond} from "../src/Diamond.sol";
import {IDigitalWill} from "../src/facets/utilityFacets/digitalWill/IDigitalWill.sol";
import {OwnershipFacet} from "../src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DiamondFactoryTest is Test {
    DiamondFactory factory;
    MockToken token;

    address user1 = address(0x1);
    address user2 = address(0x2);
    address heir = address(0x3);

    event DiamondDeployed(
        address indexed diamond,
        address indexed owner,
        address indexed deployer
    );

    function setUp() public {
        // Deploy factory
        factory = new DiamondFactory();

        // Deploy mock token
        token = new MockToken();
    }

    function testDeployFactory() public view {
        // Verify factory deployed
        assertTrue(address(factory) != address(0), "Factory not deployed");

        // Verify facet implementations exist
        (
            address cutFacet,
            address loupeFacet,
            address ownership,
            address digitalWill
        ) = factory.getFacetImplementations();

        assertTrue(cutFacet != address(0), "DiamondCutFacet not set");
        assertTrue(loupeFacet != address(0), "DiamondLoupeFacet not set");
        assertTrue(ownership != address(0), "OwnershipFacet not set");
        assertTrue(digitalWill != address(0), "DigitalWillFacet not set");
    }

    function testDeployDiamond() public {
        vm.expectEmit(false, true, true, true);
        emit DiamondDeployed(address(0), user1, address(this));

        address diamond = factory.deployDiamond(user1);

        // Verify diamond deployed
        assertTrue(diamond != address(0), "Diamond not deployed");
        assertTrue(factory.isDiamond(diamond), "Diamond not registered");

        // Verify owner
        OwnershipFacet ownership = OwnershipFacet(diamond);
        assertEq(ownership.owner(), user1, "Owner not set correctly");
    }

    function testDeployDiamondForSelf() public {
        vm.prank(user1);
        address diamond = factory.deployDiamondForSelf();

        // Verify ownership
        OwnershipFacet ownership = OwnershipFacet(diamond);
        assertEq(ownership.owner(), user1, "Owner not set to caller");
    }

    function testCannotDeployWithZeroOwner() public {
        vm.expectRevert("DiamondFactory: Invalid owner");
        factory.deployDiamond(address(0));
    }

    function testGetDiamondCount() public {
        assertEq(factory.getDiamondCount(), 0, "Initial count should be 0");

        factory.deployDiamond(user1);
        assertEq(factory.getDiamondCount(), 1, "Count should be 1");

        factory.deployDiamond(user2);
        assertEq(factory.getDiamondCount(), 2, "Count should be 2");
    }

    function testGetAllDiamonds() public {
        address diamond1 = factory.deployDiamond(user1);
        address diamond2 = factory.deployDiamond(user2);

        address[] memory diamonds = factory.getAllDiamonds();

        assertEq(diamonds.length, 2, "Should return 2 diamonds");
        assertEq(diamonds[0], diamond1, "First diamond incorrect");
        assertEq(diamonds[1], diamond2, "Second diamond incorrect");
    }

    function testGetDiamondsForOwner() public {
        address diamond1 = factory.deployDiamond(user1);
        address diamond2 = factory.deployDiamond(user1);
        factory.deployDiamond(user2);

        address[] memory user1Diamonds = factory.getDiamondsForOwner(user1);
        address[] memory user2Diamonds = factory.getDiamondsForOwner(user2);

        assertEq(user1Diamonds.length, 2, "User1 should have 2 diamonds");
        assertEq(user1Diamonds[0], diamond1, "First diamond incorrect");
        assertEq(user1Diamonds[1], diamond2, "Second diamond incorrect");
        assertEq(user2Diamonds.length, 1, "User2 should have 1 diamond");
    }

    function testGetDiamondCountForOwner() public {
        assertEq(
            factory.getDiamondCountForOwner(user1),
            0,
            "Initial count should be 0"
        );

        factory.deployDiamond(user1);
        assertEq(
            factory.getDiamondCountForOwner(user1),
            1,
            "Count should be 1"
        );

        factory.deployDiamond(user1);
        assertEq(
            factory.getDiamondCountForOwner(user1),
            2,
            "Count should be 2"
        );
    }

    function testDeployedDiamondHasDigitalWillFunctionality() public {
        address diamond = factory.deployDiamond(user1);
        IDigitalWill digitalWill = IDigitalWill(diamond);

        // Transfer tokens to user1 and approve diamond
        token.transfer(user1, 1000 * 10 ** 18);

        vm.startPrank(user1);
        token.approve(diamond, 1000 * 10 ** 18);

        // Set will
        digitalWill.setWill(heir, 30 days, address(token), 1000 * 10 ** 18);

        // Verify will status
        (address storedHeir, , ) = digitalWill.getWillStatus(user1);
        assertEq(storedHeir, heir, "Heir not set correctly");

        vm.stopPrank();
    }

    function testDeployedDiamondHasLoupeFunctionality() public {
        address diamond = factory.deployDiamond(user1);
        DiamondLoupeFacet loupe = DiamondLoupeFacet(diamond);

        // Get all facets
        DiamondLoupeFacet.Facet[] memory facets = loupe.facets();

        // Should have 4 facets (Cut, Loupe, Ownership, DigitalWill)
        assertEq(facets.length, 4, "Should have 4 facets");
    }

    function testMultipleUsersDeployDiamonds() public {
        vm.prank(user1);
        address diamond1 = factory.deployDiamondForSelf();

        vm.prank(user2);
        address diamond2 = factory.deployDiamondForSelf();

        // Verify different diamonds
        assertTrue(diamond1 != diamond2, "Diamonds should be different");

        // Verify correct owners
        assertEq(
            OwnershipFacet(diamond1).owner(),
            user1,
            "Diamond1 owner incorrect"
        );
        assertEq(
            OwnershipFacet(diamond2).owner(),
            user2,
            "Diamond2 owner incorrect"
        );
    }
}
