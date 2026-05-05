// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available
// Use of this source code is governed by the LICENSE file in the project root.
// Public readability and auditability do not grant rights to copy, modify,
// distribute, redeploy, or commercialize this code except as expressly permitted.

module paperproof_governance::governance;

use openzeppelin_access::two_step_transfer::{
    Self as two_step_transfer,
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use sui::coin::{Self as coin, Coin};
use sui::sui::SUI;
use sui::transfer::Receiving;

const E_INVALID_GOVERNANCE_AUTHORITY: u64 = 1;
const E_INVALID_OPERATOR: u64 = 2;
const E_NOT_GOVERNANCE_AUTHORITY: u64 = 3;
const E_PENDING_OPERATOR_TRANSFER_EXISTS: u64 = 4;
const E_NO_PENDING_OPERATOR_TRANSFER: u64 = 5;
const E_INVALID_REGISTRY: u64 = 6;
const E_NOT_ACTIVE_OPERATOR: u64 = 7;
const E_STALE_OPERATOR_PERMIT: u64 = 8;
const E_INVALID_FEE_LEVEL: u64 = 9;
const E_FEE_PAYMENT_REQUIRED: u64 = 10;
const E_INSUFFICIENT_FEE_PAYMENT: u64 = 11;

const FEE_LEVEL_FREE: u8 = 0;
const FEE_LEVEL_MICRO: u8 = 1;
const FEE_LEVEL_LOW: u8 = 2;
const FEE_LEVEL_STANDARD: u8 = 3;
const FEE_LEVEL_HIGH: u8 = 4;
const FEE_LEVEL_PREMIUM: u8 = 5;

const FEE_AMOUNT_FREE: u64 = 0;
const FEE_AMOUNT_MICRO: u64 = 10_000;
const FEE_AMOUNT_LOW: u64 = 100_000;
const FEE_AMOUNT_STANDARD: u64 = 1_000_000;
const FEE_AMOUNT_HIGH: u64 = 10_000_000;
const FEE_AMOUNT_PREMIUM: u64 = 100_000_000;

public struct AdminCap has key, store {
    id: UID,
    registry_id: ID,
}

public struct GovernanceVault has key {
    id: UID,
    registry_id: ID,
    admin_cap: AdminCap,
    governance_authority: address,
    active_operator: address,
    active_operator_epoch: u64,
    pending_operator: address,
    pending_operator_epoch: u64,
    has_pending_operator_transfer: bool,
    fee_recipient: address,
    publishing_fee_level: u8,
    comments_fee_level: u8,
}

public struct OperatorPermit has key, store {
    id: UID,
    registry_id: ID,
    operator_epoch: u64,
}

public fun new_vault(
    registry_id: ID,
    governance_authority: address,
    initial_operator: address,
    ctx: &mut TxContext,
): (GovernanceVault, OperatorPermit) {
    assert!(governance_authority != @0x0, E_INVALID_GOVERNANCE_AUTHORITY);
    assert!(initial_operator != @0x0, E_INVALID_OPERATOR);

    let admin_cap = AdminCap {
        id: object::new(ctx),
        registry_id,
    };

    let vault = GovernanceVault {
        id: object::new(ctx),
        registry_id,
        admin_cap,
        governance_authority,
        active_operator: initial_operator,
        active_operator_epoch: 1,
        pending_operator: @0x0,
        pending_operator_epoch: 0,
        has_pending_operator_transfer: false,
        fee_recipient: governance_authority,
        publishing_fee_level: FEE_LEVEL_FREE,
        comments_fee_level: FEE_LEVEL_FREE,
    };

    let permit = OperatorPermit {
        id: object::new(ctx),
        registry_id,
        operator_epoch: 1,
    };

    (vault, permit)
}

public fun registry_id(vault: &GovernanceVault): ID {
    vault.registry_id
}

public fun governance_authority(vault: &GovernanceVault): address {
    vault.governance_authority
}

public fun active_operator(vault: &GovernanceVault): address {
    vault.active_operator
}

public fun active_operator_epoch(vault: &GovernanceVault): u64 {
    vault.active_operator_epoch
}

public fun has_pending_operator_transfer(vault: &GovernanceVault): bool {
    vault.has_pending_operator_transfer
}

public fun pending_operator(vault: &GovernanceVault): address {
    vault.pending_operator
}

public fun pending_operator_epoch(vault: &GovernanceVault): u64 {
    vault.pending_operator_epoch
}

public fun operator_epoch(permit: &OperatorPermit): u64 {
    permit.operator_epoch
}

public fun fee_recipient(vault: &GovernanceVault): address {
    vault.fee_recipient
}

public fun publishing_fee_level(vault: &GovernanceVault): u8 {
    vault.publishing_fee_level
}

public fun comments_fee_level(vault: &GovernanceVault): u8 {
    vault.comments_fee_level
}

public fun publishing_fee_amount(vault: &GovernanceVault): u64 {
    fee_amount_for_level(vault.publishing_fee_level)
}

public fun comments_fee_amount(vault: &GovernanceVault): u64 {
    fee_amount_for_level(vault.comments_fee_level)
}

public fun borrow_admin_cap(vault: &GovernanceVault): &AdminCap {
    &vault.admin_cap
}

public fun share_vault(vault: GovernanceVault) {
    transfer::share_object(vault)
}

public fun set_fee_recipient(
    vault: &mut GovernanceVault,
    new_fee_recipient: address,
    ctx: &TxContext,
) {
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    apply_fee_recipient(vault, new_fee_recipient);
}

public fun set_publishing_fee_level(
    vault: &mut GovernanceVault,
    new_level: u8,
    ctx: &TxContext,
) {
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    apply_publishing_fee_level(vault, new_level);
}

public fun set_comments_fee_level(
    vault: &mut GovernanceVault,
    new_level: u8,
    ctx: &TxContext,
) {
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    apply_comments_fee_level(vault, new_level);
}

public fun collect_publishing_fee(
    vault: &GovernanceVault,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    collect_fee(vault, publishing_fee_amount(vault), payment, ctx);
}

public fun collect_comments_fee(
    vault: &GovernanceVault,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    collect_fee(vault, comments_fee_amount(vault), payment, ctx);
}

public fun assert_active_operator(
    vault: &GovernanceVault,
    permit: &OperatorPermit,
    registry_id: ID,
    sender: address,
) {
    assert!(vault.registry_id == registry_id, E_INVALID_REGISTRY);
    assert!(permit.registry_id == registry_id, E_INVALID_REGISTRY);
    assert!(sender == vault.active_operator, E_NOT_ACTIVE_OPERATOR);
    assert!(permit.operator_epoch == vault.active_operator_epoch, E_STALE_OPERATOR_PERMIT);
}

public fun nominate_operator(
    vault: &mut GovernanceVault,
    new_operator: address,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    nominate_operator_internal(vault, new_operator, ctx);
}

public(package) fun apply_fee_recipient(
    vault: &mut GovernanceVault,
    new_fee_recipient: address,
) {
    assert!(new_fee_recipient != @0x0, E_INVALID_GOVERNANCE_AUTHORITY);
    vault.fee_recipient = new_fee_recipient;
}

public(package) fun apply_publishing_fee_level(
    vault: &mut GovernanceVault,
    new_level: u8,
) {
    assert_valid_fee_level(new_level);
    vault.publishing_fee_level = new_level;
}

public(package) fun apply_comments_fee_level(
    vault: &mut GovernanceVault,
    new_level: u8,
) {
    assert_valid_fee_level(new_level);
    vault.comments_fee_level = new_level;
}

public(package) fun nominate_operator_from_vote(
    vault: &mut GovernanceVault,
    new_operator: address,
    ctx: &mut TxContext,
) {
    nominate_operator_internal(vault, new_operator, ctx);
}

fun nominate_operator_internal(
    vault: &mut GovernanceVault,
    new_operator: address,
    ctx: &mut TxContext,
) {
    assert!(!vault.has_pending_operator_transfer, E_PENDING_OPERATOR_TRANSFER_EXISTS);
    assert!(new_operator != @0x0, E_INVALID_OPERATOR);

    let new_epoch = vault.active_operator_epoch + 1;
    let permit = OperatorPermit {
        id: object::new(ctx),
        registry_id: vault.registry_id,
        operator_epoch: new_epoch,
    };

    vault.pending_operator = new_operator;
    vault.pending_operator_epoch = new_epoch;
    vault.has_pending_operator_transfer = true;

    let permit_wrapper = two_step_transfer::wrap(permit, ctx);
    two_step_transfer::initiate_transfer(permit_wrapper, new_operator, ctx);
}

public fun accept_operator_transfer(
    vault: &mut GovernanceVault,
    request: PendingOwnershipTransfer<OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<OperatorPermit>>,
    ctx: &mut TxContext,
) {
    assert!(vault.has_pending_operator_transfer, E_NO_PENDING_OPERATOR_TRANSFER);
    two_step_transfer::accept_transfer(request, wrapper_ticket, ctx);

    vault.active_operator = vault.pending_operator;
    vault.active_operator_epoch = vault.pending_operator_epoch;
    vault.pending_operator = @0x0;
    vault.pending_operator_epoch = 0;
    vault.has_pending_operator_transfer = false;
}

public fun cancel_operator_transfer(
    vault: &mut GovernanceVault,
    request: PendingOwnershipTransfer<OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<OperatorPermit>>,
    ctx: &mut TxContext,
) {
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    assert!(vault.has_pending_operator_transfer, E_NO_PENDING_OPERATOR_TRANSFER);
    two_step_transfer::cancel_transfer(request, wrapper_ticket, ctx);

    vault.pending_operator = @0x0;
    vault.pending_operator_epoch = 0;
    vault.has_pending_operator_transfer = false;
}

public fun unwrap_operator_permit(
    operator_wrapper: TwoStepTransferWrapper<OperatorPermit>,
    ctx: &mut TxContext,
): OperatorPermit {
    two_step_transfer::unwrap(operator_wrapper, ctx)
}

public fun borrow_operator_from_wrapper(
    operator_wrapper: &TwoStepTransferWrapper<OperatorPermit>,
): &OperatorPermit {
    two_step_transfer::borrow(operator_wrapper)
}

fun collect_fee(
    vault: &GovernanceVault,
    required_amount: u64,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    let mut payment = payment;

    if (required_amount == 0) {
        if (option::is_some(&payment)) {
            let refund_coin = option::extract(&mut payment);
            refund_or_destroy(refund_coin, sender);
        };
        option::destroy_none(payment);
        return
    };

    assert!(option::is_some(&payment), E_FEE_PAYMENT_REQUIRED);
    let mut payment_coin = option::extract(&mut payment);
    option::destroy_none(payment);

    assert!(coin::value(&payment_coin) >= required_amount, E_INSUFFICIENT_FEE_PAYMENT);

    let fee_coin = coin::split(&mut payment_coin, required_amount, ctx);
    transfer::public_transfer(fee_coin, vault.fee_recipient);
    refund_or_destroy(payment_coin, sender);
}

fun refund_or_destroy(coin_to_refund: Coin<SUI>, sender: address) {
    if (coin::value(&coin_to_refund) == 0) {
        coin::destroy_zero(coin_to_refund);
    } else {
        transfer::public_transfer(coin_to_refund, sender);
    };
}

fun assert_valid_fee_level(level: u8) {
    assert!(
        level == FEE_LEVEL_FREE ||
        level == FEE_LEVEL_MICRO ||
        level == FEE_LEVEL_LOW ||
        level == FEE_LEVEL_STANDARD ||
        level == FEE_LEVEL_HIGH ||
        level == FEE_LEVEL_PREMIUM,
        E_INVALID_FEE_LEVEL,
    );
}

fun fee_amount_for_level(level: u8): u64 {
    assert_valid_fee_level(level);

    if (level == FEE_LEVEL_FREE) {
        FEE_AMOUNT_FREE
    } else if (level == FEE_LEVEL_MICRO) {
        FEE_AMOUNT_MICRO
    } else if (level == FEE_LEVEL_LOW) {
        FEE_AMOUNT_LOW
    } else if (level == FEE_LEVEL_STANDARD) {
        FEE_AMOUNT_STANDARD
    } else if (level == FEE_LEVEL_HIGH) {
        FEE_AMOUNT_HIGH
    } else {
        FEE_AMOUNT_PREMIUM
    }
}
