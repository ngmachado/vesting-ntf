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

    /// @notice SUP Vesting Factory contract address
    IVestingFactory public immutable override factory;

    /// @notice Vesting Recipient address
    address public immutable override recipient;

    /// @notice SUP Token contract address
    ISuperToken public immutable override superToken;

    /// @notice Amount of tokens to vest per second
    int96 public immutable override amountPerSecond;

    /// @notice ERC721 Id
    uint256 public immutable override erc721TokenId;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Creates a new vesting stream contract
     * @param token The SuperToken to be streamed
     * @param _recipient The recipient of the stream
     * @param _amountPerSecond The flow rate of tokens per second
     * @param _erc721TokenId The NFT token ID associated with this stream
     */
    constructor(ISuperToken token, address _recipient, int96 _amountPerSecond, uint256 _erc721TokenId) {
        // Persist the admin, recipient, and vesting scheduler addresses
        recipient = _recipient;
        superToken = token;
        factory = IVestingFactory(msg.sender);
        amountPerSecond = _amountPerSecond;
        erc721TokenId = _erc721TokenId;

        // Grant flow and token allowances
        superToken.setMaxFlowPermissions(address(factory));
        superToken.approve(address(factory), type(uint256).max);
    }

    /**
     * @notice Opens the stream after funding
     */
    function openStream() external {
        require(msg.sender == address(factory), "Only factory can open stream");
        require(superToken.balanceOf(address(this)) >= uint256(uint96(amountPerSecond)), "Insufficient balance");

        superToken.createFlow(recipient, amountPerSecond);
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/___  ____  _____/ /________  _______/ /_____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Withdraws remaining tokens in case of emergency
     */
    function emergencyWithdraw() external onlyAdmin {
        // Close the flow between this contract and the recipient
        superToken.deleteFlow(address(this), recipient);

        // Fetch the remaining balance of the vesting contract
        uint256 remainingBalance = superToken.balanceOf(address(this));

        // Transfer the remaining tokens to the treasury
        superToken.transfer(factory.treasury(), remainingBalance);

        // Emit the `VestingDeleted` event
        emit VestingDeleted(remainingBalance);
    }

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @notice Modifier to restrict access to admin only
     */
    modifier onlyAdmin() {
        require(msg.sender == factory.admin() || msg.sender == address(factory), "Only admin or factory");
        _;
    }

    /**
     * @notice Updates the recipient of the vesting stream
     * @param newRecipient The new recipient address
     */
    function updateRecipient(address newRecipient) external {
        require(msg.sender == address(factory), "Only factory can update recipient");

        // Close existing stream
        superToken.deleteFlow(address(this), recipient);

        // Start new stream to new recipient
        superToken.createFlow(newRecipient, amountPerSecond);
    }

    /**
     * @notice Stops the vesting stream and sends remaining tokens to treasury
     */
    function stopStream() external {
        require(msg.sender == address(factory), "Only factory can stop stream");

        // Close the flow between this contract and the recipient
        superToken.deleteFlow(address(this), recipient);

        // Fetch the remaining balance of the vesting contract
        uint256 remainingBalance = superToken.balanceOf(address(this));

        // Transfer the remaining tokens to the treasury
        if (remainingBalance > 0) {
            superToken.transfer(factory.treasury(), remainingBalance);
        }

        emit VestingDeleted(remainingBalance);
    }
}
