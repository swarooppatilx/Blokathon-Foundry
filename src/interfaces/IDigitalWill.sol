// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDigitalWillFacet {
    event WillSet(address indexed user, address indexed heir, uint256 duration);
    event Ping(address indexed user, uint256 timestamp);
    event InheritanceClaimed(address indexed owner, address indexed heir, address asset, uint256 amount);

    function setWill(address _heir, uint256 _inactivityDuration) external;
    function ping() external;
    function claimInheritance(address _owner, address _asset) external;
    function getWillStatus(address _user) external view returns (address heir, uint256 lastPing, uint256 timeUntilDeath);
}