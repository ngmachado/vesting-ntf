// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* SUP Token Vesting Interfaces */
import {IVestingFactory} from "./interfaces/IVestingFactory.sol";
import {IVesting} from "./interfaces/IVesting.sol";

/**
 * @title Token Vesting Contract
 * @author Superfluid
 * @notice Contract holding unvested tokens and acting as sender for the vesting stream
 */
contract Vesting is IVesting {
    using SuperTokenV1Library for ISuperToken;
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice Vesting Factory contract address
    IVestingFactory public immutable override factory;

    /// @notice SUP Token contract address
    ISuperToken public immutable override superToken;

    /// @notice ERC721 Id
    uint256 public immutable override erc721TokenId;

    error OnlyFactoryOrAdmin();
    error OnlyFactory();

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Creates a new vesting stream contract
     * @param token The SuperToken to be streamed
     * @param _erc721TokenId The NFT token ID associated with this stream
     */
    constructor(ISuperToken token, uint256 _erc721TokenId) {
        superToken = token;
        factory = IVestingFactory(msg.sender);
        erc721TokenId = _erc721TokenId;

        // Grant flow and token allowances to admin
        address admin = factory.admin();
        superToken.setMaxFlowPermissions(admin);
        superToken.approve(admin, type(uint256).max);
    }

    modifier onlyFactoryOrAdmin() {
        if (msg.sender != factory.admin() && msg.sender != address(factory))
            revert OnlyFactoryOrAdmin();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert OnlyFactory();
        _;
    }

    /**
     * @notice Get current recipient from NFT ownership
     */
    function recipient() external view override returns (address) {
        return factory.ownerOf(erc721TokenId);
    }

    /**
     * @notice Get amount of tokens to vest per second
     */
    function amountPerSecond() external view override returns (int96) {
        return factory.getVestingSchedule(erc721TokenId).amountPerSecond;
    }

    /**
     * @notice Opens the stream after funding
     */
    function openStream() external onlyFactory {
        superToken.createFlow(
            factory.ownerOf(erc721TokenId),
            factory.getVestingSchedule(erc721TokenId).amountPerSecond
        );
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/___  ____  _____/ /________  _______/ /_____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Updates the recipient of the vesting stream
     * @param newRecipient The new recipient address
     */
    function updateRecipient(address newRecipient) external onlyFactory {
        int96 flowRate = factory
            .getVestingSchedule(erc721TokenId)
            .amountPerSecond;

        // Close existing stream
        superToken.deleteFlow(address(this), factory.ownerOf(erc721TokenId));

        // Start new stream to new recipient
        superToken.createFlow(newRecipient, flowRate);
    }

    /**
     * @notice Stops the vesting stream and sends remaining tokens to treasury
     */
    function stopStream() external onlyFactoryOrAdmin {
        // Close the flow between this contract and the current recipient
        superToken.deleteFlow(address(this), factory.ownerOf(erc721TokenId));

        // Fetch and transfer remaining balance to treasury
        uint256 remainingBalance = superToken.balanceOf(address(this));
        if (remainingBalance > 0) {
            superToken.transfer(factory.treasury(), remainingBalance);
        }

        emit VestingDeleted(remainingBalance);
    }
}
