# Vesting System using Superfluid Streams

A modular vesting system built on top of Superfluid Protocol that uses NFTs to represent and manage vesting streams.

## Overview

The Superfluid Vesting System allows organizations to create vesting schedules for token distributions using Superfluid's streaming capabilities. Each vesting stream is represented by an NFT, which can be transferred to update the stream recipient.

### Key Features

- Create multiple vesting sessions
- Schedule vesting streams with customizable parameters
- NFT-based vesting rights
- Transferable vesting streams
- Emergency controls for admin
- Metadata support for NFTs

## Architecture

The system consists of three main contracts:

1. **VestingSessionManager**: Creates and manages vesting sessions
   - Creates new vesting factories
   - Manages session state
   - Controls admin access

2. **VestingFactory**: Handles vesting schedules and NFT minting
   - Creates vesting schedules
   - Mints NFTs
   - Manages vesting contracts
   - Handles token transfers

3. **VestingStream**: Manages individual vesting streams
   - Controls Superfluid streams
   - Handles recipient updates
   - Manages emergency functions

## Usage

### Creating a Vesting Session

```solidity
// Deploy session manager
VestingSessionManager sessionManager = new VestingSessionManager(admin);

// Create new session
uint256 sessionId = sessionManager.createSession(
    "Session Name",
    treasury,
    superToken,
    "https://api.example.com/metadata/"
);
```

### Scheduling a Vesting Stream

```solidity
// Get factory from session
VestingFactory factory = VestingFactory(sessionManager.getSessionFactory(sessionId));

// Schedule vesting
uint256 tokenId = factory.scheduleVestingStream(
    recipient,
    flowRate,
    startTime,
    endTime
);

// Fund the vesting
superToken.transfer(address(factory), totalAmount);
```

### Claiming a Vesting Stream

```solidity
// Recipient claims their vesting
factory.claimVestingStream(tokenId);
```

### Transferring a Vesting Stream

```solidity
// Transfer vesting rights to new recipient
factory.transferFrom(currentOwner, newRecipient, tokenId);
```

## Security Features

- Role-based access control
- Emergency withdrawal functionality
- Stream rate validation
- Balance checks
- Time-based restrictions

## Development

### Prerequisites

- Foundry
- Superfluid Protocol Dependencies

### Installation

```bash
forge install
forge compile
```

### Testing

```bash
forge test
```

### Deployment

1. Deploy VestingSessionManager
2. Create sessions as needed
3. Schedule and fund vestings
4. Recipients can claim their vestings

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
