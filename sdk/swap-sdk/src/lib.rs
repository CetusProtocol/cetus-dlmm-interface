pub mod bin;
pub mod config;
pub mod error;
pub mod math;
pub mod pool;

pub const MAX_FEE_RATE: u64 = 100_000_000;
pub const FEE_PRECISION: u64 = 1_000_000_000;

pub use crate::bin::Bin;
pub use crate::config::{BinStepConfig, VariableParameters};
pub use crate::pool::{BinSwap, Pool, SwapResult};
