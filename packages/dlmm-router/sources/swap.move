#[allow(unused_variable)]
module dlmmrouter::swap;

use cetusdlmm::config::GlobalConfig;
use cetusdlmm::partner::Partner;
use cetusdlmm::pool::Pool;
use cetusdlmm::versioned::Versioned;
use sui::clock::Clock;
use sui::coin::Coin;

public fun swap_a2b<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_a: &mut Coin<CoinTypeA>,
    by_amount_in: bool,
    amount: u64,
    amount_limit: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 1
}

public fun swap_b2a<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_b: &mut Coin<CoinTypeB>,
    by_amount_in: bool,
    amount: u64,
    amount_limit: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 1
}

public fun swap_a2b_with_partner<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    coin_a: &mut Coin<CoinTypeA>,
    by_amount_in: bool,
    amount: u64,
    amount_limit: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 1
}

public fun swap_b2a_with_partner<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    coin_b: &mut Coin<CoinTypeB>,
    by_amount_in: bool,
    amount: u64,
    amount_limit: u64,
    config: &GlobalConfig,
    versioned: &Versioned,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 1
}

public fun send_coin<CoinType>(coin: Coin<CoinType>, receipt: address) {
    abort 1
}
