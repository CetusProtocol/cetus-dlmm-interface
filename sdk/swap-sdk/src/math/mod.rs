pub mod dlmm_math;
pub mod full_math;
pub mod q64x64_math;

pub const BASIS_POINT_MAX: u32 = 10_000;

#[derive(Clone, Copy, Debug)]
pub enum Rounding {
    Up,
    Down,
}
