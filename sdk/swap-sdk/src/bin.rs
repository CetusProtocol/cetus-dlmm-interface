use anyhow::{Error, anyhow};
use serde::{Deserialize, Serialize};

use crate::math::dlmm_math::{
    calculate_amount_in,
    calculate_amount_out,
    calculate_fee_exclusive,
    calculate_fee_inclusive,
};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Bin {
    pub id: i32,
    pub amount_a: u64,
    pub amount_b: u64,
    pub price: u128,
    pub liquidity_supply: u128,
    pub rewards_growth_global: Vec<u128>,
    pub fee_amount_a_growth_global: u128,
    pub fee_amount_b_growth_global: u128,
}

impl Default for Bin {
    fn default() -> Self {
        Self {
            id: 0,
            amount_a: 0,
            amount_b: 0,
            price: 0,
            liquidity_supply: 0,
            rewards_growth_global: vec![],
            fee_amount_a_growth_global: 0,
            fee_amount_b_growth_global: 0,
        }
    }
}

impl Bin {
    pub fn swap_exact_amount_in(
        &mut self,
        amount_in: u64,
        a2b: bool,
        fee_rate: u64,
        protocol_fee_rate: u64,
    ) -> Result<(u64, u64, u64, u64), Error> {
        if a2b {
            let fee_amount = calculate_fee_inclusive(amount_in, fee_rate)?;
            let amount_out = calculate_amount_out(amount_in - fee_amount, self.price, a2b)?;

            let (amount_in, amount_out, fee_amount) = if amount_out <= self.amount_b {
                (amount_in, amount_out, fee_amount)
            } else {
                let amount_in_without_fee = calculate_amount_in(self.amount_b, self.price, a2b)?;
                let fee_amount = calculate_fee_exclusive(amount_in_without_fee, fee_rate)?;
                let amount_in_with_fee = amount_in_without_fee + fee_amount;
                if amount_in_with_fee > amount_in {
                    return Err(anyhow!("amount_in_with_fee is greater than amount_in"));
                }
                (amount_in_with_fee, self.amount_b, fee_amount)
            };
            let protocol_fee = calculate_fee_inclusive(fee_amount, protocol_fee_rate)?;
            self.amount_a = self.amount_a + amount_in - fee_amount;
            self.amount_b = self.amount_b - amount_out;
            Ok((amount_in, amount_out, fee_amount, protocol_fee))
        } else {
            let fee_amount = calculate_fee_inclusive(amount_in, fee_rate)?;
            let amount_out = calculate_amount_out(amount_in - fee_amount, self.price, a2b)?;

            let (amount_in, amount_out, fee_amount) = if amount_out <= self.amount_a {
                (amount_in, amount_out, fee_amount)
            } else {
                let amount_in_without_fee = calculate_amount_in(self.amount_a, self.price, a2b)?;
                let fee_amount = calculate_fee_exclusive(amount_in_without_fee, fee_rate)?;
                let amount_in_with_fee = amount_in_without_fee + fee_amount;
                if amount_in_with_fee > amount_in {
                    return Err(anyhow!("amount_in_with_fee is greater than amount_in"));
                }
                (amount_in_with_fee, self.amount_a, fee_amount)
            };
            let protocol_fee = calculate_fee_inclusive(fee_amount, protocol_fee_rate)?;
            self.amount_a = self.amount_a - amount_out;
            self.amount_b = self.amount_b + amount_in - fee_amount;
            Ok((amount_in, amount_out, fee_amount, protocol_fee))
        }
    }

    pub fn swap_exact_amount_out(
        &mut self,
        amount_out: u64,
        a2b: bool,
        fee_rate: u64,
        protocol_fee_rate: u64,
    ) -> Result<(u64, u64, u64, u64), Error> {
        if a2b {
            let allow_amount_out = self.amount_b.min(amount_out);
            let amount_in_without_fee = calculate_amount_in(allow_amount_out, self.price, a2b)?;
            let fee_amount = calculate_fee_exclusive(amount_in_without_fee, fee_rate)?;
            let amount_in_with_fee = amount_in_without_fee + fee_amount;

            let protocol_fee = calculate_fee_inclusive(fee_amount, protocol_fee_rate)?;
            self.amount_a = self.amount_a + amount_in_without_fee;
            self.amount_b = self.amount_b - allow_amount_out;

            Ok((
                amount_in_with_fee,
                allow_amount_out,
                fee_amount,
                protocol_fee,
            ))
        } else {
            let allow_amount_out = self.amount_a.min(amount_out);
            let amount_in_without_fee = calculate_amount_in(allow_amount_out, self.price, a2b)?;
            let fee_amount = calculate_fee_exclusive(amount_in_without_fee, fee_rate)?;
            let amount_in_with_fee = amount_in_without_fee + fee_amount;

            let protocol_fee = calculate_fee_inclusive(fee_amount, protocol_fee_rate)?;
            self.amount_a = self.amount_a - allow_amount_out;
            self.amount_b = self.amount_b + amount_in_without_fee;

            Ok((
                amount_in_with_fee,
                allow_amount_out,
                fee_amount,
                protocol_fee,
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Bin;

    fn make_bin(amount_a: u64, amount_b: u64, price: u128) -> Bin {
        Bin {
            id: 0,
            amount_a,
            amount_b,
            price,
            liquidity_supply: 0,
            rewards_growth_global: vec![],
            fee_amount_a_growth_global: 0,
            fee_amount_b_growth_global: 0,
        }
    }

    #[test]
    fn swap_in_respects_inventory_a2b() {
        let mut bin = make_bin(1_000_000, 500_000, 1 << 64);
        let (amount_in, amount_out, fee, protocol_fee) =
            bin.swap_exact_amount_in(100_000, true, 300_000, 1000).unwrap();
        assert!(amount_in >= amount_out);
        assert!(fee > 0);
        assert!(protocol_fee > 0);
        assert_eq!(bin.amount_b, 500_000 - amount_out);
        assert_eq!(bin.amount_a, 1_000_000 + amount_in - fee);
    }
}
