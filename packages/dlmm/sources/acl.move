// Copyright (c) Cetus Technology Limited

/// Fork @https://github.com/pentagonxyz/movemate.git
///
/// `acl` is a simple access control module, where `member` represents a member and `role` represents a type
/// of permission. A member can have multiple permissions.
module cetusdlmm::acl;

use move_stl::linked_table::{Self, LinkedTable};

/// Stores access control permissions for members using a linked table mapping addresses to permission bitmasks.
/// Each member's permissions are represented by a 128-bit integer where each bit corresponds to a role.
///
/// # Fields
/// * `permissions` - LinkedTable mapping member addresses to their permission bitmasks
///   - Key: Member address
///   - Value: 128-bit permission mask where each bit represents a role
///   - Bit 0 = role 0, bit 1 = role 1, etc
///   - 1 means member has the role, 0 means they don't
///
/// # Example
/// ```
/// let acl = ACL {
///   permissions: linked_table::new() // Maps addresses to permission bitmasks
/// };
/// // Member @0x1 with roles 0 and 2 would have permissions value of 5 (binary 101)
/// ```
public struct ACL has store {
    permissions: LinkedTable<address, u128>,
}

/// ```
public fun new(ctx: &mut TxContext): ACL {
    ACL { permissions: linked_table::new(ctx) }
}