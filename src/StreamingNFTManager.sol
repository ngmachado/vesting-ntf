// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {VestingFactory} from "./VestingFactory.sol";
import {IStreamingNFTManager} from "./interfaces/IStreamingNFTManager.sol";

contract StreamingNFTManager is IStreamingNFTManager {
    /// @notice Admin address
    address public immutable override admin;

    /// @notice Counter for season IDs
    uint256 private _seasonCounter;

    /// @notice Mapping from season ID to season data
    mapping(uint256 => Season) private _seasons;

    constructor(address _admin) {
        if (_admin == address(0)) revert InvalidParameters();
        admin = _admin;
    }

    function createSeason(
        string memory name,
        address treasury,
        ISuperToken superToken,
        string memory baseURI
    ) external override returns (uint256 seasonId) {
        if (msg.sender != admin) revert Unauthorized();

        seasonId = _seasonCounter++;

        // Create new factory for this season
        VestingFactory factory = new VestingFactory(
            admin,
            treasury,
            superToken,
            baseURI
        );

        // Store season data
        _seasons[seasonId] = Season({
            factory: address(factory),
            timestamp: block.timestamp,
            name: name,
            active: true
        });

        emit SeasonCreated(seasonId, name, address(factory));
    }

    function deactivateSeason(uint256 seasonId) external override {
        if (msg.sender != admin) revert Unauthorized();
        Season storage season = _seasons[seasonId];
        season.active = false;
        emit SeasonDeactivated(seasonId);
    }

    function getSeason(
        uint256 seasonId
    ) external view override returns (Season memory) {
        return _seasons[seasonId];
    }

    function seasons(
        uint256 seasonId
    ) external view override returns (Season memory) {
        return _seasons[seasonId];
    }

    function getSeasonFactory(
        uint256 seasonId
    ) external view override returns (address) {
        return _seasons[seasonId].factory;
    }
}
