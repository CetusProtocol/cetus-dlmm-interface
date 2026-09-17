#[allow(unused_variable)]
module dlmmrouter::utils;

use cetusdlmm::pool::Pool;
use sui::bag::Bag;
use sui::balance::Balance;

public fun validate_active_id_slippage<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    expected_active_id: u32,
    max_bin_slippage: u32,
) {
    abort 1
}

public fun find_active_id_idx(active_id: u32, active_id_vector: vector<u32>): u64 {
    abort 1
}

public fun add_balance_to_bag<T>(balances: &mut Bag, balance: Balance<T>): u64 {
    abort 1
}

public fun remove_balance_from_bag<T>(balance_bag: &mut Bag): Balance<T> {
    abort 1
}
