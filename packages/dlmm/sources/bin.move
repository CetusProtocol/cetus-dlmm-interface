// Copyright (c) Cetus Technology Limited

/// # Bin Management Module
///
/// This module provides the core data structures and operations for managing liquidity bins
/// in the Cetus DLMM (Dynamic Liquidity Market Maker) protocol. It implements a skip list-based
/// bin management system where each bin represents a price point with associated liquidity.
///
#[allow(unused_variable, unused_function, unused_const,unused_type_parameter, unused_field)]
module cetusdlmm::bin;


use integer_mate::i32::I32;
use move_stl::skip_list::SkipList;

/// ## Error Codes
///
/// - `EBinNotExists`: Attempted to access a non-existent bin
/// - `EInvalidBinId`: Bin ID is outside valid range
/// - `EBinLiquidityUnderflow`: Attempted to remove more liquidity than available
/// - `EBinNotEmpty`: Attempted to remove a bin that still has liquidity
/// - `EFeeAmountOverflow`: Fee calculation resulted in overflow
/// - `EBinLiquiditySupplyZero`: Attempted operation on bin with zero liquidity supply
/// - `EBinLiquidityOverflow`: Bin liquidity overflow
/// - `EGroupNotExists`: Group not exists
/// - `EBinNotInGroup`: Bin not in group
#[error]
const EBinNotExists: vector<u8> = b"Bin not exists";
#[error]
const EInvalidBinId: vector<u8> = b"Invalid bin id";
#[error]
const EBinLiquidityUnderflow: vector<u8> = b"Bin liquidity underflow";
#[error]
const EBinNotEmpty: vector<u8> = b"Bin not empty";
#[error]
const EFeeAmountOverflow: vector<u8> = b"Fee amount overflow";
#[error]
const EBinLiquiditySupplyZero: vector<u8> = b"Bin liquidity supply zero";
#[error]
const EBinLiquidityShareOverflow: vector<u8> = b"Bin liquidity share overflow";
#[error]
const EGroupNotExists: vector<u8> = b"Group not exists";
#[error]
const EBinNotInGroup: vector<u8> = b"Bin not in group";
#[error]
const EGroupNotEmpty: vector<u8> = b"Group not empty";
#[error]
const EOffsetOverflow: vector<u8> = b"Offset overflow";

/// Manages a collection of liquidity bins with a specific bin step.
///
/// The `BinManager` is responsible for:
/// - Storing bins in a skip list for efficient access
/// - Managing bin creation and removal
/// - Providing access to bins for operations
///
/// # Fields
/// - `bin_step`: The step size between consecutive bins (determines price granularity)
/// - `bins`: Skip list containing all bins, organized by bin score
public struct BinManager has store {
    pool_id: ID,
    bin_step: u16,
    bins: SkipList<BinGroupRef>,
}

/// Represents a reference to a bin group.
///
/// ## Fields
/// - `pool_id`: ID of the pool
/// - `group`: Reference to the bin group
public struct BinGroupRef has store {
    pool_id: ID,
    group: BinGroup,
}

/// Represents a group of bins with a specific index.
///
/// ## Fields
/// - `idx`: The index of the group
/// - `used_bins_mask`: A mask indicating which bins are used in the group
/// - `bins`: Vector of bins in the group
public struct BinGroup has store {
    idx: u32,
    used_bins_mask: u16,
    bins: vector<Bin>,
}

/// Represents a single liquidity bin at a specific price point.
///
/// Each bin contains liquidity in the form of token amounts and tracks
/// accumulated fees and rewards for liquidity providers.
///
/// ## Fields
/// - `id`: Unique identifier for the bin (I32)
/// - `amount_a`, `amount_b`: Token amounts in the bin
/// - `price`: Price at this bin's price point (u128)
/// - `liquidity_share`: Total liquidity share in the bin
/// - `rewards_growth_global`: Accumulated rewards growth per liquidity share
/// - `fee_a_growth_global`, `fee_b_growth_global`: Accumulated fees growth per liquidity share
public struct Bin has store {
    id: I32,
    amount_a: u64,
    amount_b: u64,
    price: u128,
    liquidity_share: u128,
    rewards_growth_global: vector<u128>,
    fee_a_growth_global: u128,
    fee_b_growth_global: u128,
}

/// Borrows a bin group from the reference.
///
/// ## Parameters
/// - `group`: Reference to the bin group reference
///
/// ## Returns
/// - `&BinGroup`: Reference to the bin group
public fun borrow_bin_group(group: &BinGroupRef): &BinGroup {
    abort 1
}

/// Borrows a bin from the group.
///
/// ## Parameters
/// - `group`: Reference to the group
/// - `offset_in_group`: The offset of the bin in the group
///
/// ## Returns
/// - `&Bin`: Reference to the bin
public fun borrow_bin_from_group(group: &BinGroup, offset_in_group: u8): &Bin {
    abort 1
}

/// Checks if a group is empty.
///
/// ## Parameters
/// - `group`: Reference to the group
///
/// ## Returns
/// - `bool`: `true` if the group is empty, `false` otherwise
public fun is_empty_group(group: &BinGroup): bool {
    abort 1
}


/// Resolves the bin position from a score.
///
/// ## Parameters
/// - `score`: The score to resolve
///
/// ## Returns
/// - `(u64, u8)`: Tuple of (group index, offset in group)
public fun resolve_bin_position(score: u64): (u64, u8) {
    abort 1
}
/// Calculates composition fees for liquidity addition.
///
/// This function calculates the composition fees that should be charged
/// when adding liquidity to a bin, based on the amounts and fee rate.
///
/// ## Parameters
/// - `bin`: Reference to the bin
/// - `amount_a`: Amount of token A to add
/// - `amount_b`: Amount of token B to add
/// - `fee_rate`: Fee rate to apply
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (fee A, fee B)
public fun get_composition_fees(
    bin: &Bin,
    amount_a: u64,
    amount_b: u64,
    fee_rate: u64,
): (u64, u64) {
    abort 1
}

/// Checks if a bin is empty for a specific token.
///
/// ## Parameters
/// - `bin`: Reference to the bin
/// - `is_a`: `true` to check token A, `false` to check token B
///
/// ## Returns
/// - `bool`: `true` if the specified token amount is zero, `false` otherwise
public fun is_empty(bin: &Bin, is_a: bool): bool {
    abort 1
}

/// Fetches bins from the bin manager.
///
/// ## Parameters
/// - `manager`: Reference to the bin manager
/// - `start`: Option of the start bin ID
/// - `limit`: Limit of the bins to fetch
///
/// ## Returns
/// - `vector<BinInfo>`: Vector of bin infos
///
/// ## Errors
/// - `EBinNotExists`: If the bin doesn't exist
public fun fetch_bins(
    manager: &BinManager,
    start: option::Option<u32>,
    limit: u64,
): vector<BinInfo> {
    abort 1

}

/// Calculates output amounts based on liquidity share.
///
/// This function calculates the token amounts that would be returned when removing
/// a specific amount of liquidity shares from the bin.
///
/// ## Parameters
/// - `bin`: Reference to the bin
/// - `liquidity_delta`: Amount of liquidity shares to remove
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (amount_a, amount_b) that would be returned
public fun calculate_out_amount(bin: &Bin, liquidity_delta: u128): (u64, u64) {
    abort 1
}

/// Gets the pool ID from the bin group reference.
///
/// ## Parameters
/// - `bin_group_ref`: Reference to the bin group reference
///
/// ## Returns
/// - `ID`: The pool ID
public fun pool_id(bin_group_ref: &BinGroupRef): ID {
    bin_group_ref.pool_id
}

/// Gets the index of the group.
///
/// ## Parameters
/// - `group`: Reference to the group
///
/// ## Returns
/// - `u32`: The index of the group
public fun group_idx(group: &BinGroup): u32 {
    group.idx
}

/// Gets the bins in the group.
///
/// ## Parameters
/// - `group`: Reference to the group
///
/// ## Returns
/// - `&vector<Bin>`: The bins in the group
public fun group_bins(group: &BinGroup): &vector<Bin> {
    &group.bins
}

/// Gets the total liquidity share in the bin.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `u128`: Total liquidity share in the bin
public fun liquidity_share(bin: &Bin): u128 {
    bin.liquidity_share
}

/// Gets the price at this bin's price point.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `u128`: Price at this bin's price point
public fun price(bin: &Bin): u128 {
    bin.price
}

/// Gets the ID of the bin.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `I32`: The bin ID
public fun id(bin: &Bin): I32 {
    bin.id
}

/// Gets the amount of token A in the bin.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `u64`: Amount of token A in the bin
public fun amount_a(bin: &Bin): u64 {
    bin.amount_a
}

/// Gets the amount of token B in the bin.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `u64`: Amount of token B in the bin
public fun amount_b(bin: &Bin): u64 {
    bin.amount_b
}

/// Gets the global fee growth for token A.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `u128`: Global fee growth for token A
public fun fee_a_growth_global(bin: &Bin): u128 {
    bin.fee_a_growth_global
}

/// Gets the global fee growth for token B.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `u128`: Global fee growth for token B
public fun fee_b_growth_global(bin: &Bin): u128 {
    bin.fee_b_growth_global
}

/// Gets the global rewards growth for all reward tokens.
///
/// ## Parameters
/// - `bin`: Reference to the bin
///
/// ## Returns
/// - `vector<u128>`: Vector of global rewards growth for each reward token
public fun rewards_growth_global(bin: &Bin): vector<u128> {
    bin.rewards_growth_global
}

/// Calculates the score for a bin ID used in the skip list.
///
/// This function converts a bin ID to a score that can be used for ordering
/// bins in the skip list. The score is calculated by adding the bin bound
/// to the bin ID to ensure positive values.
///
/// ## Parameters
/// - `bin_id`: The bin ID to convert
///
/// ## Returns
/// - `u64`: The calculated score for the bin
///
/// ## Errors
/// - `EInvalidBinId`: If the calculated score is outside the valid range
public fun bin_score(bin_id: I32): u64 {
    abort 1
}

/// Converts a score to a bin ID.
///
/// ## Parameters
/// - `score`: The score to convert
///
/// ## Returns
/// - `I32`: The bin ID
public fun bin_id_from_score(score: u64): I32 {
    abort 1
}

/// Creates a zero bin group.
///
/// ## Returns
/// - `BinGroup`: The zero bin group
public fun zero_bin_group_ref(): BinGroupRef {
    abort 1

}

/// Destroys a zero bin group reference.
///
/// ## Parameters
/// - `bin_group_ref`: Reference to the bin group
public fun destroy_zero_bin_group_ref(bin_group_ref: BinGroupRef) {
    abort 1
}

/// Bin info.
///
/// ## Fields
/// - `id`: The bin ID
/// - `amount_a`: The amount of token A
/// - `amount_b`: The amount of token B
/// - `price`: The price
/// - `liquidity_share`: The liquidity share
/// - `rewards_growth_global`: The rewards growth global
/// - `fee_a_growth_global`: The fee A growth global
/// - `fee_b_growth_global`: The fee B growth global
public struct BinInfo has copy, drop {
    id: I32,
    amount_a: u64,
    amount_b: u64,
    price: u128,
    liquidity_share: u128,
    rewards_growth_global: vector<u128>,
    fee_a_growth_global: u128,
    fee_b_growth_global: u128,
}
