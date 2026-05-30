// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_memory_registry::memory_registry;

use paperproof_governance::governance::{Self as governance, GovernanceVault};
use std::string::{Self as string, String};
use sui::event;
use sui::table::{Self as table, Table};

const REGISTRY_VERSION: u64 = 1;
const ENTRY_VERSION: u64 = 1;

const E_INVALID_GOVERNANCE: u64 = 1;
const E_EMPTY_APP_ID: u64 = 2;
const E_EMPTY_PROVIDER: u64 = 3;
const E_EMPTY_NAMESPACE_ROOT: u64 = 4;
const E_TEXT_TOO_LONG: u64 = 5;
const E_ZERO_ACCOUNT: u64 = 6;
const E_EMPTY_MEMORY_ID: u64 = 7;
const E_EMPTY_ARTIFACT_CODE: u64 = 8;
const E_INVALID_VERSION_POLICY: u64 = 9;
const E_NOT_OWNER: u64 = 10;
const E_ZERO_SERIES: u64 = 11;
const E_PROVIDER_NOT_FOUND: u64 = 12;
const E_ACTIVE_ENTRY_EXISTS: u64 = 13;

const MAX_APP_ID_BYTES: u64 = 64;
const MAX_MEMORY_ID_BYTES: u64 = 128;
const MAX_PROVIDER_BYTES: u64 = 32;
const MAX_NAMESPACE_ROOT_BYTES: u64 = 128;
const MAX_ARTIFACT_CODE_BYTES: u64 = 96;

public struct MemoryRegistry has key {
    id: UID,
    version: u64,
    root_id: ID,
    governance_vault_id: ID,
    provider_policies: Table<String, ProviderPolicy>,
    active_entries: Table<address, Table<String, ID>>,
}

public struct ProviderPolicy has copy, drop, store {
    provider: String,
    enabled: bool,
    min_schema_version: u64,
    max_schema_version: u64,
    updated_epoch: u64,
    updated_by: address,
}

public struct MemoryEntry has key {
    id: UID,
    version: u64,
    registry_id: ID,
    owner: address,
    app_id: String,
    memory_id: String,
    provider: String,
    account_id: ID,
    namespace_root: String,
    artifact_code: String,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    schema_version: u64,
    available: bool,
    owner_enabled: bool,
    owner_deleted: bool,
    deleted_epoch: Option<u64>,
    created_epoch: u64,
    updated_epoch: u64,
    updated_by: address,
}

public struct MemoryRegistryCreatedEvent has copy, drop {
    registry_id: ID,
    root_id: ID,
    governance_vault_id: ID,
    version: u64,
}

public struct ProviderPolicySetEvent has copy, drop {
    registry_id: ID,
    provider: String,
    enabled: bool,
    min_schema_version: u64,
    max_schema_version: u64,
    updated_epoch: u64,
    updated_by: address,
}

public struct MemoryEntryCreatedEvent has copy, drop {
    registry_id: ID,
    entry_id: ID,
    owner: address,
    app_id: String,
    memory_id: String,
    provider: String,
    account_id: ID,
    namespace_root: String,
    artifact_code: String,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    schema_version: u64,
    available: bool,
    owner_enabled: bool,
    owner_deleted: bool,
    updated_epoch: u64,
}

public struct MemoryEntryPointerUpdatedEvent has copy, drop {
    registry_id: ID,
    entry_id: ID,
    owner: address,
    account_id: ID,
    namespace_root: String,
    owner_enabled: bool,
    updated_epoch: u64,
}

public struct MemoryEntryDeletedEvent has copy, drop {
    registry_id: ID,
    entry_id: ID,
    owner: address,
    deleted_epoch: u64,
}

public struct MemoryEntryAvailabilitySetEvent has copy, drop {
    registry_id: ID,
    entry_id: ID,
    owner: address,
    available: bool,
    updated_epoch: u64,
    updated_by: address,
}

public struct MemoryEntryVersionPolicySetEvent has copy, drop {
    registry_id: ID,
    entry_id: ID,
    owner: address,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    updated_epoch: u64,
    updated_by: address,
}

public fun create_registry(
    root_id: ID,
    governance_vault: &GovernanceVault,
    ctx: &mut TxContext,
) {
    assert_governance_binding(root_id, governance_vault);
    assert_active_operator(governance_vault, tx_context::sender(ctx));
    let registry = MemoryRegistry {
        id: object::new(ctx),
        version: REGISTRY_VERSION,
        root_id,
        governance_vault_id: object::id(governance_vault),
        provider_policies: table::new(ctx),
        active_entries: table::new(ctx),
    };
    event::emit(MemoryRegistryCreatedEvent {
        registry_id: object::id(&registry),
        root_id,
        governance_vault_id: object::id(governance_vault),
        version: REGISTRY_VERSION,
    });
    transfer::share_object(registry);
}

public fun set_provider_policy(
    registry: &mut MemoryRegistry,
    governance_vault: &GovernanceVault,
    provider: String,
    enabled: bool,
    min_schema_version: u64,
    max_schema_version: u64,
    ctx: &mut TxContext,
) {
    assert_registry_governance(registry, governance_vault);
    assert_active_operator(governance_vault, tx_context::sender(ctx));
    validate_text(&provider, MAX_PROVIDER_BYTES, E_EMPTY_PROVIDER);
    let policy = ProviderPolicy {
        provider,
        enabled,
        min_schema_version,
        max_schema_version,
        updated_epoch: tx_context::epoch(ctx),
        updated_by: tx_context::sender(ctx),
    };
    let key = policy.provider;
    if (table::contains(&registry.provider_policies, key)) {
        *table::borrow_mut(&mut registry.provider_policies, key) = policy;
    } else {
        table::add(&mut registry.provider_policies, key, policy);
    };
    let saved = table::borrow(&registry.provider_policies, key);
    event::emit(ProviderPolicySetEvent {
        registry_id: object::id(registry),
        provider: saved.provider,
        enabled: saved.enabled,
        min_schema_version: saved.min_schema_version,
        max_schema_version: saved.max_schema_version,
        updated_epoch: saved.updated_epoch,
        updated_by: saved.updated_by,
    });
}

public fun create_memory_entry(
    registry: &mut MemoryRegistry,
    app_id: String,
    memory_id: String,
    provider: String,
    account_id: ID,
    namespace_root: String,
    artifact_code: String,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    schema_version: u64,
    ctx: &mut TxContext,
) {
    validate_entry_input(&app_id, &memory_id, &provider, account_id, &namespace_root, &artifact_code, series_id, &pinned_version_id, use_latest);
    let owner = tx_context::sender(ctx);
    assert_no_active_entry(registry, owner, app_id);
    let entry = MemoryEntry {
        id: object::new(ctx),
        version: ENTRY_VERSION,
        registry_id: object::id(registry),
        owner,
        app_id,
        memory_id,
        provider,
        account_id,
        namespace_root,
        artifact_code,
        series_id,
        pinned_version_id,
        use_latest,
        schema_version,
        available: true,
        owner_enabled: true,
        owner_deleted: false,
        deleted_epoch: option::none(),
        created_epoch: tx_context::epoch(ctx),
        updated_epoch: tx_context::epoch(ctx),
        updated_by: owner,
    };
    event::emit(MemoryEntryCreatedEvent {
        registry_id: object::id(registry),
        entry_id: object::id(&entry),
        owner,
        app_id: entry.app_id,
        memory_id: entry.memory_id,
        provider: entry.provider,
        account_id: entry.account_id,
        namespace_root: entry.namespace_root,
        artifact_code: entry.artifact_code,
        series_id: entry.series_id,
        pinned_version_id: entry.pinned_version_id,
        use_latest: entry.use_latest,
        schema_version: entry.schema_version,
        available: entry.available,
        owner_enabled: entry.owner_enabled,
        owner_deleted: entry.owner_deleted,
        updated_epoch: entry.updated_epoch,
    });
    ensure_owner_entries_table(registry, owner, ctx);
    let owner_entries = table::borrow_mut(&mut registry.active_entries, owner);
    table::add(owner_entries, entry.app_id, object::id(&entry));
    transfer::share_object(entry);
}

public fun update_memory_pointer(
    entry: &mut MemoryEntry,
    account_id: ID,
    namespace_root: String,
    owner_enabled: bool,
    ctx: &mut TxContext,
) {
    assert_owner(entry, tx_context::sender(ctx));
    assert!(account_id.to_address() != @0x0, E_ZERO_ACCOUNT);
    validate_text(&namespace_root, MAX_NAMESPACE_ROOT_BYTES, E_EMPTY_NAMESPACE_ROOT);
    entry.account_id = account_id;
    entry.namespace_root = namespace_root;
    entry.owner_enabled = owner_enabled;
    entry.updated_epoch = tx_context::epoch(ctx);
    entry.updated_by = tx_context::sender(ctx);
    event::emit(MemoryEntryPointerUpdatedEvent {
        registry_id: entry.registry_id,
        entry_id: object::id(entry),
        owner: entry.owner,
        account_id,
        namespace_root: entry.namespace_root,
        owner_enabled,
        updated_epoch: entry.updated_epoch,
    });
}

public fun disable_own_memory_entry(entry: &mut MemoryEntry, ctx: &mut TxContext) {
    assert_owner(entry, tx_context::sender(ctx));
    entry.owner_enabled = false;
    entry.updated_epoch = tx_context::epoch(ctx);
    entry.updated_by = tx_context::sender(ctx);
    event::emit(MemoryEntryPointerUpdatedEvent {
        registry_id: entry.registry_id,
        entry_id: object::id(entry),
        owner: entry.owner,
        account_id: entry.account_id,
        namespace_root: entry.namespace_root,
        owner_enabled: false,
        updated_epoch: entry.updated_epoch,
    });
}

public fun delete_own_memory_entry(registry: &mut MemoryRegistry, entry: &mut MemoryEntry, ctx: &mut TxContext) {
    assert_entry_registry(registry, entry);
    assert_owner(entry, tx_context::sender(ctx));
    release_active_entry(registry, entry.owner, entry.app_id, object::id(entry));
    entry.owner_enabled = false;
    entry.owner_deleted = true;
    entry.available = false;
    entry.deleted_epoch = option::some(tx_context::epoch(ctx));
    entry.updated_epoch = tx_context::epoch(ctx);
    entry.updated_by = tx_context::sender(ctx);
    event::emit(MemoryEntryDeletedEvent {
        registry_id: entry.registry_id,
        entry_id: object::id(entry),
        owner: entry.owner,
        deleted_epoch: entry.updated_epoch,
    });
}

public fun set_memory_availability(
    registry: &MemoryRegistry,
    governance_vault: &GovernanceVault,
    entry: &mut MemoryEntry,
    available: bool,
    ctx: &mut TxContext,
) {
    assert_registry_governance(registry, governance_vault);
    assert_entry_registry(registry, entry);
    assert_active_operator(governance_vault, tx_context::sender(ctx));
    entry.available = available;
    entry.updated_epoch = tx_context::epoch(ctx);
    entry.updated_by = tx_context::sender(ctx);
    event::emit(MemoryEntryAvailabilitySetEvent {
        registry_id: object::id(registry),
        entry_id: object::id(entry),
        owner: entry.owner,
        available,
        updated_epoch: entry.updated_epoch,
        updated_by: entry.updated_by,
    });
}

public fun set_memory_version_policy(
    registry: &MemoryRegistry,
    governance_vault: &GovernanceVault,
    entry: &mut MemoryEntry,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    ctx: &mut TxContext,
) {
    assert_registry_governance(registry, governance_vault);
    assert_entry_registry(registry, entry);
    assert_active_operator(governance_vault, tx_context::sender(ctx));
    assert!(series_id.to_address() != @0x0, E_ZERO_SERIES);
    assert!(use_latest || option::is_some(&pinned_version_id), E_INVALID_VERSION_POLICY);
    entry.series_id = series_id;
    entry.pinned_version_id = pinned_version_id;
    entry.use_latest = use_latest;
    entry.updated_epoch = tx_context::epoch(ctx);
    entry.updated_by = tx_context::sender(ctx);
    event::emit(MemoryEntryVersionPolicySetEvent {
        registry_id: object::id(registry),
        entry_id: object::id(entry),
        owner: entry.owner,
        series_id,
        pinned_version_id,
        use_latest,
        updated_epoch: entry.updated_epoch,
        updated_by: entry.updated_by,
    });
}

public fun provider_policy(registry: &MemoryRegistry, provider: String): ProviderPolicy {
    assert!(table::contains(&registry.provider_policies, provider), E_PROVIDER_NOT_FOUND);
    *table::borrow(&registry.provider_policies, provider)
}

public fun active_entry_id(registry: &MemoryRegistry, owner: address, app_id: String): Option<ID> {
    if (!table::contains(&registry.active_entries, owner)) return option::none();
    let owner_entries = table::borrow(&registry.active_entries, owner);
    if (!table::contains(owner_entries, app_id)) return option::none();
    option::some(*table::borrow(owner_entries, app_id))
}

public fun is_entry_usable(registry: &MemoryRegistry, entry: &MemoryEntry): bool {
    if (!entry.available || !entry.owner_enabled || entry.owner_deleted || entry.registry_id != object::id(registry)) return false;
    if (!table::contains(&registry.provider_policies, entry.provider)) return false;
    let policy = table::borrow(&registry.provider_policies, entry.provider);
    policy.enabled && entry.schema_version >= policy.min_schema_version && entry.schema_version <= policy.max_schema_version
}

public fun registry_version(registry: &MemoryRegistry): u64 { registry.version }
public fun registry_root_id(registry: &MemoryRegistry): ID { registry.root_id }
public fun registry_governance_vault_id(registry: &MemoryRegistry): ID { registry.governance_vault_id }

public fun provider_policy_enabled(policy: &ProviderPolicy): bool { policy.enabled }
public fun provider_policy_min_schema_version(policy: &ProviderPolicy): u64 { policy.min_schema_version }
public fun provider_policy_max_schema_version(policy: &ProviderPolicy): u64 { policy.max_schema_version }

public fun entry_owner(entry: &MemoryEntry): address { entry.owner }
public fun entry_app_id(entry: &MemoryEntry): String { entry.app_id }
public fun entry_memory_id(entry: &MemoryEntry): String { entry.memory_id }
public fun entry_provider(entry: &MemoryEntry): String { entry.provider }
public fun entry_account_id(entry: &MemoryEntry): ID { entry.account_id }
public fun entry_namespace_root(entry: &MemoryEntry): String { entry.namespace_root }
public fun entry_artifact_code(entry: &MemoryEntry): String { entry.artifact_code }
public fun entry_series_id(entry: &MemoryEntry): ID { entry.series_id }
public fun entry_pinned_version_id(entry: &MemoryEntry): Option<ID> { entry.pinned_version_id }
public fun entry_use_latest(entry: &MemoryEntry): bool { entry.use_latest }
public fun entry_schema_version(entry: &MemoryEntry): u64 { entry.schema_version }
public fun entry_available(entry: &MemoryEntry): bool { entry.available }
public fun entry_owner_enabled(entry: &MemoryEntry): bool { entry.owner_enabled }
public fun entry_owner_deleted(entry: &MemoryEntry): bool { entry.owner_deleted }
public fun entry_deleted_epoch(entry: &MemoryEntry): Option<u64> { entry.deleted_epoch }

fun validate_entry_input(
    app_id: &String,
    memory_id: &String,
    provider: &String,
    account_id: ID,
    namespace_root: &String,
    artifact_code: &String,
    series_id: ID,
    pinned_version_id: &Option<ID>,
    use_latest: bool,
) {
    validate_text(app_id, MAX_APP_ID_BYTES, E_EMPTY_APP_ID);
    validate_text(memory_id, MAX_MEMORY_ID_BYTES, E_EMPTY_MEMORY_ID);
    validate_text(provider, MAX_PROVIDER_BYTES, E_EMPTY_PROVIDER);
    validate_text(namespace_root, MAX_NAMESPACE_ROOT_BYTES, E_EMPTY_NAMESPACE_ROOT);
    validate_text(artifact_code, MAX_ARTIFACT_CODE_BYTES, E_EMPTY_ARTIFACT_CODE);
    assert!(account_id.to_address() != @0x0, E_ZERO_ACCOUNT);
    assert!(series_id.to_address() != @0x0, E_ZERO_SERIES);
    assert!(use_latest || option::is_some(pinned_version_id), E_INVALID_VERSION_POLICY);
}

fun assert_no_active_entry(registry: &MemoryRegistry, owner: address, app_id: String) {
    if (!table::contains(&registry.active_entries, owner)) return;
    let owner_entries = table::borrow(&registry.active_entries, owner);
    assert!(!table::contains(owner_entries, app_id), E_ACTIVE_ENTRY_EXISTS);
}

fun ensure_owner_entries_table(registry: &mut MemoryRegistry, owner: address, ctx: &mut TxContext) {
    if (!table::contains(&registry.active_entries, owner)) {
        table::add(&mut registry.active_entries, owner, table::new(ctx));
    };
}

fun release_active_entry(registry: &mut MemoryRegistry, owner: address, app_id: String, entry_id: ID) {
    if (!table::contains(&registry.active_entries, owner)) return;
    let owner_entries = table::borrow_mut(&mut registry.active_entries, owner);
    if (!table::contains(owner_entries, app_id)) return;
    if (*table::borrow(owner_entries, app_id) == entry_id) {
        table::remove(owner_entries, app_id);
    };
}

fun assert_governance_binding(root_id: ID, governance_vault: &GovernanceVault) {
    governance::assert_current_vault(governance_vault);
    assert!(governance::registry_id(governance_vault) == root_id, E_INVALID_GOVERNANCE);
}

fun assert_registry_governance(registry: &MemoryRegistry, governance_vault: &GovernanceVault) {
    assert_governance_binding(registry.root_id, governance_vault);
    assert!(registry.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE);
}

fun assert_entry_registry(registry: &MemoryRegistry, entry: &MemoryEntry) {
    assert!(entry.registry_id == object::id(registry), E_INVALID_GOVERNANCE);
}

fun assert_active_operator(governance_vault: &GovernanceVault, sender: address) {
    assert!(governance::active_operator(governance_vault) == sender, E_INVALID_GOVERNANCE);
}

fun assert_owner(entry: &MemoryEntry, sender: address) {
    assert!(entry.owner == sender, E_NOT_OWNER);
}

fun validate_text(value: &String, max_bytes: u64, empty_code: u64) {
    assert!(string::length(value) > 0, empty_code);
    assert!(string::length(value) <= max_bytes, E_TEXT_TOO_LONG);
}

#[test_only]
public fun create_registry_for_testing(root_id: ID, governance_vault_id: ID, ctx: &mut TxContext): MemoryRegistry {
    MemoryRegistry {
        id: object::new(ctx),
        version: REGISTRY_VERSION,
        root_id,
        governance_vault_id,
        provider_policies: table::new(ctx),
        active_entries: table::new(ctx),
    }
}

#[test_only]
public fun create_memory_entry_for_testing(
    registry_id: ID,
    owner: address,
    app_id: String,
    memory_id: String,
    provider: String,
    account_id: ID,
    namespace_root: String,
    artifact_code: String,
    series_id: ID,
    ctx: &mut TxContext,
): MemoryEntry {
    MemoryEntry {
        id: object::new(ctx),
        version: ENTRY_VERSION,
        registry_id,
        owner,
        app_id,
        memory_id,
        provider,
        account_id,
        namespace_root,
        artifact_code,
        series_id,
        pinned_version_id: option::none(),
        use_latest: true,
        schema_version: 1,
        available: true,
        owner_enabled: true,
        owner_deleted: false,
        deleted_epoch: option::none(),
        created_epoch: tx_context::epoch(ctx),
        updated_epoch: tx_context::epoch(ctx),
        updated_by: owner,
    }
}

#[test_only]
public fun share_registry_for_testing(registry: MemoryRegistry) {
    transfer::share_object(registry);
}

#[test_only]
public fun share_entry_for_testing(entry: MemoryEntry) {
    transfer::share_object(entry);
}
