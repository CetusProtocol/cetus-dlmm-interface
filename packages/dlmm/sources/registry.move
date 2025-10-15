// Copyright (c) Cetus Technology Limited

/// # Registry Module
///
/// This module provides pool registry functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles pool creation, management, and tracking of all pools in the protocol.
#[allow(unused_variable, unused_function, unused_const, unused_type_parameter, unused_field)]
module cetusdlmm::registry;

use cetusdlmm::config::GlobalConfig;
use cetusdlmm::pool::{Pool};
use cetusdlmm::versioned::Versioned;
use move_stl::linked_table::{LinkedTable};
use std::string::{String};
use std::type_name::{TypeName};
use sui::clock::Clock;
use sui::coin::CoinMetadata;
/// ## Error Codes
///
/// - `EInvalidActiveId`: Active ID is outside valid price range
/// - `ESameCoinType`: Both token types are the same
/// - `EPoolAlreadyExist`: Pool with the same key already exists
/// - `ECreatePoolCertNotMatch`: Pool receipt doesn't match the pool
/// - `ECoinTypeNotAllowed`: One or both coin types are not allowed
#[error]
const EInvalidActiveId: vector<u8> = b"Invalid active id";
#[error]
const ESameCoinType: vector<u8> = b"Same coin type";
#[error]
const EPoolAlreadyExist: vector<u8> = b"Pool already exist";
#[error]
const ECreatePoolCertNotMatch: vector<u8> = b"Create pool cert not match";
#[error]
const ECoinTypeNotAllowed: vector<u8> = b"Coin type not allowed";
#[error]
const EInvalidCoinTypeSequence: vector<u8> = b"Invalid coin type sequence";

/// Global registry that tracks all pools in the protocol.
///
/// This struct serves as the central registry for all pools, providing
/// pool creation, management, and lookup functionality.
///
/// ## Fields
/// - `id`: Unique identifier for the registry
/// - `index`: Next available pool index
/// - `pools`: Linked table mapping pool keys to pool information
public struct Registry has key {
    id: UID,
    index: u64,
    pools: LinkedTable<ID, PoolInfo>,
}

/// Metadata for a pool in the registry.
///
/// This struct contains essential information about a pool for
/// lookup and management purposes.
///
/// ## Fields
/// - `pool_id`: Unique identifier for the pool
/// - `pool_key`: Unique key for the pool configuration
/// - `coin_type_a`: Type name of token A
/// - `coin_type_b`: Type name of token B
/// - `bin_step`: Bin step configuration for the pool
/// - `base_factor`: Base factor for the pool configuration
public struct PoolInfo has copy, drop, store {
    pool_id: ID,
    pool_key: ID,
    coin_type_a: TypeName,
    coin_type_b: TypeName,
    bin_step: u16,
    base_factor: u16,
}

/// Receipt for pool creation operations.
///
/// This struct provides a receipt that can be used to verify
/// pool creation and manage the pool lifecycle.
///
/// ## Fields
/// - `pool_id`: ID of the created pool
public struct CreatePoolReceipt {
    pool_id: ID,
}

/// Event emitted when the registry is initialized.
///
/// ## Fields
/// - `pools_id`: The ID of the created registry
public struct RegistryEvent has copy, drop {
    pools_id: ID,
}

/// Event emitted when a new pool is created.
///
/// ## Fields
/// - `pool_id`: The ID of the created pool
/// - `coin_type_a`: String representation of token A type
/// - `coin_type_b`: String representation of token B type
/// - `bin_step`: Bin step configuration for the pool
public struct CreatePoolEvent has copy, drop {
    pool_id: ID,
    coin_type_a: String,
    coin_type_b: String,
    bin_step: u16,
    base_factor: u16,
}
/// Creates a new pool for the specified token pair.
///
/// This function creates a new pool with the given configuration, validates
/// all parameters, and registers it in the global registry.
///
/// ## Type Parameters
/// - `CoinTypeA`: Type of token A in the pool
/// - `CoinTypeB`: Type of token B in the pool
///
/// ## Parameters
/// - `registry`: Mutable reference to the global registry
/// - `metadata_a`: Metadata for token A
/// - `metadata_b`: Metadata for token B
/// - `bin_step`: Bin step configuration for the pool
/// - `base_factor`: Base factor for the pool configuration
/// - `active_id`: Initial active bin ID for the pool
/// - `url`: URL for pool metadata
/// - `config`: Reference to the global config for validations
/// - `versioned`: Versioned object for version checking
/// - `clock`: Clock object for timestamp operations
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(CreatePoolReceipt, Pool)`: Tuple of receipt and created pool
///
/// ## Errors
/// - `ECoinTypeNotAllowed`: If one or both coin types are not allowed
/// - `EInvalidActiveId`: If active ID is outside valid price range
/// - `ESameCoinType`: If both token types are the same
/// - `EPoolAlreadyExist`: If pool with the same key already exists
/// - `ENoUserOperationPermission`: If sender lacks user operation permission
///
/// ## Events Emitted
/// - `CreatePoolEvent`: Contains pool creation details
#[allow(lint(share_owned, self_transfer))]
public fun create_pool<CoinTypeA, CoinTypeB>(
    registry: &mut Registry,
    metadata_a: &CoinMetadata<CoinTypeA>,
    metadata_b: &CoinMetadata<CoinTypeB>,
    bin_step: u16,
    base_factor: u16,
    active_id: u32,
    url: String,
    config: &mut GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &mut TxContext,
): (CreatePoolReceipt, Pool<CoinTypeA, CoinTypeB>) {
    abort 1
}


public fun create_pool_v2<CoinTypeA, CoinTypeB>(
    registry: &mut Registry,
    bin_step: u16,
    base_factor: u16,
    active_id: u32,
    url: String,
    config: &mut GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &mut TxContext,
): (CreatePoolReceipt, Pool<CoinTypeA, CoinTypeB>){
    abort 1
}

/// Destroys the pool creation receipt and shares the pool.
///
/// This function validates that the receipt matches the pool and then
/// shares the pool object for public access.
///
/// ## Type Parameters
/// - `CoinTypeA`: Type of token A in the pool
/// - `CoinTypeB`: Type of token B in the pool
///
/// ## Parameters
/// - `receipt`: The pool creation receipt to destroy
/// - `pool`: The pool to share
///
/// ## Errors
/// - `ECreatePoolCertNotMatch`: If receipt doesn't match the pool
#[allow(lint(share_owned))]
public fun destroy_receipt<CoinTypeA, CoinTypeB>(
    receipt: CreatePoolReceipt,
    pool: Pool<CoinTypeA, CoinTypeB>,
    versioned: &Versioned,
) {
    abort 1
}

/// Generates a unique pool key for the given configuration.
///
/// This function creates a deterministic pool key by hashing the token types,
/// bin step, and base factor. The key ensures uniqueness for each pool configuration.
///
/// ## Type Parameters
/// - `CoinTypeA`: Type of token A in the pool
/// - `CoinTypeB`: Type of token B in the pool
///
/// ## Parameters
/// - `bin_step`: Bin step configuration for the pool
/// - `base_factor`: Base factor for the pool configuration
///
/// ## Returns
/// - `ID`: Unique pool key generated from the configuration
public fun new_pool_key<CoinTypeA, CoinTypeB>(bin_step: u16, base_factor: u16): ID {
    abort 1
}

/// Check if the order of CoinTypeA and CoinTypeB is right
///
/// ## Type Parameters
/// - `CoinTypeA`: Type of token A in the pool
/// - `CoinTypeB`: Type of token B in the pool
///
/// ## Returns
/// - `bool`: True if the order is correct, false otherwise
public fun is_right_order<CoinTypeA, CoinTypeB>(): bool {
    abort 1
}
