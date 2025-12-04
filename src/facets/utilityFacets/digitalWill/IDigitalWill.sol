// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title IDigitalWill
    @author BLOK Capital DAO
    @notice Interface for Digital Will functionality
    @dev Allows users to set up inheritance plans for their crypto assets

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IDigitalWill {
    // ============================================================================
    // Events
    // ============================================================================

    /// @notice Emitted when a user sets up their digital will
    /// @param user The address of the will creator
    /// @param heir The address of the designated heir
    /// @param duration The inactivity period before will activates
    /// @param token The token address to be inherited
    /// @param amount The amount of tokens deposited
    event WillSet(
        address indexed user,
        address indexed heir,
        uint256 duration,
        address token,
        uint256 amount
    );

    /// @notice Emitted when a user pings to prove they're still active
    /// @param user The address of the user
    /// @param timestamp The time of the ping
    event Ping(address indexed user, uint256 timestamp);

    /// @notice Emitted when an heir successfully claims inheritance
    /// @param owner The address of the deceased owner
    /// @param heir The address of the heir claiming assets
    /// @param asset The token address being inherited
    /// @param amount The amount of tokens inherited
    event InheritanceClaimed(
        address indexed owner,
        address indexed heir,
        address indexed asset,
        uint256 amount
    );

    // ============================================================================
    // Functions
    // ============================================================================

    /// @notice Set up or update a digital will
    /// @param heir The address that will inherit your assets
    /// @param inactivityDuration Time in seconds before will activates
    /// @param token The ERC20 token address to deposit
    /// @param amount The amount of tokens to deposit for inheritance
    function setWill(
        address heir,
        uint256 inactivityDuration,
        address token,
        uint256 amount
    ) external;

    /// @notice Ping to prove you're still active and reset the inactivity timer
    function ping() external;

    /// @notice Claim inheritance from an inactive owner
    /// @param owner The address of the inactive owner
    function claimInheritance(address owner) external;

    /// @notice Get the status of a user's will
    /// @param user The address to query
    /// @return heir The designated heir address
    /// @return lastPing The timestamp of the last ping
    /// @return timeUntilDeath Time remaining before will activates (0 if already active)
    function getWillStatus(
        address user
    )
        external
        view
        returns (address heir, uint256 lastPing, uint256 timeUntilDeath);
}
