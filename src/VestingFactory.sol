// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

import {Vesting} from "./VestingStream.sol";
import {IVestingFactory} from "./interfaces/IVestingFactory.sol";

/**
 * @title Vesting Factory Contract
 * @author Superfluid
 * @notice Factory contract for creating new vesting streams, represented as NFTs
 */
contract VestingFactory is IVestingFactory, ERC721, ERC721URIStorage {
    using SuperTokenV1Library for ISuperToken;

    /// @notice Counter for NFT token IDs
    uint256 private _tokenIdCounter;

    /// @notice Admin address that can create new vesting streams and perform emergency actions
    address public override admin;

    /// @notice Treasury address where emergency withdrawn funds are sent
    address public override treasury;

    /// @notice The SuperToken used for all vesting streams
    ISuperToken public override superToken;

    /// @notice Mapping from token ID to vesting schedule
    mapping(uint256 => VestingSchedule) private _vestingSchedules;

    /// @notice Mapping from token ID to vesting contract address
    mapping(uint256 => address) public vestingContracts;

    /// @notice Base URI for all token metadata
    string private _baseURIStorage;

    constructor(
        address _admin,
        address _treasury,
        ISuperToken _superToken,
        string memory baseURI
    ) ERC721("Vesting NFT - Session 1", "VEST-NFT-SESSION-1") {
        if (
            _admin == address(0) ||
            _treasury == address(0) ||
            address(_superToken) == address(0)
        ) {
            revert InvalidParameters();
        }
        admin = _admin;
        treasury = _treasury;
        superToken = _superToken;
        _baseURIStorage = baseURI;
    }

    /**
     * @notice Updates the token address
     * @param newToken The new token address
     */
    function setToken(ISuperToken newToken) external {
        if (msg.sender != admin) revert Unauthorized();
        if (address(newToken) == address(0)) revert InvalidParameters();
        superToken = newToken;
    }

    /**
     * @notice Schedules a new vesting stream to be claimed later
     * @param recipient The recipient of the vesting stream
     * @param amountPerSecond The amount of tokens to vest per second
     * @param startTime The timestamp when vesting begins
     * @param endTime The timestamp when vesting ends
     * @return tokenId The ID of the scheduled vesting
     */
    function scheduleVestingStream(
        address recipient,
        int96 amountPerSecond,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 tokenId) {
        if (msg.sender != admin) revert Unauthorized();
        if (recipient == address(0) || amountPerSecond <= 0) {
            revert InvalidParameters();
        }
        if (endTime <= startTime || startTime < block.timestamp) {
            revert InvalidParameters();
        }

        tokenId = _tokenIdCounter++;

        _vestingSchedules[tokenId] = VestingSchedule({
            originalRecipient: recipient,
            startTime: startTime,
            endTime: endTime,
            amountPerSecond: amountPerSecond,
            isExecuted: false,
            active: true
        });

        emit VestingScheduled(
            tokenId,
            recipient,
            amountPerSecond,
            startTime,
            endTime
        );
    }

    /**
     * @notice Claims a scheduled vesting stream and starts the token flow
     * @param tokenId The ID of the scheduled vesting
     */
    function claimVestingStream(uint256 tokenId) external {
        VestingSchedule storage schedule = _vestingSchedules[tokenId];
        if (!schedule.active) revert StreamError();
        if (schedule.isExecuted) revert StreamError();
        if (block.timestamp < schedule.startTime) revert StreamError();
        if (msg.sender != schedule.originalRecipient) revert Unauthorized();

        uint256 totalAmount = uint256(uint96(schedule.amountPerSecond)) *
            uint256(schedule.endTime - schedule.startTime);

        if (superToken.balanceOf(address(this)) < totalAmount) {
            revert BalanceError();
        }

        // Create new vesting contract
        Vesting vestingContract = new Vesting(superToken, tokenId);

        vestingContracts[tokenId] = address(vestingContract);

        superToken.transfer(address(vestingContract), totalAmount);

        _mint(schedule.originalRecipient, tokenId);

        schedule.isExecuted = true;

        vestingContract.openStream();

        emit VestingClaimed(
            tokenId,
            schedule.originalRecipient,
            address(vestingContract),
            totalAmount
        );
    }

    /**
     * @notice Allows admin to directly execute a vesting stream without recipient claiming
     * @param tokenId The ID of the scheduled vesting
     */
    function directExecuteVesting(uint256 tokenId) external {
        if (msg.sender != admin) revert Unauthorized();
        VestingSchedule storage schedule = _vestingSchedules[tokenId];
        if (!schedule.active) revert StreamError();
        if (schedule.isExecuted) revert StreamError();

        address existingContract = vestingContracts[tokenId];
        if (existingContract != address(0)) {
            // Stop existing stream if any
            Vesting(existingContract).stopStream();
        }

        // Create new vesting contract
        Vesting vestingContract = new Vesting(superToken, tokenId);

        // Store vesting contract address
        vestingContracts[tokenId] = address(vestingContract);

        // Mark as executed
        schedule.isExecuted = true;

        // Mint NFT to recipient
        _mint(schedule.originalRecipient, tokenId);

        emit VestingDirectExecuted(
            tokenId,
            schedule.originalRecipient,
            address(vestingContract)
        );
    }

    /**
     * @notice Updates the treasury address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external {
        if (msg.sender != admin) revert Unauthorized();
        if (newTreasury == address(0)) revert InvalidParameters();
        treasury = newTreasury;
    }

    /**
     * @notice Updates the admin address
     * @param newAdmin The new admin address
     */
    function setAdmin(address newAdmin) external {
        if (msg.sender != admin) revert Unauthorized();
        if (newAdmin == address(0)) revert InvalidParameters();
        admin = newAdmin;
    }

    /**
     * @notice Get vesting schedule from mapping
     */
    function vestingSchedules(
        uint256 tokenId
    ) external view override returns (VestingSchedule memory) {
        return _vestingSchedules[tokenId];
    }

    /**
     * @notice Gets the vesting schedule for a given token ID
     * @param tokenId The NFT token ID
     * @return The vesting schedule details
     */
    function getVestingSchedule(
        uint256 tokenId
    ) external view override returns (VestingSchedule memory) {
        return _vestingSchedules[tokenId];
    }

    /**
     * @notice Gets the vesting contract address for a given token ID
     * @param tokenId The NFT token ID
     * @return The vesting contract address
     */
    function getVestingContract(
        uint256 tokenId
    ) external view returns (address) {
        return vestingContracts[tokenId];
    }

    /**
     * @notice Hook that is called before any token transfer
     * @dev Updates the vesting recipient when NFT is transferred or stops stream when burned
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 /* batchSize */
    ) internal override {
        if (from != address(0)) {
            // Skip for minting
            VestingSchedule storage schedule = _vestingSchedules[tokenId];
            address vestingContract = vestingContracts[tokenId];

            if (schedule.active && schedule.isExecuted) {
                if (to == address(0)) {
                    // Burning - stop stream and mark as inactive
                    Vesting(vestingContract).stopStream();
                    schedule.active = false;
                } else {
                    // Update recipient in vesting contract
                    Vesting(vestingContract).updateRecipient(to);
                }
            }
        }
    }

    /**
     * @notice Set the base URI for all token metadata
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external {
        if (msg.sender != admin) revert Unauthorized();
        _baseURIStorage = baseURI;
    }

    /**
     * @notice Set the URI for a specific token
     * @param tokenId Token ID to set URI for
     * @param uri New token URI
     */
    function setTokenURI(uint256 tokenId, string memory uri) external {
        if (msg.sender != admin) revert Unauthorized();
        _setTokenURI(tokenId, uri);
    }

    // Override required functions
    function _baseURI() internal view override returns (string memory) {
        return _baseURIStorage;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function ownerOf(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721, IERC721, IVestingFactory)
        returns (address)
    {
        return super.ownerOf(tokenId);
    }
}
