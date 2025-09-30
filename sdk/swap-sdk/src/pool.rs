use std::collections::HashMap;

use anyhow::{Context, Error};
use serde::{Deserialize, Serialize};

use crate::{
    bin::Bin,
    config::{BinStepConfig, VariableParameters},
    math::BASIS_POINT_MAX,
    MAX_FEE_RATE,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwapResult {
    pub amount_in: u64,
    pub amount_out: u64,
    pub fee: u64,
    pub ref_fee: u64,
    pub protocol_fee: u64,
    pub steps: Vec<BinSwap>,
    pub is_exceed: bool,
}

impl Default for SwapResult {
    fn default() -> Self {
        Self {
            amount_in: 0,
            amount_out: 0,
            fee: 0,
            ref_fee: 0,
            protocol_fee: 0,
            steps: Vec::new(),
            is_exceed: false,
        }
    }
}

impl SwapResult {
    pub fn update_swap_result(&mut self, swap_step: BinSwap) {
        self.amount_in += swap_step.amount_in;
        self.amount_out += swap_step.amount_out;
        self.fee += swap_step.fee;
        self.steps.push(swap_step);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct BinSwap {
    pub bin_id: i32,
    pub amount_in: u64,
    pub amount_out: u64,
    pub fee: u64,
    pub var_fee_rate: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pool {
    pub active_id: i32,
    pub base_fee_rate: u64,
    pub v_parameters: VariableParameters,
    pub bins: Vec<Bin>,
}

impl Pool {
    pub fn new(
        active_id: i32,
        base_fee_rate: u64,
        v_parameters: VariableParameters,
        bins: Vec<Bin>,
    ) -> Self {
        Self {
            active_id,
            base_fee_rate,
            v_parameters,
            bins,
        }
    }

    pub fn bins_map(&self) -> HashMap<i32, Bin> {
        self.bins.iter().cloned().map(|bin| (bin.id, bin)).collect()
    }

    pub fn swap_exact_amount_in(
        &mut self,
        amount_in: u64,
        a2b: bool,
        current_timestamp: u64,
    ) -> Result<SwapResult, Error> {
        self.swap_in_pool(amount_in, a2b, true, current_timestamp)
    }

    pub fn swap_exact_amount_out(
        &mut self,
        amount_out: u64,
        a2b: bool,
        current_timestamp: u64,
    ) -> Result<SwapResult, Error> {
        self.swap_in_pool(amount_out, a2b, false, current_timestamp)
    }

    fn swap_in_pool(
        &mut self,
        amount: u64,
        a2b: bool,
        by_amount_in: bool,
        current_timestamp: u64,
    ) -> Result<SwapResult, Error> {
        if self.bins.is_empty() {
            return Ok(SwapResult {
                is_exceed: true,
                ..Default::default()
            });
        }

        self.update_references(current_timestamp as i64)?;
        let (mut op_next_bin_idx, _) = self.find_first_swap_bin_index(self.active_id, a2b);
        let mut remaining_amount = amount;
        let mut swap_result = SwapResult::default();
        let protocol_fee_rate = self.v_parameters.bin_step_config.protocol_fee_rate;
        let mut protocol_fee_acc = 0u64;

        while remaining_amount > 0 {
            if op_next_bin_idx.is_none() {
                swap_result.is_exceed = true;
                break;
            }

            let current_bin_idx = op_next_bin_idx.unwrap();
            let next_bin_idx = if a2b {
                if current_bin_idx > 0 {
                    Some(current_bin_idx - 1)
                } else {
                    None
                }
            } else if current_bin_idx < self.bins.len() - 1 {
                Some(current_bin_idx + 1)
            } else {
                None
            };

            op_next_bin_idx = next_bin_idx;
            self.update_volatility_accumulator()?;
            let (fee_rate, dy_fee_rate) = self.get_total_fee()?;
            let cur_bin = &mut self.bins[current_bin_idx];
            let (amount_in, amount_out, fee, bin_protocol_fee) = if by_amount_in {
                cur_bin.swap_exact_amount_in(remaining_amount, a2b, fee_rate, protocol_fee_rate)?
            } else {
                cur_bin.swap_exact_amount_out(remaining_amount, a2b, fee_rate, protocol_fee_rate)?
            };

            let step_result = BinSwap {
                bin_id: cur_bin.id,
                amount_in,
                amount_out,
                fee,
                var_fee_rate: dy_fee_rate,
            };

            if by_amount_in {
                remaining_amount = remaining_amount.saturating_sub(amount_in);
            } else {
                remaining_amount = remaining_amount.saturating_sub(amount_out);
            }
            protocol_fee_acc = protocol_fee_acc.saturating_add(bin_protocol_fee);
            swap_result.update_swap_result(step_result);

            if remaining_amount > 0 {
                if let Some(next_idx) = op_next_bin_idx {
                    let next_bin = &self.bins[next_idx];
                    self.active_id = next_bin.id;
                }
            }
        }

        swap_result.protocol_fee = protocol_fee_acc;
        self.v_parameters.last_update_timestamp = current_timestamp;

        Ok(swap_result)
    }

    fn find_first_swap_bin_index(
        &self,
        current_bin_index: i32,
        a2b: bool,
    ) -> (Option<usize>, Option<usize>) {
        if self.bins.is_empty() {
            return (None, None);
        }

        if a2b {
            let mut left = 0;
            let mut right = self.bins.len() - 1;
            while left <= right {
                let mid = left + ((right - left) >> 1);
                if self.bins[mid].id <= current_bin_index {
                    if mid == self.bins.len() - 1 || self.bins[mid + 1].id > current_bin_index {
                        let next_idx = if mid > 0 { Some(mid - 1) } else { None };
                        return (Some(mid), next_idx);
                    } else {
                        left = mid + 1;
                    }
                } else if mid == 0 {
                    return (None, None);
                } else {
                    right = mid - 1;
                }
            }
            (None, None)
        } else {
            let mut left = 0;
            let mut right = self.bins.len() - 1;
            while left <= right {
                let mid = left + ((right - left) >> 1);
                if self.bins[mid].id > current_bin_index {
                    if mid == 0 || self.bins[mid - 1].id <= current_bin_index {
                        let next_idx = if mid >= self.bins.len() - 1 {
                            None
                        } else {
                            Some(mid + 1)
                        };
                        return (Some(mid), next_idx);
                    } else {
                        right = mid - 1;
                    }
                } else {
                    left = mid + 1;
                }
            }
            (None, None)
        }
    }

    fn update_references(&mut self, current_timestamp: i64) -> Result<(), Error> {
        let v_params = &mut self.v_parameters;
        let s_params: &BinStepConfig = &v_params.bin_step_config;
        let last = v_params.last_update_timestamp as i64;

        if current_timestamp <= last {
            return Ok(());
        }

        let elapsed = current_timestamp - last;

        if elapsed >= s_params.filter_period as i64 {
            v_params.index_reference = self.active_id;

            if elapsed < s_params.decay_period as i64 {
                let scaled = u64::from(v_params.volatility_accumulator)
                    .checked_mul(s_params.reduction_factor as u64)
                    .context("volatility reference overflow")?
                    .checked_div(BASIS_POINT_MAX as u64)
                    .context("volatility reference overflow")?;
                v_params.volatility_reference = scaled as u32;
            } else {
                v_params.volatility_reference = 0;
            }
        }

        Ok(())
    }

    fn update_volatility_accumulator(&mut self) -> Result<(), Error> {
        let max_accumulator = self.v_parameters.bin_step_config.max_volatility_accumulator;
        let v_params = &mut self.v_parameters;

        let delta_id = (v_params.index_reference as i64 - self.active_id as i64).abs() as u64;

        let accumulator = u64::from(v_params.volatility_reference)
            .checked_add(
                delta_id
                    .checked_mul(BASIS_POINT_MAX as u64)
                    .context("volatility accumulator overflow")?,
            )
            .context("volatility accumulator overflow")?;

        let capped = accumulator.min(max_accumulator as u64);
        v_params.volatility_accumulator = capped as u32;
        Ok(())
    }

    fn get_variable_fee(&self) -> Result<u128, Error> {
        self.compute_variable_fee(self.v_parameters.volatility_accumulator)
    }

    fn compute_variable_fee(&self, volatility_accumulator: u32) -> Result<u128, Error> {
        let s_params = &self.v_parameters.bin_step_config;
        if s_params.variable_fee_control > 0 {
            let va = volatility_accumulator as u128;
            let bin_step = s_params.bin_step as u128;
            let variable_fee_control = s_params.variable_fee_control as u128;

            let combined = va
                .checked_mul(bin_step)
                .context("variable fee overflow")?;
            let square = combined
                .checked_mul(combined)
                .context("variable fee overflow")?;

            let v_fee = variable_fee_control
                .checked_mul(square)
                .context("variable fee overflow")?;

            let scaled_v_fee = v_fee
                .checked_add(99_999_999_999)
                .context("variable fee overflow")?
                .checked_div(100_000_000_000)
                .context("variable fee overflow")?;

            return Ok(scaled_v_fee);
        }

        Ok(0)
    }

    fn get_total_fee(&self) -> Result<(u64, u64), Error> {
        let variable_fee = self.get_variable_fee()?;
        let total_fee_rate = (self.base_fee_rate as u128)
            .checked_add(variable_fee)
            .context("total fee overflow")?;
        let capped = total_fee_rate.min(MAX_FEE_RATE.into());
        Ok((capped as u64, variable_fee as u64))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bin::Bin;

    fn make_bin(id: i32, amount_a: u64, amount_b: u64, price: u128) -> Bin {
        Bin {
            id,
            amount_a,
            amount_b,
            price,
            liquidity_supply: 0,
            rewards_growth_global: vec![],
            fee_amount_a_growth_global: 0,
            fee_amount_b_growth_global: 0,
        }
    }

    fn default_bin_step() -> BinStepConfig {
        BinStepConfig::new(25, 1, 60, 600, 9000, 0, 1_000_000, 30_000)
    }

    #[test]
    fn swap_exact_in_across_bins() {
        let mut pool = Pool::new(
            0,
            30_000,
            VariableParameters::new(default_bin_step(), 0, 0),
            vec![
                make_bin(0, 1_000_000, 500_000, 1 << 64),
                make_bin(1, 1_000_000, 2_000_000, (1 << 64) + 1000),
            ],
        );

        let result = pool
            .swap_exact_amount_in(200_000, true, 10)
            .expect("swap succeeds");

        assert!(result.amount_out > 0);
        assert_eq!(result.steps.len(), 1);
    }
}
