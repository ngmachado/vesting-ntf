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


## Contract Architecture

### StreamingNFTManager
- Creates and manages different streaming seasons
- Each season has its own VestingFactory
- Controls season activation/deactivation

### VestingFactory
- ERC721 contract that mints streaming NFTs
- Schedules new streams
- Manages stream claims and transfers
- Handles stream metadata and URIs

### VestingStream
- Individual stream contract
- Manages Superfluid stream for a specific NFT
- Updates stream recipient based on NFT ownership
- Handles stream start/stop operations

## Usage

1. Deploy `StreamingNFTManager` with admin address
2. Create a new season with:
   - Treasury address
   - SuperToken to be streamed
   - Base URI for NFT metadata
3. Schedule streams through the season's factory
4. Recipients claim their streams
5. Stream recipients can transfer their NFTs to transfer the stream

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
