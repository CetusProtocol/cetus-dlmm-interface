#[allow(unused_variable)]
module dlmmrouter::liquidity_strategy;

use cetusdlmm::config::GlobalConfig;
use cetusdlmm::pool::Pool;
use cetusdlmm::position::Position;
use cetusdlmm::versioned::Versioned;
use sui::clock::Clock;
use sui::coin::Coin;

public enum StrategyEnum has copy, drop, store {
    Spot,
    Curve,
    BidAsk,
}

public fun spot(): StrategyEnum {
    abort 1
}

public fun curve(): StrategyEnum {
    abort 1
}

public fun bid_ask(): StrategyEnum {
    abort 1
}

public fun open_position<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_a: &mut Coin<CoinTypeA>,
    coin_b: &mut Coin<CoinTypeB>,
    total_amount_a: u64,
    total_amount_b: u64,
    lower_bin_id: u32,
    width: u16,
    expected_active_id: u32,
    max_bin_slippage: u32,
    strategy: StrategyEnum,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &mut TxContext,
): Position {
    abort 1
}

public fun add_liquidity<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: &mut Position,
    coin_a: &mut Coin<CoinTypeA>,
    coin_b: &mut Coin<CoinTypeB>,
    total_amount_a: u64,
    total_amount_b: u64,
    min_bin_id: u32,
    max_bin_id: u32,
    expected_active_id: u32,
    max_bin_slippage: u32,
    strategy: StrategyEnum,
    config: &GlobalConfig,
    versioned: &Versioned,
    clk: &Clock,
    ctx: &mut TxContext,
) {
    abort 1
}
