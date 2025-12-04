// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DigitalWillStorage
    @author BLOK Capital DAO
    @notice Storage library for Digital Will facet using Diamond Storage pattern
    @dev Uses namespaced storage to avoid collisions with other facets

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library DigitalWillStorage {
    /// @notice Unique storage position for Digital Will data
    bytes32 constant STORAGE_POSITION =
        keccak256("blokathon.facets.digitalwill.storage");

    /// @notice Structure representing a user's digital will
    /// @dev Contains heir information and activity tracking
    struct Will {
        address heir; // Address that will inherit assets
        uint256 lastPingTime; // Last time owner proved they're alive
        uint256 inactivityDuration; // Time of inactivity before will activates
        address token; // The ERC20 token to be inherited
        bool isActive; // Whether the will is currently active
    }

    /// @notice Main storage layout for Digital Will facet
    struct Layout {
        mapping(address => Will) wills; // Mapping of owner address to their will
    }

    /// @notice Returns the storage struct from the specified storage slot
    /// @return l The storage layout struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
