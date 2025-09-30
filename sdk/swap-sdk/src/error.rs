use std::fmt;

#[derive(Debug)]
pub enum DlmmError {
    InvalidStartBinIndex,
    InvalidBinId,
    InvalidInput,
    MathOverflow,
}

impl fmt::Display for DlmmError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DlmmError::InvalidStartBinIndex => write!(f, "Invalid start bin index"),
            DlmmError::InvalidBinId => write!(f, "Invalid bin id"),
            DlmmError::InvalidInput => write!(f, "Invalid input data"),
            DlmmError::MathOverflow => write!(f, "Math overflow"),
        }
    }
}

impl std::error::Error for DlmmError {}
