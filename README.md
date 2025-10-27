# Cetus DLMM (Dynamic Liquidity Market Maker)

A sophisticated Dynamic Liquidity Market Maker protocol built on Sui blockchain, providing efficient liquidity management, automated market making, and reward distribution for decentralized exchanges.

## Overview

Cetus DLMM is an advanced AMM protocol that dynamically adjusts liquidity distribution based on market conditions. It features:

- **Dynamic Liquidity Management**: Automatically rebalances liquidity across price ranges
- **Multi-Bin Architecture**: Supports up to 1000 bins per position for granular liquidity control
- **Advanced Fee Management**: Configurable fee rates with partner and protocol fee support
- **Reward Distribution**: Built-in reward system with up to 5 different reward types per position
- **Access Control**: Comprehensive ACL system for user and position restrictions
- **Flash Swaps**: Support for flash loan functionality
- **Version Management**: Upgradeable protocol with version tracking

## Architecture

The protocol consists of several core modules:

### Core Modules

- **`pool`**: Main pool functionality handling swaps, liquidity management, and position operations
- **`position`**: Position management for liquidity providers with fee collection and reward distribution
- **`bin`**: Bin management system for organizing liquidity across price ranges
- **`registry`**: Global pool registry for creating and tracking all pools
- **`config`**: Global configuration management with access control and restrictions
- **`reward`**: Reward distribution and management system
- **`partner`**: Partner fee management and tracking
- **`restriction`**: User and position blocking with operation-level restrictions
- **`acl`**: Access Control List implementation for permission management
- **`admin_cap`**: Administrative capabilities and permissions
- **`parameters`**: Variable parameter management for pools
- **`dlmm_math`**: Mathematical utilities for price calculations and liquidity management
- **`price_math`**: Price calculation utilities
- **`versioned`**: Version management and upgrade mechanisms
- **`constants`**: Protocol constants and configuration values

## Installation

### Dependencies

Add the following dependencies to your `Move.toml`:

```toml
[dependencies]
CetusDlmm = { git = "https://github.com/CetusProtocol/cetus-dlmm-interface.git", subdir = "packages/dlmm", rev = "testnet-v0.0.4" }
IntegerMate = { git = "https://github.com/CetusProtocol/integer-mate.git", rev = "testnet-v1.3.0", override = true }
MoveSTL = { git = "https://github.com/CetusProtocol/move-stl.git", rev = "testnet-v1.3.0", override = true }
```

### Address Configuration

Configure the package address in your `Move.toml`:

```toml
[addresses]
cetusdlmm = "0x0"  # Replace with actual deployed address
```

## Development

### Building

```bash
# Build the package
sui move build

# Run tests
sui move test
```

### Testing

The package includes comprehensive tests for all modules. Run tests with:

```bash
sui move test
```

## Rust SDK Module

The repository includes a standalone **Rust SDK** for off-chain swap simulations and price calculations:

- **[`sdk/`](./sdk/README.md)**: Lightweight Rust library implementing DLMM swap pricing logic without blockchain dependencies

The SDK enables developers to simulate swaps, calculate price impact, and analyze liquidity distribution without requiring a connection to the Sui network. See the [SDK README](./sdk/README.md) for detailed documentation and usage examples.



## License

Copyright (c) Cetus Technology Limited

## Support

For support and questions, please visit our [GitHub Issues](https://github.com/CetusProtocol/cetus-dlmm-interface/issues) or contact us through our official channels.
