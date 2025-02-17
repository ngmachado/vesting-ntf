// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VestingFactory} from "./VestingFactory.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IVestingSessionManager} from "./interfaces/IVestingSessionManager.sol";

contract VestingSessionManager is IVestingSessionManager {
    // State variables
    address public override admin;
    mapping(uint256 => Session) private _sessions;
    uint256 private _sessionCounter;

    constructor(address _admin) {
        if (_admin == address(0)) revert InvalidParameters();
        admin = _admin;
    }

    /**
     * @notice Create a new vesting session
     */
    function createSession(string memory name, address treasury, ISuperToken superToken, string memory baseURI)
        external
        returns (uint256 sessionId)
    {
        if (msg.sender != admin) revert Unauthorized();
        if (treasury == address(0)) revert InvalidParameters();

        // Deploy new factory
        VestingFactory factory = new VestingFactory(admin, treasury, superToken, baseURI);

        _sessionCounter = _sessionCounter + 1;
        sessionId = _sessionCounter;

        _sessions[sessionId] =
            Session({factory: address(factory), timestamp: block.timestamp, active: true, name: name});

        emit SessionCreated(sessionId, address(factory), name);
        return sessionId;
    }

    /**
     * @notice Deactivate a session
     */
    function deactivateSession(uint256 sessionId) external {
        if (msg.sender != admin) revert Unauthorized();
        Session storage session = _sessions[sessionId];
        if (!session.active) revert SessionNotActive();

        session.active = false;
        emit SessionDeactivated(sessionId);
    }

    /**
     * @notice Get session details from mapping
     */
    function sessions(uint256 sessionId) external view override returns (Session memory) {
        return _sessions[sessionId];
    }

    /**
     * @notice Get session details (alias for sessions)
     */
    function getSession(uint256 sessionId) external view override returns (Session memory) {
        return _sessions[sessionId];
    }

    /**
     * @notice Get factory address for a session
     */
    function getSessionFactory(uint256 sessionId) external view returns (address) {
        return _sessions[sessionId].factory;
    }
}
