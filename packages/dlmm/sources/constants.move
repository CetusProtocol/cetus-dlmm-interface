// Copyright (c) Cetus Technology Limited
module cetusdlmm::constants;

/// Returns the scale offset used for mathematical calculations.
///
/// ## Returns
/// - `u8`: The scale offset value (64)
public macro fun scale_offset(): u8 {
    64
}

/// Returns the default URI for pool metadata.
///
/// ## Returns
/// - `vector<u8>`: The default pool metadata URI
public macro fun pool_default_uri(): vector<u8> {
    b"https://node1.irys.xyz/yKfgcB2yEJ1JZSeGm_eXAD0d34a3Wx7tcomS502ZKT8"
}

/// Returns the fee precision used for calculations.
///
/// ## Returns
/// - `u64`: The fee precision value (1,000,000,000)
public macro fun fee_precision(): u64 {
    1_000_000_000
}

/// Returns the squared fee precision used for advanced calculations.
///
/// ## Returns
/// - `u128`: The squared fee precision value (1,000,000,000,000,000,000)
public macro fun fee_precision_square(): u128 {
    1_000_000_000_000_000_000
}

/// Returns the maximum allowed fee rate in the protocol.
///
/// ## Returns
/// - `u64`: The maximum fee rate (100,000,000 = 10%)
public macro fun max_fee_rate(): u64 {
    100_000_000
}

/// Returns the standard basis point value used throughout the protocol.
///
/// ## Returns
/// - `u64`: The basis point value (10,000 = 100%)
public macro fun basis_point(): u64 {
    10000
}

/// Returns the maximum number of rewards that can be distributed per position.
///
/// ## Returns
/// - `u64`: The maximum number of rewards (5)
public macro fun max_reward_num(): u64 {
    5
}

/// Returns the maximum allowed protocol fee rate.
///
/// ## Returns
/// - `u64`: The maximum protocol fee rate (300,000,000 = 30%)
public macro fun max_protocol_fee_rate(): u64 {
    300_000_000
}

/// Returns the maximum value for 24-bit unsigned integer.
///
/// ## Returns
/// - `u32`: The maximum 24-bit value (0xffffff)
public macro fun u24_max(): u32 {
    0xffffff
}

/// Returns the maximum allowed partner fee rate.
///
/// ## Returns
/// - `u64`: The maximum partner fee rate (1,000,000,000 = 100%)
public macro fun max_partner_fee_rate(): u64 {
    1_000_000_000
}

/// Returns the maximum number of bins allowed per position.
///
/// ## Returns
/// - `u16`: The maximum bins per position (1000)
public macro fun max_bin_per_position(): u16 {
    1000
}

/// Returns the reward distribution period in seconds.
///
/// ## Returns
/// - `u64`: The reward period in seconds (7 days = 604,800 seconds)
public macro fun reward_period(): u64 {
    7 * 24 * 60 * 60
}

/// Returns the start timestamp for reward periods.
///
/// ## Returns
/// - `u64`: The Unix timestamp when reward periods begin
public macro fun reward_period_start_at(): u64 {
    1757332800
}

/// Returns the maximum number of bins in a group.
///
/// ## Returns
/// - `u8`: The maximum bins per group (16)
public macro fun max_bin_per_group(): u8 {
    16
}

/// Returns the version of the package that requires an emergency pause
///
/// ## Returns
/// - `u64`: The version of the package that requires an emergency pause
public macro fun emergency_pause_version(): u64 {
    9223372036854775808
}

/// Returns the maximum bin step.
///
/// ## Returns
/// - `u16`: The maximum bin step (1000)
public macro fun max_bin_step(): u16 {
    1000
}