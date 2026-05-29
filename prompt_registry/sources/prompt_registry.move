// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_prompt_registry::prompt_registry;

use paperproof_governance::governance::{Self as governance, GovernanceVault};
use std::string::{Self as string, String};
use sui::event;
use sui::table::{Self as table, Table};

const REGISTRY_VERSION: u64 = 1;

const E_INVALID_GOVERNANCE: u64 = 1;
const E_EMPTY_APP_ID: u64 = 2;
const E_EMPTY_ROUTE_ID: u64 = 3;
const E_INVALID_VERSION_POLICY: u64 = 4;
const E_PROMPT_NOT_FOUND: u64 = 5;
const E_ZERO_ROOT: u64 = 6;
const E_TEXT_TOO_LONG: u64 = 7;

const MAX_APP_ID_BYTES: u64 = 64;
const MAX_ROUTE_ID_BYTES: u64 = 128;

public struct PromptRegistry has key {
    id: UID,
    version: u64,
    root_id: ID,
    governance_vault_id: ID,
    prompts: Table<String, PromptRegistration>,
}

public struct PromptRegistration has copy, drop, store {
    app_id: String,
    route_id: String,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    schema_version: u64,
    updated_epoch: u64,
    updated_by: address,
}

public struct PromptRegistryCreatedEvent has copy, drop {
    registry_id: ID,
    root_id: ID,
    governance_vault_id: ID,
}

public struct PromptRegisteredEvent has copy, drop {
    registry_id: ID,
    root_id: ID,
    app_id: String,
    route_id: String,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    schema_version: u64,
    updated_epoch: u64,
    updated_by: address,
}

public fun create_registry(
    root_id: ID,
    governance_vault: &GovernanceVault,
    ctx: &mut TxContext,
) {
    assert!(root_id.to_address() != @0x0, E_ZERO_ROOT);
    assert_governance_binding(root_id, governance_vault);
    assert_active_operator(governance_vault, tx_context::sender(ctx));
    let registry = PromptRegistry {
        id: object::new(ctx),
        version: REGISTRY_VERSION,
        root_id,
        governance_vault_id: object::id(governance_vault),
        prompts: table::new(ctx),
    };
    let registry_id = object::id(&registry);
    event::emit(PromptRegistryCreatedEvent {
        registry_id,
        root_id,
        governance_vault_id: object::id(governance_vault),
    });
    transfer::share_object(registry);
}

public fun register_prompt(
    registry: &mut PromptRegistry,
    governance_vault: &GovernanceVault,
    app_id: String,
    route_id: String,
    series_id: ID,
    pinned_version_id: Option<ID>,
    use_latest: bool,
    schema_version: u64,
    ctx: &mut TxContext,
) {
    assert_registry_governance(registry, governance_vault);
    assert_active_operator(governance_vault, tx_context::sender(ctx));
    validate_key(&app_id, MAX_APP_ID_BYTES, E_EMPTY_APP_ID);
    validate_key(&route_id, MAX_ROUTE_ID_BYTES, E_EMPTY_ROUTE_ID);
    assert!(use_latest || option::is_some(&pinned_version_id), E_INVALID_VERSION_POLICY);

    let key = prompt_key(&app_id, &route_id);
    let record = PromptRegistration {
        app_id,
        route_id,
        series_id,
        pinned_version_id,
        use_latest,
        schema_version,
        updated_epoch: tx_context::epoch(ctx),
        updated_by: tx_context::sender(ctx),
    };
    if (table::contains(&registry.prompts, key)) {
        *table::borrow_mut(&mut registry.prompts, key) = record;
    } else {
        table::add(&mut registry.prompts, key, record);
    };
    let saved = table::borrow(&registry.prompts, key);
    event::emit(PromptRegisteredEvent {
        registry_id: object::id(registry),
        root_id: registry.root_id,
        app_id: saved.app_id,
        route_id: saved.route_id,
        series_id: saved.series_id,
        pinned_version_id: saved.pinned_version_id,
        use_latest: saved.use_latest,
        schema_version: saved.schema_version,
        updated_epoch: saved.updated_epoch,
        updated_by: saved.updated_by,
    });
}

public fun contains_prompt(registry: &PromptRegistry, app_id: String, route_id: String): bool {
    table::contains(&registry.prompts, prompt_key(&app_id, &route_id))
}

public fun prompt_registration(registry: &PromptRegistry, app_id: String, route_id: String): PromptRegistration {
    let key = prompt_key(&app_id, &route_id);
    assert!(table::contains(&registry.prompts, key), E_PROMPT_NOT_FOUND);
    *table::borrow(&registry.prompts, key)
}

public fun registry_version(registry: &PromptRegistry): u64 { registry.version }
public fun registry_root_id(registry: &PromptRegistry): ID { registry.root_id }
public fun registry_governance_vault_id(registry: &PromptRegistry): ID { registry.governance_vault_id }

public fun registration_series_id(record: &PromptRegistration): ID { record.series_id }
public fun registration_pinned_version_id(record: &PromptRegistration): Option<ID> { record.pinned_version_id }
public fun registration_use_latest(record: &PromptRegistration): bool { record.use_latest }
public fun registration_schema_version(record: &PromptRegistration): u64 { record.schema_version }

fun assert_governance_binding(root_id: ID, governance_vault: &GovernanceVault) {
    governance::assert_current_vault(governance_vault);
    assert!(governance::registry_id(governance_vault) == root_id, E_INVALID_GOVERNANCE);
}

fun assert_registry_governance(registry: &PromptRegistry, governance_vault: &GovernanceVault) {
    assert_governance_binding(registry.root_id, governance_vault);
    assert!(registry.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE);
}

fun assert_active_operator(governance_vault: &GovernanceVault, sender: address) {
    assert!(governance::active_operator(governance_vault) == sender, E_INVALID_GOVERNANCE);
}

fun validate_key(value: &String, max_bytes: u64, empty_code: u64) {
    assert!(string::length(value) > 0, empty_code);
    assert!(string::length(value) <= max_bytes, E_TEXT_TOO_LONG);
}

fun prompt_key(app_id: &String, route_id: &String): String {
    let mut key = *app_id;
    string::append(&mut key, string::utf8(b":"));
    string::append(&mut key, *route_id);
    key
}

#[test_only]
public fun create_registry_for_testing(root_id: ID, governance_vault_id: ID, ctx: &mut TxContext): PromptRegistry {
    assert!(root_id.to_address() != @0x0, E_ZERO_ROOT);
    PromptRegistry {
        id: object::new(ctx),
        version: REGISTRY_VERSION,
        root_id,
        governance_vault_id,
        prompts: table::new(ctx),
    }
}

#[test_only]
public fun share_registry_for_testing(registry: PromptRegistry) {
    transfer::share_object(registry);
}
