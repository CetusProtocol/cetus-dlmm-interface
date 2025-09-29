// Copyright (c) Cetus Technology Limited

/// # Reward Management Module
///
/// This module provides reward management functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles reward distribution, emission rate management, and reward tracking for liquidity providers.
#[allow(unused_variable, unused_function, unused_const, unused_type_parameter)]
module cetusdlmm::reward;

use integer_mate::i128::{I128};
use move_stl::skip_list::{SkipList};
use std::type_name::{TypeName};
use sui::bag::{Bag};

/// ## Error Codes
///
/// - `ERewardAlreadyExists`: Reward type already initialized
/// - `ERewardSlotIsFull`: Maximum number of rewards reached
/// - `ERewardNotFound`: Reward type not found
/// - `ESettleRewardAbort`: Reward settlement failed
/// - `ERewardNotEnough`: Insufficient reward balance
/// - `ERewardRateOverflow`: Emission rate overflow
/// - `EInvalidRewardStartTime`: Invalid reward start time
/// - `EInvalidRewardEndTime`: Invalid reward end time
/// - `ERewardRateUnderflow`: Emission rate underflow
/// - `EInvalidCurrentTime`: Invalid current time
/// - `ERewardEmergencyPause`: Reward emergency pause
#[error]
const ERewardAlreadyExists: vector<u8> = b"Reward already exists";
#[error]
const ERewardSlotIsFull: vector<u8> = b"Reward slot is full";
#[error]
const ERewardNotFound: vector<u8> = b"Reward not found";
#[error]
const ESettleRewardAbort: vector<u8> = b"Settle reward abort";
#[error]
const ERewardNotEnough: vector<u8> = b"Reward not enough";
#[error]
const ERewardRateOverflow: vector<u8> = b"Reward rate overflow";
#[error]
const EInvalidRewardStartTime: vector<u8> = b"Invalid reward start time";
#[error]
const EInvalidRewardEndTime: vector<u8> = b"Invalid reward end time";
#[error]
const ERewardRateUnderflow: vector<u8> = b"Reward rate underflow";
#[error]
const EInvalidCurrentTime: vector<u8> = b"Invalid current time";
#[error]
const ERewardEmergencyPause: vector<u8> = b"Reward emergency pause";
#[error]
const ERewardRefundedOverflow: vector<u8> = b"Reward refunded overflow";

/// Main reward manager that handles reward distribution and tracking.
///
/// This struct manages all reward-related operations including emission rates,
/// reward vaults, and time-based settlements.
///
/// ## Fields
/// - `is_public`: Whether the reward manager is publicly accessible
/// - `vault`: Bag containing reward balances for different token types
/// - `rewards`: Vector of reward configurations and states
/// - `last_updated_time`: Timestamp of last reward settlement
public struct RewardManager has store {
    is_public: bool,
    vault: Bag,
    rewards: vector<Reward>,
    last_updated_time: u64,
    emergency_reward_pause: bool,
}

/// Individual reward configuration and state tracking.
///
/// This struct tracks the state of a specific reward type including
/// emission rates, released amounts, and harvesting statistics.
///
/// ## Fields
/// - `reward_coin`: Type name of the reward token
/// - `current_emission_rate`: Current emission rate in Q64x64 format
/// - `period_emission_rates`: Skip list tracking emission rate changes over time
/// - `reward_released`: Total amount of rewards released to liquidity providers, for statistics
/// - `reward_refunded`: Total amount of rewards refunded due to zero liquidity, for statistics. If the reward is released, but the liquidity is zero, the reward will be refund and accumulated
/// - `reward_harvested`: Total amount of rewards harvested by users, for statistics
public struct Reward has store {
    reward_coin: TypeName,
    current_emission_rate: u128,
    period_emission_rates: SkipList<I128>,
    reward_released: u256,
    reward_refunded: u128,
    reward_harvested: u128,
}
/// Borrows a reward from the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
/// - `idx`: Index of the reward to borrow
///
/// ## Returns
public fun borrow_reward(manager: &RewardManager, idx: u64): &Reward {
    abort 1
}


/// Borrows a reward from the reward manager by type.
///
/// ## Type Parameters
/// - `RewardType`: The reward token type to borrow
///
/// ## Parameters
public fun borrow_reward_by_type<RewardType>(manager: &RewardManager): &Reward {
    abort 1
}

/// Gets the vault amount for a specific reward type.
///
/// ## Type Parameters
/// - `RewardType`: The reward token type
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `u64`: Amount of rewards in the vault for the specified type
///
/// ## Errors
/// - `ERewardNotFound`: If the reward type is not found
public fun vault_amount<RewardType>(manager: &RewardManager): u64 {
    abort 1
}

/// Gets the index of a reward type in the rewards vector.
///
/// ## Type Parameters
/// - `RewardType`: The reward token type to find
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `Option<u64>`: Some(index) if found, None if not found
public fun reward_index<RewardType>(manager: &RewardManager): Option<u64> {
   abort 1
}

/// Gets the index of a reward type, asserting it exists.
///
/// ## Type Parameters
/// - `RewardType`: The reward token type to find
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `u64`: Index of the reward type
///
/// ## Errors
/// - `ERewardNotFound`: If the reward type is not found
public fun get_index<RewardType>(manager: &RewardManager): u64 {
    abort 1
}

/// Gets the public status of the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `bool`: `true` if the reward manager is public, `false` otherwise
public fun is_public(manager: &RewardManager): bool {
    manager.is_public
}

/// Gets the last updated time of the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `u64`: Timestamp of the last reward settlement
public fun last_update_time(manager: &RewardManager): u64 {
    manager.last_updated_time
}

/// Gets the rewards vector from the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `&vector<Reward>`: Reference to the rewards vector
public fun rewards(manager: &RewardManager): &vector<Reward> {
    &manager.rewards
}

/// Gets the number of rewards from the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `u64`: Number of rewards
public fun reward_num(manager: &RewardManager): u64 {
    manager.rewards.length()
}

/// Gets the vault from the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `&Bag`: Reference to the vault
public fun vault(manager: &RewardManager): &Bag {
    &manager.vault
}

/// Gets the emergency reward pause status of the reward manager.
///
/// ## Parameters
/// - `manager`: Reference to the reward manager
///
/// ## Returns
/// - `bool`: `true` if the emergency reward pause is enabled, `false` otherwise
public fun emergency_reward_pause(manager: &RewardManager): bool {
    manager.emergency_reward_pause
}

/// Gets the reward coin type from the reward.
///
/// ## Parameters
/// - `reward`: Reference to the reward
///
/// ## Returns
/// - `TypeName`: Type name of the reward coin
public fun reward_coin(reward: &Reward): TypeName {
    reward.reward_coin
}

/// Gets the released amount of rewards from the reward.
///
/// ## Parameters
/// - `reward`: Reference to the reward
///
/// ## Returns
/// - `u256`: Released amount of rewards
public fun reward_released(reward: &Reward): u256 {
    reward.reward_released
}

/// Gets the refunded amount of rewards from the reward.
///
/// ## Parameters
/// - `reward`: Reference to the reward
///
/// ## Returns
/// - `u128`: Refunded amount of rewards
public fun reward_refunded(reward: &Reward): u128 {
    reward.reward_refunded
}

/// Gets the harvested amount of rewards from the reward.
///
/// ## Parameters
/// - `reward`: Reference to the reward
///
/// ## Returns
/// - `u128`: Harvested amount of rewards
public fun reward_harvested(reward: &Reward): u128 {
    reward.reward_harvested
}

/// Gets the current emission rate of the reward.
///
/// ## Parameters
/// - `reward`: Reference to the reward
///
/// ## Returns
/// - `u128`: Current emission rate
public fun current_emission_rate(reward: &Reward): u128 {
    reward.current_emission_rate
}

/// Gets the period emission rates of the reward.
///
/// ## Parameters
/// - `reward`: Reference to the reward
///
/// ## Returns
/// - `&SkipList<I128>`: Reference to the period emission rates
public fun period_emission_rates(reward: &Reward): &SkipList<I128> {
    &reward.period_emission_rates
}