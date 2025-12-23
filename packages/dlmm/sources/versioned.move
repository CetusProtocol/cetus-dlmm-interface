// Copyright (c) Cetus Technology Limited

/// # Versioned Module
///
/// This module provides version management functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles version tracking, upgrade mechanisms, and version compatibility checks.
///
/// ## Overview
///
/// The versioned module is responsible for:
/// - Tracking the current version of the protocol
/// - Providing version compatibility checks
/// - Managing version upgrades with administrative control
/// - Ensuring backward compatibility
/// - Preventing usage of deprecated versions
///
/// ## Key Components
///
/// - `Versioned`: Main version tracking object
/// - `InitEvent`: Event emitted when versioned object is initialized
///
/// ## Version System
///
/// ### Version Tracking
/// - Current version is defined as a constant (`VERSION = 1`)
/// - Versioned objects track their current version
/// - Version checks ensure compatibility
///
/// ### Upgrade Mechanism
/// - Only administrators can upgrade versions
/// - Upgrades can only move forward (not backward)
/// - Version upgrades require AdminCap
///
/// ### Compatibility Checks
/// - Functions check version before execution
/// - Deprecated versions are rejected
/// - Invalid version upgrades are prevented
///
/// ## Error Codes
///
/// - `EVersionDeprecated`: Version is deprecated and no longer supported
/// - `EInvalidVersion`: Invalid version for upgrade operation
#[allow(unused_variable, unused_field, unused_const)]
module cetusdlmm::versioned;

/// Current version of the protocol.
///
/// This constant defines the current supported version of the DLMM protocol.
/// All versioned objects should be at or below this version.
const VERSION: u64 = 7;
/// Main version tracking object.
///
/// This struct tracks the version of a component in the DLMM protocol.
/// It provides version checking and upgrade capabilities.
///
/// ## Fields
/// - `id`: Unique identifier for the versioned object
/// - `version`: Current version of the object
public struct Versioned has key, store {
    id: object::UID,
    version: u64,
}
