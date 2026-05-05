#[test_only]
module paperproof_publishing::publishing_tests;

use std::string;

use paperproof_comments::comments::{Self as comments, CommentsTree};
use paperproof_governance::governance::{
    Self as governance,
    GovernanceVault,
    OperatorPermit,
};
use paperproof_publishing::publishing::{Self, PaperRecord, PaperRegistry, PaperVersion};

use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use sui::clock;
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario as ts;

const ADMIN: address = @0xA;
const USER1: address = @0xB;
const USER2: address = @0xC;

#[test]
fun test_full_paper_lifecycle_with_comments_tree() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::finalize_paper(
            &registry,
            &mut record,
            &vault,
            string::utf8(b"OriginPaper Test Title"),
            string::utf8(b"This is a test abstract."),
            vector[
                string::utf8(b"sui"),
                string::utf8(b"move"),
                string::utf8(b"preprint"),
            ],
            vector[
                string::utf8(b"Alice"),
                string::utf8(b"Bob"),
            ],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            string::utf8(b"walrus_blob_001"),
            string::utf8(b"walrus_blob_object_001"),
            string::utf8(b"sha256_hash_v1"),
            1_000_000,
            10,
            100,
            true,
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(publishing::record_status(&record) == 1, 100);
        assert!(publishing::current_version(&record) == 1, 101);
        assert!(publishing::version_count(&record) == 1, 102);
        assert!(option::is_some(publishing::comments_tree_id(&record)), 103);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let record = ts::take_shared<PaperRecord>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        assert!(comments::paper_object_id(&tree) == object::id(&record), 110);
        assert!(comments::owner(&tree) == USER1, 111);
        comments::add_onchain_comment(
            &mut tree,
            &vault,
            0,
            b"First comment",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(comments::total_comments(&tree) == 1, 112);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(record);
        ts::return_shared(tree);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::add_version(
            &registry,
            &mut record,
            &vault,
            string::utf8(b"OriginPaper Test Title v2"),
            string::utf8(b"This is a revised abstract."),
            vector[
                string::utf8(b"sui"),
                string::utf8(b"move"),
            ],
            vector[
                string::utf8(b"Alice"),
                string::utf8(b"Bob"),
            ],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            string::utf8(b"walrus_blob_002"),
            string::utf8(b"walrus_blob_object_002"),
            string::utf8(b"sha256_hash_v2"),
            1_200_000,
            12,
            120,
            true,
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(publishing::current_version(&record) == 2, 200);
        assert!(publishing::version_count(&record) == 2, 201);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::transfer_paper_owner(
            &mut record,
            &mut tree,
            USER2,
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(publishing::paper_owner(&record) == USER2, 300);
        assert!(comments::owner(&tree) == USER2, 301);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(record);
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let record = ts::take_shared<PaperRecord>(&scenario);
        let mut version = ts::take_shared<PaperVersion>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::record_storage_extension(
            &record,
            &mut version,
            200,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        comments::set_tree_status(
            &mut tree,
            comments::tree_status_locked(),
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(record);
        ts::return_shared(version);
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
fun test_publishing_fee_level_requires_payment() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::set_publishing_fee_level(&mut vault, 1, ts::ctx(&mut scenario));
        assert!(governance::publishing_fee_amount(&vault) == 10_000, 350);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let payment = coin::mint_for_testing<SUI>(10_000, ts::ctx(&mut scenario));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::finalize_paper(
            &registry,
            &mut record,
            &vault,
            string::utf8(b"Fee Gated Title"),
            string::utf8(b"Fee gated abstract"),
            vector[string::utf8(b"sui")],
            vector[string::utf8(b"Alice")],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            string::utf8(b"walrus_blob_fee"),
            string::utf8(b"walrus_blob_object_fee"),
            string::utf8(b"sha256_hash_fee"),
            1_000_000,
            10,
            100,
            true,
            option::some(payment),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10, location = paperproof_governance::governance)]
fun test_publishing_fee_requires_payment_coin() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::set_publishing_fee_level(&mut vault, 1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::finalize_paper(
            &registry,
            &mut record,
            &vault,
            string::utf8(b"Missing Fee Coin"),
            string::utf8(b"Abstract"),
            vector[string::utf8(b"sui")],
            vector[string::utf8(b"Alice")],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            string::utf8(b"walrus_blob_missing_fee"),
            string::utf8(b"walrus_blob_object_missing_fee"),
            string::utf8(b"sha256_hash_missing_fee"),
            1_000_000,
            10,
            100,
            true,
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 23, location = paperproof_publishing::publishing)]
fun test_foreign_vault_cannot_bypass_publishing_fee_binding() {
    let mut scenario = ts::begin(ADMIN);
    let foreign_registry_id = object::id_from_address(@0x999);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    let foreign_vault_id = {
        let (foreign_vault, foreign_permit) = governance::new_vault(
            foreign_registry_id,
            ADMIN,
            ADMIN,
            ts::ctx(&mut scenario),
        );
        let id = object::id(&foreign_vault);
        governance::share_vault(foreign_vault);
        transfer::public_transfer(foreign_permit, ADMIN);
        id
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let foreign_vault = ts::take_shared_by_id<GovernanceVault>(&scenario, foreign_vault_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::finalize_paper(
            &registry,
            &mut record,
            &foreign_vault,
            string::utf8(b"Foreign Vault Title"),
            string::utf8(b"Abstract"),
            vector[string::utf8(b"sui")],
            vector[string::utf8(b"Alice")],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            string::utf8(b"walrus_blob_foreign"),
            string::utf8(b"walrus_blob_object_foreign"),
            string::utf8(b"sha256_hash_foreign"),
            1_000_000,
            10,
            100,
            true,
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(foreign_vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 2, location = paperproof_publishing::publishing)]
fun test_paused_registry_rejects_reserve() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let operator_permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::set_paused(
            &mut registry,
            &vault,
            &operator_permit,
            true,
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(operator_permit, ADMIN);
        ts::return_shared(registry);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    ts::end(scenario);
}

#[test]
fun test_operator_nomination_accept_flow() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::nominate_operator(&mut vault, USER1, ts::ctx(&mut scenario));
        assert!(governance::has_pending_operator_transfer(&vault), 400);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        let request = ts::take_shared<PendingOwnershipTransfer<OperatorPermit>>(&scenario);
        let request_id = object::id(&request);
        let ticket = ts::most_recent_receiving_ticket<TwoStepTransferWrapper<OperatorPermit>>(&request_id);

        governance::accept_operator_transfer(
            &mut vault,
            request,
            ticket,
            ts::ctx(&mut scenario),
        );

        assert!(!governance::has_pending_operator_transfer(&vault), 401);
        assert!(governance::active_operator(&vault) == USER1, 402);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let wrapper = ts::take_from_sender<TwoStepTransferWrapper<OperatorPermit>>(&scenario);
        let operator_permit = governance::unwrap_operator_permit(
            wrapper,
            ts::ctx(&mut scenario),
        );
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::set_paused(
            &mut registry,
            &vault,
            &operator_permit,
            true,
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(operator_permit, USER1);
        ts::return_shared(registry);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_operator_nomination_cancel_flow() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::nominate_operator(&mut vault, USER1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        let request = ts::take_shared<PendingOwnershipTransfer<OperatorPermit>>(&scenario);
        let request_id = object::id(&request);
        let ticket = ts::most_recent_receiving_ticket<TwoStepTransferWrapper<OperatorPermit>>(&request_id);

        governance::cancel_operator_transfer(
            &mut vault,
            request,
            ticket,
            ts::ctx(&mut scenario),
        );

        assert!(!governance::has_pending_operator_transfer(&vault), 500);
        assert!(governance::active_operator(&vault) == ADMIN, 501);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let operator_permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::set_paused(
            &mut registry,
            &vault,
            &operator_permit,
            true,
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(operator_permit, ADMIN);
        ts::return_shared(registry);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_registry_and_record_migration_hooks() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        assert!(publishing::registry_version(&registry) == publishing::current_registry_version(), 600);
        publishing::migrate_registry(&mut registry, &vault, ts::ctx(&mut scenario));
        ts::return_shared(registry);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        assert!(publishing::paper_record_version(&record) == publishing::current_paper_record_version(), 601);
        publishing::migrate_record(&registry, &mut record, &vault, ts::ctx(&mut scenario));
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 15, location = paperproof_publishing::publishing)]
fun test_non_owner_cannot_add_version() {
    let mut scenario = ts::begin(ADMIN);

    {
        publishing::init_for_testing(ts::ctx(&mut scenario));
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut registry = ts::take_shared<PaperRegistry>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::reserve_code(&mut registry, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::finalize_paper(
            &registry,
            &mut record,
            &vault,
            string::utf8(b"Title"),
            string::utf8(b"Abstract"),
            vector[string::utf8(b"sui")],
            vector[string::utf8(b"Alice")],
            string::utf8(b"CS"),
            string::utf8(b"CC-BY"),
            string::utf8(b"blob1"),
            string::utf8(b"blob_object1"),
            string::utf8(b"hash1"),
            1_000,
            3,
            100,
            true,
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let registry = ts::take_shared<PaperRegistry>(&scenario);
        let mut record = ts::take_shared<PaperRecord>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::add_version(
            &registry,
            &mut record,
            &vault,
            string::utf8(b"Title v2"),
            string::utf8(b"Abstract v2"),
            vector[string::utf8(b"sui")],
            vector[string::utf8(b"Alice")],
            string::utf8(b"CS"),
            string::utf8(b"CC-BY"),
            string::utf8(b"blob2"),
            string::utf8(b"blob_object2"),
            string::utf8(b"hash2"),
            1_000,
            3,
            120,
            true,
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(registry);
        ts::return_shared(record);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}
