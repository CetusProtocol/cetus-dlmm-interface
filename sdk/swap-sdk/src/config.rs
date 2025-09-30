use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinStepConfig {
    pub bin_step: u16,
    pub base_factor: u16,
    pub filter_period: u16,
    pub decay_period: u16,
    pub reduction_factor: u16,
    pub variable_fee_control: u32,
    pub max_volatility_accumulator: u32,
    pub protocol_fee_rate: u64,
}

impl BinStepConfig {
    pub fn new(
        bin_step: u16,
        base_factor: u16,
        filter_period: u16,
        decay_period: u16,
        reduction_factor: u16,
        variable_fee_control: u32,
        max_volatility_accumulator: u32,
        protocol_fee_rate: u64,
    ) -> Self {
        Self {
            bin_step,
            base_factor,
            filter_period,
            decay_period,
            reduction_factor,
            variable_fee_control,
            max_volatility_accumulator,
            protocol_fee_rate,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VariableParameters {
    pub volatility_accumulator: u32,
    pub volatility_reference: u32,
    pub index_reference: i32,
    pub last_update_timestamp: u64,
    pub bin_step_config: BinStepConfig,
}

impl VariableParameters {
    pub fn new(bin_step_config: BinStepConfig, index_reference: i32, last_update_timestamp: u64) -> Self {
        Self {
            volatility_accumulator: 0,
            volatility_reference: 0,
            index_reference,
            last_update_timestamp,
            bin_step_config,
        }
    }
}
