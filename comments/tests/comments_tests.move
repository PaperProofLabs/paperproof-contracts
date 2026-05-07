#[test_only]
module paperproof_comments::comments_tests;

use std::string;

use paperproof_governance::governance::{Self as governance, FeeManager, GovernanceVault};
use pprf::pprf::PPRF;
use sui::clock;
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario as ts;

use paperproof_comments::comments::{Self, CommentsTree, LikesBook};

const ADMIN: address = @0xA;
const USER1: address = @0xB;
const USER2: address = @0xC;

fun shared_tree(
    scenario: &mut ts::Scenario,
    registry_id: ID,
    target_series_id: ID,
    owner: address,
    paper_key: vector<u8>,
) {
    let (vault, permit) = governance::new_vault(
        registry_id,
        ADMIN,
        ADMIN,
        ts::ctx(scenario),
    );
    let governance_vault_id = object::id(&vault);
    let fee_manager = governance::new_fee_manager(registry_id, ts::ctx(scenario));
    let fee_manager_id = governance::fee_manager_id(&fee_manager);
    let tree_factory_cap = comments::new_tree_factory_cap(&vault, &fee_manager, ts::ctx(scenario));
    governance::share_vault(vault);
    transfer::public_transfer(permit, ADMIN);
    governance::share_fee_manager(fee_manager);
    let clock_ref = clock::create_for_testing(ts::ctx(scenario));
    let (tree, likes_book) = comments::new_tree(
        &tree_factory_cap,
        registry_id,
        governance_vault_id,
        fee_manager_id,
        owner,
        string::utf8(paper_key),
        target_series_id,
        1,
        &clock_ref,
        ts::ctx(scenario),
    );
    comments::share_tree(tree);
    comments::share_likes_book(likes_book);
    clock::destroy_for_testing(clock_ref);
}

#[test]
fun test_create_tree_and_owner_controls_tree() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x101);
    let paper_object_id = object::id_from_address(@0x201);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0001",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        assert!(comments::creator(&tree) == ADMIN, 0);
        assert!(comments::owner(&tree) == USER1, 1);
        assert!(comments::registry_id(&tree) == registry_id, 2);
        assert!(comments::target_series_id(&tree) == paper_object_id, 8);
        assert!(comments::target_artifact_type(&tree) == 1, 9);
        assert!(comments::root_comment_id(&tree) == 0, 3);
        assert!(comments::total_comments(&tree) == 0, 4);
        assert!(comments::has_comment(&tree, 0), 5);

        comments::set_tree_status(
            &mut tree,
            comments::tree_status_locked(),
            ts::ctx(&mut scenario),
        );
        assert!(comments::tree_status(&tree) == comments::tree_status_locked(), 6);

        let root = comments::borrow_comment(&tree, 0);
        assert!(comments::comment_depth(root) == 0, 7);
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
fun test_add_onchain_and_blob_comments() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x102);
    let paper_object_id = object::id_from_address(@0x202);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0002",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            b"First on-chain comment",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(comments::total_comments(&tree) == 1, 10);
        assert!(comments::has_comment(&tree, 1), 11);
        let c1 = comments::borrow_comment(&tree, 1);
        assert!(comments::comment_author(c1) == USER1, 12);
        assert!(comments::content_mode(c1) == comments::comment_mode_onchain(), 13);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_blob_comment(
            &mut tree,
            &vault,
            &fee_manager,
            1,
            b"walrus-blob-1",
            option::none<ID>(),
            b"sha256:abcd",
            b"Preview text",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(comments::total_comments(&tree) == 2, 20);
        let c2 = comments::borrow_comment(&tree, 2);
        assert!(comments::comment_author(c2) == USER2, 21);
        assert!(comments::content_mode(c2) == comments::comment_mode_blob(), 22);

        let parent = comments::borrow_comment(&tree, 1);
        assert!(comments::children_count(parent) == 1, 23);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 20, location = paperproof_comments::comments)]
fun test_hidden_comment_cannot_receive_replies() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x112);
    let paper_object_id = object::id_from_address(@0x212);

    shared_tree(
        &mut scenario,
        registry_id,
        paper_object_id,
        USER1,
        b"PaperProof-2026-0012",
    );

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            b"Moderated parent",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        comments::set_comment_status(
            &mut tree,
            1,
            comments::comment_status_hidden(),
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            1,
            b"Reply should fail",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_comments_fee_level_requires_payment() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x103);
    let paper_object_id = object::id_from_address(@0x203);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0003",
        );
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        governance::set_comments_fee_level(&vault, &mut fee_manager, 2, ts::ctx(&mut scenario));
        assert!(governance::comments_fee_amount(&fee_manager) == 100_000, 24);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let payment = coin::mint_for_testing<SUI>(100_000, ts::ctx(&mut scenario));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            b"Paid comment",
            option::some(payment),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_like_and_unlike_paper() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x107);
    let paper_object_id = object::id_from_address(@0x207);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0007",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut likes_book = ts::take_shared<LikesBook>(&scenario);
        let proof_coin = coin::mint_for_testing<PPRF>(comments::minimum_pprf_for_like(), ts::ctx(&mut scenario));

        comments::like_paper(&mut likes_book, &proof_coin, ts::ctx(&mut scenario));
        assert!(comments::like_count(&likes_book) == 1, 60);
        assert!(comments::has_liked(&likes_book, USER1), 61);

        comments::unlike_paper(&mut likes_book, &proof_coin, ts::ctx(&mut scenario));
        assert!(comments::like_count(&likes_book) == 0, 62);
        assert!(!comments::has_liked(&likes_book, USER1), 63);

        transfer::public_transfer(proof_coin, USER1);
        ts::return_shared(likes_book);
    };

    ts::end(scenario);
}

#[test]
fun test_owner_transfer_updates_tree_governance() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x104);
    let paper_object_id = object::id_from_address(@0x204);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0004",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        comments::transfer_tree_owner(&mut tree, USER2, ts::ctx(&mut scenario));
        assert!(comments::owner(&tree) == USER2, 30);
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        comments::set_tree_status(
            &mut tree,
            comments::tree_status_locked(),
            ts::ctx(&mut scenario),
        );
        assert!(comments::tree_status(&tree) == comments::tree_status_locked(), 31);
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
fun test_tree_migration_hook() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x10A);
    let paper_object_id = object::id_from_address(@0x20A);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0010",
        );
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        assert!(comments::tree_version(&tree) == comments::current_tree_version(), 32);
        comments::migrate_tree(&mut tree, &vault, ts::ctx(&mut scenario));
        ts::return_shared(tree);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10, location = paperproof_governance::governance)]
fun test_comments_fee_requires_payment_coin() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x105);
    let paper_object_id = object::id_from_address(@0x205);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0005",
        );
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        governance::set_comments_fee_level(&vault, &mut fee_manager, 1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            b"Missing fee coin",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 14, location = paperproof_comments::comments)]
fun test_foreign_vault_cannot_bypass_comment_fee_binding() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x106);
    let paper_object_id = object::id_from_address(@0x206);
    let foreign_registry_id = object::id_from_address(@0x999);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0006",
        );
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
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let foreign_vault = ts::take_shared_by_id<GovernanceVault>(&scenario, foreign_vault_id);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &foreign_vault,
            &fee_manager,
            0,
            b"Should fail",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(foreign_vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 14, location = paperproof_comments::comments)]
fun test_same_registry_fake_fee_manager_cannot_bypass_comment_fee_binding() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x116);
    let paper_object_id = object::id_from_address(@0x216);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0016",
        );
    };

    let fake_fee_manager_id = {
        let fake_fee_manager = governance::new_fee_manager(registry_id, ts::ctx(&mut scenario));
        let id = governance::fee_manager_id(&fake_fee_manager);
        governance::share_fee_manager(fake_fee_manager);
        id
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fake_fee_manager = ts::take_shared_by_id<FeeManager>(&scenario, fake_fee_manager_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fake_fee_manager,
            0,
            b"Should fail",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fake_fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 12, location = paperproof_comments::comments)]
fun test_comment_author_cannot_restore_owner_hidden_comment() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x117);
    let paper_object_id = object::id_from_address(@0x217);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER2,
            b"PaperProof-2026-0017",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            b"Moderated by owner",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        comments::set_comment_status(
            &mut tree,
            1,
            comments::comment_status_hidden(),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        comments::set_comment_status(
            &mut tree,
            1,
            comments::comment_status_active(),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 26, location = paperproof_comments::comments)]
fun test_deleted_comment_is_final_even_for_tree_owner() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x118);
    let paper_object_id = object::id_from_address(@0x218);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER2,
            b"PaperProof-2026-0018",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            b"Delete me",
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        comments::set_comment_status(
            &mut tree,
            1,
            comments::comment_status_deleted(),
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        comments::set_comment_status(
            &mut tree,
            1,
            comments::comment_status_active(),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 25, location = paperproof_comments::comments)]
fun test_root_comment_status_is_immutable() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x119);
    let paper_object_id = object::id_from_address(@0x219);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0019",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let root_comment_id = comments::root_comment_id(&tree);
        comments::set_comment_status(
            &mut tree,
            root_comment_id,
            comments::comment_status_hidden(),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 17, location = paperproof_comments::comments)]
fun test_double_like_is_rejected() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x108);
    let paper_object_id = object::id_from_address(@0x208);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0008",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut likes_book = ts::take_shared<LikesBook>(&scenario);
        let proof_coin = coin::mint_for_testing<PPRF>(comments::minimum_pprf_for_like(), ts::ctx(&mut scenario));
        comments::like_paper(&mut likes_book, &proof_coin, ts::ctx(&mut scenario));
        comments::like_paper(&mut likes_book, &proof_coin, ts::ctx(&mut scenario));
        transfer::public_transfer(proof_coin, USER1);
        ts::return_shared(likes_book);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 16, location = paperproof_comments::comments)]
fun test_like_requires_at_least_one_pprf() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x109);
    let paper_object_id = object::id_from_address(@0x209);

    {
        shared_tree(
            &mut scenario,
            registry_id,
            paper_object_id,
            USER1,
            b"PaperProof-2026-0009",
        );
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut likes_book = ts::take_shared<LikesBook>(&scenario);
        let proof_coin = coin::mint_for_testing<PPRF>(comments::minimum_pprf_for_like() - 1, ts::ctx(&mut scenario));
        comments::like_paper(&mut likes_book, &proof_coin, ts::ctx(&mut scenario));
        transfer::public_transfer(proof_coin, USER1);
        ts::return_shared(likes_book);
    };

    ts::end(scenario);
}
