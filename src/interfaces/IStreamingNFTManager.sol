// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface IStreamingNFTManager {
    struct Season {
        address factory;
        uint256 timestamp;
        string name;
        bool active;
    }

    error Unauthorized();
    error InvalidParameters();
    error SeasonNotActive();

    event SeasonCreated(uint256 indexed seasonId, string name, address factory);
    event SeasonDeactivated(uint256 indexed seasonId);

    function admin() external view returns (address);

    function seasons(uint256 seasonId) external view returns (Season memory);

    function createSeason(
        string memory name,
        address treasury,
        ISuperToken superToken,
        string memory baseURI
    ) external returns (uint256 seasonId);

    function deactivateSeason(uint256 seasonId) external;

    function getSeason(uint256 seasonId) external view returns (Season memory);

    function getSeasonFactory(uint256 seasonId) external view returns (address);
}
