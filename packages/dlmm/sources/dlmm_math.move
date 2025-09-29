// Copyright (c) Cetus Technology Limited

/// # DLMM Mathematics Module
///
/// This module provides the core mathematical functions for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It implements precise calculations for swaps, fees, liquidity, and growth tracking using fixed-point arithmetic.
///

module cetusdlmm::dlmm_math;

use cetusdlmm::constants::{scale_offset, fee_precision_square, fee_precision, max_fee_rate};
use integer_mate::full_math_u128;
use integer_mate::full_math_u64;

/// ## Error Codes
///
/// - `EAmountOverflow`: Amount calculation resulted in overflow
/// - `ELiquidityOverflow`: Liquidity calculation resulted in overflow
/// - `EInvalidFeeRatePrecision`: Fee rate exceeds precision limit
/// - `EInvalidFeeRate`: Fee rate exceeds maximum allowed
/// - `EInvalidDeltaLiquidity`: Delta liquidity exceeds supply
/// - `EInvalidLiquidity`: Liquidity value is invalid
/// - `EPriceIsZero`: Price cannot be zero
/// - `EAmountInOverflow`: Amount in calculation overflow
/// - `EAmountOutOverflow`: Amount out calculation overflow
/// - `ELiquiditySupplyIsZero`: Liquidity supply cannot be zero
/// - `EInvalidFeeAmount`: Fee amount is invalid
#[error]
const EAmountOverflow: vector<u8> = b"Amount overflow";
#[error]
const ELiquidityOverflow: vector<u8> = b"Liquidity overflow";
#[error]
const EInvalidFeeRatePrecision: vector<u8> = b"Invalid fee rate precision";
#[error]
const EInvalidFeeRate: vector<u8> = b"Invalid fee rate";
#[error]
const EInvalidDeltaLiquidity: vector<u8> = b"Invalid delta liquidity";
#[error]
const EInvalidLiquidity: vector<u8> = b"Invalid liquidity";
#[error]
const EPriceIsZero: vector<u8> = b"Price is zero";
#[error]
const EAmountInOverflow: vector<u8> = b"Amount in overflow";
#[error]
const EAmountOutOverflow: vector<u8> = b"Amount out overflow";
#[error]
const ELiquiditySupplyIsZero: vector<u8> = b"Liquidity supply is zero";
#[error]
const EInvalidFeeAmount: vector<u8> = b"Invalid fee amount";

/// Calculates the input amount needed to get a specific output amount.
///
/// This function calculates how much of the input token is needed to receive
/// the specified output amount, considering the bin's price and swap direction.
/// The result is ceiling-rounded to ensure sufficient input.
///
/// ## Mathematical Formula
/// - **A → B**: `amount_in = amount_out / price`
/// - **B → A**: `amount_in = amount_out * price`
///
/// ## Parameters
/// - `amount_out`: The desired output amount
/// - `price`: The bin's price in Q64x64 format
/// - `a2b`: `true` for token A to token B swap, `false` for token B to token A
///
/// ## Returns
/// - `u64`: The required input amount (ceiling-rounded)
///
/// ## Errors
/// - `EPriceIsZero`: If the price is zero
/// - `EAmountInOverflow`: If the calculation results in overflow
public fun calculate_amount_in(amount_out: u64, price: u128, a2b: bool): u64 {
    assert!(price > 0, EPriceIsZero);
    if (amount_out == 0) {
        return 0
    };
    let r = if (a2b) {
        // (amount_y << SCALE_OFFSET) / price
        // Convert amount_y into Q64x0, if not the result will always in 0 as price is in Q64x64
        // Division between same Q number format cancel out, result in integer
        // amount_y / price = amount_in_token_x (integer [Rounding::Down])
        full_math_u128::mul_div_ceil(amount_out as u128, 1u128 << scale_offset!(), price)
    } else {
        // (Q64x64(price) * Q64x0(amount_x)) >> SCALE_OFFSET
        // price * amount_x = amount_in_token_y (Q64x64)
        // amount_in_token_y >> SCALE_OFFSET (convert it back to integer form [Rounding::Down])
        full_math_u128::mul_div_ceil(amount_out as u128, price, 1u128 << scale_offset!())
    };
    assert!(r < std::u64::max_value!() as u128, EAmountInOverflow);
    r as u64
}

/// Calculates the output amount for a given input amount.
///
/// This function calculates how much of the output token will be received for
/// a given input amount, considering the bin's price and swap direction.
/// The result is floor-rounded to ensure the bin has sufficient liquidity.
///
/// ## Mathematical Formula
/// - **A → B**: `amount_out = amount_in * price`
/// - **B → A**: `amount_out = amount_in / price`
///
/// ## Parameters
/// - `amount_in`: The input amount
/// - `price`: The bin's price in Q64x64 format
/// - `a2b`: `true` for token A to token B swap, `false` for token B to token A
///
/// ## Returns
/// - `u64`: The output amount (floor-rounded)
///
/// ## Errors
/// - `EPriceIsZero`: If the price is zero
/// - `EAmountOutOverflow`: If the calculation results in overflow
public fun calculate_amount_out(amount_in: u64, price: u128, a2b: bool): u64 {
    assert!(price > 0, EPriceIsZero);
    if (amount_in == 0) {
        return 0
    };
    let r = if (a2b) {
        // (Q64x64(price) * Q64x0(amount_in)) >> SCALE_OFFSET
        // price * amount_in = amount_out_token_y (Q64x64)
        // amount_out_in_token_y >> SCALE_OFFSET (convert it back to integer form, with some loss of precision [Rounding::Down])
        full_math_u128::mul_div_floor(amount_in as u128, price, 1u128 << scale_offset!())
    } else {
        // (amount_in << SCALE_OFFSET) / price
        // Convert amount_in into Q64x0, if not the result will always in 0 as price is in Q64x64
        // Division between same Q number format cancel out, result in integer
        // amount_in / price = amount_out_token_x (integer [Rounding::Down])
        full_math_u128::mul_div_floor(amount_in as u128, 1u128 << scale_offset!(), price)
    };
    assert!(r < std::u64::max_value!() as u128, EAmountOutOverflow);
    r as u64
}

/// Calculates the fee amount using inclusive fee calculation.
///
/// In inclusive fee calculation, the fee is added to the input amount.
/// The result is ceiling-rounded to ensure sufficient payment.
///
/// ## Mathematical Formula
/// `fee_amount = ceil(amount * fee_rate / fee_precision)`
///
/// ## Parameters
/// - `amount`: The base amount to calculate fee from
/// - `fee_rate`: The fee rate in basis points
///
/// ## Returns
/// - `u64`: The fee amount (ceiling-rounded)
///
/// ## Errors
/// - `EInvalidFeeRatePrecision`: If fee rate exceeds precision limit
public fun calculate_fee_inclusive(amount: u64, fee_rate: u64): u64 {
    assert!(fee_rate <= fee_precision!(), EInvalidFeeRatePrecision);
    if (amount == 0 || fee_rate == 0) {
        return 0
    };
    full_math_u64::mul_div_ceil(amount, fee_rate, fee_precision!())
}

/// Calculates the fee amount using exclusive fee calculation.
///
/// In exclusive fee calculation, the fee is calculated from the input amount.
/// The result is ceiling-rounded to ensure sufficient payment.
///
/// ## Mathematical Formula
/// `fee_amount = ceil(amount * fee_rate / (fee_precision - fee_rate))`
///
/// ## Parameters
/// - `amount`: The base amount to calculate fee from
/// - `fee_rate`: The fee rate in basis points
///
/// ## Returns
/// - `u64`: The fee amount (ceiling-rounded)
///
/// ## Errors
/// - `EInvalidFeeRatePrecision`: If fee rate exceeds precision limit
public fun calculate_fee_exclusive(amount: u64, fee_rate: u64): u64 {
    assert!(fee_rate < fee_precision!(), EInvalidFeeRatePrecision);
    if (amount == 0 || fee_rate == 0) {
        return 0
    };
    full_math_u64::mul_div_ceil(amount, fee_rate, fee_precision!() - fee_rate)
}

/// Calculates liquidity using the constant sum formula.
///
/// This function calculates the total liquidity value based on the amounts
/// of both tokens and the bin's price using the constant sum formula.
///
/// ## Mathematical Formula
/// `L = price * amount_a + amount_b`
///
/// Where:
/// - `L` = Total liquidity
/// - `price` = Bin price in Q64x64 format
/// - `amount_a` = Amount of token A
/// - `amount_b` = Amount of token B
///
/// ## Parameters
/// - `amount_a`: Amount of token A
/// - `amount_b`: Amount of token B
/// - `price`: Bin price in Q64x64 format
///
/// ## Returns
/// - `u128`: Total liquidity value
///
/// ## Errors
/// - `EPriceIsZero`: If the price is zero
/// - `ELiquidityOverflow`: If the calculation results in overflow
public fun calculate_liquidity_by_amounts(amount_a: u64, amount_b: u64, price: u128): u128 {
    assert!(price > 0, EPriceIsZero);
    if (amount_a == 0 && amount_b == 0) {
        return 0
    };
    let liquidity =
        full_math_u128::full_mul(amount_a as u128, price) + (amount_b as u256 << scale_offset!());
    assert!(liquidity < std::u128::max_value!() as u256, ELiquidityOverflow);
    liquidity as u128
}

/// Calculates token amounts from a given liquidity delta.
///
/// This function calculates how much of each token corresponds to a given
/// liquidity delta, proportional to the current bin composition.
/// The result is floor-rounded to ensure the bin has sufficient tokens.
///
/// ## Mathematical Formula
/// ```
/// amount_a_out = floor(amount_a * delta_liquidity / liquidity_share)
/// amount_b_out = floor(amount_b * delta_liquidity / liquidity_share)
/// ```
///
/// ## Parameters
/// - `amount_a`: Current amount of token A in the bin
/// - `amount_b`: Current amount of token B in the bin
/// - `delta_liquidity`: The liquidity delta to calculate amounts for
/// - `liquidity_share`: Total liquidity share in the bin
///
/// ## Returns
/// - `(u64, u64)`: Tuple of (amount_a, amount_b) corresponding to the liquidity delta
///
/// ## Errors
/// - `ELiquiditySupplyIsZero`: If liquidity supply is zero
/// - `EInvalidDeltaLiquidity`: If delta liquidity exceeds supply
public fun calculate_amounts_by_liquidity(
    amount_a: u64,
    amount_b: u64,
    delta_liquidity: u128,
    liquidity_share: u128,
): (u64, u64) {
    assert!(liquidity_share > 0, ELiquiditySupplyIsZero);
    assert!(delta_liquidity <= liquidity_share, EInvalidDeltaLiquidity);
    if (delta_liquidity == 0) {
        return (0, 0)
    };

    let out_amount_a = if (amount_a == 0) { 0 } else {
        full_math_u128::mul_div_floor(
            amount_a as u128,
            delta_liquidity,
            liquidity_share,
        )
    };
    let out_amount_b = if (amount_b == 0) { 0 } else {
        full_math_u128::mul_div_floor(
            amount_b as u128,
            delta_liquidity,
            liquidity_share,
        )
    };
    (out_amount_a as u64, out_amount_b as u64)
}

/// Calculates the composition fee for swap amounts.
///
/// This function implements a complex fee calculation that includes both
/// linear and quadratic components. The maximum fee rate is 10%.
///
/// ## Mathematical Formula
/// ```
/// r = fee_rate
/// p = fee_rate_precision
/// a = amount
/// R = fee_rate / fee_rate_precision = r / p
///
/// fee_amount = (a * R) + (a * R^2)
///  = (a * (r/p)) + (a * (r/p)^2)
///  = ((a * r) / p) + ((a * r^2) / p^2)
///  = ((a * r * p) / p^2) + ((a * r^2) / p^2)
///  = ((a * r * p) + (a * r^2)) / p^2
///  = (a * r * (p + r)) / p^2
/// ```
///
/// ## Parameters
/// - `amount`: The base amount to calculate fee from
/// - `fee_rate`: The fee rate in basis points
///
/// ## Returns
/// - `u64`: The composition fee amount
///
/// ## Errors
/// - `EInvalidFeeRate`: If fee rate exceeds maximum allowed (10%)
/// - `EInvalidFeeAmount`: If calculated fee amount is invalid
public fun calculate_composition_fee(amount: u64, fee_rate: u64): u64 {
    assert!(fee_rate <= max_fee_rate!(), EInvalidFeeRate);
    if (amount == 0 || fee_rate == 0) {
        return 0
    };
    let fee_amount = full_math_u128::mul_div_floor(
        full_math_u64::full_mul(amount, fee_rate),
        (fee_precision!() + fee_rate) as u128,
        fee_precision_square!(),
    );
    assert!(fee_amount < amount as u128, EInvalidFeeAmount);
    fee_amount as u64
}

/// Calculates the growth delta from an amount.
///
/// This function calculates the growth delta (used for fee_growth, reward_growth)
/// from a given amount and liquidity. The result is in Q64x64 format and floor-rounded.
///
/// ## Mathematical Formula
/// `growth_delta = floor((amount << scale_offset) / liquidity)`
///
/// ## Parameters
/// - `amount`: The amount to calculate growth from
/// - `liquidity`: The total liquidity supply
///
/// ## Returns
/// - `u128`: The growth delta in Q64x64 format (floor-rounded)
///
/// ## Errors
/// - `EInvalidLiquidity`: If liquidity is zero or invalid
public fun calculate_growth_by_amount(amount: u64, liquidity: u128): u128 {
    assert!(liquidity > 0, EInvalidLiquidity);
    if (amount == 0) {
        return 0
    };
    full_math_u128::mul_div_floor(
        (amount as u128) << scale_offset!(),
        1u128 << scale_offset!(),
        liquidity,
    )
}

/// Calculates the amount from a growth delta.
///
/// This function calculates the amount corresponding to a given growth delta.
/// Both growth_delta and liquidity are in Q64x64 format.
/// The result is floor-rounded.
///
/// ## Mathematical Formula
/// `amount = floor((growth_delta * liquidity) / (1 << (scale_offset * 2)))`
///
/// ## Parameters
/// - `growth_delta`: The growth delta in Q64x64 format
/// - `liquidity`: The liquidity in Q64x64 format
///
/// ## Returns
/// - `u64`: The calculated amount (floor-rounded)
///
/// ## Errors
/// - `EAmountOverflow`: If the calculation results in overflow
public fun calculate_amount_by_growth(growth_delta: u128, liquidity: u128): u64 {
    if (growth_delta == 0 || liquidity == 0) {
        return 0
    };

    let r =
        full_math_u128::full_mul(growth_delta, liquidity) / (1u256 << (scale_offset!() + scale_offset!()));
    assert!(r <= std::u64::max_value!() as u256, EAmountOverflow);
    r as u64
}