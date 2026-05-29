// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

#[test_only]
module paperproof_prompt_registry::prompt_registry_tests;

use paperproof_governance::governance;
use std::string;
use sui::test_scenario as ts;
use paperproof_prompt_registry::prompt_registry;

const ADMIN: address = @0xA11CE;
const OTHER: address = @0xB0B;

#[test]
fun register_latest_and_pinned_prompt() {
    let mut scenario = ts::begin(ADMIN);
    {
        let root_uid = object::new(ts::ctx(&mut scenario));
        let root_id = object::uid_to_inner(&root_uid);
        object::delete(root_uid);
        let (vault, permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let mut registry = prompt_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));
        let series_uid = object::new(ts::ctx(&mut scenario));
        let series_id = object::uid_to_inner(&series_uid);
        let version_uid = object::new(ts::ctx(&mut scenario));
        let version_id = object::uid_to_inner(&version_uid);
        object::delete(series_uid);
        object::delete(version_uid);

        prompt_registry::register_prompt(
            &mut registry,
            &vault,
            string::utf8(b"paperproof-app"),
            string::utf8(b"copilot/global"),
            series_id,
            option::none(),
            true,
            1,
            ts::ctx(&mut scenario),
        );
        let latest = prompt_registry::prompt_registration(&registry, string::utf8(b"paperproof-app"), string::utf8(b"copilot/global"));
        assert!(prompt_registry::registration_series_id(&latest) == series_id, 1);
        assert!(prompt_registry::registration_use_latest(&latest), 2);

        prompt_registry::register_prompt(
            &mut registry,
            &vault,
            string::utf8(b"paperproof-app"),
            string::utf8(b"copilot/global"),
            series_id,
            option::some(version_id),
            false,
            2,
            ts::ctx(&mut scenario),
        );
        let pinned = prompt_registry::prompt_registration(&registry, string::utf8(b"paperproof-app"), string::utf8(b"copilot/global"));
        assert!(!prompt_registry::registration_use_latest(&pinned), 3);
        assert!(option::borrow(&prompt_registry::registration_pinned_version_id(&pinned)) == &version_id, 4);
        assert!(prompt_registry::registration_schema_version(&pinned) == 2, 5);
        prompt_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 4, location = paperproof_prompt_registry::prompt_registry)]
fun pinned_policy_requires_version() {
    let mut scenario = ts::begin(ADMIN);
    {
        let root_uid = object::new(ts::ctx(&mut scenario));
        let root_id = object::uid_to_inner(&root_uid);
        object::delete(root_uid);
        let (vault, permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let mut registry = prompt_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));
        let series_uid = object::new(ts::ctx(&mut scenario));
        let series_id = object::uid_to_inner(&series_uid);
        object::delete(series_uid);
        prompt_registry::register_prompt(
            &mut registry,
            &vault,
            string::utf8(b"paperproof-app"),
            string::utf8(b"governance"),
            series_id,
            option::none(),
            false,
            1,
            ts::ctx(&mut scenario),
        );
        prompt_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_prompt_registry::prompt_registry)]
fun only_active_operator_can_register() {
    let mut scenario = ts::begin(OTHER);
    {
        let root_uid = object::new(ts::ctx(&mut scenario));
        let root_id = object::uid_to_inner(&root_uid);
        object::delete(root_uid);
        let (vault, permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let mut registry = prompt_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));
        let series_uid = object::new(ts::ctx(&mut scenario));
        let series_id = object::uid_to_inner(&series_uid);
        object::delete(series_uid);
        prompt_registry::register_prompt(
            &mut registry,
            &vault,
            string::utf8(b"paperproof-app"),
            string::utf8(b"explore"),
            series_id,
            option::none(),
            true,
            1,
            ts::ctx(&mut scenario),
        );
        prompt_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_prompt_registry::prompt_registry)]
fun registry_rejects_foreign_governance_vault() {
    let mut scenario = ts::begin(ADMIN);
    {
        let root_uid = object::new(ts::ctx(&mut scenario));
        let root_id = object::uid_to_inner(&root_uid);
        object::delete(root_uid);
        let other_root_uid = object::new(ts::ctx(&mut scenario));
        let other_root_id = object::uid_to_inner(&other_root_uid);
        object::delete(other_root_uid);
        let (vault, permit) = governance::new_vault(other_root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let vault_id = object::id(&vault);
        let mut registry = prompt_registry::create_registry_for_testing(root_id, vault_id, ts::ctx(&mut scenario));
        let series_uid = object::new(ts::ctx(&mut scenario));
        let series_id = object::uid_to_inner(&series_uid);
        object::delete(series_uid);
        prompt_registry::register_prompt(
            &mut registry,
            &vault,
            string::utf8(b"paperproof-app"),
            string::utf8(b"explore"),
            series_id,
            option::none(),
            true,
            1,
            ts::ctx(&mut scenario),
        );
        prompt_registry::share_registry_for_testing(registry);
        governance::share_vault(vault);
        transfer::public_transfer(permit, ADMIN);
    };
    ts::end(scenario);
}
