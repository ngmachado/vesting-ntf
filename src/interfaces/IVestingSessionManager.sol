// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface IVestingSessionManager {
    // Structs
    struct Session {
        address factory;
        uint256 timestamp;
        bool active;
        string name;
    }

    // Events
    event SessionCreated(uint256 indexed sessionId, address factory, string name);
    event SessionDeactivated(uint256 indexed sessionId);

    // Errors
    error Unauthorized();
    error InvalidParameters();
    error SessionNotActive();

    // Functions
    function admin() external view returns (address);

    function sessions(uint256 sessionId) external view returns (Session memory);

    function createSession(string memory name, address treasury, ISuperToken superToken, string memory baseURI)
        external
        returns (uint256 sessionId);

    function deactivateSession(uint256 sessionId) external;

    function getSession(uint256 sessionId) external view returns (Session memory);

    function getSessionFactory(uint256 sessionId) external view returns (address);
}
