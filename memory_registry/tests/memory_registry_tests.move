// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

#[test_only]
module paperproof_memory_registry::memory_registry_tests;

use paperproof_governance::governance;
use paperproof_memory_registry::memory_registry;
use std::string;
use sui::test_scenario as ts;

const ADMIN: address = @0xA11CE;
const USER: address = @0xC0FFEE;
const OTHER: address = @0xB0B;

fun new_id(ctx: &mut TxContext): ID {
    let uid = object::new(ctx);
    let id = object::uid_to_inner(&uid);
    object::delete(uid);
    id
}

fun app_id(): std::string::String { string::utf8(b"paperproof-app") }
fun memory_id(): std::string::String { string::utf8(b"copilot/profile") }
fun provider(): std::string::String { string::utf8(b"memwal") }
fun namespace_root(): std::string::String { string::utf8(b"paperproof/copilot/profile") }
fun artifact_code(): std::string::String { string::utf8(b"PaperProof-generic_file-000001-memory") }

#[test]
fun entry_policy_availability_and_version_flow() {
    let mut scenario = ts::begin(ADMIN);
    {
        let root_id = new_id(ts::ctx(&mut scenario));
        let (vault, permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let mut registry = memory_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));

        memory_registry::set_provider_policy(
            &mut registry,
            &vault,
            provider(),
            true,
            1,
            3,
            ts::ctx(&mut scenario),
        );
        let policy = memory_registry::provider_policy(&registry, provider());
        assert!(memory_registry::provider_policy_enabled(&policy), 1);

        let account_id = new_id(ts::ctx(&mut scenario));
        let series_id = new_id(ts::ctx(&mut scenario));
        let mut entry = memory_registry::create_memory_entry_for_testing(
            object::id(&registry),
            USER,
            app_id(),
            memory_id(),
            provider(),
            account_id,
            namespace_root(),
            artifact_code(),
            series_id,
            ts::ctx(&mut scenario),
        );
        assert!(!memory_registry::entry_available(&entry), 3);
        assert!(!memory_registry::is_entry_usable(&registry, &entry), 4);

        memory_registry::set_memory_availability(&registry, &vault, &mut entry, true, ts::ctx(&mut scenario));
        assert!(memory_registry::entry_available(&entry), 5);
        assert!(memory_registry::is_entry_usable(&registry, &entry), 6);

        let next_series = new_id(ts::ctx(&mut scenario));
        let pinned = new_id(ts::ctx(&mut scenario));
        memory_registry::set_memory_version_policy(
            &registry,
            &vault,
            &mut entry,
            next_series,
            option::some(pinned),
            false,
            ts::ctx(&mut scenario),
        );
        assert!(memory_registry::entry_series_id(&entry) == next_series, 7);
        assert!(!memory_registry::entry_use_latest(&entry), 8);
        assert!(option::borrow(&memory_registry::entry_pinned_version_id(&entry)) == &pinned, 9);

        memory_registry::share_entry_for_testing(entry);
        memory_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}

#[test]
fun user_creates_entry_and_updates_pointer() {
    let mut scenario = ts::begin(USER);
    {
        let mut registry = memory_registry::create_registry_for_testing(new_id(ts::ctx(&mut scenario)), new_id(ts::ctx(&mut scenario)), ts::ctx(&mut scenario));
        let account_id = new_id(ts::ctx(&mut scenario));
        let series_id = new_id(ts::ctx(&mut scenario));
        memory_registry::create_memory_entry(
            &mut registry,
            app_id(),
            memory_id(),
            provider(),
            account_id,
            namespace_root(),
            artifact_code(),
            series_id,
            option::none(),
            true,
            1,
            ts::ctx(&mut scenario),
        );
        let entry_id = option::destroy_some(memory_registry::active_entry_id(&registry, USER, app_id()));
        let mut entry = memory_registry::create_memory_entry_for_testing(
            object::id(&registry),
            USER,
            app_id(),
            memory_id(),
            provider(),
            account_id,
            namespace_root(),
            artifact_code(),
            series_id,
            ts::ctx(&mut scenario),
        );
        assert!(entry_id != object::id(&entry), 0);
        let next_account = new_id(ts::ctx(&mut scenario));
        memory_registry::update_memory_pointer(
            &mut entry,
            next_account,
            string::utf8(b"paperproof/copilot/tasks"),
            true,
            ts::ctx(&mut scenario),
        );
        assert!(memory_registry::entry_account_id(&entry) == next_account, 1);
        assert!(memory_registry::entry_owner_enabled(&entry), 2);
        memory_registry::disable_own_memory_entry(&mut entry, ts::ctx(&mut scenario));
        assert!(!memory_registry::entry_owner_enabled(&entry), 3);
        memory_registry::update_memory_pointer(
            &mut entry,
            next_account,
            string::utf8(b"paperproof/copilot/tasks"),
            true,
            ts::ctx(&mut scenario),
        );
        memory_registry::delete_own_memory_entry(&mut registry, &mut entry, ts::ctx(&mut scenario));
        assert!(memory_registry::entry_owner_deleted(&entry), 4);
        assert!(!memory_registry::entry_owner_enabled(&entry), 5);
        assert!(!memory_registry::entry_available(&entry), 6);
        memory_registry::share_entry_for_testing(entry);
        memory_registry::share_registry_for_testing(registry);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 13, location = paperproof_memory_registry::memory_registry)]
fun one_active_entry_per_owner_and_app() {
    let mut scenario = ts::begin(USER);
    {
        let mut registry = memory_registry::create_registry_for_testing(new_id(ts::ctx(&mut scenario)), new_id(ts::ctx(&mut scenario)), ts::ctx(&mut scenario));
        memory_registry::create_memory_entry(
            &mut registry,
            app_id(),
            memory_id(),
            provider(),
            new_id(ts::ctx(&mut scenario)),
            namespace_root(),
            artifact_code(),
            new_id(ts::ctx(&mut scenario)),
            option::none(),
            true,
            1,
            ts::ctx(&mut scenario),
        );
        memory_registry::create_memory_entry(
            &mut registry,
            app_id(),
            string::utf8(b"copilot/tasks"),
            provider(),
            new_id(ts::ctx(&mut scenario)),
            string::utf8(b"paperproof/copilot/tasks"),
            artifact_code(),
            new_id(ts::ctx(&mut scenario)),
            option::none(),
            true,
            1,
            ts::ctx(&mut scenario),
        );
        memory_registry::share_registry_for_testing(registry);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10, location = paperproof_memory_registry::memory_registry)]
fun only_owner_deletes_entry() {
    let mut scenario = ts::begin(OTHER);
    {
        let mut registry = memory_registry::create_registry_for_testing(new_id(ts::ctx(&mut scenario)), new_id(ts::ctx(&mut scenario)), ts::ctx(&mut scenario));
        let mut entry = memory_registry::create_memory_entry_for_testing(
            object::id(&registry),
            USER,
            app_id(),
            memory_id(),
            provider(),
            new_id(ts::ctx(&mut scenario)),
            namespace_root(),
            artifact_code(),
            new_id(ts::ctx(&mut scenario)),
            ts::ctx(&mut scenario),
        );
        memory_registry::delete_own_memory_entry(&mut registry, &mut entry, ts::ctx(&mut scenario));
        memory_registry::share_entry_for_testing(entry);
        memory_registry::share_registry_for_testing(registry);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_memory_registry::memory_registry)]
fun only_active_operator_sets_availability() {
    let mut scenario = ts::begin(OTHER);
    {
        let root_id = new_id(ts::ctx(&mut scenario));
        let (vault, permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let registry = memory_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));
        let mut entry = memory_registry::create_memory_entry_for_testing(
            object::id(&registry),
            USER,
            app_id(),
            memory_id(),
            provider(),
            new_id(ts::ctx(&mut scenario)),
            namespace_root(),
            artifact_code(),
            new_id(ts::ctx(&mut scenario)),
            ts::ctx(&mut scenario),
        );
        memory_registry::set_memory_availability(&registry, &vault, &mut entry, true, ts::ctx(&mut scenario));
        memory_registry::share_entry_for_testing(entry);
        memory_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10, location = paperproof_memory_registry::memory_registry)]
fun only_owner_updates_pointer() {
    let mut scenario = ts::begin(OTHER);
    {
        let mut entry = memory_registry::create_memory_entry_for_testing(
            new_id(ts::ctx(&mut scenario)),
            USER,
            app_id(),
            memory_id(),
            provider(),
            new_id(ts::ctx(&mut scenario)),
            namespace_root(),
            artifact_code(),
            new_id(ts::ctx(&mut scenario)),
            ts::ctx(&mut scenario),
        );
        memory_registry::update_memory_pointer(
            &mut entry,
            new_id(ts::ctx(&mut scenario)),
            namespace_root(),
            true,
            ts::ctx(&mut scenario),
        );
        memory_registry::share_entry_for_testing(entry);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_memory_registry::memory_registry)]
fun pinned_policy_requires_version() {
    let mut scenario = ts::begin(ADMIN);
    {
        let root_id = new_id(ts::ctx(&mut scenario));
        let (vault, permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let registry = memory_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));
        let mut entry = memory_registry::create_memory_entry_for_testing(
            object::id(&registry),
            USER,
            app_id(),
            memory_id(),
            provider(),
            new_id(ts::ctx(&mut scenario)),
            namespace_root(),
            artifact_code(),
            new_id(ts::ctx(&mut scenario)),
            ts::ctx(&mut scenario),
        );
        memory_registry::set_memory_version_policy(
            &registry,
            &vault,
            &mut entry,
            new_id(ts::ctx(&mut scenario)),
            option::none(),
            false,
            ts::ctx(&mut scenario),
        );
        memory_registry::share_entry_for_testing(entry);
        memory_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}
