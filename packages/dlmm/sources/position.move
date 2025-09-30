// Copyright (c) Cetus Technology Limited

/// # Position Management Module
///
/// This module provides position management functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles liquidity positions, fee collection, reward distribution, and position lifecycle management.
///
#[allow(unused_variable, unused_function, unused_const,unused_type_parameter, unused_field)]
module cetusdlmm::position;

use integer_mate::i32::{Self, I32};
use std::string::{String};
use sui::table::{Table};

const POSITION_DESCRIPTION: vector<u8> = b"Cetus DLMM Position";
const POSITION_LINK: vector<u8> = b"https://app.cetus.zone/pools";
const POSITION_CREATOR: vector<u8> = b"Cetus";
const POSITION_PROJECT_URL: vector<u8> = b"https://cetus.zone";
const POSITION_NAME: vector<u8> = b"Cetus DLMM LP | Pool";
const NAME: vector<u8> = b"name";
const COIN_A: vector<u8> = b"coin_a";
const COIN_B: vector<u8> = b"coin_b";
const LINK: vector<u8> = b"link";
const IMAGE_URL: vector<u8> = b"image_url";
const DESCRIPTION: vector<u8> = b"description";
const PROJECT_URL: vector<u8> = b"project_url";
const CREATOR: vector<u8> = b"creator";

/// ## Error Codes
///
/// - `EPositionLiquidityOverflow`: Liquidity calculation overflow
/// - `EPositionLiquidityNotEnough`: Insufficient liquidity for decrease
/// - `EPositionRewardIndexOutOfRange`: Reward index exceeds available rewards
/// - `EPositionBinIdMismatch`: Bin ID doesn't match expected sequence
/// - `EPositionAmountANotZero`: Position still has token A amounts
/// - `EPositionAmountBNotZero`: Position still has token B amounts
/// - `EPositionRewardNotZero`: Position still has unclaimed rewards
/// - `EPositionStatsNotEmpty`: Position stats not fully processed
/// - `EPositionNotFound`: Position not found
/// - `EPositionPendingAddLiquidity`: Position is pending add liquidity
/// - `EPositionNoPendingAddLiquidity`: Position is no pending add liquidity
/// - `EPositionAlreadyExists`: Position already exists
#[error]
const EPositionLiquidityOverflow: vector<u8> = b"Position liquidity overflow";
#[error]
const EPositionLiquidityNotEnough: vector<u8> = b"Position liquidity not enough";
#[error]
const EPositionRewardIndexOutOfRange: vector<u8> = b"Position reward index out of range";
#[error]
const EPositionBinIdMismatch: vector<u8> = b"Position bin id mismatch";
#[error]
const EPositionAmountANotZero: vector<u8> = b"Position amount a not zero";
#[error]
const EPositionAmountBNotZero: vector<u8> = b"Position amount b not zero";
#[error]
const EPositionRewardNotZero: vector<u8> = b"Position reward not zero";
#[error]
const EPositionStatsNotEmpty: vector<u8> = b"Position stats not empty";
#[error]
const EPositionNotFound: vector<u8> = b"Position not found";
#[error]
const EPositionPendingAddLiquidity: vector<u8> = b"Position is pending add liquidity";
#[error]
const EPositionNoPendingAddLiquidity: vector<u8> = b"Position is no pending add liquidity";
#[error]
const EPositionAlreadyExists: vector<u8> = b"Position already exists";

/// One-time witness for the position module.
///
/// This struct is used as a one-time witness to ensure the module
/// can only be initialized once and to claim the package publisher.
public struct POSITION has drop {}

/// Manager for all positions within a specific bin step.
///
/// This struct manages all positions for a particular bin step, providing
/// centralized position tracking and management functionality.
///
/// ## Fields
/// - `bin_step`: The bin step this manager handles
/// - `position_index`: Next available position index
/// - `positions`: Linked table mapping position IDs to their info
public struct PositionManager has store {
    bin_step: u16,
    position_index: u64,
    positions: Table<ID, PositionInfo>,
}

/// Individual liquidity position with metadata and liquidity shares.
///
/// This struct represents a liquidity position that spans multiple bins,
/// with metadata for display and tracking of liquidity shares across bins.
///
/// ## Fields
/// - `id`: Unique identifier for the position
/// - `pool_id`: ID of the pool this position belongs to
/// - `index`: Position index within the pool
/// - `coin_type_a`: Name of token A in the position
/// - `coin_type_b`: Name of token B in the position
/// - `description`: Description of the position
/// - `name`: Display name for the position
/// - `uri`: URI for position metadata
/// - `lower_bin_id`: Lower bound bin ID of the position
/// - `upper_bin_id`: Upper bound bin ID of the position
/// - `liquidity_shares`: Vector of liquidity shares for each bin
/// - `flash_count`: Number of flash swaps for the position
public struct Position has key, store {
    id: UID,
    pool_id: ID,
    index: u64,
    coin_type_a: String,
    coin_type_b: String,
    description: String,
    name: String,
    uri: String,
    lower_bin_id: I32,
    upper_bin_id: I32,
    liquidity_shares: vector<u128>,
    flash_count: u64,
}

/// Internal position data including fees, rewards, and statistics.
///
/// This struct contains the internal state of a position, including
/// accumulated fees, rewards, and statistics for each bin in the position.
///
/// ## Fields
/// - `id`: Position ID
/// - `fee_owned_a`: Accumulated fees for token A
/// - `fee_owned_b`: Accumulated fees for token B
/// - `rewards_owned`: Vector of accumulated rewards for each reward type
/// - `stats`: Vector of bin statistics for each bin in the position
public struct PositionInfo has copy, store {
    id: ID,
    fee_owned_a: u64,
    fee_owned_b: u64,
    rewards_owned: vector<u64>,
    stats: vector<BinStat>,
}

/// Statistics for a single bin within a position.
///
/// This struct tracks the state of a specific bin within a position,
/// including liquidity shares, fee growth, and reward growth tracking.
///
/// ## Fields
/// - `bin_id`: ID of the bin
/// - `liquidity_share`: Current liquidity share in this bin
/// - `fee_a_growth`: Fee growth for token A at last update
/// - `fee_b_growth`: Fee growth for token B at last update
/// - `rewards_growth`: Vector of reward growth for each reward type
public struct BinStat has copy, store {
    bin_id: I32,
    liquidity_share: u128,
    fee_a_growth: u128,
    fee_b_growth: u128,
    rewards_growth: vector<u128>,
}

/// Certificate for safely closing a position.
///
/// This struct contains the position information and accumulated amounts
/// needed to safely close a position and process all its bins.
///
/// ## Fields
/// - `position_info`: The position information being closed
/// - `pool_id`: ID of the pool this position belongs to
/// - `amount_a`: Accumulated amount of token A from closed bins
/// - `amount_b`: Accumulated amount of token B from closed bins
public struct ClosePositionCert {
    pool_id: ID,
    position_info: PositionInfo,
    amount_a: u64,
    amount_b: u64,
}

/// Gets the bin step of the position manager.
///
/// ## Parameters
/// - `manager`: Reference to the position manager
///
/// ## Returns
/// - `u16`: The bin step this manager handles
public fun bin_step(manager: &PositionManager): u16 {
    manager.bin_step
}

/// Borrows position information from the manager.
///
/// ## Parameters
/// - `manager`: Reference to the position manager
/// - `id`: ID of the position
///
/// ## Returns
/// - `&PositionInfo`: Reference to the position information
public fun borrow_position_info(manager: &PositionManager, id: ID): &PositionInfo {
    abort 1
}

/// Gets the lower bin ID from the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
///
/// ## Returns
/// - `I32`: The lower bin ID
public fun lower_bin_id_on_position_info(position_info: &PositionInfo): I32 {
    position_info.stats[0].bin_id
}

/// Gets the upper bin ID from the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
///
/// ## Returns
/// - `I32`: The upper bin ID
public fun upper_bin_id_on_position_info(position_info: &PositionInfo): I32 {
    position_info.stats[position_info.stats.length() - 1].bin_id
}

/// Gets the width of the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
///
/// ## Returns
/// - `u64`: The width of the position info
public fun width_on_position_info(position_info: &PositionInfo): u64 {
    position_info.stats.length()
}

/// Gets the bin index of the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
/// - `bin_id`: The bin ID
///
/// ## Returns
/// - `u64`: The bin index
public fun bin_idx_on_position_info(position_info: &PositionInfo, bin_id: I32): u64 {
    bin_id.sub(position_info.lower_bin_id_on_position_info()).as_u32() as u64
}

/// Gets the fees from the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (fee_a, fee_b) from the position info
public fun info_fees(position_info: &PositionInfo): (u64, u64) {
    (position_info.fee_owned_a, position_info.fee_owned_b)
}

/// Gets the rewards from the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
///
/// ## Returns
/// - `&vector<u64>`: Reference to the vector of rewards
public fun info_rewards(position_info: &PositionInfo): &vector<u64> {
    &position_info.rewards_owned
}

/// Gets the stats from the position info.
///
/// ## Parameters
/// - `position_info`: Reference to the position info
///
/// ## Returns
/// - `&vector<BinStat>`: Reference to the vector of bin stats
public fun info_stats(position_info: &PositionInfo): &vector<BinStat> {
    &position_info.stats
}

/// Gets the amount of token A from the close position certificate.
///
/// ## Parameters
/// - `cert`: Reference to the close position certificate
///
/// ## Returns
/// - `u64`: The amount of token A
public fun amount_a(cert: &ClosePositionCert): u64 {
    cert.amount_a
}

/// Gets the amount of token B from the close position certificate.
///
/// ## Parameters
/// - `cert`: Reference to the close position certificate
///
/// ## Returns
/// - `u64`: The amount of token B
public fun amount_b(cert: &ClosePositionCert): u64 {
    cert.amount_b
}

/// Gets the position info from the close position certificate.
///
/// ## Parameters
/// - `cert`: Reference to the close position certificate
///
/// ## Returns
/// - `&PositionInfo`: Reference to the position info
public fun position_info(cert: &ClosePositionCert): &PositionInfo {
    &cert.position_info
}

/// Gets the width of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `u16`: The width of the position
public fun width(position: &Position): u16 {
    position.upper_bin_id.sub(position.lower_bin_id).add(i32::from(1)).as_u32() as u16
}

/// Gets the pool ID from the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `ID`: The pool ID
public fun pool_id(position: &Position): ID {
    position.pool_id
}

/// Gets the position index from the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `u64`: The position index
public fun index(position: &Position): u64 {
    position.index
}

/// Gets the name of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `String`: The name of the position
public fun name(position: &Position): String {
    position.name
}

/// Gets the URI of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `String`: The URI of the position
public fun uri(position: &Position): String {
    position.uri
}

/// Gets the coin type A of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `String`: The coin type A of the position
public fun coin_type_a(position: &Position): String {
    position.coin_type_a
}

/// Gets the coin type B of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `String`: The coin type B of the position
public fun coin_type_b(position: &Position): String {
    position.coin_type_b
}

/// Gets the liquidity shares of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `vector<u128>`: The liquidity shares of the position
public fun liquidity_shares(position: &Position): vector<u128> {
    position.liquidity_shares
}

/// Gets the description of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `String`: The description of the position
public fun description(position: &Position): String {
    position.description
}

/// Gets the lower bin ID of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `I32`: The lower bin ID
public fun lower_bin_id(position: &Position): I32 {
    position.lower_bin_id
}

/// Gets the upper bin ID from the position.
///
/// ## Parameters
/// - `position`: Reference to the position
///
/// ## Returns
/// - `I32`: The upper bin ID
public fun upper_bin_id(position: &Position): I32 {
    position.upper_bin_id
}

/// Gets the bin index of the position.
///
/// ## Parameters
/// - `position`: Reference to the position
/// - `bin_id`: The bin ID
///
/// ## Returns
/// - `u64`: The bin index
public fun bin_idx(position: &Position, bin_id: I32): u64 {
    bin_id.sub(position.lower_bin_id).as_u32() as u64
}

/// Gets the bin ID from the bin stat.
///
/// ## Parameters
/// - `bin_stat`: Reference to the bin stat
///
/// ## Returns
/// - `I32`: The bin ID
public fun bin_id(bin_stat: &BinStat): I32 {
    bin_stat.bin_id
}

/// Gets the liquidity share from the bin stat.
///
/// ## Parameters
/// - `bin_stat`: Reference to the bin stat
///
/// ## Returns
/// - `u128`: The liquidity share
public fun liquidity_share(bin_stat: &BinStat): u128 {
    bin_stat.liquidity_share
}

/// Gets the fee A growth from the bin stat.
///
/// ## Parameters
/// - `bin_stat`: Reference to the bin stat
///
/// ## Returns
/// - `u128`: The fee A growth
public fun fee_a_growth(bin_stat: &BinStat): u128 {
    bin_stat.fee_a_growth
}

/// Gets the fee B growth from the bin stat.
///
/// ## Parameters
/// - `bin_stat`: Reference to the bin stat
///
/// ## Returns
/// - `u128`: The fee B growth
public fun fee_b_growth(bin_stat: &BinStat): u128 {
    bin_stat.fee_b_growth
}

/// Gets the rewards growth from the bin stat.
///
/// ## Parameters
/// - `bin_stat`: Reference to the bin stat
///
/// ## Returns
/// - `vector<u128>`: vector of rewards growth
public fun rewards_growth(bin_stat: &BinStat): vector<u128> {
    bin_stat.rewards_growth
}
