// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IVestingFactory} from "./IVestingFactory.sol";

interface IVesting {
    // Events
    event VestingDeleted(uint256 remainingBalance);

    // Functions
    function factory() external view returns (IVestingFactory);
    function recipient() external view returns (address);
    function superToken() external view returns (ISuperToken);
    function amountPerSecond() external view returns (int96);
    function erc721TokenId() external view returns (uint256);

    function openStream() external;
    function updateRecipient(address newRecipient) external;
    function emergencyWithdraw() external;
    function stopStream() external;
}
