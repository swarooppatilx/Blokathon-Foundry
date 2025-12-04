// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Diamond} from "../src/Diamond.sol";
import {IDiamondCut} from "../src/facets/baseFacets/cut/IDiamondCut.sol";
import {DiamondCutFacet} from "../src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {DigitalWillFacet} from "../src/facets/utilityFacets/digitalWill/DigitalWillFacet.sol";
import {IDigitalWill} from "../src/facets/utilityFacets/digitalWill/IDigitalWill.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

contract DigitalWillFacetTest is Test {
    Diamond diamond;
    DigitalWillFacet digitalWillFacet;
    IDigitalWill digitalWill;
    MockToken token;

    address owner = address(this);
    address heir = address(0x1);
    address notHeir = address(0x2);
    uint256 inactivityDuration = 30 days;

    event WillSet(
        address indexed user,
        address indexed heir,
        uint256 duration,
        address token,
        uint256 amount
    );
    event Ping(address indexed user, uint256 timestamp);
    event InheritanceClaimed(
        address indexed owner,
        address indexed heir,
        address indexed asset,
        uint256 amount
    );

    function setUp() public {
        // Deploy base facets
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        digitalWillFacet = new DigitalWillFacet();

        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // DiamondCut
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupe
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Ownership
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.owner.selector;
        ownershipSelectors[1] = OwnershipFacet.transferOwnership.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        // DigitalWill
        bytes4[] memory digitalWillSelectors = new bytes4[](4);
        digitalWillSelectors[0] = IDigitalWill.setWill.selector;
        digitalWillSelectors[1] = IDigitalWill.ping.selector;
        digitalWillSelectors[2] = IDigitalWill.claimInheritance.selector;
        digitalWillSelectors[3] = IDigitalWill.getWillStatus.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(digitalWillFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: digitalWillSelectors
        });

        // Deploy Diamond
        diamond = new Diamond(owner, cuts);
        digitalWill = IDigitalWill(address(diamond));

        // Deploy mock token
        token = new MockToken();
    }

    function testSetWill() public {
        uint256 amount = 1000 * 10 ** 18;
        token.approve(address(diamond), amount);

        vm.expectEmit(true, true, false, true);
        emit WillSet(owner, heir, inactivityDuration, address(token), amount);

        digitalWill.setWill(heir, inactivityDuration, address(token), amount);

        (
            address storedHeir,
            uint256 lastPing,
            uint256 timeUntilDeath
        ) = digitalWill.getWillStatus(owner);
        assertEq(storedHeir, heir, "Heir not set correctly");
        assertEq(lastPing, block.timestamp, "Last ping time incorrect");
        assertEq(
            timeUntilDeath,
            inactivityDuration,
            "Time until death incorrect"
        );
    }

    function testCannotSetWillWithZeroAddress() public {
        vm.expectRevert();
        digitalWill.setWill(address(0), inactivityDuration, address(token), 0);
    }

    function testCannotSetWillWithZeroDuration() public {
        vm.expectRevert();
        digitalWill.setWill(heir, 0, address(token), 0);
    }

    function testPing() public {
        digitalWill.setWill(heir, inactivityDuration, address(token), 0);

        vm.warp(block.timestamp + 10 days);

        vm.expectEmit(true, false, false, true);
        emit Ping(owner, block.timestamp);

        digitalWill.ping();

        (, uint256 lastPing, uint256 timeUntilDeath) = digitalWill
            .getWillStatus(owner);
        assertEq(lastPing, block.timestamp, "Last ping not updated");
        assertEq(
            timeUntilDeath,
            inactivityDuration,
            "Time until death not reset"
        );
    }

    function testCannotPingWithoutWill() public {
        vm.expectRevert();
        digitalWill.ping();
    }

    function testClaimInheritance() public {
        // Set up will with token deposit
        uint256 amount = 1000 * 10 ** 18;
        token.approve(address(diamond), amount);
        digitalWill.setWill(heir, inactivityDuration, address(token), amount);

        // Fast forward past inactivity period
        vm.warp(block.timestamp + inactivityDuration + 1);

        // Claim as heir
        vm.prank(heir);
        vm.expectEmit(true, true, true, true);
        emit InheritanceClaimed(owner, heir, address(token), amount);

        digitalWill.claimInheritance(owner);

        assertEq(token.balanceOf(heir), amount, "Heir did not receive tokens");
        assertEq(
            token.balanceOf(address(diamond)),
            0,
            "Diamond still has tokens"
        );
    }

    function testCannotClaimIfNotHeir() public {
        uint256 amount = 1000 * 10 ** 18;
        token.approve(address(diamond), amount);
        digitalWill.setWill(heir, inactivityDuration, address(token), amount);
        vm.warp(block.timestamp + inactivityDuration + 1);

        vm.prank(notHeir);
        vm.expectRevert();
        digitalWill.claimInheritance(owner);
    }

    function testCannotClaimIfOwnerStillActive() public {
        uint256 amount = 1000 * 10 ** 18;
        token.approve(address(diamond), amount);
        digitalWill.setWill(heir, inactivityDuration, address(token), amount);

        // Try to claim before inactivity period
        vm.prank(heir);
        vm.expectRevert();
        digitalWill.claimInheritance(owner);
    }

    function testCannotClaimWithoutWill() public {
        vm.prank(heir);
        vm.expectRevert();
        digitalWill.claimInheritance(owner);
    }

    function testGetWillStatus() public {
        digitalWill.setWill(heir, inactivityDuration, address(token), 0);

        (
            address storedHeir,
            uint256 lastPing,
            uint256 timeUntilDeath
        ) = digitalWill.getWillStatus(owner);

        assertEq(storedHeir, heir, "Heir incorrect");
        assertEq(lastPing, block.timestamp, "Last ping incorrect");
        assertEq(
            timeUntilDeath,
            inactivityDuration,
            "Time until death incorrect"
        );

        // Fast forward halfway
        vm.warp(block.timestamp + inactivityDuration / 2);
        (, , timeUntilDeath) = digitalWill.getWillStatus(owner);
        assertEq(
            timeUntilDeath,
            inactivityDuration / 2,
            "Time until death not decreasing"
        );

        // Fast forward past deadline
        vm.warp(block.timestamp + inactivityDuration);
        (, , timeUntilDeath) = digitalWill.getWillStatus(owner);
        assertEq(timeUntilDeath, 0, "Time should be zero after deadline");
    }

    function testUpdateWill() public {
        // Set initial will
        digitalWill.setWill(heir, inactivityDuration, address(token), 0);

        // Update to new heir
        address newHeir = address(0x3);
        uint256 newDuration = 60 days;
        digitalWill.setWill(newHeir, newDuration, address(token), 0);

        (address storedHeir, , uint256 timeUntilDeath) = digitalWill
            .getWillStatus(owner);
        assertEq(storedHeir, newHeir, "Heir not updated");
        assertEq(timeUntilDeath, newDuration, "Duration not updated");
    }
}
