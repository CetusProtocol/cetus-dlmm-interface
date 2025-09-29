// Copyright (c) Cetus Technology Limited

/// # Restriction Module
///
/// This module provides restriction management functionality for the Cetus DLMM (Dynamic Liquidity Market Maker) protocol.
/// It handles user and position blocking, operation restrictions, and access control for various operations.
#[allow(unused_variable, unused_function, unused_const, unused_field)]
module cetusdlmm::restriction;

use cetusdlmm::acl::ACL;

/// Main restriction manager that tracks blocked users and positions.
///
/// This struct contains two ACL (Access Control List) instances for managing
/// blocked users and blocked positions separately.
///
/// ## Fields
/// - `blocked_user`: ACL for tracking blocked users and their operation restrictions
/// - `blocked_position`: ACL for tracking blocked positions and their operation restrictions
public struct Restriction has store {
    blocked_user: ACL,
    blocked_position: ACL,
}


/// Enum defining all possible operation types that can be restricted.
///
/// This enum represents the different operations in the DLMM system that
/// can be blocked for users or positions.
///
/// ## Variants
/// - `ALL`: Blocks all operations for an entity
/// - `ADD`: Blocks liquidity addition operations
/// - `REMOVE`: Blocks liquidity removal operations
/// - `SWAP`: Blocks swap operations
/// - `CREATE_POOL`: Blocks pool creation operations
/// - `COLLECT_FEE`: Blocks fee collection operations
/// - `COLLECT_REWARD`: Blocks reward collection operations
/// - `ADD_REWARD`: Blocks reward addition operations
/// - `RESERVED_0`, `RESERVED_1`, `RESERVED_2`: Reserved for future use
public enum OperationKind has copy, drop, store {
    ALL,
    ADD,
    REMOVE,
    SWAP,
    CREATE_POOL,
    COLLECT_FEE,
    COLLECT_REWARD,
    ADD_REWARD,
    RESERVED_0,
    RESERVED_1,
    RESERVED_2,
}
