// Copyright (c) Cetus Technology Limited

/// # Pool Module
///
/// This module provides the core pool functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles liquidity management, swaps, position operations, and reward distribution.
#[
    allow(
        unused_variable,
        unused_function,
        unused_const,
        unused_type_parameter,
        unused_let_mut,
        unused_field,
    ),
]
module cetusdlmm::pool;

use cetusdlmm::bin::{Self, BinManager, Bin, BinGroupRef};
use cetusdlmm::config::GlobalConfig;
use cetusdlmm::parameters::VariableParameters;
use cetusdlmm::partner::Partner;
use cetusdlmm::position::{PositionManager, Position, ClosePositionCert, PositionInfo};
use cetusdlmm::reward::RewardManager;
use cetusdlmm::versioned::Versioned;
use integer_mate::i32::I32;
use std::string::String;
use std::type_name::TypeName;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::vec_map::VecMap;

/// ## Error Codes
///
/// - `EPoolIsBlocked`: Pool operations are blocked
/// - `EPositionPoolNotMatch`: Position does not belong to this pool
/// - `EInvalidAmountsOrBinsLength`: Invalid amounts or bins length
/// - `EInvalidRepayAmount`: Invalid repay amount for flash swap
/// - `ERewardTypeNotPermitted`: Reward type not permitted
/// - `EFlashSwapRepayNotMatch`: Flash swap repay does not match
/// - `EFlashSwapRepayAmountNotCorrect`: Flash swap repay amount incorrect
/// - `ENotEnoughLiquidity`: Not enough liquidity for swap
/// - `EAmountInZero`: Amount in is zero
/// - `EAmountOutIsZero`: Amount out is zero
/// - `EInvalidRefFeeRate`: Invalid referral fee rate
/// - `EInvalidBins`: Invalid bin configuration
/// - `EBinNotExistsButLiquidityNotZero`: Bin not exists but liquidity not zero
/// - `EInvalidLiquiditySharesOrBinsLength`: Invalid liquidity shares or bins length
/// - `ERewardDurationLessThanMinRewardDuration`: Reward duration less than min reward duration
/// - `ERemainingRewardSlotsReservedForManager`: Remaining reward slots reserved for manager
/// - `EInvalidRewardEndTime`: Invalid reward end time
/// - `EClosePositionCertNotMatchWithPool`: Close position cert not match with pool
/// - `EBinIdOutOfPositionRange`: If bin ID is outside position bounds
/// - `EActiveIdAlreadyFilled`: Active id already filled
/// - `EPositionLengthOverMax`: Position length over max
/// - `EOpenPositionCountNotEmpty`: Open position count not empty
/// - `EBinGroupRefNotMatch`: Bin group ref not match
/// - `EInvalidBinRange`: Invalid bin range
/// - `EInvalidPercent`: Invalid percent
/// - `ECannotOpenEmptyPosition`: Cannot open empty position
/// - `EInvalidBaseFeeRate`: Invalid base fee rate
/// - `EActiveIdNotFilled`: Active id not filled
/// - `EActiveIdNotIncluded`: Active id not included
/// - `EInvalidWidth`: Invalid width
#[error]
const EPoolIsBlocked: vector<u8> = b"Pool is blocked";
#[error]
const EPositionPoolNotMatch: vector<u8> = b"Position pool not match";
#[error]
const EPositionNotMatch: vector<u8> = b"Position not match";
#[error]
const EInvalidAmountsOrBinsLength: vector<u8> = b"Invalid amounts or bins length";
#[error]
const EInvalidRepayAmount: vector<u8> = b"Invalid repay amount";
#[error]
const ERewardTypeNotPermitted: vector<u8> = b"Reward type not permitted";
#[error]
const EFlashSwapRepayNotMatch: vector<u8> = b"Flash swap repay not match";
#[error]
const EFlashSwapRepayAmountNotCorrect: vector<u8> = b"Flash swap repay amount not correct";
#[error]
const ENotEnoughLiquidity: vector<u8> = b"Not enough liquidity";
#[error]
const EAmountInZero: vector<u8> = b"Amount in zero";
#[error]
const EAmountOutIsZero: vector<u8> = b"Amount out is zero";
#[error]
const EInvalidRefFeeRate: vector<u8> = b"Invalid ref fee rate";
#[error]
const EInvalidBins: vector<u8> = b"Invalid bins";
#[error]
const EBinNotExistsButLiquidityNotZero: vector<u8> = b"Bin not exists but liquidity not zero";
#[error]
const EInvalidLiquiditySharesOrBinsLength: vector<u8> = b"Invalid liquidity shares or bins length";
#[error]
const ERewardDurationLessThanMinRewardDuration: vector<u8> =
    b"Reward duration less than min reward duration";
#[error]
const ERemainingRewardSlotsReservedForManager: vector<u8> =
    b"Remaining reward slots reserved for manager";
#[error]
const EInvalidRewardStartTime: vector<u8> = b"Invalid reward start time";
#[error]
const EInvalidRewardEndTime: vector<u8> = b"Invalid reward end time";
#[error]
const EClosePositionCertNotMatchWithPool: vector<u8> = b"Close position cert not match with pool";
#[error]
const EBinIdOutOfPositionRange: vector<u8> = b"Bin id out of position range";
#[error]
const EActiveIdAlreadyFilled: vector<u8> = b"Active id already filled";
#[error]
const EPositionLengthOverMax: vector<u8> = b"Position length over max";
#[error]
const EOpenPositionCountNotEmpty: vector<u8> = b"Open position count not empty";
#[error]
const EBinGroupRefNotMatch: vector<u8> = b"Bin group ref not match";
#[error]
const EInvalidBinRange: vector<u8> = b"Invalid bin range";
#[error]
const EInvalidPercent: vector<u8> = b"Invalid percent";
#[error]
const ECannotOpenEmptyPosition: vector<u8> = b"Cannot open empty position";
#[error]
const EInvalidBaseFeeRate: vector<u8> = b"Invalid base fee rate";
#[error]
const EActiveIdNotFilled: vector<u8> = b"Active id not filled";
#[error]
const EActiveIdNotIncluded: vector<u8> = b"Active id not included";
#[error]
const EInvalidWidth: vector<u8> = b"Invalid width";

/// One-time witness for pool module initialization.
///
/// This struct is used as a one-time witness to ensure the pool module
/// can only be initialized once.
public struct POOL has drop {}

/// Main pool structure managing liquidity and operations for a token pair.
///
/// This struct represents a liquidity pool for two token types. It manages
/// liquidity across multiple bins, handles swaps, and tracks positions and rewards.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Fields
/// - `id`: Unique identifier for the pool
/// - `index`: Pool index for identification
/// - `v_parameters`: Variable parameters for dynamic fee calculation
/// - `active_id`: Current active bin ID representing market price
/// - `base_fee_rate`: Base fee rate for swaps
/// - `balance_a`: Balance of token A in the pool
/// - `balance_b`: Balance of token B in the pool
/// - `protocol_fee_a`: Accumulated protocol fees for token A
/// - `protocol_fee_b`: Accumulated protocol fees for token B
/// - `reward_manager`: Manager for reward distribution
/// - `bin_manager`: Manager for liquidity bins
/// - `position_manager`: Manager for liquidity positions
/// - `url`: Pool metadata URL
/// - `permissions`: Pool operation permissions
/// - `active_open_positions`: Number of open position operation, forbid swap when open position is not 0
public struct Pool<phantom CoinTypeA, phantom CoinTypeB> has key, store {
    id: UID,
    index: u64,
    v_parameters: VariableParameters,
    active_id: I32,
    base_fee_rate: u64,
    balance_a: Balance<CoinTypeA>,
    balance_b: Balance<CoinTypeB>,
    protocol_fee_a: u64,
    protocol_fee_b: u64,
    reward_manager: RewardManager,
    bin_manager: BinManager,
    position_manager: PositionManager,
    url: String,
    permissions: Permissions,
    active_open_positions: u64,
}

/// Pool operation permissions and restrictions.
///
/// This struct defines which operations are allowed or disabled for a pool.
/// Each field controls a specific operation type.
///
/// ## Fields
/// - `disable_add`: Whether liquidity addition is disabled
/// - `disable_remove`: Whether liquidity removal is disabled
/// - `disable_swap`: Whether swap operations are disabled
/// - `disable_collect_fee`: Whether fee collection is disabled
/// - `disable_collect_reward`: Whether reward collection is disabled
/// - `disable_add_reward`: Whether adding rewards is disabled
public struct Permissions has copy, drop, store {
    disable_add: bool,
    disable_remove: bool,
    disable_swap: bool,
    disable_collect_fee: bool,
    disable_collect_reward: bool,
    disable_add_reward: bool,
}

/// Result of a swap operation with detailed breakdown.
///
/// This struct contains the complete result of a swap operation,
/// including amounts, fees, and step-by-step execution details.
///
/// ## Fields
/// - `amount_in`: Total amount of input tokens
/// - `amount_out`: Total amount of output tokens
/// - `fee`: Total fee charged for the swap
/// - `ref_fee`: Referral fee amount
/// - `protocol_fee`: Protocol fee amount
/// - `steps`: Vector of individual bin swap steps
public struct SwapResult has copy, drop {
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    ref_fee: u64,
    protocol_fee: u64,
    steps: vector<BinSwap>,
}

/// Individual bin swap step within a swap operation.
///
/// This struct represents a single bin swap step, containing
/// the swap details for one specific bin.
///
/// ## Fields
/// - `bin_id`: ID of the bin where the swap occurred
/// - `amount_in`: Amount of input tokens for this step
/// - `amount_out`: Amount of output tokens for this step
/// - `fee`: Fee charged for this step
/// - `var_fee_rate`: Variable fee rate applied for this step
public struct BinSwap has copy, drop {
    bin_id: I32,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    var_fee_rate: u64,
}

/// Fee rate structure combining base and variable fees.
///
/// This struct contains the complete fee rate breakdown,
/// including base fee, variable fee, and total fee rate.
///
/// ## Fields
/// - `base_fee_rate`: Base fee rate from configuration
/// - `var_fee_rate`: Variable fee rate based on volatility
/// - `total_fee_rate`: Total fee rate (base + variable)
public struct FeeRate has copy, drop {
    base_fee_rate: u64,
    var_fee_rate: u64,
    total_fee_rate: u64,
}

/// Liquidity delta for a specific bin.
///
/// This struct tracks the liquidity changes for a specific bin
/// during position operations (add/remove liquidity).
///
/// ## Fields
/// - `bin_id`: ID of the bin
/// - `liquidity_share`: Liquidity share amount
/// - `amount_a`: Amount of token A
/// - `amount_b`: Amount of token B
public struct BinLiquidityDelta has copy, drop {
    bin_id: I32,
    liquidity_share: u128,
    amount_a: u64,
    amount_b: u64,
}

/// Receipt for flash swap operations.
///
/// This struct contains the details of a flash swap operation,
/// including the pool, direction, partner, and fee information.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Fields
/// - `pool_id`: ID of the pool where the flash swap occurred
/// - `a2b`: Whether the swap was from token A to token B
/// - `partner_id`: ID of the partner (if any)
/// - `pay_amount`: Amount to be repaid
/// - `ref_fee_amount`: Referral fee amount
public struct FlashSwapReceipt<phantom CoinTypeA, phantom CoinTypeB> {
    pool_id: ID,
    a2b: bool,
    partner_id: ID,
    pay_amount: u64,
    ref_fee_amount: u64,
}

/// The capability to collect protocol fees from pools.
///
/// Only the holder of this capability can collect protocol fees
/// from pools. This provides administrative control over fee collection.
///
/// ## Fields
/// - `id`: Unique identifier for the capability
public struct ProtocolFeeCollectCap has key, store {
    id: UID,
}

/// Certificate for safely opening a position.
///
/// This struct contains the position information and accumulated amounts
/// needed to safely open a position and add liquidity to the specified bins.
///
/// ## Fields
/// - `pool_id`: ID of the pool where the position was opened
/// - `position_id`: ID of the position being opened
/// - `width`: Width of the position
/// - `next_bin_id`: Next bin ID to add liquidity to
/// - `position_info`: The position information being opened
/// - `total_amount_a`: Total amount of token A from opened bins
/// - `total_amount_b`: Total amount of token B from opened bins
/// - `active_id`: Active bin ID at the time of opening
/// - `fee_rate`: Fee rate for the active bin
/// - `protocol_fee_rate`: Protocol fee rate for the active bin
/// - `protocol_fee_a`: Protocol fee amount for token A
/// - `protocol_fee_b`: Protocol fee amount for token B
/// - `fee_a`: Fee amount for token A
/// - `fee_b`: Fee amount for token B
/// - `active_id_included`: Whether the active bin amounts are non-zero
/// - `active_id_filled`: Whether the active bin has been filled
/// - `liquidity_deltas`: Vector of liquidity changes per bin
public struct OpenPositionCert<phantom CoinTypeA, phantom CoinTypeB> {
    pool_id: ID,
    position_id: ID,
    width: u16,
    next_bin_id: I32,
    position_info: PositionInfo,
    total_amount_a: u64,
    total_amount_b: u64,
    active_id: I32,
    fee_rate: u64,
    protocol_fee_rate: u64,
    protocol_fee_a: u64,
    protocol_fee_b: u64,
    fee_a: u64,
    fee_b: u64,
    active_id_included: bool,
    active_id_filled: bool,
    liquidity_deltas: vector<BinLiquidityDelta>,
}

/// Certificate for safely adding liquidity to a position.
///
/// This struct contains the position information and accumulated amounts
/// needed to safely add liquidity to the specified bins.
///
/// ## Fields
/// - `pool_id`: ID of the pool where the position was opened
/// - `position_id`: ID of the position being added liquidity to
/// - `position_info`: The position information being added liquidity to
/// - `total_amount_a`: Total amount of token A from added bins
/// - `total_amount_b`: Total amount of token B from added bins
/// - `active_id`: Active bin ID at the time of adding liquidity
/// - `fee_rate`: Fee rate for the active bin
/// - `protocol_fee_rate`: Protocol fee rate for the active bin
/// - `protocol_fee_a`: Protocol fee amount for token A
/// - `protocol_fee_b`: Protocol fee amount for token B
/// - `fee_a`: Fee amount for token A
/// - `fee_b`: Fee amount for token B
/// - `active_id_included`: Whether the active bin amounts are non-zero
/// - `active_id_filled`: Whether the active bin has been filled
/// - `liquidity_deltas`: Vector of liquidity changes per bin
public struct AddLiquidityCert<phantom CoinTypeA, phantom CoinTypeB> {
    pool_id: ID,
    position_id: ID,
    position_info: PositionInfo,
    total_amount_a: u64,
    total_amount_b: u64,
    active_id: I32,
    fee_rate: u64,
    protocol_fee_rate: u64,
    protocol_fee_a: u64,
    protocol_fee_b: u64,
    fee_a: u64,
    fee_b: u64,
    active_id_included: bool,
    active_id_filled: bool,
    liquidity_deltas: vector<BinLiquidityDelta>,
}

/// Position detail.
///
/// This struct contains the position detail, including the position id, amount of token A, amount of token B, fee of token A, fee of token B, rewards, and update transaction.
///
/// ## Fields
/// - `position_id`: ID of the position
/// - `amount_a`: Amount of token A
/// - `amount_b`: Amount of token B
/// - `fee_a`: Fee of token A
/// - `fee_b`: Fee of token B
/// - `rewards`: Rewards
/// - `update_tx`: Update transaction
public struct PositionDetail has copy, drop {
    position_id: ID,
    amount_a: u64,
    amount_b: u64,
    fee_a: u64,
    fee_b: u64,
    rewards: VecMap<TypeName, u64>,
    update_tx: vector<u8>,
}

/// Event emitted when a new position is opened.
///
/// ## Fields
/// - `pool`: ID of the pool where position was opened
/// - `position_id`: ID of the newly created position
/// - `active_id`: Active bin ID at the time of opening
/// - `lower_bin_id`: Lower bin ID at the time of opening
/// - `width`: Width of the position
/// - `active_id`: Active bin ID at the time of opening
public struct OpenPositionEvent has copy, drop {
    pool: ID,
    position_id: ID,
    lower_bin_id: I32,
    width: u16,
    active_id: I32,
}

/// Event emitted when a position is closed.
///
/// ## Fields
/// - `pool`: ID of the pool where position was closed
/// - `position_id`: ID of the position that was closed
/// - `active_id`: Active bin ID at the time of closing
/// - `total_amount_a`: Total amount of token A removed
/// - `total_amount_b`: Total amount of token B removed
/// - `fee_a`: Fee amount for token A
/// - `fee_b`: Fee amount for token B
/// - `rewards`: Vector of reward amounts for each reward type
/// - `liquidity_deltas`: Vector of liquidity changes per bin
public struct ClosePositionEvent has copy, drop {
    pool: ID,
    position_id: ID,
    active_id: I32,
    total_amount_a: u64,
    total_amount_b: u64,
    fee_a: u64,
    fee_b: u64,
    rewards: vector<u64>,
    liquidity_deltas: vector<BinLiquidityDelta>,
}

/// Event emitted when a position is opened.
///
/// ## Fields
/// - `pool`: ID of the pool where position was opened
/// - `position_id`: ID of the newly created position
/// - `active_id`: Active bin ID at the time of opening
/// - `total_amount_a`: Total amount of token A added
/// - `total_amount_b`: Total amount of token B added
/// - `fee_a`: Composite Fee amount for token A
/// - `fee_b`: Composite Fee amount for token B
/// - `liquidity_deltas`: Vector of liquidity changes per bin
public struct AddLiquidityEvent has copy, drop {
    pool: ID,
    position_id: ID,
    active_id: I32,
    total_amount_a: u64,
    total_amount_b: u64,
    fee_a: u64,
    fee_b: u64,
    liquidity_deltas: vector<BinLiquidityDelta>,
}

/// Event emitted when a position is removed.
///
/// ## Fields
/// - `pool`: ID of the pool where position was removed
/// - `position_id`: ID of the position that was removed
/// - `active_id`: Active bin ID at the time of removal
/// - `total_amount_a`: Total amount of token A removed
/// - `total_amount_b`: Total amount of token B removed
/// - `liquidity_deltas`: Vector of liquidity changes per bin
public struct RemoveLiquidityEvent has copy, drop {
    pool: ID,
    position_id: ID,
    active_id: I32,
    total_amount_a: u64,
    total_amount_b: u64,
    liquidity_deltas: vector<BinLiquidityDelta>,
}

/// Event emitted when a swap operation is performed.
///
/// ## Fields
/// - `pool`: ID of the pool where swap occurred
/// - `from`: Type name of the input token
/// - `target`: Type name of the output token
/// - `partner`: ID of the partner (if any)
/// - `amount_in`: Total input amount
/// - `amount_out`: Total output amount
/// - `fee`: Total fee charged
/// - `protocol_fee`: Protocol fee amount
/// - `ref_fee`: Referral fee amount
/// - `vault_a`: Token A vault balance before swap
/// - `vault_b`: Token B vault balance before swap
/// - `bin_swaps`: Vector of individual bin swap steps
public struct SwapEvent has copy, drop {
    pool: ID,
    from: TypeName,
    target: TypeName,
    partner: ID,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    protocol_fee: u64,
    ref_fee: u64,
    vault_a: u64,
    vault_b: u64,
    bin_swaps: vector<BinSwap>,
}

/// Event emitted when protocol fees are collected.
///
/// ## Fields
/// - `pool`: ID of the pool where fees were collected
/// - `fee_a`: Fee amount for token A
/// - `fee_b`: Fee amount for token B
public struct CollectProtocolFeeEvent has copy, drop {
    pool: ID,
    fee_a: u64,
    fee_b: u64,
}

/// Event emitted when fees are collected from a position.
///
/// ## Fields
/// - `pool`: ID of the pool where fees were collected
/// - `position`: ID of the position where fees were collected
/// - `fee_a`: Fee amount for token A
/// - `fee_b`: Fee amount for token B
public struct CollectFeeEvent has copy, drop {
    pool: ID,
    position: ID,
    fee_a: u64,
    fee_b: u64,
}

/// Event emitted when rewards are collected from a position.
///
/// ## Fields
/// - `pool`: ID of the pool where rewards were collected
/// - `position`: ID of the position where rewards were collected
/// - `reward`: Type name of the reward token
/// - `amount`: Amount of reward collected
public struct CollectRewardEvent has copy, drop {
    pool: ID,
    position: ID,
    reward: TypeName,
    amount: u64,
}

/// Event emitted when a reward is initialized.
///
/// ## Fields
/// - `pool`: ID of the pool where reward was initialized
/// - `reward`: Type name of the reward token
public struct InitializeRewardEvent has copy, drop {
    pool: ID,
    reward: TypeName,
}

/// Event emitted when a reward is added.
///
/// ## Fields
/// - `pool`: ID of the pool where reward was added
/// - `reward`: Type name of the reward token
/// - `amount`: Amount of reward added
/// - `start_time`: Start time of the reward
/// - `end_time`: End time of the reward
public struct AddRewardEvent has copy, drop {
    pool: ID,
    reward: TypeName,
    amount: u64,
    start_time: u64,
    end_time: u64,
}

/// Event emitted when permissions are updated.
///
/// ## Fields
/// - `pool`: ID of the pool where permissions were updated
/// - `old_permissions`: Old permissions
/// - `new_permissions`: New permissions
public struct UpdatePermissionsEvent has copy, drop {
    pool: ID,
    old_permissions: Permissions,
    new_permissions: Permissions,
}

/// Event emitted when a reward is made public.
///
/// ## Fields
/// - `pool`: ID of the pool where reward was made public
public struct MakeRewardPublicEvent has copy, drop {
    pool: ID,
}

/// Event emitted when a reward is made private.
///
/// ## Fields
/// - `pool`: ID of the pool where reward was made private
public struct MakeRewardPrivateEvent has copy, drop {
    pool: ID,
}

/// Event emitted when a reward is paused.
///
/// ## Fields
/// - `pool`: ID of the pool where reward was paused
public struct EmergencyPauseRewardEvent has copy, drop {
    pool: ID,
}

/// Event emitted when a reward is unpaused.
///
/// ## Fields
/// - `pool`: ID of the pool where reward was unpaused
public struct EmergencyUnpauseRewardEvent has copy, drop {
    pool: ID,
}

/// Event emitted when the base fee rate is updated.
///
/// ## Fields
/// - `pool`: ID of the pool where refund reward was withdrawn
/// - `reward`: Type name of the reward token
/// - `amount`: Amount of reward withdrawn
public struct EmergencyWithdrawRefundRewardEvent has copy, drop {
    pool: ID,
    reward: TypeName,
    amount: u64,
}

/// Event emitted when the base fee rate is updated.
///
/// ## Fields
/// - `pool`: ID of the pool where base fee rate was updated
/// - `old_base_fee_rate`: Old base fee rate
/// - `new_base_fee_rate`: New base fee rate
public struct UpdateBaseFeeRateEvent has copy, drop {
    pool: ID,
    old_base_fee_rate: u64,
    new_base_fee_rate: u64,
}

/// Checks if a bin exists in the pool.
///
/// ## Parameters
/// - `pool`: Reference to the pool
/// - `bin_id`: ID of the bin to check
///
/// ## Returns
/// - `bool`: True if the bin exists, false otherwise
public fun contains_bin<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    bin_id: I32,
): bool {
    abort 1
}

/// Borrows a bin from the pool.
///
/// ## Parameters
/// - `pool`: Reference to the pool
/// - `bin_id`: ID of the bin to borrow
///
/// ## Returns
/// - `&Bin`: Reference to the bin
public fun borrow_bin<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>, bin_id: I32): &Bin {
    abort 1
}

/// Checks if a group exists in the pool.
///
/// ## Parameters
/// - `pool`: Reference to the pool
/// - `group_index`: Index of the group to check
///
/// ## Returns
/// - `bool`: True if the group exists, false otherwise
public fun contains_group<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    group_index: u64,
): bool {
    abort 1
}

/// Borrows a group reference from the pool.
///
/// ## Parameters
/// - `pool`: Reference to the pool
/// - `group_index`: Index of the group to borrow
///
/// ## Returns
/// - `&BinGroupRef`: Reference to the group reference
public fun borrow_group_ref<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    group_index: u64,
): &BinGroupRef {
    abort 1
}

/// Adds a group to the pool if it doesn't exist.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `group_index`: Index of the group to add
///
/// ## Returns
/// - `&mut BinGroupRef`: Mutable reference to the group
public fun add_group_if_absent<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    group_index: u64,
    versioned: &Versioned,
): &mut BinGroupRef {
    abort 1
}

/// Updates the base fee rate for the pool.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `base_fee_rate`: New base fee rate
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `ctx`: Transaction context
///
/// ## Events Emitted
/// - `UpdateBaseFeeRateEvent`: Contains old and new base fee rate
public fun update_base_fee_rate<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    base_fee_rate: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    ctx: &TxContext,
) {
    abort 1
}

/// Pauses the reward Release.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `ctx`: Transaction context
public fun emergency_pause_reward<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    config: &GlobalConfig,
    versioned: &Versioned,
    ctx: &TxContext,
) {
    abort 1
}

/// Unpauses the reward Release.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `ctx`: Transaction context
public fun emergency_unpause_reward<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    config: &GlobalConfig,
    versioned: &Versioned,
    ctx: &TxContext,
) {
    abort 1
}

/// Opens a new liquidity position in the pool.
///
/// This function creates a new position and adds liquidity to the specified bins.
/// It handles composition fees for the active bin and tracks all liquidity changes.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `bins`: Vector of bin IDs for the position
/// - `amounts_a`: Vector of token A amounts for each bin
/// - `amounts_b`: Vector of token B amounts for each bin
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Position, AddLiquidityCert<CoinTypeA, CoinTypeB>)`: New position and receipt
///
/// ## Errors
/// - `EInvalidAmountsOrBinsLength`: If amounts and bins have different lengths
/// - `EInvalidBins`: If bins are not consecutive or exceed maximum
/// - `EPositionLengthOverMax`: If position length exceeds maximum
public fun open_position<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    bins: vector<u32>,
    amounts_a: vector<u64>,
    amounts_b: vector<u64>,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &mut TxContext,
): (Position, OpenPositionCert<CoinTypeA, CoinTypeB>) {
    abort 1
}

/// Creates a new open position certificate.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `lower_bin_id`: Lower bin ID
/// - `width`: Width of the position
/// - `active_id_included`: Whether the active bin amounts are non-zero
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Position, OpenPositionCert<CoinTypeA, CoinTypeB>)`: New position and certificate
public fun new_open_position_cert<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    lower_bin_id: u32,
    width: u16,
    active_id_included: bool,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &mut TxContext,
): (Position, OpenPositionCert<CoinTypeA, CoinTypeB>) {
    abort 1
}

/// Opens a position on a bin.
///
/// ## Parameters
/// - `position`: Mutable reference to the position
/// - `cert`: Mutable reference to the open position certificate
/// - `bin_group_ref`: Mutable reference to the bin group reference
/// - `offset_in_group`: Offset in the group
/// - `amount_a`: Amount of token A
/// - `amount_b`: Amount of token B
/// - `versioned`: Versioned object for compatibility check
///
/// ## Events Emitted
/// - `OpenPositionEvent`: Contains position ID, lower bin ID, width, and active ID
public fun open_position_on_bin<CoinTypeA, CoinTypeB>(
    position: &mut Position,
    cert: &mut OpenPositionCert<CoinTypeA, CoinTypeB>,
    bin_group_ref: &mut BinGroupRef,
    offset_in_group: u8,
    mut amount_a: u64,
    mut amount_b: u64,
    versioned: &Versioned,
) {
    abort 1
}

/// Creates a new add liquidity certificate.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `active_id_included`: Whether the active bin amounts are non-zero
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `AddLiquidityCert<CoinTypeA, CoinTypeB>`: New add liquidity certificate
public fun new_add_liquidity_cert<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    active_id_included: bool,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): AddLiquidityCert<CoinTypeA, CoinTypeB> {
    abort 1
}

/// Adds liquidity to a bin.
///
/// ## Parameters
/// - `position`: Mutable reference to the position
/// - `cert`: Mutable reference to the add liquidity certificate
/// - `bin_group_ref`: Mutable reference to the bin group reference
/// - `offset_in_group`: Offset in the group
/// - `amount_a`: Amount of token A
/// - `amount_b`: Amount of token B
/// - `versioned`: Versioned object for compatibility check
///
/// ## Events Emitted
/// - `AddLiquidityEvent`: Contains position and liquidity delta information
public fun add_liquidity_on_bin<CoinTypeA, CoinTypeB>(
    position: &mut Position,
    cert: &mut AddLiquidityCert<CoinTypeA, CoinTypeB>,
    bin_group_ref: &mut BinGroupRef,
    offset_in_group: u8,
    mut amount_a: u64,
    mut amount_b: u64,
    versioned: &Versioned,
) {
    abort 1
}

/// Adds liquidity to an existing position.
///
/// This function adds liquidity to the specified bins of an existing position.
/// It handles composition fees for the active bin and updates both pool and position.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `bins`: Vector of bin IDs for liquidity addition
/// - `amounts_a`: Vector of token A amounts for each bin
/// - `amounts_b`: Vector of token B amounts for each bin
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `AddLiquidityCert<CoinTypeA, CoinTypeB>`: Certificate with added amounts
///
/// ## Events Emitted
/// - `AddLiquidityEvent`: Contains position and liquidity delta information
public fun add_liquidity<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    bins: vector<u32>,
    amounts_a: vector<u64>,
    amounts_b: vector<u64>,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): AddLiquidityCert<CoinTypeA, CoinTypeB> {
    abort 1
}

/// Repays an open position.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `cert`: Open position certificate
/// - `balance_a`: Balance of token A
/// - `balance_b`: Balance of token B
/// - `versioned`: Versioned object for compatibility check
///
/// ## Events Emitted
/// - `AddLiquidityEvent`: Contains position and liquidity delta information
public fun repay_open_position<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    cert: OpenPositionCert<CoinTypeA, CoinTypeB>,
    balance_a: Balance<CoinTypeA>,
    balance_b: Balance<CoinTypeB>,
    versioned: &Versioned,
) {
    abort 1
}

/// Repays an add liquidity certificate.
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `cert`: Add liquidity certificate
/// - `balance_a`: Balance of token A
/// - `balance_b`: Balance of token B
/// - `versioned`: Versioned object for compatibility check
///
/// ## Events Emitted
/// - `AddLiquidityEvent`: Contains position and liquidity delta information
public fun repay_add_liquidity<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    cert: AddLiquidityCert<CoinTypeA, CoinTypeB>,
    balance_a: Balance<CoinTypeA>,
    balance_b: Balance<CoinTypeB>,
    versioned: &Versioned,
) {
    abort 1
}

/// Removes liquidity from a position and returns the underlying tokens.
///
/// This function removes liquidity from the specified bins of a position
/// and returns the corresponding token amounts. It handles bin cleanup if empty.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `bins`: Vector of bin IDs for liquidity removal
/// - `liquidity_shares`: Vector of liquidity shares to remove from each bin
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>)`: Token balances returned
///
/// ## Events Emitted
/// - `RemoveLiquidityEvent`: Contains position and liquidity delta information
public fun remove_liquidity<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    bins: vector<u32>,
    liquidity_shares: vector<u128>,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): (Balance<CoinTypeA>, Balance<CoinTypeB>) {
    abort 1
}

/// Removes liquidity from a position by a percentage of the total liquidity.
///
/// This function removes liquidity from the specified bins of a position
/// and returns the corresponding token amounts. It handles bin cleanup if empty.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `min_bin_id`: Minimum bin ID for removal
/// - `max_bin_id`: Maximum bin ID for removal
/// - `percent`: Percentage of liquidity to remove
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>)`: Token balances returned
///
/// ## Events Emitted
/// - `RemoveLiquidityEvent`: Contains position and liquidity delta information
public fun remove_liquidity_by_percent<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    min_bin_id: u32,
    max_bin_id: u32,
    percent: u16,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): (Balance<CoinTypeA>, Balance<CoinTypeB>) {
    abort 1
}

/// Removes full range liquidity from a position specified by numerator and denominator.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `numerator`: Numerator of the percentage
/// - `denominator`: Denominator of the percentage
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>)`: Token balances returned
///
/// ## Events Emitted
/// - `RemoveLiquidityEvent`: Contains position and liquidity delta information
public fun remove_full_range_liquidity_by_percent<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    numerator: u128,
    denominator: u128,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): (Balance<CoinTypeA>, Balance<CoinTypeB>) {
    abort 1
}

/// Updates fee and reward tracking for a position.
///
/// This function updates the accumulated fees and rewards for a position
/// by iterating through all bins in the position and updating their state.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position_id`: ID of the position to update
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
public fun update_position_fee_and_rewards<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position_id: ID,
    versioned: &Versioned,
    clk: &Clock,
) {
    abort 1
}

/// Refreshes the position info and returns the position detail.
///
/// This function refreshes the position info and returns the position detail.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position_id`: ID of the position to refresh
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `PositionDetail`: Position detail
public fun refresh_position_info<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position_id: ID,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): PositionDetail {
    abort 1
}

/// Refreshes the position info and returns the position detail.
///
/// This function refreshes the position info and returns the position detail, and the amounts are calculated based on the expected active ID.
/// 
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position_id`: ID of the position to refresh
/// - `expected_active_id`: Expected active bin ID
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `PositionDetail`: Position detail
public fun refresh_position_info_v2<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position_id: ID,
    mut expected_active_id: Option<I32>,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): PositionDetail {
    abort 1
}

/// Collects accumulated fees from a position.
///
/// This function extracts the accumulated fees from a position and returns
/// them as token balances. The fees are taken from the pool's balance.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>)`: Collected fee balances
///
/// ## Events Emitted
/// - `CollectFeeEvent`: Contains position and fee amounts
///
/// ## Errors
/// - `EPositionPoolNotMatch`: If position doesn't belong to this pool
public fun collect_position_fee<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    config: &GlobalConfig,
    versioned: &Versioned,
    ctx: &TxContext,
): (Balance<CoinTypeA>, Balance<CoinTypeB>) {
    abort 1
}

/// Collects accumulated rewards of a specific type from a position.
///
/// This function extracts the accumulated rewards of the specified type
/// from a position and returns them as a token balance.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
/// - `RewardType`: Type of reward token to collect
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Mutable reference to the position
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `Balance<RewardType>`: Collected reward balance
///
/// ## Events Emitted
/// - `CollectRewardEvent`: Contains position, reward type, and amount
///
/// ## Errors
/// - `EPositionPoolNotMatch`: If position doesn't belong to this pool
public fun collect_position_reward<CoinTypeA, CoinTypeB, RewardType>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    config: &GlobalConfig,
    versioned: &Versioned,
    ctx: &TxContext,
): (Balance<RewardType>) {
    abort 1
}

/// Closes a position and returns all underlying tokens and fees.
///
/// This function completely closes a position, removing all liquidity
/// and returning the underlying tokens plus accumulated fees.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Position to close (consumed)
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(ClosePositionCert, Balance<CoinTypeA>, Balance<CoinTypeB>, Balance<CoinTypeA>, Balance<CoinTypeB>)`: Certificate and token balances
///
/// ## Events Emitted
/// - `ClosePositionEvent`: Contains position and closure details
public fun close_position_with_fee<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: Position,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): (
    ClosePositionCert,
    Balance<CoinTypeA>,
    Balance<CoinTypeB>,
    Balance<CoinTypeA>,
    Balance<CoinTypeB>,
) {
    abort 1
}

/// Closes a position and returns all underlying tokens and fees.
///
/// This function completely closes a position, removing all liquidity
/// and returning the underlying tokens plus accumulated fees.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `position`: Position to close (consumed)
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(ClosePositionCert, Balance<CoinTypeA>, Balance<CoinTypeB>)`: Certificate and token balances
///
/// ## Events Emitted
/// - `ClosePositionEvent`: Contains position and closure details
///
/// ## Errors
/// - `EPositionPoolNotMatch`: If position doesn't belong to this pool
public fun close_position<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: Position,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
): (ClosePositionCert, Balance<CoinTypeA>, Balance<CoinTypeB>) {
    abort 1
}

/// Takes rewards of a specific type from a close position certificate.
///
/// This function extracts rewards of the specified type from a close position
/// certificate and returns them as a token balance.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
/// - `RewardType`: Type of reward token to extract
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `cert`: Mutable reference to the close position certificate
/// - `versioned`: Versioned object for compatibility check
///
/// ## Returns
/// - `Balance<RewardType>`: Extracted reward balance
public fun take_reward_from_close_position_cert<CoinTypeA, CoinTypeB, RewardType>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    cert: &mut ClosePositionCert,
    versioned: &Versioned,
): Balance<RewardType> {
    abort 1
}

/// Destroys a close position certificate.
///
/// This function destroys a close position certificate after all rewards
/// have been extracted from it.
///
/// ## Parameters
/// - `cert`: Close position certificate to destroy (consumed)
/// - `versioned`: Versioned object for compatibility check
public fun destroy_close_position_cert(cert: ClosePositionCert, versioned: &Versioned) {
    abort 1
}

/// Performs a flash swap operation.
///
/// This function allows users to borrow tokens from the pool for a single transaction,
/// with the requirement to repay the borrowed amount plus fees.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `a2b`: Whether swapping from token A to token B
/// - `by_amount_in`: Whether the amount is input amount (true) or output amount (false)
/// - `amount`: Amount to swap
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clock`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>)`: Token balances and receipt
///
/// ## Errors
/// - `EAmountInZero`: If input amount is zero
/// - `EAmountOutIsZero`: If output amount is zero
/// - `ENotEnoughLiquidity`: If insufficient liquidity for swap
public fun flash_swap<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    a2b: bool,
    by_amount_in: bool,
    amount: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &TxContext,
): (Balance<CoinTypeA>, Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
    abort 1
}

/// Repays a flash swap operation.
///
/// This function repays a flash swap by transferring tokens back to the pool.
/// It validates that the amounts match the receipt and handles token direction.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `balance_a`: Balance of token A to repay
/// - `balance_b`: Balance of token B to repay
/// - `receipt`: Flash swap receipt
/// - `versioned`: Versioned object for compatibility check
///
/// ## Errors
/// - `EFlashSwapRepayNotMatch`: If pool ID doesn't match or ref fee is non-zero
/// - `EFlashSwapRepayAmountNotCorrect`: If repay amount doesn't match receipt
public fun repay_flash_swap<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    balance_a: Balance<CoinTypeA>,
    balance_b: Balance<CoinTypeB>,
    receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>,
    versioned: &Versioned,
) {
    abort 1
}

/// Performs a flash swap operation with partner referral fees.
///
/// This function performs a flash swap with partner referral fees.
/// The partner receives a portion of the fees based on their referral rate.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `partner`: Reference to the partner for referral fees
/// - `a2b`: Whether swapping from token A to token B
/// - `by_amount_in`: Whether the amount is input amount (true) or output amount (false)
/// - `amount`: Amount to swap
/// - `config`: Global configuration
/// - `versioned`: Versioned object for compatibility check
/// - `clock`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>)`: Token balances and receipt
public fun flash_swap_with_partner<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &Partner,
    a2b: bool,
    by_amount_in: bool,
    amount: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &TxContext,
): (Balance<CoinTypeA>, Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
    abort 1
}

/// Repays a flash swap operation with partner referral fees.
///
/// This function repays a flash swap with partner referral fees.
/// The partner receives their referral fee portion from the repayment.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `partner`: Mutable reference to the partner
/// - `balance_a`: Balance of token A to repay
/// - `balance_b`: Balance of token B to repay
/// - `receipt`: Flash swap receipt
/// - `versioned`: Versioned object for compatibility check
///
/// ## Errors
/// - `EFlashSwapRepayNotMatch`: If pool ID or partner ID doesn't match
/// - `EFlashSwapRepayAmountNotCorrect`: If repay amount doesn't match receipt
public fun repay_flash_swap_with_partner<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    mut balance_a: Balance<CoinTypeA>,
    mut balance_b: Balance<CoinTypeB>,
    receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>,
    versioned: &Versioned,
) {
    abort 1
}

/// Collects accumulated protocol fees from the pool.
///
/// This function allows protocol fee managers to collect accumulated
/// protocol fees from the pool. Only authorized addresses can call this.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `config`: Global configuration for role checking
/// - `versioned`: Versioned object for compatibility check
/// - `ctx`: Transaction context
///
/// ## Returns
/// - `(Coin<CoinTypeA>, Coin<CoinTypeB>)`: Protocol fee coins
///
/// ## Events Emitted
/// - `CollectProtocolFeeEvent`: Contains pool and fee amounts
public fun collect_protocol_fee<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    config: &GlobalConfig,
    versioned: &Versioned,
    ctx: &mut TxContext,
): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
    abort 1
}

/// Collects accumulated protocol fees using a capability.
///
/// This function allows protocol fee collection using a capability
/// instead of checking the sender address directly.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `config`: Global configuration for role checking
/// - `versioned`: Versioned object for compatibility check
/// - `cap`: Protocol fee collection capability
///
/// ## Returns
/// - `(Balance<CoinTypeA>, Balance<CoinTypeB>)`: Protocol fee balances
///
/// ## Events Emitted
/// - `CollectProtocolFeeEvent`: Contains pool and fee amounts
public fun collect_protocol_fee_with_cap<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    config: &GlobalConfig,
    versioned: &Versioned,
    cap: &ProtocolFeeCollectCap,
): (Balance<CoinTypeA>, Balance<CoinTypeB>) {
    abort 1
}

/// Initializes a new reward type in the pool.
///
/// This function initializes a new reward type in the pool's reward manager.
/// The reward type must be whitelisted or be one of the pool's token types.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
/// - `CoinTypeC`: Reward token type to initialize
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `config`: Global configuration for role checking
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Events Emitted
/// - `InitializeRewardEvent`: Contains pool and reward type
///
/// ## Errors
/// - `ERewardTypeNotPermitted`: If reward type is not whitelisted or pool token
public fun initialize_reward<CoinTypeA, CoinTypeB, CoinTypeC>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &mut TxContext,
) {
    abort 1
}

/// Adds rewards to the pool.
///
/// This function adds rewards to the pool's reward manager with specified
/// emission schedule. The reward type must be initialized first.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
/// - `CoinTypeC`: Reward token type to add
///
/// ## Parameters
/// - `pool`: Mutable reference to the pool
/// - `reward_coin`: Coin containing the reward tokens
/// - `start_time`: Vector of start times for emission periods
/// - `end_time`: End time for reward emission
/// - `config`: Global configuration for role checking
/// - `versioned`: Versioned object for compatibility check
/// - `clk`: Clock for timestamp tracking
/// - `ctx`: Transaction context
///
/// ## Events Emitted
/// - `AddRewardEvent`: Contains pool, reward type, amount, and timing
public fun add_reward<CoinTypeA, CoinTypeB, CoinTypeC>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    reward_coin: Coin<CoinTypeC>,
    start_time: Option<u64>,
    end_time: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &TxContext,
) {
    abort 1
}

/// Fetches bins from the pool's bin manager.
///
/// This function retrieves bins from the pool's bin manager based on the
/// provided start index and limit.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
/// - `start`: Optional start index for bin retrieval
/// - `limit`: Maximum number of bins to retrieve
///
/// ## Returns
/// - `vector<bin::BinInfo>`: Vector of bin information
///
/// ## Errors
/// - `EBinNotExists`: If the bin doesn't exist
public fun fetch_bins<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    start: option::Option<u32>,
    limit: u64,
): vector<bin::BinInfo> {
    abort 1
}

/// Gets the amounts of tokens in the position.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
/// - `position_id`: ID of the position
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (token A amount, token B amount) in the position
public fun get_position_amounts<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    position_id: ID,
): (u64, u64) {
    abort 1
}

/// Gets the current variable fee rate for the pool.
///
/// This function returns the current variable fee rate based on market volatility.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `u128`: Current variable fee rate
public fun get_variable_fee_rate<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u128 {
    abort 1
}

/// Gets the total fee rate for the pool.
///
/// This function calculates the total fee rate by combining the base fee rate
/// with the variable fee rate, capped at the maximum fee rate.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `FeeRate`: Complete fee rate breakdown
public fun get_total_fee_rate<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): FeeRate {
    abort 1
}

/// Calculates the total fee rate.
///
/// This function calculates the total fee rate based on the variable fee rate and the base fee rate.
///
/// ## Parameters
/// - `v_parameters`: Reference to the variable parameters
/// - `base_fee_rate`: The base fee rate
///
/// ## Returns
/// - `FeeRate`: Complete fee rate breakdown
public fun calculate_total_fee_rate(
    v_parameters: &VariableParameters,
    base_fee_rate: u64,
): FeeRate {
    abort 1
}

/// Gets the amounts of tokens in the active bin.
///
/// This function returns the current amounts of both tokens in the active bin.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (token A amount, token B amount) in active bin
public fun amounts_in_active_bin<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
): (u64, u64) {
    abort 1
}

/// Gets the current active bin ID.
///
/// This function returns the ID of the current active bin in the pool.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `I32`: Current active bin ID
public fun active_id<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): I32 {
    pool.active_id
}

/// Gets the bin step of the pool.
///
/// This function returns the bin step configuration of the pool.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `u16`: Bin step value
public fun bin_step<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u16 {
    pool.v_parameters.bin_step()
}

/// Gets the current reserves of the pool.
///
/// This function returns the current balances of both tokens in the pool.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (token A balance, token B balance)
public fun reserves<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): (u64, u64) {
    abort 1
}

/// Gets the pay amount from a flash swap receipt.
///
/// This function returns the amount that needs to be repaid for a flash swap.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `receipt`: Reference to the flash swap receipt
///
/// ## Returns
/// - `u64`: Amount to be repaid
public fun pay_amount<CoinTypeA, CoinTypeB>(receipt: &FlashSwapReceipt<CoinTypeA, CoinTypeB>): u64 {
    receipt.pay_amount
}

/// Gets the amounts from an add liquidity receipt.
///
/// This function returns the amounts that were added in a liquidity operation.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `receipt`: Reference to the add liquidity receipt
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (token A amount, token B amount)
public fun amounts<CoinTypeA, CoinTypeB>(
    receipt: &AddLiquidityCert<CoinTypeA, CoinTypeB>,
): (u64, u64) {
    (receipt.total_amount_a, receipt.total_amount_b)
}

/// Gets the amounts from an open position certificate.
///
/// This function returns the amounts that were opened in a position operation.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `receipt`: Reference to the open position certificate
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (token A amount, token B amount)
public fun open_cert_amounts<CoinTypeA, CoinTypeB>(
    receipt: &OpenPositionCert<CoinTypeA, CoinTypeB>,
): (u64, u64) {
    (receipt.total_amount_a, receipt.total_amount_b)
}

/// Gets a reference to the reward manager.
///
/// This function returns a reference to the pool's reward manager.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `&RewardManager`: Reference to the reward manager
public fun reward_manager<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): &RewardManager {
    &pool.reward_manager
}

/// Gets a reference to the position manager.
///
/// This function returns a reference to the pool's position manager.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `&PositionManager`: Reference to the position manager
public fun position_manager<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
): &PositionManager {
    &pool.position_manager
}

/// Gets a reference to the bin manager.
///
/// This function returns a reference to the pool's bin manager.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `&BinManager`: Reference to the bin manager
public fun bin_manager<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): &BinManager {
    &pool.bin_manager
}

/// Gets the base fee rate of the pool.
///
/// This function returns the base fee rate of the pool.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `u64`: Base fee rate
public fun base_fee_rate<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u64 {
    pool.base_fee_rate
}

/// Gets the variable parameters of the pool.
///
/// This function returns the variable parameters of the pool.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `&VariableParameters`: Reference to the variable parameters
public fun v_parameters<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
): &VariableParameters {
    &pool.v_parameters
}

/// Gets the permissions of the pool.
///
/// This function returns the permissions of the pool.
///
/// ## Type Parameters
/// - `CoinTypeA`: First token type in the pool
/// - `CoinTypeB`: Second token type in the pool
///
/// ## Parameters
/// - `pool`: Reference to the pool
///
/// ## Returns
/// - `&Permissions`: Reference to the permissions
public fun permissions<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): &Permissions {
    &pool.permissions
}

/// Returns whether adding liquidity is disabled.
public fun disable_add(permissions: &Permissions): bool {
    permissions.disable_add
}

/// Returns whether removing liquidity is disabled.
public fun disable_remove(permissions: &Permissions): bool {
    permissions.disable_remove
}

/// Returns whether swap operations are disabled.
public fun disable_swap(permissions: &Permissions): bool {
    permissions.disable_swap
}

/// Returns whether fee collection is disabled.
public fun disable_collect_fee(permissions: &Permissions): bool {
    permissions.disable_collect_fee
}

/// Returns whether reward collection is disabled.
public fun disable_collect_reward(permissions: &Permissions): bool {
    permissions.disable_collect_reward
}

/// Returns whether adding rewards is disabled.
public fun disable_add_reward(permissions: &Permissions): bool {
    permissions.disable_add_reward
}

/// Gets the amounts from the position detail.
///
/// ## Parameters
/// - `position_detail`: Reference to the position detail
///
/// ## Returns
/// - `(u64, u64)`: The amounts
public fun position_detail_amounts(position_detail: &PositionDetail): (u64, u64) {
    (position_detail.amount_a, position_detail.amount_b)
}

/// Gets the fees from the position detail.
///
/// ## Parameters
/// - `position_detail`: Reference to the position detail
///
/// ## Returns
/// - `(u64, u64)`: The fees
public fun position_detail_fees(position_detail: &PositionDetail): (u64, u64) {
    (position_detail.fee_a, position_detail.fee_b)
}

/// Gets the rewards from the position detail.
///
/// ## Parameters
/// - `position_detail`: Reference to the position detail
///
/// ## Returns
/// - `&VecMap<TypeName, u64>`: The rewards
public fun position_detail_rewards(position_detail: &PositionDetail): &VecMap<TypeName, u64> {
    &position_detail.rewards
}

/// Gets the update transaction from the position detail.
///
/// ## Parameters
/// - `position_detail`: Reference to the position detail
///
/// ## Returns
/// - `&vector<u8>`: The update transaction
public fun position_detail_update_tx(position_detail: &PositionDetail): &vector<u8> {
    &position_detail.update_tx
}

/// Gets the position ID from the position detail.
///
/// ## Parameters
/// - `position_detail`: Reference to the position detail
///
/// ## Returns
/// - `ID`: The position ID
public fun position_detail_position_id(position_detail: &PositionDetail): ID {
    position_detail.position_id
}
