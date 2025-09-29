// Copyright (c) Cetus Technology Limited

/// # Configuration Management Module
///
/// This module provides global configuration management for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles access control, bin configurations, restrictions, and rewward config management for the protocol.
#[allow(unused_variable, unused_function, unused_const, unused_field, unused_type_parameter)]
module cetusdlmm::config;

use cetusdlmm::acl;
use cetusdlmm::restriction::{Self, OperationKind};
use std::type_name::{TypeName};
use sui::coin::CoinMetadata;
use sui::table::{Table};
use sui::vec_map::{VecMap};

/// ## Error Codes
///
/// - `EInvalidRoleCode`: Invalid role code provided
/// - `ENoRestrictionManagerPermission`: No restriction manager permission
/// - `EUserIsBlocked`: User is blocked from operation
/// - `EPositionIsBlocked`: Position is blocked from operation
/// - `EBinConfigAlreadyExist`: Bin config already exists
/// - `EBinConfigNotExists`: Bin config doesn't exist
/// - `EInvalidBinStep`: Invalid bin step value
/// - `ECoinAlreadyExistsInList`: Coin already exists in list
/// - `ECoinNotExistsInList`: Coin doesn't exist in list
/// - `ENoPoolManagerPermission`: No pool manager permission
/// - `ENoConfigManagerPermission`: No config manager permission
/// - `ENoProtocolFeeManagerPermission`: No protocol fee manager permission
/// - `ENoPartnerManagerPermission`: No partner manager permission
/// - `ENoRewardManagerPermission`: No reward manager permission
/// - `EInvalidProtocolFeeRate`: Invalid protocol fee rate
/// - `EInvalidBinCfg`: Invalid bin configuration
/// - `ERewardExistsInWhiteList`: Reward already in whitelist
/// - `ERewardNotInWhiteList`: Reward not in whitelist
/// - `EAddLiquidityWhiteListNotExists`: Add liquidity white list not exists
/// - `EAddressNotInAddLiquidityWhiteList`: Address not in add liquidity white list
/// - `ENoEmergencyPauseManagerPermission`: No emergency pause manager permission
#[error]
const EInvalidRoleCode: vector<u8> = b"Invalid role code";
#[error]
const ENoRestrictionManagerPermission: vector<u8> = b"No restriction manager permission";
#[error]
const EUserIsBlocked: vector<u8> = b"User is blocked";
#[error]
const EPositionIsBlocked: vector<u8> = b"Position is blocked";
#[error]
const EBinConfigAlreadyExist: vector<u8> = b"Bin config already exist";
#[error]
const EBinConfigNotExists: vector<u8> = b"Bin config not exists";
#[error]
const EInvalidBinStep: vector<u8> = b"Invalid bin step";
#[error]
const ECoinAlreadyExistsInList: vector<u8> = b"Coin already exists in list";
#[error]
const ECoinNotExistsInList: vector<u8> = b"Coin not exists in list";
#[error]
const ENoPoolManagerPermission: vector<u8> = b"No pool manager permission";
#[error]
const ENoConfigManagerPermission: vector<u8> = b"No config manager permission";
#[error]
const ENoProtocolFeeManagerPermission: vector<u8> = b"No protocol fee manager permission";
#[error]
const ENoPartnerManagerPermission: vector<u8> = b"No partner manager permission";
#[error]
const ENoRewardManagerPermission: vector<u8> = b"No reward manager permission";
#[error]
const EInvalidProtocolFeeRate: vector<u8> = b"Invalid protocol fee rate";
#[error]
const EInvalidBinCfg: vector<u8> = b"Invalid bin cfg";
#[error]
const ERewardExistsInWhiteList: vector<u8> = b"Reward exists in white list";
#[error]
const ERewardNotInWhiteList: vector<u8> = b"Reward not in white list";
#[error]
const ENoEmergencyPauseManagerPermission: vector<u8> = b"No emergency pause manager permission";
#[error]
const EProtocolAlreadyEmergencyPause: vector<u8> = b"Protocol already emergency pause";
#[error]
const EProtocolNotEmergencyPause: vector<u8> = b"Protocol not emergency pause";
#[error]
const EInvalidPackageVersion: vector<u8> = b"Invalid package version";

/// Main configuration struct containing all protocol settings and access controls.
///
/// This struct manages the global state of the DLMM protocol including:
/// - Access control lists for different roles
/// - Bin step configurations
/// - Token allow/deny lists
/// - User and position restrictions
/// - Reward token whitelists
///
/// ## Fields
/// - `id`: Unique identifier for the config object
/// - `acl`: Access control list for role management
/// - `bin_steps`: Table of bin step configurations
/// - `denied_list`: Table of denied token types
/// - `allowed_list`: Table of allowed token types
/// - `restriction`: Restriction management for users and positions
/// - `before_version`: version before emergency pause
public struct GlobalConfig has key, store {
    id: UID,
    acl: acl::ACL,
    bin_steps: Table<BinConfigKey, BinStepConfig>,
    denied_list: Table<TypeName, bool>,
    allowed_list: Table<TypeName, bool>,
    restriction: restriction::Restriction,
    reward_config: RewardConfig,
    before_version: u64,
}

/// Reward configuration for the protocol.
///
/// This struct contains the configuration for reward distribution including:
/// - Whitelist of allowed reward tokens
/// - Minimum reward duration
/// - Manager reserved reward init slots
/// - Whether the reward is public
public struct RewardConfig has copy, drop, store {
    reward_white_list: VecMap<TypeName, bool>,
    min_reward_duration: u64,
    manager_reserved_reward_init_slots: u8,
    reward_public: bool,
}

/// Key for identifying bin step configurations.
///
/// ## Fields
/// - `bin_step`: The bin step value
/// - `base_factor`: The base factor for the configuration
public struct BinConfigKey has copy, drop, store {
    bin_step: u16,
    base_factor: u16,
}

/// Configuration parameters for a specific bin step.
///
/// This struct contains all the parameters needed to configure a bin step,
/// including fee controls, volatility settings, and protocol fees.
///
/// ## Fields
/// - `bin_step`: The bin step value
/// - `base_factor`: Base factor for calculations
/// - `filter_period`: Period for filtering operations
/// - `decay_period`: Period for decay calculations
/// - `reduction_factor`: Factor for fee reductions
/// - `variable_fee_control`: Control parameter for variable fees
/// - `max_volatility_accumulator`: Maximum volatility accumulator value
/// - `protocol_fee_rate`: Protocol fee rate in basis points
public struct BinStepConfig has copy, drop, store {
    bin_step: u16,
    base_factor: u16,
    filter_period: u16,
    decay_period: u16,
    reduction_factor: u16,
    variable_fee_control: u32,
    max_volatility_accumulator: u32,
    protocol_fee_rate: u64,
}

/// Checks if a member has the reward manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Returns
/// - `bool`: `true` if the member has the reward manager role, `false` otherwise
public fun has_reward_manager_role(config: &GlobalConfig, member: address): bool {
    abort 1
}

/// Checks if a user is blocked from performing a specific operation.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `user`: Address of the user to check
/// - `operation`: Type of operation to check
///
/// ## Errors
/// - `EUserIsBlocked`: If the user is blocked from the operation
public fun check_user_operation(config: &GlobalConfig, user: address, operation: OperationKind) {
    abort 1
}

/// Checks if a position is blocked from performing a specific operation.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `position`: ID of the position to check
/// - `operation`: Type of operation to check
///
/// ## Errors
/// - `EPositionIsBlocked`: If the position is blocked from the operation
public fun check_position_operation(config: &GlobalConfig, position: ID, operation: OperationKind) {
    abort 1
}

/// Checks if a member has the pool manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoPoolManagerPermission`: If the member doesn't have pool manager permission
public fun check_pool_manager_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Checks if a member has the config manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoConfigManagerPermission`: If the member doesn't have config manager permission
public fun check_config_manager_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Checks if a member has the protocol fee manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoProtocolFeeManagerPermission`: If the member doesn't have protocol fee manager permission
public fun check_protocol_fee_manager_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Checks if a member has the partner manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoPartnerManagerPermission`: If the member doesn't have partner manager permission
public fun check_partner_manager_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Checks if a member has the reward manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoRewardManagerPermission`: If the member doesn't have reward manager permission
public fun check_reward_manager_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Checks if a member has the restriction manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoRestrictionManagerPermission`: If the member doesn't have restriction manager permission
public fun check_restriction_manager_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Checks if a member has the emergency pause manager role.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `member`: Address of the member to check
///
/// ## Errors
/// - `ENoEmergencyPauseManagerPermission`: If the member doesn't have emergency pause manager permission
public fun check_emergency_pause_role(config: &GlobalConfig, member: address) {
    abort 1
}

/// Gets the minimum reward duration.
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `u64`: The minimum reward duration
public fun min_reward_duration(config: &GlobalConfig): u64 {
    config.reward_config.min_reward_duration
}

/// Gets the manager reserved reward init slots.
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `u8`: The manager reserved reward init slots
public fun manager_reserved_reward_init_slots(config: &GlobalConfig): u8 {
    config.reward_config.manager_reserved_reward_init_slots
}

/// Checks if the reward manager is public.
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `bool`: `true` if the reward manager is public, `false` otherwise
public fun is_reward_public(config: &GlobalConfig): bool { config.reward_config.reward_public }

/// Gets the reward white list.
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `&VecMap<TypeName, bool>`: Reference to the reward white list
public fun reward_white_list(config: &GlobalConfig): VecMap<TypeName, bool> {
    abort 1
}

/// Gets the bin step configuration for a specific bin step and base factor.
///
/// ## Parameters
/// - `config`: Reference to the global config
/// - `bin_step`: The bin step value
/// - `base_factor`: The base factor value
///
/// ## Returns
/// - `BinStepConfig`: The configuration for the specified bin step
///
/// ## Errors
/// - `EBinConfigNotExists`: If the bin config doesn't exist
public fun get_bin_step_config(
    config: &GlobalConfig,
    bin_step: u16,
    base_factor: u16,
): BinStepConfig {
    abort 1
}

/// Checks if a coin type is in the allowed list.
///
/// ## Type Parameters
/// - `Coin`: The coin type to check
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `bool`: `true` if the coin is in the allowed list, `false` otherwise
public fun in_allowed_list<Coin>(config: &GlobalConfig): bool {
    abort 1
}

/// Checks if a coin type is in the denied list.
///
/// ## Type Parameters
/// - `Coin`: The coin type to check
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `bool`: `true` if the coin is in the denied list, `false` otherwise
public fun in_denied_list<Coin>(config: &GlobalConfig): bool {
    abort 1
}

/// Checks if a coin is allowed to be used in the protocol.
///
/// ## Type Parameters
/// - `Coin`: The coin type to check
///
/// ## Parameters
/// - `config`: Mutable reference to the global config
///
/// ## Returns
/// - `bool`: `true` if the coin is allowed to be used in the protocol, `false` otherwise
public fun is_allowed_coin<Coin>(config: &GlobalConfig, _metadata: &CoinMetadata<Coin>): bool {
    abort 1
}

/// Gets the bin step for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u16`: The bin step for the bin step configuration
public fun bin_step(bin_step_config: &BinStepConfig): u16 { bin_step_config.bin_step }

/// Gets the base factor for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u16`: The base factor for the bin step
public fun base_factor(bin_step_config: &BinStepConfig): u16 { bin_step_config.base_factor }

/// Gets the filter period for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u16`: The filter period for the bin step
public fun filter_period(bin_step_config: &BinStepConfig): u16 { bin_step_config.filter_period }

/// Gets the decay period for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u16`: The decay period for the bin step
public fun decay_period(bin_step_config: &BinStepConfig): u16 { bin_step_config.decay_period }

/// Gets the reduction factor for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u16`: The reduction factor for the bin step
public fun reduction_factor(bin_step_config: &BinStepConfig): u16 {
    bin_step_config.reduction_factor
}

/// Gets the variable fee control for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u32`: The variable fee control for the bin step
public fun variable_fee_control(bin_step_config: &BinStepConfig): u32 {
    bin_step_config.variable_fee_control
}

/// Gets the max volatility accumulator for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u32`: The max volatility accumulator for the bin step
public fun max_volatility_accumulator(bin_step_config: &BinStepConfig): u32 {
    bin_step_config.max_volatility_accumulator
}

/// Gets the protocol fee rate for a bin step configuration.
///
/// ## Parameters
/// - `bin_step_config`: Reference to the bin step configuration
///
/// ## Returns
/// - `u64`: The protocol fee rate for the bin step
public fun protocol_fee_rate(bin_step_config: &BinStepConfig): u64 {
    bin_step_config.protocol_fee_rate
}

/// Checks if a reward type is in the whitelist.
///
/// ## Type Parameters
/// - `RewardType`: The reward type to check
///
/// ## Parameters
/// - `config`: Reference to the global config
///
/// ## Returns
/// - `bool`: `true` if the reward type is in the whitelist, `false` otherwise
public fun is_whitelist<RewardType>(config: &GlobalConfig): bool {
    abort 1
}
