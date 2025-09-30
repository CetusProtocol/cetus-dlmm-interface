// Copyright (c) Cetus Technology Limited

/// # Price Mathematics Module
///
/// This module provides price calculation functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles bin ID to price conversion, exponential calculations, and price range management.
#[allow(unused_variable)]
module cetusdlmm::price_math;

use integer_mate::full_math_u128;
use integer_mate::i32::{Self, I32};

/// ## Error Codes
///
/// - `EPriceMathExponentialOverflow`: Exponent exceeds maximum allowed
/// - `EPriceMathResultIsZero`: Result is zero (division by zero or overflow)
#[error]
const EPriceMathExponentialOverflow: vector<u8> = b"Exponent exceeds maximum allowed";
#[error]
const EPriceMathResultIsZero: vector<u8> = b"Result is zero (division by zero or overflow)";

/// Scale offset for Q64x64 fixed-point arithmetic.
///
/// This constant defines the number of bits used for the fractional part
/// in the Q64x64 fixed-point format.
const SCALE_OFFSET: u8 = 64;

/// One in Q64x64 fixed-point format.
///
/// This represents the value 1.0 in the Q64x64 format,
/// which is 2^64 (1 shifted left by 64 bits).
const ONE: u128 = 1u128 << SCALE_OFFSET;
// When smallest bin is used (1 bps), the maximum of bin limit is 887272 (Check: https://docs.traderjoexyz.com/concepts/bin-math).
// But in solana, the token amount is represented in 64 bits, therefore, it will be (1 + 0.0001)^n < 2 ** 64, solve for n, n ~= 443636
// Then we calculate bits needed to represent 443636 exponential, 2^n >= 443636, ~= 19
// If we convert 443636 to binary form, it will be 1101100010011110100 (19 bits).
// Which, the 19 bits are the bits the binary exponential will loop through.
// The 20th bit will be 0x80000,  which the exponential already > the maximum number of bin Q64.64 can support
const MAX_EXPONENTIAL: u32 = 0x80000;

/// Bin boundary for price range calculations.
///
/// This constant defines the maximum bin ID value (443,636) which corresponds
/// to the maximum price that can be represented without overflow in the Q64x64
/// format when using the smallest bin step.
const BIN_BOUND: u32 = 443636;

/// Gets the minimum valid bin ID.
///
/// This function returns the minimum bin ID (-443,636) which corresponds
/// to the lowest price that can be represented in the system.
///
/// ## Returns
/// - `I32`: The minimum bin ID (-BIN_BOUND)
public fun min_bin_id(): I32 {
    i32::neg_from(BIN_BOUND)
}

/// Gets the maximum valid bin ID.
///
/// This function returns the maximum bin ID (+443,636) which corresponds
/// to the highest price that can be represented in the system.
///
/// ## Returns
/// - `I32`: The maximum bin ID (+BIN_BOUND)
public fun max_bin_id(): I32 {
    i32::from(BIN_BOUND)
}

/// Gets the bin boundary value.
///
/// This function returns the bin boundary constant (443,636) which defines
/// the maximum absolute value for bin IDs.
///
/// ## Returns
/// - `u32`: The bin boundary value (BIN_BOUND)
public fun bin_bound(): u32 {
    BIN_BOUND
}

/// Calculates the power of a base raised to an exponent.
///
/// This function implements efficient power calculation using binary exponentiation
/// for Q64x64 fixed-point arithmetic. It handles both positive and negative exponents
/// and includes overflow protection.
///
/// ## Mathematical Formula
/// ```
/// result = base^exp
/// ```
/// For negative exponents: `result = 1 / base^|exp|`
///
/// ## Parameters
/// - `base`: The base value in Q64x64 format
/// - `exp`: The exponent (can be negative or positive)
///
/// ## Returns
/// - `u128`: The result in Q64x64 format
///
/// ## Errors
/// - `1`: If exponent exceeds MAX_EXPONENTIAL (0x80000)
/// - `2`: If result is zero (division by zero or overflow)
///
/// ## Algorithm
/// The function uses binary exponentiation with the following optimizations:
/// - Handles negative exponents by inverting the result
/// - Uses bitwise operations for efficient calculation
/// - Limits exponential to 19 bits to prevent overflow
/// - Implements inverse calculation trick for large bases
public fun pow(base: u128, exp: I32): u128 {
    // If exponent is negative. We will invert the result later by 1 / base^exp.abs()
    let mut invert = exp.is_neg();

    // When exponential is 0, result will always be 1
    if (exp.as_u32() == 0) {
        return ONE
    };
    if (base == ONE) {
        return ONE
    };

    // Make the exponential positive. Which will compute the result later by 1 / base^exp
    let exp = if (invert) { exp.abs().as_u32() } else { exp.as_u32() };

    // No point to continue the calculation as it will overflow the maximum value Q64.64 can support
    assert!(exp < MAX_EXPONENTIAL, EPriceMathExponentialOverflow);

    let mut squared_base = base;
    let mut result = ONE;

    // When multiply the base twice, the number of bits double from 128 -> 256, which overflow.
    // The trick here is to inverse the calculation, which make the upper 64 bits (number bits) to be 0s.
    // For example:
    // let base = 1.001, exp = 5
    // let neg = 1 / (1.001 ^ 5)
    // Inverse the neg: 1 / neg
    // By using a calculator, you will find out that 1.001^5 == 1 / (1 / 1.001^5)
    if (squared_base >= result) {
        // This inverse the base: 1 / base
        squared_base = std::u128::max_value!() / squared_base;
        // If exponent is negative, the above already inverted the result. Therefore, at the end of the function, we do not need to invert again.
        invert = !invert;
    };

    // The following code is equivalent to looping through each binary value of the exponential.
    // As explained in MAX_EXPONENTIAL, 19 exponential bits are enough to covert the full bin price.
    // Therefore, there will be 19 if statements, which similar to the following pseudo code.
    /*
        let mut result = 1;
        while exponential > 0 {
            if exponential & 1 > 0 {
                result *= base;
            }
            base *= base;
            exponential >>= 1;
        }
    */

    // From right to left
    // squared_base = 1 * base^1
    // 1st bit is 1
    if (exp & 0x1 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    // squared_base = base^2
    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    // 2nd bit is 1
    if (exp & 0x2 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    // Example:
    // If the base is 1.001, exponential is 3. Binary form of 3 is ..0011. The last 2 1's bit fulfill the above 2 bitwise condition.
    // The result will be 1 * base^1 * base^2 == base^3. The process continues until reach the 20th bit

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x4 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x8 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x10 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x20 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x40 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x80 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x100 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x200 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x400 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x800 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x1000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x2000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x4000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x8000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x10000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x20000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    squared_base = (full_math_u128::full_mul(squared_base, squared_base) >> SCALE_OFFSET) as u128;
    if (exp & 0x40000 > 0) {
        result = (full_math_u128::full_mul(result, squared_base) >> SCALE_OFFSET) as u128;
    };

    // Stop here as the next is 20th bit, which > MAX_EXPONENTIAL
    assert!(result != 0, EPriceMathResultIsZero);

    if (invert) {
        result = std::u128::max_value!() / result;
    };
    result
}

/// Calculates the price from a bin ID and bin step.
///
/// This function converts a bin ID to its corresponding price using the
/// exponential formula: `price = (1 + bin_step/10000)^active_id`
///
/// ## Mathematical Formula
/// ```
/// bps = (bin_step << 64) / 10000  // Convert to Q64x64
/// base = 1 + bps                   // Base for exponential
/// price = base^active_id           // Calculate price
/// ```
///
/// ## Parameters
/// - `active_id`: The bin ID (can be negative or positive)
/// - `bin_step`: The bin step in basis points (e.g., 1 = 0.01%)
///
/// ## Returns
/// - `u128`: The price in Q64x64 format
///
/// ## Example
/// - `bin_step = 1, active_id = 0` → `price = 1.0`
/// - `bin_step = 1, active_id = 1` → `price = 1.0001`
/// - `bin_step = 1, active_id = -1` → `price = 0.9999`
public fun get_price_from_id(active_id: I32, bin_step: u16): u128 {
    // Make bin_step into Q64x64, and divided by BASIS_POINT_MAX. If bin_step = 1, we get 0.0001 in Q64x64
    let bps = ((bin_step as u128) << SCALE_OFFSET) / 10000;
    // Add 1 to bps, we get 1.0001 in Q64.64
    let base = ONE + bps;
    pow(base, active_id)
}

#[test]
fun test_pow() {
    let p = pow(1<<64, i32::from(1));
    std::debug::print(&p);
}
