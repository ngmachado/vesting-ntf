// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface IVestingFactory {
    error Unauthorized();
    error InvalidParameters();
    error StreamError();
    error BalanceError();

    struct VestingSchedule {
        address originalRecipient;
        uint32 startTime;
        uint32 endTime;
        int96 amountPerSecond;
        bool isExecuted;
        bool active;
    }

    event VestingScheduled(
        uint256 indexed tokenId,
        address indexed originalRecipient,
        int96 amountPerSecond,
        uint32 startTime,
        uint32 endTime
    );

    event VestingExecuted(
        uint256 indexed tokenId,
        address indexed originalRecipient,
        address vestingContract
    );

    event VestingClaimed(
        uint256 indexed tokenId,
        address indexed originalRecipient,
        address vestingContract,
        uint256 totalAmount
    );

    event VestingDirectExecuted(
        uint256 indexed tokenId,
        address indexed originalRecipient,
        address vestingContract
    );

    function admin() external view returns (address);

    function treasury() external view returns (address);

    function superToken() external view returns (ISuperToken);

    function vestingSchedules(
        uint256 tokenId
    ) external view returns (VestingSchedule memory);

    function vestingContracts(uint256 tokenId) external view returns (address);

    function setToken(ISuperToken newToken) external;

    function scheduleVestingStream(
        address recipient,
        int96 amountPerSecond,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 tokenId);

    function claimVestingStream(uint256 tokenId) external;

    function directExecuteVesting(uint256 tokenId) external;

    function setTreasury(address newTreasury) external;

    function setAdmin(address newAdmin) external;

    function getVestingSchedule(
        uint256 tokenId
    ) external view returns (VestingSchedule memory);

    function getVestingContract(
        uint256 tokenId
    ) external view returns (address);

    function setBaseURI(string memory baseURI) external;

    function setTokenURI(uint256 tokenId, string memory tokenURI) external;

    function ownerOf(uint256 tokenId) external view returns (address);
}
