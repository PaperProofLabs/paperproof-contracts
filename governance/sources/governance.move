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
use sui::event;
use sui::package::{Self as package, UpgradeCap, UpgradeReceipt, UpgradeTicket};
use sui::sui::SUI;
use sui::table::{Self as table, Table};
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
const E_NOT_UPGRADE_AUTHORITY: u64 = 12;
const E_UNSUPPORTED_VAULT_VERSION: u64 = 13;
const E_INVALID_MANAGED_UPGRADE_CAP: u64 = 14;
const E_INVALID_DIRECT_AUTHORITY_MODE: u64 = 15;
const E_DIRECT_AUTHORITY_DISABLED: u64 = 16;
const E_INVALID_OPERATOR_TRANSFER_REQUEST: u64 = 17;
const E_GOVERNANCE_CONFIG_ALREADY_BOUND: u64 = 18;

const GOVERNANCE_VAULT_VERSION: u64 = 1;

const ACTION_SET_COMMENTS_FEE_LEVEL: u8 = 2;
const ACTION_SET_ARTIFACT_TYPE_ENABLED: u8 = 9;
const ACTION_SET_ARTIFACT_FEE_LEVEL: u8 = 10;
const ACTION_ACTIVATE_ARTIFACT_TYPE: u8 = 11;

const FEE_KEY_COMMENTS: u8 = 0;

const DIRECT_AUTHORITY_MODE_FULL: u8 = 0;
const DIRECT_AUTHORITY_MODE_EMERGENCY: u8 = 1;
const DIRECT_AUTHORITY_MODE_READ_ONLY: u8 = 2;
const DIRECT_AUTHORITY_MODE_DISABLED: u8 = 3;

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
    version: u64,
    registry_id: ID,
    governance_config_id: ID,
    admin_cap: AdminCap,
    governance_authority: address,
    upgrade_authority: address,
    active_operator: address,
    active_operator_epoch: u64,
    pending_operator: address,
    pending_operator_epoch: u64,
    pending_operator_wrapper_id: ID,
    has_pending_operator_transfer: bool,
    fee_recipient: address,
    direct_authority_mode: u8,
    direct_authority_permanently_disabled: bool,
}

public struct FeeManager has key {
    id: UID,
    version: u64,
    registry_id: ID,
    fee_levels: Table<u8, u8>,
}

public struct GovernanceActionTicket {
    registry_id: ID,
    action_type: u8,
    payload_u64_1: u64,
    payload_u64_2: u64,
    executed_by: address,
}

public struct GovernanceActionExecutorCap has key, store {
    id: UID,
    registry_id: ID,
    governance_vault_id: ID,
}

public struct OperatorPermit has key, store {
    id: UID,
    registry_id: ID,
    operator_epoch: u64,
}

public struct ManagedUpgradeCap has key {
    id: UID,
    registry_id: ID,
    cap: UpgradeCap,
}

#[allow(unused_field)]
public struct GovernanceVaultCreatedEvent has copy, drop {
    registry_id: ID,
    vault_id: ID,
    governance_config_id: ID,
    governance_authority: address,
    upgrade_authority: address,
    active_operator: address,
    active_operator_epoch: u64,
    fee_recipient: address,
    direct_authority_mode: u8,
}

#[allow(unused_field)]
public struct FeeManagerCreatedEvent has copy, drop {
    registry_id: ID,
    fee_manager_id: ID,
    created_by: address,
}

public struct GovernanceConfigBoundEvent has copy, drop {
    registry_id: ID,
    vault_id: ID,
    governance_config_id: ID,
    bound_by: address,
}

public struct OperatorNominatedEvent has copy, drop {
    registry_id: ID,
    nominated_by: address,
    new_operator: address,
    operator_epoch: u64,
    pending_operator_wrapper_id: ID,
}

public struct OperatorTransferAcceptedEvent has copy, drop {
    registry_id: ID,
    accepted_by: address,
    operator_epoch: u64,
    operator_wrapper_id: ID,
}

public struct OperatorTransferCancelledEvent has copy, drop {
    registry_id: ID,
    cancelled_by: address,
    pending_operator: address,
    pending_operator_epoch: u64,
    pending_operator_wrapper_id: ID,
}

public struct FeeRecipientChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_fee_recipient: address,
    new_fee_recipient: address,
}

public struct CommentsFeeLevelChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_level: u8,
    new_level: u8,
    new_amount: u64,
}

public struct ArtifactFeeLevelChangedEvent has copy, drop {
    registry_id: ID,
    artifact_type: u8,
    changed_by: address,
    old_fee_level: u8,
    fee_level: u8,
    fee_amount: u64,
}

public struct UpgradeAuthorityChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_upgrade_authority: address,
    new_upgrade_authority: address,
}

public struct FeeCollectedEvent has copy, drop {
    registry_id: ID,
    fee_key: u8,
    artifact_type: u8,
    payer: address,
    recipient: address,
    amount: u64,
}

public struct DirectAuthorityModeChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_mode: u8,
    new_mode: u8,
    permanently_disabled: bool,
}

public struct ManagedUpgradeCapRegisteredEvent has copy, drop {
    registry_id: ID,
    registered_by: address,
    package_id: ID,
}

public struct ManagedUpgradeAuthorizedEvent has copy, drop {
    registry_id: ID,
    authorized_by: address,
    package_id: ID,
    policy: u8,
    digest: vector<u8>,
}

public struct ManagedUpgradeCommittedEvent has copy, drop {
    registry_id: ID,
    committed_by: address,
    package_id: ID,
}

public struct GovernanceVaultMigratedEvent has copy, drop {
    registry_id: ID,
    migrated_by: address,
    new_version: u64,
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

    let vault_uid = object::new(ctx);
    let vault = GovernanceVault {
        id: vault_uid,
        version: GOVERNANCE_VAULT_VERSION,
        registry_id,
        governance_config_id: object::id_from_address(@0x0),
        admin_cap,
        governance_authority,
        upgrade_authority: governance_authority,
        active_operator: initial_operator,
        active_operator_epoch: 1,
        pending_operator: @0x0,
        pending_operator_epoch: 0,
        pending_operator_wrapper_id: object::id_from_address(@0x0),
        has_pending_operator_transfer: false,
        fee_recipient: governance_authority,
        direct_authority_mode: DIRECT_AUTHORITY_MODE_FULL,
        direct_authority_permanently_disabled: false,
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

public fun governance_config_id(vault: &GovernanceVault): ID {
    vault.governance_config_id
}

public fun governance_vault_version(vault: &GovernanceVault): u64 {
    vault.version
}

public fun current_governance_vault_version(): u64 {
    GOVERNANCE_VAULT_VERSION
}

public fun governance_authority(vault: &GovernanceVault): address {
    vault.governance_authority
}

public fun upgrade_authority(vault: &GovernanceVault): address {
    vault.upgrade_authority
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

public fun pending_operator_wrapper_id(vault: &GovernanceVault): ID {
    vault.pending_operator_wrapper_id
}

public fun operator_epoch(permit: &OperatorPermit): u64 {
    permit.operator_epoch
}

public fun fee_recipient(vault: &GovernanceVault): address {
    vault.fee_recipient
}

public fun direct_authority_mode(vault: &GovernanceVault): u8 {
    vault.direct_authority_mode
}

public fun direct_authority_permanently_disabled(vault: &GovernanceVault): bool {
    vault.direct_authority_permanently_disabled
}

public fun action_executor_cap_registry_id(cap: &GovernanceActionExecutorCap): ID {
    cap.registry_id
}

public fun new_vault_with_action_executor_cap(
    registry_id: ID,
    governance_authority: address,
    initial_operator: address,
    ctx: &mut TxContext,
): (GovernanceVault, OperatorPermit, GovernanceActionExecutorCap) {
    let (vault, permit) = new_vault(registry_id, governance_authority, initial_operator, ctx);
    let action_executor_cap = GovernanceActionExecutorCap {
        id: object::new(ctx),
        registry_id,
        governance_vault_id: object::id(&vault),
    };
    (vault, permit, action_executor_cap)
}

public fun assert_action_executor_cap(
    vault: &GovernanceVault,
    cap: &GovernanceActionExecutorCap,
) {
    assert_current_vault(vault);
    assert!(cap.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    assert!(cap.governance_vault_id == object::id(vault), E_INVALID_REGISTRY);
}

public fun direct_authority_mode_full(): u8 {
    DIRECT_AUTHORITY_MODE_FULL
}

public fun direct_authority_mode_emergency(): u8 {
    DIRECT_AUTHORITY_MODE_EMERGENCY
}

public fun direct_authority_mode_read_only(): u8 {
    DIRECT_AUTHORITY_MODE_READ_ONLY
}

public fun direct_authority_mode_disabled(): u8 {
    DIRECT_AUTHORITY_MODE_DISABLED
}

public fun borrow_admin_cap(vault: &GovernanceVault): &AdminCap {
    &vault.admin_cap
}

public fun assert_current_vault(vault: &GovernanceVault) {
    assert!(vault.version == GOVERNANCE_VAULT_VERSION, E_UNSUPPORTED_VAULT_VERSION);
}

public fun assert_upgrade_authority(vault: &GovernanceVault, sender: address) {
    assert_current_vault(vault);
    assert!(sender == vault.upgrade_authority, E_NOT_UPGRADE_AUTHORITY);
}

public fun share_vault(vault: GovernanceVault) {
    transfer::share_object(vault)
}

public(package) fun bind_governance_config(
    vault: &mut GovernanceVault,
    governance_config_id: ID,
    ctx: &TxContext,
) {
    assert_current_vault(vault);
    assert!(
        vault.governance_config_id == object::id_from_address(@0x0),
        E_GOVERNANCE_CONFIG_ALREADY_BOUND,
    );
    vault.governance_config_id = governance_config_id;
    event::emit(GovernanceConfigBoundEvent {
        registry_id: vault.registry_id,
        vault_id: object::id(vault),
        governance_config_id,
        bound_by: tx_context::sender(ctx),
    });
}

public fun new_fee_manager(
    registry_id: ID,
    ctx: &mut TxContext,
): FeeManager {
    let fee_manager_uid = object::new(ctx);
    FeeManager {
        id: fee_manager_uid,
        version: GOVERNANCE_VAULT_VERSION,
        registry_id,
        fee_levels: table::new(ctx),
    }
}

public fun share_fee_manager(fee_manager: FeeManager) {
    transfer::share_object(fee_manager)
}

public(package) fun new_action_ticket(
    registry_id: ID,
    action_type: u8,
    payload_u64_1: u64,
    payload_u64_2: u64,
    executed_by: address,
): GovernanceActionTicket {
    GovernanceActionTicket {
        registry_id,
        action_type,
        payload_u64_1,
        payload_u64_2,
        executed_by,
    }
}

public fun action_ticket_registry_id(ticket: &GovernanceActionTicket): ID {
    ticket.registry_id
}

public fun action_ticket_action_type(ticket: &GovernanceActionTicket): u8 {
    ticket.action_type
}

public fun action_ticket_payload_u64_1(ticket: &GovernanceActionTicket): u64 {
    ticket.payload_u64_1
}

public fun action_ticket_payload_u64_2(ticket: &GovernanceActionTicket): u64 {
    ticket.payload_u64_2
}

public fun fee_manager_id(fee_manager: &FeeManager): ID {
    object::id(fee_manager)
}

public fun fee_manager_registry_id(fee_manager: &FeeManager): ID {
    fee_manager.registry_id
}

public fun artifact_fee_level(
    fee_manager: &FeeManager,
    artifact_type: u8,
): u8 {
    fee_level(fee_manager, artifact_type)
}

public fun comments_fee_level(fee_manager: &FeeManager): u8 {
    fee_level(fee_manager, FEE_KEY_COMMENTS)
}

public fun comments_fee_amount(fee_manager: &FeeManager): u64 {
    fee_amount_for_level(comments_fee_level(fee_manager))
}

public fun fee_level(
    fee_manager: &FeeManager,
    fee_key: u8,
): u8 {
    if (table::contains(&fee_manager.fee_levels, fee_key)) {
        *table::borrow(&fee_manager.fee_levels, fee_key)
    } else {
        FEE_LEVEL_FREE
    }
}

public fun artifact_fee_amount(
    fee_manager: &FeeManager,
    artifact_type: u8,
): u64 {
    fee_amount_for_level(artifact_fee_level(fee_manager, artifact_type))
}

public(package) fun apply_comments_fee_level_from_ticket(
    vault: &GovernanceVault,
    fee_manager: &mut FeeManager,
    ticket: GovernanceActionTicket,
) {
    assert_current_vault(vault);
    let GovernanceActionTicket {
        registry_id,
        action_type,
        payload_u64_1,
        payload_u64_2: _,
        executed_by,
    } = ticket;
    assert!(registry_id == vault.registry_id, E_INVALID_REGISTRY);
    assert!(fee_manager.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    assert!(action_type == ACTION_SET_COMMENTS_FEE_LEVEL, E_INVALID_GOVERNANCE_AUTHORITY);

    apply_comments_fee_level(fee_manager, payload_u64_1 as u8, executed_by);
}

public fun apply_artifact_fee_level_from_ticket(
    vault: &GovernanceVault,
    fee_manager: &mut FeeManager,
    ticket: GovernanceActionTicket,
) {
    assert_current_vault(vault);
    let GovernanceActionTicket {
        registry_id,
        action_type,
        payload_u64_1,
        payload_u64_2,
        executed_by,
    } = ticket;
    assert!(registry_id == vault.registry_id, E_INVALID_REGISTRY);
    assert!(fee_manager.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    assert!(action_type == ACTION_SET_ARTIFACT_FEE_LEVEL || action_type == ACTION_ACTIVATE_ARTIFACT_TYPE, E_INVALID_GOVERNANCE_AUTHORITY);

    let artifact_type = payload_u64_1 as u8;
    let fee_level = payload_u64_2 as u8;
    assert_valid_fee_level(fee_level);
    let old_fee_level = artifact_fee_level(fee_manager, artifact_type);

    set_fee_level(fee_manager, artifact_type, fee_level);

    event::emit(ArtifactFeeLevelChangedEvent {
        registry_id: fee_manager.registry_id,
        artifact_type,
        changed_by: executed_by,
        old_fee_level,
        fee_level,
        fee_amount: fee_amount_for_level(fee_level),
    });
}

public fun unpack_artifact_type_enabled_ticket(
    ticket: GovernanceActionTicket,
): (ID, u64, u64, address) {
    let GovernanceActionTicket {
        registry_id,
        action_type,
        payload_u64_1,
        payload_u64_2,
        executed_by,
    } = ticket;
    assert!(action_type == ACTION_SET_ARTIFACT_TYPE_ENABLED, E_INVALID_GOVERNANCE_AUTHORITY);
    (registry_id, payload_u64_1, payload_u64_2, executed_by)
}

public(package) fun apply_direct_authority_mode_from_vote(
    vault: &mut GovernanceVault,
    new_mode: u8,
    changed_by: address,
) {
    assert_valid_direct_authority_mode(new_mode);
    assert!(
        !vault.direct_authority_permanently_disabled || new_mode == DIRECT_AUTHORITY_MODE_DISABLED,
        E_DIRECT_AUTHORITY_DISABLED,
    );

    let old_mode = vault.direct_authority_mode;
    vault.direct_authority_mode = new_mode;
    if (new_mode == DIRECT_AUTHORITY_MODE_DISABLED) {
        vault.direct_authority_permanently_disabled = true;
    };

    event::emit(DirectAuthorityModeChangedEvent {
        registry_id: vault.registry_id,
        changed_by,
        old_mode,
        new_mode,
        permanently_disabled: vault.direct_authority_permanently_disabled,
    });
}

public fun collect_artifact_fee(
    vault: &GovernanceVault,
    fee_manager: &FeeManager,
    artifact_type: u8,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    assert_current_vault(vault);
    assert!(fee_manager.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    collect_fee(
        vault,
        artifact_type,
        artifact_type,
        artifact_fee_amount(fee_manager, artifact_type),
        payment,
        ctx,
    )
}

public fun collect_comments_fee(
    vault: &GovernanceVault,
    fee_manager: &FeeManager,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    assert_current_vault(vault);
    assert!(fee_manager.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    collect_fee(
        vault,
        FEE_KEY_COMMENTS,
        0,
        comments_fee_amount(fee_manager),
        payment,
        ctx,
    )
}

public fun register_managed_upgrade_cap(
    vault: &GovernanceVault,
    cap: UpgradeCap,
    ctx: &mut TxContext,
): ManagedUpgradeCap {
    assert_current_vault(vault);
    assert!(tx_context::sender(ctx) == vault.upgrade_authority, E_NOT_UPGRADE_AUTHORITY);
    assert!(package::upgrade_package(&cap).to_address() != @0x0, E_INVALID_MANAGED_UPGRADE_CAP);
    let package_id = package::upgrade_package(&cap);
    let managed_cap = ManagedUpgradeCap {
        id: object::new(ctx),
        registry_id: vault.registry_id,
        cap,
    };
    event::emit(ManagedUpgradeCapRegisteredEvent {
        registry_id: vault.registry_id,
        registered_by: tx_context::sender(ctx),
        package_id,
    });
    managed_cap
}

public fun share_managed_upgrade_cap(managed_cap: ManagedUpgradeCap) {
    transfer::share_object(managed_cap)
}

public fun managed_upgrade_package(managed_cap: &ManagedUpgradeCap): ID {
    package::upgrade_package(&managed_cap.cap)
}

public fun authorize_managed_upgrade(
    vault: &GovernanceVault,
    managed_cap: &mut ManagedUpgradeCap,
    policy: u8,
    digest: vector<u8>,
    ctx: &TxContext,
): UpgradeTicket {
    assert_current_vault(vault);
    assert!(tx_context::sender(ctx) == vault.upgrade_authority, E_NOT_UPGRADE_AUTHORITY);
    assert!(managed_cap.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    event::emit(ManagedUpgradeAuthorizedEvent {
        registry_id: vault.registry_id,
        authorized_by: tx_context::sender(ctx),
        package_id: package::upgrade_package(&managed_cap.cap),
        policy,
        digest: copy digest,
    });
    managed_cap.cap.authorize(policy, digest)
}

public fun commit_managed_upgrade(
    vault: &GovernanceVault,
    managed_cap: &mut ManagedUpgradeCap,
    receipt: UpgradeReceipt,
    ctx: &TxContext,
) {
    assert_current_vault(vault);
    assert!(tx_context::sender(ctx) == vault.upgrade_authority, E_NOT_UPGRADE_AUTHORITY);
    assert!(managed_cap.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    managed_cap.cap.commit(receipt);
    event::emit(ManagedUpgradeCommittedEvent {
        registry_id: vault.registry_id,
        committed_by: tx_context::sender(ctx),
        package_id: package::upgrade_package(&managed_cap.cap),
    });
}

public fun migrate_vault(
    vault: &mut GovernanceVault,
    ctx: &TxContext,
) {
    assert!(tx_context::sender(ctx) == vault.upgrade_authority, E_NOT_UPGRADE_AUTHORITY);
    migrate_vault_version(vault);
    event::emit(GovernanceVaultMigratedEvent {
        registry_id: vault.registry_id,
        migrated_by: tx_context::sender(ctx),
        new_version: vault.version,
    });
}

public fun set_fee_recipient(
    vault: &mut GovernanceVault,
    new_fee_recipient: address,
    ctx: &TxContext,
) {
    assert_current_vault(vault);
    assert_direct_authority_allowed(vault, false);
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    apply_fee_recipient(vault, new_fee_recipient, tx_context::sender(ctx));
}

public fun set_upgrade_authority(
    vault: &mut GovernanceVault,
    new_upgrade_authority: address,
    ctx: &TxContext,
) {
    assert_current_vault(vault);
    assert_direct_authority_allowed(vault, true);
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    apply_upgrade_authority(vault, new_upgrade_authority, tx_context::sender(ctx));
}

public fun set_comments_fee_level(
    vault: &GovernanceVault,
    fee_manager: &mut FeeManager,
    new_level: u8,
    ctx: &TxContext,
) {
    assert_current_vault(vault);
    assert_direct_authority_allowed(vault, false);
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    assert!(fee_manager.registry_id == vault.registry_id, E_INVALID_REGISTRY);
    apply_comments_fee_level(fee_manager, new_level, tx_context::sender(ctx));
}

public fun assert_active_operator(
    vault: &GovernanceVault,
    permit: &OperatorPermit,
    registry_id: ID,
    sender: address,
) {
    assert_current_vault(vault);
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
    assert_current_vault(vault);
    assert_direct_authority_allowed(vault, true);
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    nominate_operator_internal(vault, new_operator, tx_context::sender(ctx), ctx);
}

public(package) fun apply_fee_recipient(
    vault: &mut GovernanceVault,
    new_fee_recipient: address,
    changed_by: address,
) {
    assert!(new_fee_recipient != @0x0, E_INVALID_GOVERNANCE_AUTHORITY);
    let old_fee_recipient = vault.fee_recipient;
    vault.fee_recipient = new_fee_recipient;
    event::emit(FeeRecipientChangedEvent {
        registry_id: vault.registry_id,
        changed_by,
        old_fee_recipient,
        new_fee_recipient,
    });
}

public(package) fun apply_upgrade_authority(
    vault: &mut GovernanceVault,
    new_upgrade_authority: address,
    changed_by: address,
) {
    assert!(new_upgrade_authority != @0x0, E_INVALID_GOVERNANCE_AUTHORITY);
    let old_upgrade_authority = vault.upgrade_authority;
    vault.upgrade_authority = new_upgrade_authority;
    event::emit(UpgradeAuthorityChangedEvent {
        registry_id: vault.registry_id,
        changed_by,
        old_upgrade_authority,
        new_upgrade_authority,
    });
}

public(package) fun nominate_operator_from_vote(
    vault: &mut GovernanceVault,
    new_operator: address,
    ctx: &mut TxContext,
) {
    nominate_operator_internal(vault, new_operator, tx_context::sender(ctx), ctx);
}

fun nominate_operator_internal(
    vault: &mut GovernanceVault,
    new_operator: address,
    nominated_by: address,
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
    let wrapper_id = object::id(&permit_wrapper);
    vault.pending_operator_wrapper_id = wrapper_id;
    two_step_transfer::initiate_transfer(permit_wrapper, new_operator, ctx);
    event::emit(OperatorNominatedEvent {
        registry_id: vault.registry_id,
        nominated_by,
        new_operator,
        operator_epoch: new_epoch,
        pending_operator_wrapper_id: wrapper_id,
    });
}

public fun accept_operator_transfer(
    vault: &mut GovernanceVault,
    request: PendingOwnershipTransfer<OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<OperatorPermit>>,
    ctx: &mut TxContext,
) {
    assert_current_vault(vault);
    assert!(vault.has_pending_operator_transfer, E_NO_PENDING_OPERATOR_TRANSFER);
    assert!(
        transfer::receiving_object_id(&wrapper_ticket) == vault.pending_operator_wrapper_id,
        E_INVALID_OPERATOR_TRANSFER_REQUEST,
    );
    let operator_wrapper_id = vault.pending_operator_wrapper_id;
    two_step_transfer::accept_transfer(request, wrapper_ticket, ctx);

    vault.active_operator = vault.pending_operator;
    vault.active_operator_epoch = vault.pending_operator_epoch;
    vault.pending_operator = @0x0;
    vault.pending_operator_epoch = 0;
    vault.pending_operator_wrapper_id = object::id_from_address(@0x0);
    vault.has_pending_operator_transfer = false;
    event::emit(OperatorTransferAcceptedEvent {
        registry_id: vault.registry_id,
        accepted_by: tx_context::sender(ctx),
        operator_epoch: vault.active_operator_epoch,
        operator_wrapper_id,
    });
}

public fun cancel_operator_transfer(
    vault: &mut GovernanceVault,
    request: PendingOwnershipTransfer<OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<OperatorPermit>>,
    ctx: &mut TxContext,
) {
    assert_current_vault(vault);
    assert_direct_authority_allowed(vault, true);
    assert!(tx_context::sender(ctx) == vault.governance_authority, E_NOT_GOVERNANCE_AUTHORITY);
    assert!(vault.has_pending_operator_transfer, E_NO_PENDING_OPERATOR_TRANSFER);
    assert!(
        transfer::receiving_object_id(&wrapper_ticket) == vault.pending_operator_wrapper_id,
        E_INVALID_OPERATOR_TRANSFER_REQUEST,
    );
    let pending_operator = vault.pending_operator;
    let pending_operator_epoch = vault.pending_operator_epoch;
    let pending_operator_wrapper_id = vault.pending_operator_wrapper_id;
    two_step_transfer::cancel_transfer(request, wrapper_ticket, ctx);

    vault.pending_operator = @0x0;
    vault.pending_operator_epoch = 0;
    vault.pending_operator_wrapper_id = object::id_from_address(@0x0);
    vault.has_pending_operator_transfer = false;
    event::emit(OperatorTransferCancelledEvent {
        registry_id: vault.registry_id,
        cancelled_by: tx_context::sender(ctx),
        pending_operator,
        pending_operator_epoch,
        pending_operator_wrapper_id,
    });
}

public(package) fun cancel_operator_transfer_from_vote(
    vault: &mut GovernanceVault,
    request: PendingOwnershipTransfer<OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<OperatorPermit>>,
    ctx: &mut TxContext,
) {
    assert_current_vault(vault);
    assert!(vault.has_pending_operator_transfer, E_NO_PENDING_OPERATOR_TRANSFER);
    assert!(
        transfer::receiving_object_id(&wrapper_ticket) == vault.pending_operator_wrapper_id,
        E_INVALID_OPERATOR_TRANSFER_REQUEST,
    );
    let pending_operator = vault.pending_operator;
    let pending_operator_epoch = vault.pending_operator_epoch;
    let pending_operator_wrapper_id = vault.pending_operator_wrapper_id;
    two_step_transfer::cancel_transfer(request, wrapper_ticket, ctx);

    vault.pending_operator = @0x0;
    vault.pending_operator_epoch = 0;
    vault.pending_operator_wrapper_id = object::id_from_address(@0x0);
    vault.has_pending_operator_transfer = false;
    event::emit(OperatorTransferCancelledEvent {
        registry_id: vault.registry_id,
        cancelled_by: tx_context::sender(ctx),
        pending_operator,
        pending_operator_epoch,
        pending_operator_wrapper_id,
    });
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
    fee_key: u8,
    artifact_type: u8,
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
    event::emit(FeeCollectedEvent {
        registry_id: vault.registry_id,
        fee_key,
        artifact_type,
        payer: sender,
        recipient: vault.fee_recipient,
        amount: required_amount,
    });
    refund_or_destroy(payment_coin, sender);
}

fun apply_comments_fee_level(
    fee_manager: &mut FeeManager,
    new_level: u8,
    changed_by: address,
) {
    assert_valid_fee_level(new_level);
    let old_level = comments_fee_level(fee_manager);
    set_fee_level(fee_manager, FEE_KEY_COMMENTS, new_level);
    event::emit(CommentsFeeLevelChangedEvent {
        registry_id: fee_manager.registry_id,
        changed_by,
        old_level,
        new_level,
        new_amount: fee_amount_for_level(new_level),
    });
}

fun set_fee_level(
    fee_manager: &mut FeeManager,
    fee_key: u8,
    new_level: u8,
) {
    assert_valid_fee_level(new_level);
    if (table::contains(&fee_manager.fee_levels, fee_key)) {
        *table::borrow_mut(&mut fee_manager.fee_levels, fee_key) = new_level;
    } else {
        table::add(&mut fee_manager.fee_levels, fee_key, new_level);
    };
}

fun assert_direct_authority_allowed(vault: &GovernanceVault, emergency_allowed: bool) {
    assert!(
        vault.direct_authority_mode == DIRECT_AUTHORITY_MODE_FULL ||
        (emergency_allowed && vault.direct_authority_mode == DIRECT_AUTHORITY_MODE_EMERGENCY),
        E_DIRECT_AUTHORITY_DISABLED,
    );
}

public fun assert_valid_direct_authority_mode(mode: u8) {
    assert!(
        mode == DIRECT_AUTHORITY_MODE_FULL ||
        mode == DIRECT_AUTHORITY_MODE_EMERGENCY ||
        mode == DIRECT_AUTHORITY_MODE_READ_ONLY ||
        mode == DIRECT_AUTHORITY_MODE_DISABLED,
        E_INVALID_DIRECT_AUTHORITY_MODE,
    );
}


fun migrate_vault_version(vault: &mut GovernanceVault) {
    assert!(vault.version <= GOVERNANCE_VAULT_VERSION, E_UNSUPPORTED_VAULT_VERSION);
    if (vault.version < GOVERNANCE_VAULT_VERSION) {
        vault.version = GOVERNANCE_VAULT_VERSION;
    };
}

fun refund_or_destroy(coin_to_refund: Coin<SUI>, sender: address) {
    if (coin::value(&coin_to_refund) == 0) {
        coin::destroy_zero(coin_to_refund);
    } else {
        transfer::public_transfer(coin_to_refund, sender);
    };
}

public fun assert_valid_fee_level(level: u8) {
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
