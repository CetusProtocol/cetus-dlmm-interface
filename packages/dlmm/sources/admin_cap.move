// Copyright (c) Cetus Technology Limited
/// # Admin Capability Module
///
/// This module provides administrative capabilities for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It defines the `AdminCap` struct which serves as a capability-based access control mechanism for
/// administrative operations within the DLMM protocol.
///
/// ## Overview
///
/// The `AdminCap` is a Sui object that represents administrative privileges. Only addresses that
/// possess this capability can perform administrative operations
///
/// ## Key Components
///
/// - `AdminCap`: The main capability struct that grants administrative privileges
/// - `InitEvent`: Event emitted when the admin capability is initialized
///
/// ## Security Model
///
/// The admin capability follows Sui's capability-based security model:
/// - Only the address that possesses the `AdminCap` can perform administrative operations
/// - The capability can be transferred to other addresses if needed
///

///
/// ## Events
///
/// - `InitEvent`: Emitted when the admin capability is first created, containing the ID of the created capability
///

#[allow(unused_field)]
module cetusdlmm::admin_cap;

/// Administrative capability that grants privileges to perform administrative operations
/// within the DLMM protocol.
///
/// This struct implements the `key` and `store` abilities, making it a Sui object that can be:
/// - Stored in global storage (`key`)
/// - Transferred between addresses (`store`)
///
/// ## Security
///
/// Only addresses that possess this capability can perform administrative operations.
public struct AdminCap has key, store {
    id: object::UID,
}

/// Event emitted when the admin capability is initialized.
///
/// This event contains the ID of the newly created admin capability, allowing
/// external systems to track when administrative privileges are granted.
///
/// ## Fields
/// - `admin_cap_id`: The unique identifier of the created admin capability
public struct InitEvent has copy, drop {
    admin_cap_id: ID,
}
