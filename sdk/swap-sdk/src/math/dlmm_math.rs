use anyhow::{Context, Error, anyhow};
use ruint::aliases::U256;

use crate::{
    FEE_PRECISION,
    math::{Rounding, full_math::mul_div, q64x64_math::ONE},
};

/// U256::from_limbs([0, 0, 1, 0]) = 1 << 128
pub fn calculate_growth_by_amount(amount: u64, liquidity: u128) -> Result<u128, Error> {
    let amount = U256::from(amount);
    let liquidity = U256::from(liquidity);
    let result = amount
        .checked_mul(U256::from_limbs([0, 0, 1, 0]))
        .context("calculate_growth_by_amount: overflow")?
        .checked_div(liquidity)
        .context("calculate_growth_by_amount: overflow")?;
    Ok(result.try_into().unwrap())
}

/// U256::from_limbs([0, 0, 1, 0]) = 1 << 128
pub fn calculate_amount_by_growth(growth_delta: u128, liquidity: u128) -> Result<u64, Error> {
    let growth_delta = U256::from(growth_delta);
    let liquidity = U256::from(liquidity);
    let result = growth_delta
        .checked_mul(liquidity)
        .context("calculate_amount_by_growth: overflow")?
        .checked_div(U256::from_limbs([0, 0, 1, 0]))
        .context("calculate_amount_by_growth: overflow")?;
    Ok(result.try_into().unwrap())
}

pub fn calculate_fee_inclusive(amount: u64, fee_rate: u64) -> Result<u64, Error> {
    if amount == 0 || fee_rate == 0 {
        return Ok(0);
    }
    if fee_rate > FEE_PRECISION {
        return Err(anyhow!("fee_rate is greater than FEE_PRECISION"));
    }
    let r = mul_div(
        amount as u128,
        fee_rate as u128,
        FEE_PRECISION as u128,
        Rounding::Up,
    )
    .ok_or(anyhow!("fee_amount overflow"))?;
    Ok(r as u64)
}

pub fn calculate_fee_exclusive(amount: u64, fee_rate: u64) -> Result<u64, Error> {
    if amount == 0 || fee_rate == 0 {
        return Ok(0);
    }
    if fee_rate > FEE_PRECISION {
        return Err(anyhow!("fee_rate is greater than FEE_PRECISION"));
    }
    let denominator = FEE_PRECISION as u128 - fee_rate as u128;
    let r = mul_div(amount as u128, fee_rate as u128, denominator, Rounding::Up)
        .ok_or(anyhow!("fee_amount overflow"))?;
    Ok(r as u64)
}

pub fn calculate_amount_in(amount_out: u64, price: u128, a2b: bool) -> Result<u64, Error> {
    if price == 0 {
        return Err(anyhow!("price is zero"));
    }
    if amount_out == 0 {
        return Ok(0);
    }
    let r = if a2b {
        mul_div(amount_out as u128, ONE, price, Rounding::Up)
            .ok_or(anyhow!("amount_in overflow"))?
    } else {
        mul_div(amount_out as u128, price, ONE, Rounding::Up)
            .ok_or(anyhow!("amount_in overflow"))?
    };
    if r > u64::MAX as u128 {
        return Err(anyhow!("amount_in overflow"));
    }
    Ok(r as u64)
}

pub fn calculate_amount_out(amount_in: u64, price: u128, a2b: bool) -> Result<u64, Error> {
    if price == 0 {
        return Err(anyhow!("price is zero"));
    }
    if amount_in == 0 {
        return Ok(0);
    }
    let r = if a2b {
        mul_div(amount_in as u128, price, ONE, Rounding::Down)
            .ok_or(anyhow!("amount_out overflow"))?
    } else {
        mul_div(amount_in as u128, ONE, price, Rounding::Down)
            .ok_or(anyhow!("amount_out overflow"))?
    };
    if r > u64::MAX as u128 {
        return Err(anyhow!("amount_out overflow"));
    }
    Ok(r as u64)
}

#[cfg(test)]
mod test {
    use super::{calculate_amount_in, calculate_amount_out};

    #[test]
    fn test_calculate_amount_in() {
        assert!(calculate_amount_in(0, 1 << 64, true).unwrap() == 0);
        assert!(calculate_amount_in(1_000_000, 1 << 64, true).unwrap() == 1_000_000);
        assert!(calculate_amount_in(1_000_000, (1 << 64) - 1, true).unwrap() == 1_000_001);
        assert!(calculate_amount_in(1_000_000, (1 << 64) + 1, true).unwrap() == 1_000_000);
        assert!(calculate_amount_in(1_000_000, 2 << 64, true).unwrap() == 500_000);
        assert!(calculate_amount_in(1_000_000, (2 << 64) - 1, true).unwrap() == 500_001);
        assert!(
            calculate_amount_in(1_000_000, (u64::MAX / 2) as u128, true).unwrap()
                == 2_000_001
        );
        assert!(
            calculate_amount_in(1_000_000, (u64::MAX / 3) as u128, true).unwrap()
                == 3_000_001
        );
        assert!(
            calculate_amount_in(
                1_000_000_000_000,
                (133_333_333 << 64) + ((u64::MAX / 3) as u128),
                true
            )
            .unwrap()
                == 7_501,
        );

        assert!(calculate_amount_in(1_000_000, 1 << 64, false).unwrap() == 1_000_000);
        assert!(calculate_amount_in(1_000_000, (1 << 64) + 1, false).unwrap() == 1_000_001);
        assert!(calculate_amount_in(1_000_000, (1 << 64) - 1, false).unwrap() == 1_000_000);
        assert!(calculate_amount_in(1_000_000, 2 << 64, false).unwrap() == 2_000_000);
        assert!(calculate_amount_in(1_000_000, (u64::MAX / 2) as u128, false).unwrap() == 500_000);
        assert!(calculate_amount_in(1_000_000, (u64::MAX / 3) as u128, false).unwrap() == 333_334);
        assert!(
            calculate_amount_in(
                1_000_000,
                (133_333_333 << 64) + ((u64::MAX / 3) as u128),
                false
            )
            .unwrap()
                == 133_333_333_333_334,
        );
    }

    #[test]
    fn test_calculate_amount_out() {
        assert!(calculate_amount_out(0, 1 << 64, true).unwrap() == 0);
        assert!(calculate_amount_out(1_000_000, 1 << 64, true).unwrap() == 1_000_000);
        assert!(calculate_amount_out(1_000_000, (1 << 64) - 1, true).unwrap() == 999_999);
        assert!(calculate_amount_out(1_000_000, (1 << 64) + 1, true).unwrap() == 1_000_000);
        assert!(calculate_amount_out(1_000_000, 2 << 64, true).unwrap() == 2_000_000);
        assert!(calculate_amount_out(1_000_000, (2 << 64) - 1, true).unwrap() == 1_999_999);
        assert!(
            calculate_amount_out(1_000_000, (u64::MAX / 2) as u128, true).unwrap()
                == 499_999
        );
        assert!(
            calculate_amount_out(1_000_000, (u64::MAX / 3) as u128, true).unwrap()
                == 333_333
        );
        assert!(
            calculate_amount_out(
                1_000_000,
                (133_333_333 << 64) + ((u64::MAX / 3) as u128),
                true
            )
            .unwrap()
                == 133_333_333_333_333,
        );

        assert!(calculate_amount_out(1_000_000, 1 << 64, false).unwrap() == 1_000_000);
        assert!(calculate_amount_out(1_000_000, (1 << 64) + 1, false).unwrap() == 999_999);
        assert!(calculate_amount_out(1_000_000, (1 << 64) - 1, false).unwrap() == 1_000_000);
        assert!(calculate_amount_out(1_000_000, 2 << 64, false).unwrap() == 500_000);
        assert!(calculate_amount_out(1_000_000, (2 << 64) - 1, false).unwrap() == 500_000);
        assert!(calculate_amount_out(1_000_000, (u64::MAX / 2) as u128, false).unwrap() == 2_000_000);
        assert!(calculate_amount_out(1_000_000, (u64::MAX / 3) as u128, false).unwrap() == 3_000_000);
        assert!(
            calculate_amount_out(
                1_000_000_000_000,
                (133_333_333 << 64) + ((u64::MAX / 3) as u128),
                false
            )
            .unwrap()
                == 7_500,
        );
    }
}
