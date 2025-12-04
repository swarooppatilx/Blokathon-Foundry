// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DigitalWillBase
    @author BLOK Capital DAO
    @notice Base contract containing internal logic for Digital Will functionality
    @dev Inheriting contracts can use these internal functions for will management

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {DigitalWillStorage} from "./DigitalWillStorage.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when heir address is zero
error DigitalWill_InvalidHeir();

/// @notice Thrown when inactivity duration is zero
error DigitalWill_InvalidDuration();

/// @notice Thrown when will is not active
error DigitalWill_WillNotActive();

/// @notice Thrown when caller is not the designated heir
error DigitalWill_NotTheHeir();

/// @notice Thrown when owner is still active
error DigitalWill_OwnerStillActive();

/// @notice Thrown when will does not exist
error DigitalWill_WillDoesNotExist();

contract DigitalWillBase {
    /// @notice Internal function to set up a will
    /// @param user The address setting up the will
    /// @param heir The designated heir
    /// @param inactivityDuration The inactivity period before activation
    /// @param token The token address to be inherited
    function _setWill(
        address user,
        address heir,
        uint256 inactivityDuration,
        address token
    ) internal {
        if (heir == address(0)) revert DigitalWill_InvalidHeir();
        if (inactivityDuration == 0) revert DigitalWill_InvalidDuration();
        if (token == address(0)) revert DigitalWill_InvalidHeir(); // Reuse error for simplicity

        DigitalWillStorage.Will storage will = DigitalWillStorage
            .layout()
            .wills[user];
        will.heir = heir;
        will.inactivityDuration = inactivityDuration;
        will.token = token;
        will.lastPingTime = block.timestamp;
        will.isActive = true;
    }

    /// @notice Internal function to update last ping time
    /// @param user The address pinging
    function _ping(address user) internal {
        DigitalWillStorage.Will storage will = DigitalWillStorage
            .layout()
            .wills[user];
        if (!will.isActive) revert DigitalWill_WillNotActive();
        will.lastPingTime = block.timestamp;
    }

    /// @notice Internal function to validate inheritance claim
    /// @param owner The owner address
    /// @param heir The heir attempting to claim
    /// @return The will struct if valid
    function _validateClaim(
        address owner,
        address heir
    ) internal view returns (DigitalWillStorage.Will storage) {
        DigitalWillStorage.Will storage will = DigitalWillStorage
            .layout()
            .wills[owner];

        if (!will.isActive) revert DigitalWill_WillDoesNotExist();
        if (heir != will.heir) revert DigitalWill_NotTheHeir();
        if (block.timestamp <= will.lastPingTime + will.inactivityDuration) {
            revert DigitalWill_OwnerStillActive();
        }

        return will;
    }

    /// @notice Internal function to get will status
    /// @param user The user address to query
    /// @return heir The designated heir
    /// @return lastPing The last ping timestamp
    /// @return timeUntilDeath Time until will activates
    function _getWillStatus(
        address user
    )
        internal
        view
        returns (address heir, uint256 lastPing, uint256 timeUntilDeath)
    {
        DigitalWillStorage.Will storage will = DigitalWillStorage
            .layout()
            .wills[user];
        heir = will.heir;
        lastPing = will.lastPingTime;

        uint256 deathTime = will.lastPingTime + will.inactivityDuration;
        if (block.timestamp >= deathTime || !will.isActive) {
            timeUntilDeath = 0;
        } else {
            timeUntilDeath = deathTime - block.timestamp;
        }
    }
}
