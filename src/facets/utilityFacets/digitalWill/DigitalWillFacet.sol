// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DigitalWillFacet
    @author BLOK Capital DAO
    @notice Facet for managing digital wills and inheritance in DeFi
    @dev Allows users to designate heirs who can claim assets after inactivity period

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {Facet} from "src/facets/Facet.sol";
import {DigitalWillBase} from "./DigitalWillBase.sol";
import {DigitalWillStorage} from "./DigitalWillStorage.sol";
import {IDigitalWill} from "./IDigitalWill.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DigitalWillFacet is Facet, DigitalWillBase, IDigitalWill {
    using SafeERC20 for IERC20;

    /// @inheritdoc IDigitalWill
    function setWill(
        address heir,
        uint256 inactivityDuration,
        address token,
        uint256 amount
    ) external override {
        // Transfer tokens from user to the diamond
        if (amount > 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        _setWill(msg.sender, heir, inactivityDuration, token);
        emit WillSet(msg.sender, heir, inactivityDuration, token, amount);
    }

    /// @inheritdoc IDigitalWill
    function ping() external override {
        _ping(msg.sender);
        emit Ping(msg.sender, block.timestamp);
    }

    /// @inheritdoc IDigitalWill
    function claimInheritance(address owner) external override {
        // Validate the claim and get the will
        DigitalWillStorage.Will storage will = _validateClaim(
            owner,
            msg.sender
        );

        // Get the token balance held by the diamond
        uint256 balance = IERC20(will.token).balanceOf(address(this));
        require(balance > 0, "No funds to inherit");

        // Transfer tokens to heir
        IERC20(will.token).safeTransfer(msg.sender, balance);

        emit InheritanceClaimed(owner, msg.sender, will.token, balance);
    }

    /// @inheritdoc IDigitalWill
    function getWillStatus(
        address user
    )
        external
        view
        override
        returns (address heir, uint256 lastPing, uint256 timeUntilDeath)
    {
        return _getWillStatus(user);
    }
}
