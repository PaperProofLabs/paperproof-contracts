#[test_only]
module paperproof_publishing::publishing_tests;

use std::string;

use paperproof_comments::comments::{Self as comments, CommentsTree, LikesBook};
use paperproof_governance::governance::{Self as governance, FeeManager, GovernanceVault, OperatorPermit};
use paperproof_governance::governance_voting::{Self as voting, GovernanceConfig, Proposal};
use paperproof_shared_controller::controller::{Self as controller, ArtifactControlRecord, ControllerNFT};
use paperproof_shared_controller::controller_marketplace;
use paperproof_publishing::publishing::{
    Self as publishing,
    ArtifactSeries,
    BlogPostVersionRecord,
    DatasetVersionRecord,
    GenericFileVersionRecord,
    MetadataAttribute,
    PaperProofRoot,
    PreprintReservation,
    PreprintVersionRecord,
    SoftwareReleaseVersionRecord,
    TechnicalReportVersionRecord,
    TypeRegistry,
};
use pprf::pprf::PPRF;
use sui::clock;
use sui::coin::{Self as coin, Coin};
use sui::display::{Self as display, Display};
use sui::sui::SUI;
use sui::test_scenario as ts;
use sui::transfer_policy::TransferPolicyCap;
use sui::vec_map;

const ADMIN: address = @0xA;
const USER1: address = @0xB;
const USER2: address = @0xC;
const USER3: address = @0xD;
const PROPOSER_THRESHOLD: u64 = 10_000_000_000_000_000;
const QUORUM_PASS_VOTES: u64 = 1_500_000_000_000_000_000;

fun common_hash(): string::String { string::utf8(b"sha256:test") }
fun common_blob(): string::String { string::utf8(b"walrus_blob") }
fun common_blob_object(): string::String { string::utf8(b"walrus_blob_object") }
fun common_content_type(): string::String { string::utf8(b"application/octet-stream") }
fun no_metadata(): vector<MetadataAttribute> { vector[] }

fun metadata(key: vector<u8>, value: vector<u8>): MetadataAttribute {
    publishing::metadata_attribute(string::utf8(key), string::utf8(value))
}

fun metadata_from_strings(key: string::String, value: string::String): MetadataAttribute {
    publishing::metadata_attribute(key, value)
}

fun mint_votes(amount: u64, scenario: &mut ts::Scenario): Coin<PPRF> {
    coin::mint_for_testing<PPRF>(amount, ts::ctx(scenario))
}

fun repeated_string(byte: u8, len: u64): string::String {
    let mut bytes = vector[];
    let mut i = 0;
    while (i < len) {
        vector::push_back(&mut bytes, byte);
        i = i + 1;
    };
    string::utf8(bytes)
}

fun control_record_id(series: &ArtifactSeries): ID {
    *option::borrow(&publishing::series_control_record_id(series))
}

fun advance_beyond_voting_period(scenario: &mut ts::Scenario, sender: address) {
    let duration = voting::default_proposal_duration_epochs();
    let mut i = 0;
    while (i < duration) {
        ts::next_epoch(scenario, sender);
        i = i + 1;
    };
}

fun init_governance_config(scenario: &mut ts::Scenario) {
    ts::next_tx(scenario, ADMIN);
    let mut vault = ts::take_shared<GovernanceVault>(scenario);
    let config = voting::new_governance_config(&mut vault, ts::ctx(scenario));
    voting::share_governance_config(config);
    ts::return_shared(vault);
}

fun create_and_finalize_publishing_proposal(
    scenario: &mut ts::Scenario,
    action_type: u8,
    payload_u64_1: u64,
    payload_u64_2: u64,
): ID {
    ts::next_tx(scenario, ADMIN);
    let mut config = ts::take_shared<GovernanceConfig>(scenario);
    let proposal_id = voting::create_proposal(
        &mut config,
        voting::proposal_type_executable(),
        action_type,
        string::utf8(b"Publishing config"),
        string::utf8(b"Update publishing configuration"),
        payload_u64_1,
        payload_u64_2,
        @0x0,
        option::none(),
        vector[],
        mint_votes(PROPOSER_THRESHOLD, scenario),
        ts::ctx(scenario),
    );
    let proposal_object_id = voting::proposal_object_id(&config, proposal_id);
    ts::return_shared(config);

    ts::next_tx(scenario, USER2);
    let mut proposal = ts::take_shared_by_id<Proposal>(scenario, proposal_object_id);
    voting::vote_yes(&mut proposal, mint_votes(QUORUM_PASS_VOTES, scenario), ts::ctx(scenario));
    ts::return_shared(proposal);

    advance_beyond_voting_period(scenario, ADMIN);
    let mut config = ts::take_shared<GovernanceConfig>(scenario);
    let mut proposal = ts::take_shared_by_id<Proposal>(scenario, proposal_object_id);
    voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(scenario));
    assert!(voting::proposal_status(&proposal) == voting::proposal_status_passed(), 100);
    ts::return_shared(config);
    ts::return_shared(proposal);

    proposal_object_id
}

fun reserve_preprint_for_sender(scenario: &mut ts::Scenario, sender: address) {
    ts::next_tx(scenario, sender);
    {
        let root = ts::take_shared<PaperProofRoot>(scenario);
        let registry = ts::take_shared<TypeRegistry>(scenario);
        let vault = ts::take_shared<GovernanceVault>(scenario);
        let fee_manager = ts::take_shared<FeeManager>(scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(scenario));
        let reservation = publishing::reserve_preprint_code(&root, &registry, &vault, &fee_manager, &clock_ref, ts::ctx(scenario));
        transfer::public_transfer(reservation, sender);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };
}

fun finalize_sender_preprint(scenario: &mut ts::Scenario, sender: address) {
    ts::next_tx(scenario, sender);
    {
        let reservation = ts::take_from_sender<PreprintReservation>(scenario);
        let root = ts::take_shared<PaperProofRoot>(scenario);
        let registry = ts::take_shared<TypeRegistry>(scenario);
        let vault = ts::take_shared<GovernanceVault>(scenario);
        let fee_manager = ts::take_shared<FeeManager>(scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(scenario));
        publishing::finalize_reserved_preprint(
            reservation,
            &root,
            &registry,
            &vault,
            &fee_manager,
            string::utf8(b"Preprint title"),
            string::utf8(b"Preprint abstract"),
            vector[string::utf8(b"Alice")],
            vector[string::utf8(b"sui")],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            12,
            common_hash(),
            common_blob(),
            common_blob_object(),
            string::utf8(b"application/pdf"),
            no_metadata(), no_metadata(), option::none(),
            &clock_ref,
            ts::ctx(scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };
}

fun publish_legacy_generic_file_for_sender(scenario: &mut ts::Scenario, sender: address) {
    ts::next_tx(scenario, sender);
    {
        let root = ts::take_shared<PaperProofRoot>(scenario);
        let registry = ts::take_shared<TypeRegistry>(scenario);
        let vault = ts::take_shared<GovernanceVault>(scenario);
        let fee_manager = ts::take_shared<FeeManager>(scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(scenario));
        publishing::publish_legacy_generic_file_for_testing(
            &root,
            &registry,
            &vault,
            &fee_manager,
            string::utf8(b"Legacy generic file"),
            string::utf8(b"Legacy description"),
            string::utf8(b"legacy.zip"),
            100,
            string::utf8(b"MIT"),
            common_hash(),
            common_blob(),
            common_blob_object(),
            common_content_type(),
            vector[metadata(b"series_description", b"Legacy summary")],
            vector[metadata(b"legacy_note", b"v1 before controller")],
            option::none(),
            &clock_ref,
            ts::ctx(scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };
}

fun add_comment_to_first_series_tree_for_sender(
    scenario: &mut ts::Scenario,
    sender: address,
    content: vector<u8>,
) {
    ts::next_tx(scenario, sender);
    {
        let mut tree = ts::take_shared<CommentsTree>(scenario);
        let vault = ts::take_shared<GovernanceVault>(scenario);
        let fee_manager = ts::take_shared<FeeManager>(scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(scenario));
        comments::add_onchain_comment(
            &mut tree,
            &vault,
            &fee_manager,
            0,
            content,
            option::none(),
            &clock_ref,
            ts::ctx(scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(tree);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };
}

fun promote_first_legacy_series_to_dual_for_sender(scenario: &mut ts::Scenario, sender: address) {
    ts::next_tx(scenario, sender);
    {
        let mut series = ts::take_shared<ArtifactSeries>(scenario);
        let mut tree = ts::take_shared<CommentsTree>(scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(scenario));
        assert!(!publishing::series_control_enabled(&series), 580);
        assert!(publishing::series_comments_tree_id(&series) == comments::tree_id(&tree), 581);
        publishing::promote_existing_series_to_dual_mode(
            &mut series,
            &mut tree,
            &clock_ref,
            ts::ctx(scenario),
        );
        assert!(publishing::series_in_dual_mode(&series), 582);
        assert!(comments::tree_authority_mode(&tree) == controller::authority_mode_dual(), 583);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };
}

fun promote_first_series_to_controller_primary_for_sender(scenario: &mut ts::Scenario, sender: address) {
    ts::next_tx(scenario, sender);
    {
        let mut series = ts::take_shared<ArtifactSeries>(scenario);
        let mut tree = ts::take_shared<CommentsTree>(scenario);
        let mut control_record = ts::take_shared<ArtifactControlRecord>(scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(scenario),
        );
        assert!(publishing::series_in_controller_primary_mode(&series), 584);
        assert!(comments::tree_authority_mode(&tree) == controller::authority_mode_controller_primary(), 585);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, sender);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };
}

#[test]
fun test_controller_nft_marketplace_metadata_fields() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Marketplace file"), string::utf8(b"Description"), string::utf8(b"market.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);

        assert!(controller::controller_nft_series_id(&controller_nft) == object::id(&series), 601);
        assert!(controller::controller_nft_artifact_code(&controller_nft) == publishing::series_artifact_code(&series), 602);
        assert!(controller::controller_nft_artifact_type(&controller_nft) == publishing::series_artifact_type(&series), 603);
        assert!(controller::controller_nft_artifact_type_name(&controller_nft) == string::utf8(b"generic_file"), 604);
        assert!(controller::controller_nft_control_right(&controller_nft) == string::utf8(b"artifact_controller"), 605);
        assert!(controller::controller_nft_authority_mode_name(&controller_nft) == string::utf8(b"dual_mode"), 606);
        assert!(
            controller::controller_nft_image_url(&controller_nft) ==
                string::utf8(b"https://aggregator.walrus-mainnet.walrus.space/v1/blobs/46egR1yyhHVRNdNx72ICBQ99AiywUaMwfi00CDYznUI"),
            607,
        );
        assert!(
            controller::controller_nft_name(&controller_nft) == {
                let mut expected_name = string::utf8(b"PaperProof Artifact Controller: ");
                string::append(&mut expected_name, publishing::series_artifact_code(&series));
                expected_name
            },
            608,
        );

        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
    };

    ts::end(scenario);
}

#[test]
fun test_controller_marketplace_objects_are_initialized() {
    let mut scenario = ts::begin(ADMIN);
    ts::create_system_objects(&mut scenario);
    controller_marketplace::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let display = ts::take_shared<Display<ControllerNFT>>(&scenario);
        let fields = display::fields(&display);
        assert!(*vec_map::get(fields, &string::utf8(b"name")) == string::utf8(b"PaperProof Controller NFT: {artifact_code}"), 611);
        assert!(*vec_map::get(fields, &string::utf8(b"image")) == string::utf8(b"{image_url}"), 612);
        assert!(*vec_map::get(fields, &string::utf8(b"image_url")) == string::utf8(b"{image_url}"), 613);
        assert!(*vec_map::get(fields, &string::utf8(b"control_right")) == string::utf8(b"{control_right}"), 614);
        assert!(*vec_map::get(fields, &string::utf8(b"authority_mode")) == string::utf8(b"{authority_mode_name}"), 615);
        assert!(ts::has_most_recent_for_sender<TransferPolicyCap<ControllerNFT>>(&scenario), 616);
        ts::return_shared(display);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let cap = ts::take_from_sender<TransferPolicyCap<ControllerNFT>>(&scenario);
        transfer::public_transfer(cap, ADMIN);
    };

    ts::end(scenario);
}

#[test]
fun test_publish_all_builtin_artifact_types() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        let reservation = publishing::reserve_preprint_code(&root, &registry, &vault, &fee_manager, &clock_ref, ts::ctx(&mut scenario));
        transfer::public_transfer(reservation, USER1);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let reservation = ts::take_from_sender<PreprintReservation>(&scenario);
        let reserved_series_id = publishing::preprint_reservation_series_id(&reservation);
        assert!(
            publishing::preprint_reservation_artifact_code(&reservation) ==
                publishing::expected_artifact_code_for_testing(publishing::artifact_type_preprint(), 0, reserved_series_id),
            6,
        );
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::finalize_reserved_preprint(
            reservation,
            &root,
            &registry,
            &vault,
            &fee_manager,
            string::utf8(b"Preprint title"),
            string::utf8(b"Preprint abstract"),
            vector[string::utf8(b"Alice")],
            vector[string::utf8(b"sui")],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            12,
            common_hash(),
            common_blob(),
            common_blob_object(),
            string::utf8(b"application/pdf"),
            no_metadata(), no_metadata(), option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let series = ts::take_shared<ArtifactSeries>(&scenario);
        let tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let likes_book = ts::take_shared_by_id<LikesBook>(&scenario, publishing::series_likes_book_id(&series));
        let record = ts::take_shared<PreprintVersionRecord>(&scenario);
        assert!(publishing::series_current_version(&series) == 1, 2);
        assert!(comments::target_series_id(&tree) == object::id(&series), 3);
        assert!(comments::target_artifact_type(&tree) == publishing::artifact_type_preprint(), 4);
        assert!(publishing::header_artifact_type(publishing::preprint_header(&record)) == publishing::artifact_type_preprint(), 5);
        assert!(
            publishing::series_artifact_code(&series) ==
                publishing::expected_artifact_code_for_testing(publishing::artifact_type_preprint(), 0, object::id(&series)),
            6,
        );
        assert!(publishing::series_artifact_code(&series) == publishing::expected_artifact_code_for_testing(publishing::artifact_type_preprint(), 0, object::id(&series)), 9);
        assert!(comments::tree_likes_book_id(&tree) == publishing::series_likes_book_id(&series), 7);
        assert!(comments::likes_book_comments_tree_id(&likes_book) == publishing::series_comments_tree_id(&series), 8);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(likes_book);
        ts::return_shared(record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::publish_blog_post(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Blog title"), string::utf8(b"Blog summary"), vector[string::utf8(b"tag")], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_technical_report(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Report title"), string::utf8(b"Report abstract"), vector[string::utf8(b"Alice")],
            string::utf8(b"PaperProof Labs"), string::utf8(b"TR-1"), vector[string::utf8(b"protocol")], string::utf8(b"CC-BY"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"application/pdf"), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_dataset(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Dataset title"), string::utf8(b"Dataset description"), string::utf8(b"csv"), 2, 1000, string::utf8(b"CC0"), vector[string::utf8(b"data")],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_software_release(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Project"), string::utf8(b"v1.0.0"), string::utf8(b"source_hash"), string::utf8(b"package_hash"),
            string::utf8(b"Initial release"), string::utf8(b"MIT"), string::utf8(b"https://example.com/repo"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"application/zip"), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File title"), string::utf8(b"File description"), string::utf8(b"archive.zip"), 1000, string::utf8(b"CC-BY"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let blog = ts::take_shared<BlogPostVersionRecord>(&scenario);
        let report = ts::take_shared<TechnicalReportVersionRecord>(&scenario);
        let dataset = ts::take_shared<DatasetVersionRecord>(&scenario);
        let release = ts::take_shared<SoftwareReleaseVersionRecord>(&scenario);
        let file = ts::take_shared<GenericFileVersionRecord>(&scenario);
        assert!(publishing::header_artifact_type(publishing::blog_post_header(&blog)) == publishing::artifact_type_blog_post(), 10);
        assert!(publishing::header_artifact_type(publishing::technical_report_header(&report)) == publishing::artifact_type_technical_report(), 11);
        assert!(publishing::header_artifact_type(publishing::dataset_header(&dataset)) == publishing::artifact_type_dataset(), 12);
        assert!(publishing::header_artifact_type(publishing::software_release_header(&release)) == publishing::artifact_type_software_release(), 13);
        assert!(publishing::header_artifact_type(publishing::generic_file_header(&file)) == publishing::artifact_type_generic_file(), 14);
        ts::return_shared(blog);
        ts::return_shared(report);
        ts::return_shared(dataset);
        ts::return_shared(release);
        ts::return_shared(file);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 30, location = paperproof_publishing::publishing)]
fun test_direct_preprint_publish_is_disabled() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let vault = ts::take_shared<GovernanceVault>(&scenario);
    let fee_manager = ts::take_shared<FeeManager>(&scenario);
    let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
    publishing::publish_preprint(
        &root,
        &registry,
        &vault,
        &fee_manager,
        string::utf8(b"Preprint title"),
        string::utf8(b"Preprint abstract"),
        vector[string::utf8(b"Alice")],
        vector[string::utf8(b"sui")],
        string::utf8(b"Computer Science"),
        string::utf8(b"CC-BY-4.0"),
        12,
        common_hash(),
        common_blob(),
        common_blob_object(),
        string::utf8(b"application/pdf"),
        no_metadata(), no_metadata(), option::none(),
        &clock_ref,
        ts::ctx(&mut scenario),
    );
    abort 999
}

#[test]
#[expected_failure(abort_code = 21, location = paperproof_publishing::publishing)]
fun test_non_reserver_cannot_finalize_reserved_preprint() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        let reservation = publishing::reserve_preprint_code(&root, &registry, &vault, &fee_manager, &clock_ref, ts::ctx(&mut scenario));
        transfer::public_transfer(reservation, USER1);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    let reservation = ts::take_from_sender<PreprintReservation>(&scenario);
    transfer::public_transfer(reservation, USER2);

    ts::next_tx(&mut scenario, USER2);
    let reservation = ts::take_from_sender<PreprintReservation>(&scenario);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let vault = ts::take_shared<GovernanceVault>(&scenario);
    let fee_manager = ts::take_shared<FeeManager>(&scenario);
    let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
    publishing::finalize_reserved_preprint(
        reservation,
        &root,
        &registry,
        &vault,
        &fee_manager,
        string::utf8(b"Preprint title"),
        string::utf8(b"Preprint abstract"),
        vector[string::utf8(b"Alice")],
        vector[string::utf8(b"sui")],
        string::utf8(b"Computer Science"),
        string::utf8(b"CC-BY-4.0"),
        12,
        common_hash(),
        common_blob(),
        common_blob_object(),
        string::utf8(b"application/pdf"),
        no_metadata(), no_metadata(), option::none(),
        &clock_ref,
        ts::ctx(&mut scenario),
    );
    abort 999
}

#[test]
fun test_reserved_preprint_can_add_version_after_finalize() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    reserve_preprint_for_sender(&mut scenario, USER1);
    finalize_sender_preprint(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let original_code = publishing::series_artifact_code(&series);
        let original_tree_id = publishing::series_comments_tree_id(&series);
        let original_likes_book_id = publishing::series_likes_book_id(&series);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_preprint_version(
            &root,
            &registry,
            &mut series,
            &vault,
            &fee_manager,
            string::utf8(b"Preprint title v2"),
            string::utf8(b"Preprint abstract v2"),
            vector[string::utf8(b"Alice")],
            vector[string::utf8(b"sui"), string::utf8(b"preprint")],
            string::utf8(b"Computer Science"),
            string::utf8(b"CC-BY-4.0"),
            14,
            string::utf8(b"sha256:v2"),
            string::utf8(b"walrus_blob_v2"),
            string::utf8(b"walrus_blob_object_v2"),
            string::utf8(b"application/pdf"),
            no_metadata(),
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 31);
        assert!(publishing::version_count(&series) == 2, 32);
        assert!(publishing::series_artifact_code(&series) == original_code, 33);
        assert!(publishing::series_comments_tree_id(&series) == original_tree_id, 34);
        assert!(publishing::series_likes_book_id(&series) == original_likes_book_id, 35);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let record = ts::take_shared<PreprintVersionRecord>(&scenario);
        assert!(publishing::header_version(publishing::preprint_header(&record)) == 2, 36);
        assert!(publishing::header_artifact_type(publishing::preprint_header(&record)) == publishing::artifact_type_preprint(), 37);
        ts::return_shared(record);
    };

    ts::end(scenario);
}

#[test]
fun test_two_preprint_reservations_have_distinct_codes_and_series_ids() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        let reservation1 = publishing::reserve_preprint_code(&root, &registry, &vault, &fee_manager, &clock_ref, ts::ctx(&mut scenario));
        let reservation2 = publishing::reserve_preprint_code(&root, &registry, &vault, &fee_manager, &clock_ref, ts::ctx(&mut scenario));
        let series_id1 = publishing::preprint_reservation_series_id(&reservation1);
        let series_id2 = publishing::preprint_reservation_series_id(&reservation2);
        assert!(series_id1 != series_id2, 38);
        assert!(
            publishing::preprint_reservation_artifact_code(&reservation1) !=
                publishing::preprint_reservation_artifact_code(&reservation2),
            39,
        );
        assert!(
            publishing::preprint_reservation_artifact_code(&reservation1) ==
                publishing::expected_artifact_code_for_testing(publishing::artifact_type_preprint(), 0, series_id1),
            40,
        );
        assert!(
            publishing::preprint_reservation_artifact_code(&reservation2) ==
                publishing::expected_artifact_code_for_testing(publishing::artifact_type_preprint(), 0, series_id2),
            41,
        );
        transfer::public_transfer(reservation1, USER1);
        transfer::public_transfer(reservation2, USER1);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_non_preprint_publish_paths_still_work_with_outstanding_preprint_reservation() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    reserve_preprint_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_blog_post(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Blog title"), string::utf8(b"Blog summary"), vector[string::utf8(b"paperproof")], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_dataset(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Dataset title"), string::utf8(b"Dataset description"), string::utf8(b"csv"), 2, 1000, string::utf8(b"CC0"), vector[string::utf8(b"data")],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let blog = ts::take_shared<BlogPostVersionRecord>(&scenario);
        let dataset = ts::take_shared<DatasetVersionRecord>(&scenario);
        assert!(publishing::header_artifact_type(publishing::blog_post_header(&blog)) == publishing::artifact_type_blog_post(), 42);
        assert!(publishing::header_artifact_type(publishing::dataset_header(&dataset)) == publishing::artifact_type_dataset(), 43);
        ts::return_shared(blog);
        ts::return_shared(dataset);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_publishing::publishing)]
fun test_pause_rejects_preprint_reservation() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_paused(&mut root, &vault, &permit, true, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(permit, ADMIN);
        ts::return_shared(root);
        ts::return_shared(vault);
    };

    reserve_preprint_for_sender(&mut scenario, USER1);
    abort 999
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_publishing::publishing)]
fun test_pause_rejects_reserved_preprint_finalize() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    reserve_preprint_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_paused(&mut root, &vault, &permit, true, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(permit, ADMIN);
        ts::return_shared(root);
        ts::return_shared(vault);
    };

    finalize_sender_preprint(&mut scenario, USER1);
    abort 999
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_publishing::publishing)]
fun test_disabled_preprint_type_rejects_reserved_preprint_finalize() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    reserve_preprint_for_sender(&mut scenario, USER1);

    init_governance_config(&mut scenario);
    let proposal_object_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_artifact_type_enabled(),
        publishing::artifact_type_preprint() as u64,
        0,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, proposal_object_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::execute_artifact_type_enabled_proposal(
            &root, &mut registry, &vault, &mut config, &mut proposal, &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    finalize_sender_preprint(&mut scenario, USER1);
    abort 999
}

#[test]
fun test_add_version_and_transfer_owner_keep_comments_tree() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let original_tree_id = publishing::series_comments_tree_id(&series);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 20);
        assert!(publishing::version_count(&series) == 2, 21);
        assert!(publishing::series_comments_tree_id(&series) == original_tree_id, 22);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::transfer_artifact_owner(&mut series, &mut tree, USER2, &clock_ref, ts::ctx(&mut scenario));
        assert!(publishing::series_owner(&series) == USER2, 23);
        assert!(comments::owner(&tree) == USER2, 24);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
fun test_metadata_extensions_on_publish_add_version_and_series_update() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"doi", b"10.1234/paperproof")],
            vector[metadata(b"version_note", b"first")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let series = ts::take_shared<ArtifactSeries>(&scenario);
        let record = ts::take_shared<GenericFileVersionRecord>(&scenario);
        assert!(publishing::series_metadata_count(&series) == 1, 30);
        assert!(publishing::series_metadata_key_at(&series, 0) == string::utf8(b"doi"), 31);
        assert!(publishing::series_metadata_value_at(&series, 0) == string::utf8(b"10.1234/paperproof"), 32);
        assert!(publishing::header_metadata_count(publishing::generic_file_header(&record)) == 1, 33);
        assert!(publishing::header_metadata_key_at(publishing::generic_file_header(&record), 0) == string::utf8(b"version_note"), 34);
        assert!(publishing::header_metadata_value_at(publishing::generic_file_header(&record), 0) == string::utf8(b"first"), 35);
        ts::return_shared(series);
        ts::return_shared(record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(),
            vector[metadata(b"version_note", b"second")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::update_series_metadata_extensions(
            &mut series,
            vector[metadata(b"doi", b"10.5678/updated"), metadata(b"license_uri", b"https://example.com/license")],
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_metadata_count(&series) == 2, 36);
        assert!(publishing::series_metadata_value_at(&series, 0) == string::utf8(b"10.5678/updated"), 37);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
    };

    ts::end(scenario);
}

#[test]
fun test_publish_creates_controller_state() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controlled file"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let series = ts::take_shared<ArtifactSeries>(&scenario);
        let tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let record = ts::take_shared<GenericFileVersionRecord>(&scenario);

        assert!(publishing::series_control_enabled(&series), 500);
        assert!(comments::tree_control_enabled(&tree), 501);
        assert!(publishing::series_authority_mode(&series) == controller::authority_mode_dual(), 502);
        assert!(comments::tree_authority_mode(&tree) == controller::authority_mode_dual(), 503);
        assert!(controller::control_record_authority_mode(&control_record) == controller::authority_mode_dual(), 504);
        assert!(controller::controller_nft_series_id(&mut controller_nft) == object::id(&series), 505);
        assert!(publishing::series_description(&series) == option::some(string::utf8(b"Series summary")), 506);
        assert!(publishing::header_version_change_note(publishing::generic_file_header(&record)) == option::some(string::utf8(b"Initial release")), 507);

        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
        ts::return_shared(record);
    };

    ts::end(scenario);
}

#[test]
fun test_controller_primary_blocks_legacy_write_paths_and_allows_controller_write() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controlled file"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_authority_mode(&series) == controller::authority_mode_controller_primary(), 520);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::add_generic_file_version_with_controller(
            &root, &registry, &mut series, &mut control_record, &mut controller_nft, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(),
            vector[metadata(b"version_change_note", b"Second release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::update_series_description_with_controller(
            &mut series,
            &mut control_record,
            &mut controller_nft,
            string::utf8(b"Updated series summary"),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(publishing::series_current_version(&series) == 2, 521);
        assert!(publishing::series_description(&series) == option::some(string::utf8(b"Updated series summary")), 522);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(control_record);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_shared_controller::controller)]
fun test_controller_primary_rejects_legacy_add_version_path() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controlled file"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"Legacy blocked"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(),
            vector[metadata(b"version_change_note", b"Second release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_dual_mode_preserves_legacy_owner_transfer_and_add_version() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Dual file"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::transfer_artifact_owner(&mut series, &mut tree, USER2, &clock_ref, ts::ctx(&mut scenario));
        assert!(publishing::series_owner(&series) == USER2, 530);
        assert!(comments::owner(&tree) == USER2, 531);
        assert!(publishing::series_authority_mode(&series) == controller::authority_mode_dual(), 532);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"Dual file v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(),
            vector[metadata(b"version_change_note", b"Second release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 533);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_controller_primary_allows_controller_owner_transfer() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controlled transfer"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        publishing::transfer_artifact_owner_with_controller(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            USER1,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_owner(&series) == USER1, 534);
        assert!(comments::owner(&tree) == USER1, 535);
        assert!(controller::control_record_legacy_series_owner_mirror(&control_record) == USER1, 536);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER1, 537);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 31, location = paperproof_publishing::publishing)]
fun test_controller_primary_blocks_mirror_transfer_to_non_holder() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controlled transfer"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        publishing::transfer_artifact_owner_with_controller(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            USER2,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_shared_controller::controller)]
fun test_transfer_locked_blocks_controller_owner_transfer() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Locked transfer"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        controller::set_transfer_locked(&mut control_record, &mut controller_nft, true, &clock_ref, ts::ctx(&mut scenario));
        publishing::transfer_artifact_owner_with_controller(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            USER2,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 3, location = paperproof_shared_controller::controller)]
fun test_promote_existing_series_to_dual_mode_rejects_already_controlled_series() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Promotable file"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Legacy summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let comments_tree_id = publishing::series_comments_tree_id(&series);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, comments_tree_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_dual_mode(
            &mut series,
            &mut tree,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_shared_controller::controller)]
fun test_transfer_locked_blocks_controller_add_version() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Locked add-version"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        controller::set_transfer_locked(&mut control_record, &mut controller_nft, true, &clock_ref, ts::ctx(&mut scenario));
        publishing::add_generic_file_version_with_controller(
            &root, &registry, &mut series, &mut control_record, &mut controller_nft, &vault, &fee_manager,
            string::utf8(b"Blocked v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(),
            vector[metadata(b"version_change_note", b"Second release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_controller_only_allows_controller_write() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controller only"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_only(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_in_controller_only_mode(&series), 548);
        publishing::add_generic_file_version_with_controller(
            &root,
            &registry,
            &mut series,
            &mut control_record,
            &mut controller_nft,
            &vault,
            &fee_manager,
            string::utf8(b"Controller only v2"),
            string::utf8(b"Description v2"),
            string::utf8(b"file-v2.zip"),
            200,
            string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"),
            string::utf8(b"blob_v2"),
            string::utf8(b"blob_object_v2"),
            common_content_type(),
            vector[metadata(b"version_change_note", b"Second release")],
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 549);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_shared_controller::controller)]
fun test_controller_only_blocks_legacy_owner_transfer() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Controller only"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_only(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::transfer_artifact_owner(&mut series, &mut tree, USER2, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::end(scenario);
}

#[test]
fun test_repair_existing_series_control_mirrors_after_controller_transfer() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Repair mirrors"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        transfer::public_transfer(controller_nft, USER2);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        assert!(controller::is_control_mirror_stale(&control_record, USER2), 551);
        publishing::repair_existing_series_control_mirrors(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_owner(&series) == USER2, 552);
        assert!(comments::owner(&tree) == USER2, 553);
        assert!(controller::control_record_current_controller_mirror(&control_record) == USER2, 554);
        assert!(controller::control_record_legacy_series_owner_mirror(&control_record) == USER2, 555);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER2, 556);
        assert!(!controller::is_control_mirror_stale(&control_record, USER2), 557);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER2);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
fun test_controller_moderation_before_repair_keeps_stale_legacy_mirrors() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    publish_legacy_generic_file_for_sender(&mut scenario, USER1);
    add_comment_to_first_series_tree_for_sender(&mut scenario, USER3, b"Legacy comment before transfer");
    promote_first_legacy_series_to_dual_for_sender(&mut scenario, USER1);
    promote_first_series_to_controller_primary_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        transfer::public_transfer(controller_nft, USER2);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let mut control_record = ts::take_shared<ArtifactControlRecord>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        assert!(controller::is_control_mirror_stale(&control_record, USER2), 601);
        assert!(comments::owner(&tree) == USER1, 602);
        comments::set_comment_status_with_controller(
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            1,
            comments::comment_status_hidden(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(comments::status(comments::borrow_comment(&tree, 1)) == comments::comment_status_hidden(), 603);
        assert!(controller::control_record_current_controller_mirror(&control_record) == USER2, 604);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER1, 605);
        assert!(controller::is_control_mirror_stale(&control_record, USER2), 606);

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER2);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
fun test_sync_existing_series_control_mirrors_keeps_existing_owners() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Sync mirrors"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata(b"series_description", b"Series summary")],
            vector[metadata(b"version_change_note", b"Initial release")],
            option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::sync_existing_series_control_mirrors(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(controller::control_record_current_controller_mirror(&control_record) == USER1, 558);
        assert!(controller::control_record_legacy_series_owner_mirror(&control_record) == USER1, 559);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER1, 560);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
fun test_sync_existing_series_control_mirrors_does_not_auto_repair_stale_owners() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    publish_legacy_generic_file_for_sender(&mut scenario, USER1);
    promote_first_legacy_series_to_dual_for_sender(&mut scenario, USER1);
    promote_first_series_to_controller_primary_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        transfer::public_transfer(controller_nft, USER2);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let mut control_record = ts::take_shared<ArtifactControlRecord>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        assert!(controller::is_control_mirror_stale(&control_record, USER2), 607);
        assert!(publishing::series_owner(&series) == USER1, 608);
        assert!(comments::owner(&tree) == USER1, 609);
        publishing::sync_existing_series_control_mirrors(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(controller::control_record_current_controller_mirror(&control_record) == USER2, 610);
        assert!(controller::control_record_legacy_series_owner_mirror(&control_record) == USER1, 611);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER1, 612);
        assert!(controller::is_control_mirror_stale(&control_record, USER2), 613);
        assert!(publishing::series_owner(&series) == USER1, 614);
        assert!(comments::owner(&tree) == USER1, 615);

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER2);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
fun test_real_legacy_series_can_be_promoted_to_dual_mode() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    publish_legacy_generic_file_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let series_id = object::id(&series);
        let tree_id = publishing::series_comments_tree_id(&series);
        let likes_id = publishing::series_likes_book_id(&series);
        let version_id = publishing::series_current_version_id(&series);
        assert!(!publishing::series_control_enabled(&series), 561);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        assert!(comments::tree_id(&tree) == tree_id, 562);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_dual_mode(
            &mut series,
            &mut tree,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_control_enabled(&series), 562);
        assert!(publishing::series_in_dual_mode(&series), 563);
        assert!(comments::tree_control_enabled(&tree), 564);
        assert!(comments::tree_authority_mode(&tree) == controller::authority_mode_dual(), 565);
        assert!(object::id(&series) == series_id, 566);
        assert!(publishing::series_comments_tree_id(&series) == tree_id, 567);
        assert!(publishing::series_likes_book_id(&series) == likes_id, 568);
        assert!(publishing::series_current_version_id(&series) == version_id, 569);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let series = ts::take_shared<ArtifactSeries>(&scenario);
        let tree = ts::take_shared<CommentsTree>(&scenario);
        let control_record = ts::take_shared<ArtifactControlRecord>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let series_id = object::id(&series);
        let tree_id = publishing::series_comments_tree_id(&series);

        assert!(controller::control_record_series_id(&control_record) == series_id, 570);
        assert!(controller::control_record_comments_tree_id(&control_record) == tree_id, 571);
        assert!(controller::control_record_legacy_series_owner_mirror(&control_record) == USER1, 572);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER1, 573);
        assert!(controller::controller_nft_series_id(&mut controller_nft) == series_id, 574);
        assert!(comments::tree_id(&tree) == tree_id, 575);

        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
fun test_real_legacy_series_promote_to_dual_then_controller_primary() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    publish_legacy_generic_file_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_dual_mode(
            &mut series,
            &mut tree,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let mut control_record = ts::take_shared<ArtifactControlRecord>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref2 = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_primary(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref2,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_in_controller_primary_mode(&series), 574);
        assert!(comments::tree_authority_mode(&tree) == controller::authority_mode_controller_primary(), 575);
        clock::destroy_for_testing(clock_ref2);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut control_record = ts::take_shared_by_id<ArtifactControlRecord>(&scenario, control_record_id(&series));
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version_with_controller(
            &root, &registry, &mut series, &mut control_record, &mut controller_nft, &vault, &fee_manager,
            string::utf8(b"Legacy promoted v2"),
            string::utf8(b"Description v2"),
            string::utf8(b"legacy-v2.zip"),
            200,
            string::utf8(b"MIT"),
            string::utf8(b"sha256:legacy-v2"),
            string::utf8(b"blob_legacy_v2"),
            string::utf8(b"blob_object_legacy_v2"),
            common_content_type(),
            vector[metadata(b"version_change_note", b"Promotion-based v2")],
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 576);
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(control_record);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_real_legacy_series_can_be_promoted_to_controller_only() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    publish_legacy_generic_file_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_dual_mode(
            &mut series,
            &mut tree,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
        ts::return_shared(tree);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let mut control_record = ts::take_shared<ArtifactControlRecord>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref2 = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::promote_existing_series_to_controller_only(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref2,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_in_controller_only_mode(&series), 577);
        assert!(comments::tree_authority_mode(&tree) == controller::authority_mode_controller_only(), 578);
        clock::destroy_for_testing(clock_ref2);
        transfer::public_transfer(controller_nft, USER1);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
fun test_real_legacy_series_promotion_rehearsal_with_transfer_repair_and_controller_ops() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    publish_legacy_generic_file_for_sender(&mut scenario, USER1);
    add_comment_to_first_series_tree_for_sender(&mut scenario, USER3, b"Legacy comment before promotion");
    promote_first_legacy_series_to_dual_for_sender(&mut scenario, USER1);
    promote_first_series_to_controller_primary_for_sender(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        transfer::public_transfer(controller_nft, USER2);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let series_id = object::id(&series);
        let comments_tree_id = publishing::series_comments_tree_id(&series);
        let likes_book_id = publishing::series_likes_book_id(&series);
        let original_version_id = publishing::series_current_version_id(&series);
        let mut tree = ts::take_shared<CommentsTree>(&scenario);
        let mut control_record = ts::take_shared<ArtifactControlRecord>(&scenario);
        let mut controller_nft = ts::take_from_sender<ControllerNFT>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        assert!(controller::is_control_mirror_stale(&control_record, USER2), 586);
        publishing::repair_existing_series_control_mirrors(
            &mut series,
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(!controller::is_control_mirror_stale(&control_record, USER2), 587);
        assert!(publishing::series_owner(&series) == USER2, 588);
        assert!(comments::owner(&tree) == USER2, 589);
        assert!(comments::tree_id(&tree) == comments_tree_id, 590);
        assert!(publishing::series_current_version_id(&series) == original_version_id, 591);

        comments::set_comment_status_with_controller(
            &mut tree,
            &mut control_record,
            &mut controller_nft,
            1,
            comments::comment_status_hidden(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(comments::status(comments::borrow_comment(&tree, 1)) == comments::comment_status_hidden(), 592);

        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        publishing::add_generic_file_version_with_controller(
            &root,
            &registry,
            &mut series,
            &mut control_record,
            &mut controller_nft,
            &vault,
            &fee_manager,
            string::utf8(b"Rehearsal v2"),
            string::utf8(b"Rehearsal description v2"),
            string::utf8(b"rehearsal-v2.zip"),
            200,
            string::utf8(b"MIT"),
            string::utf8(b"sha256:rehearsal-v2"),
            string::utf8(b"blob_rehearsal_v2"),
            string::utf8(b"blob_object_rehearsal_v2"),
            common_content_type(),
            vector[metadata(b"version_change_note", b"Controller migration rehearsal v2")],
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 593);
        assert!(object::id(&series) == series_id, 594);
        assert!(publishing::series_comments_tree_id(&series) == comments_tree_id, 595);
        assert!(publishing::series_likes_book_id(&series) == likes_book_id, 596);
        assert!(publishing::series_in_controller_primary_mode(&series), 597);
        assert!(controller::control_record_current_controller_mirror(&control_record) == USER2, 598);
        assert!(controller::control_record_legacy_series_owner_mirror(&control_record) == USER2, 599);
        assert!(controller::control_record_legacy_comments_owner_mirror(&control_record) == USER2, 600);

        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(controller_nft, USER2);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(control_record);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 22, location = paperproof_publishing::publishing)]
fun test_locked_series_cannot_update_metadata_extensions() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let operator_permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_series_status(
            &root,
            &mut series,
            &vault,
            &operator_permit,
            publishing::series_status_locked(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(vault);
        ts::return_to_sender(&scenario, operator_permit);
        ts::return_shared(series);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::update_series_metadata_extensions(
            &mut series,
            vector[metadata(b"doi", b"10.5678/updated")],
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 26, location = paperproof_publishing::publishing)]
fun test_metadata_extensions_reject_more_than_four_attributes() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let vault = ts::take_shared<GovernanceVault>(&scenario);
    let fee_manager = ts::take_shared<FeeManager>(&scenario);
    let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
    publishing::publish_generic_file(
        &root, &registry, &vault, &fee_manager,
        string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
        common_hash(), common_blob(), common_blob_object(), common_content_type(),
        vector[
            metadata(b"k1", b"v1"),
            metadata(b"k2", b"v2"),
            metadata(b"k3", b"v3"),
            metadata(b"k4", b"v4"),
            metadata(b"k5", b"v5"),
        ],
        no_metadata(),
        option::none(), &clock_ref, ts::ctx(&mut scenario),
    );
    abort 999
}

#[test]
#[expected_failure(abort_code = 29, location = paperproof_publishing::publishing)]
fun test_metadata_extensions_reject_duplicate_keys() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let vault = ts::take_shared<GovernanceVault>(&scenario);
    let fee_manager = ts::take_shared<FeeManager>(&scenario);
    let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
    publishing::publish_generic_file(
        &root, &registry, &vault, &fee_manager,
        string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
        common_hash(), common_blob(), common_blob_object(), common_content_type(),
        vector[metadata(b"doi", b"v1"), metadata(b"doi", b"v2")],
        no_metadata(),
        option::none(), &clock_ref, ts::ctx(&mut scenario),
    );
    abort 999
}

#[test]
#[expected_failure(abort_code = 21, location = paperproof_publishing::publishing)]
fun test_non_owner_cannot_update_series_metadata_extensions() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER2);
    let mut series = ts::take_shared<ArtifactSeries>(&scenario);
    let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
    publishing::update_series_metadata_extensions(
        &mut series,
        vector[metadata(b"doi", b"10.5678/updated")],
        &clock_ref,
        ts::ctx(&mut scenario),
    );
    abort 999
}

#[test]
#[expected_failure(abort_code = 24, location = paperproof_comments::comments)]
fun test_non_authority_cannot_mint_comments_tree_factory_cap() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let _cap = comments::new_tree_factory_cap(&vault, &fee_manager, ts::ctx(&mut scenario));
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 28, location = paperproof_publishing::publishing)]
fun test_metadata_extensions_reject_overlong_key() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata_from_strings(repeated_string(65, 65), string::utf8(b"value"))],
            no_metadata(),
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 28, location = paperproof_publishing::publishing)]
fun test_metadata_extensions_reject_overlong_value() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(),
            vector[metadata_from_strings(string::utf8(b"key"), repeated_string(65, 512))],
            no_metadata(),
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 22, location = paperproof_publishing::publishing)]
fun test_locked_series_cannot_add_version() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_series_status(
            &root, &mut series, &vault, &permit, 1, &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(permit, ADMIN);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_publishing::publishing)]
fun test_disabled_artifact_type_rejects_publish() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    init_governance_config(&mut scenario);
    let proposal_object_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_artifact_type_enabled(),
        publishing::artifact_type_blog_post() as u64,
        0,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, proposal_object_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::execute_artifact_type_enabled_proposal(
            &root, &mut registry, &vault, &mut config, &mut proposal, &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_blog_post(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Blog"), string::utf8(b"Summary"), vector[], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_publishing::publishing)]
fun test_disabled_artifact_type_rejects_existing_series_version() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    init_governance_config(&mut scenario);
    let proposal_object_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_artifact_type_enabled(),
        publishing::artifact_type_generic_file() as u64,
        0,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, proposal_object_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::execute_artifact_type_enabled_proposal(
            &root, &mut registry, &vault, &mut config, &mut proposal, &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_artifact_type_fee_level_requires_payment() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    init_governance_config(&mut scenario);
    let proposal_object_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_artifact_fee_level(),
        publishing::artifact_type_dataset() as u64,
        1,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, proposal_object_id);
        publishing::execute_artifact_fee_level_proposal(
            &root, &vault, &mut fee_manager, &mut config, &mut proposal, ts::ctx(&mut scenario),
        );
        assert!(governance::artifact_fee_amount(&fee_manager, publishing::artifact_type_dataset()) == 10_000, 30);
        ts::return_shared(root);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let payment = coin::mint_for_testing<SUI>(10_000, ts::ctx(&mut scenario));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_dataset(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Paid dataset"), string::utf8(b"Description"), string::utf8(b"csv"), 1, 100, string::utf8(b"CC0"), vector[],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::some(payment), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_publishing::publishing)]
fun test_pause_rejects_publish() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_paused(&mut root, &vault, &permit, true, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(permit, ADMIN);
        ts::return_shared(root);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = paperproof_publishing::publishing)]
fun test_pause_rejects_add_version() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_paused(&mut root, &vault, &permit, true, &clock_ref, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(permit, ADMIN);
        ts::return_shared(root);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_publishing::publishing)]
fun test_comments_fee_proposal_rejects_foreign_fee_manager() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let root_id = object::id(&root);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let foreign_fee_manager = governance::new_fee_manager(root_id, ts::ctx(&mut scenario));
    governance::share_fee_manager(foreign_fee_manager);
    ts::return_shared(registry);
    ts::return_shared(root);

    init_governance_config(&mut scenario);
    let proposal_object_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_comments_fee_level(),
        1,
        0,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut foreign_fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, proposal_object_id);

        publishing::execute_comments_fee_level_proposal(
            &root,
            &vault,
            &mut foreign_fee_manager,
            &mut config,
            &mut proposal,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(root);
        ts::return_shared(vault);
        ts::return_shared(foreign_fee_manager);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_disabled_type_can_be_reenabled_and_published() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    init_governance_config(&mut scenario);
    let disable_proposal_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_artifact_type_enabled(),
        publishing::artifact_type_blog_post() as u64,
        0,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, disable_proposal_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::execute_artifact_type_enabled_proposal(
            &root, &mut registry, &vault, &mut config, &mut proposal, &clock_ref, ts::ctx(&mut scenario),
        );
        assert!(!publishing::type_enabled(&registry, publishing::artifact_type_blog_post()), 40);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    let enable_proposal_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_activate_artifact_type(),
        publishing::artifact_type_blog_post() as u64,
        1,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, enable_proposal_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::execute_artifact_type_activation_proposal(
            &root, &mut registry, &vault, &mut fee_manager, &mut config, &mut proposal, &clock_ref, ts::ctx(&mut scenario),
        );
        assert!(publishing::type_enabled(&registry, publishing::artifact_type_blog_post()), 41);
        assert!(governance::artifact_fee_amount(&fee_manager, publishing::artifact_type_blog_post()) == 10_000, 43);

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let payment = coin::mint_for_testing<SUI>(10_000, ts::ctx(&mut scenario));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_blog_post(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Reenabled blog"), string::utf8(b"Summary"), vector[], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), no_metadata(), no_metadata(), option::some(payment), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 21, location = paperproof_publishing::publishing)]
fun test_non_owner_cannot_add_artifact_version() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);

    ts::next_tx(&mut scenario, USER2);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        publishing::add_generic_file_version(
            &root, &registry, &mut series, &vault, &fee_manager,
            string::utf8(b"Bad v2"), string::utf8(b"Description"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 25, location = paperproof_publishing::publishing)]
fun test_more_than_max_versions_per_series_is_rejected() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let mut series = ts::take_shared<ArtifactSeries>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        let mut i = 1u64;
        while (i <= 168) {
            publishing::add_generic_file_version(
                &root,
                &registry,
                &mut series,
                &vault,
                &fee_manager,
                string::utf8(b"File v2"),
                string::utf8(b"Description v2"),
                string::utf8(b"file-v2.zip"),
                200,
                string::utf8(b"MIT"),
                string::utf8(b"sha256:v2"),
                string::utf8(b"blob_v2"),
                string::utf8(b"blob_object_v2"),
                common_content_type(),
                no_metadata(),
                option::none(),
                &clock_ref,
                ts::ctx(&mut scenario),
            );
            i = i + 1u64;
        };
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10, location = paperproof_governance::governance)]
fun test_artifact_fee_requires_payment_coin() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    init_governance_config(&mut scenario);
    let proposal_object_id = create_and_finalize_publishing_proposal(
        &mut scenario,
        voting::action_set_artifact_fee_level(),
        publishing::artifact_type_dataset() as u64,
        1,
    );

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, proposal_object_id);
        publishing::execute_artifact_fee_level_proposal(
            &root, &vault, &mut fee_manager, &mut config, &mut proposal, ts::ctx(&mut scenario),
        );
        ts::return_shared(root);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_dataset(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b"Unpaid dataset"), string::utf8(b"Description"), string::utf8(b"csv"), 1, 100, string::utf8(b"CC0"), vector[],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 14, location = paperproof_publishing::validation)]
fun test_empty_title_rejected_before_publish() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            string::utf8(b""), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_publishing::publishing)]
fun test_foreign_fee_manager_cannot_collect_artifact_fee() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let root_id = object::id(&root);
    ts::return_shared(registry);
    ts::return_shared(root);

    let foreign_fee_manager_id = {
        let foreign_fee_manager = governance::new_fee_manager(root_id, ts::ctx(&mut scenario));
        let id = governance::fee_manager_id(&foreign_fee_manager);
        governance::share_fee_manager(foreign_fee_manager);
        id
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let foreign_fee_manager = ts::take_shared_by_id<FeeManager>(&scenario, foreign_fee_manager_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &foreign_fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(foreign_fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 7, location = paperproof_publishing::publishing)]
fun test_same_registry_fake_type_registry_cannot_publish() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let fake_registry_id = publishing::share_test_type_registry_with_same_registry_id(&root, ts::ctx(&mut scenario));
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let fake_registry = ts::take_shared_by_id<TypeRegistry>(
            &scenario,
            fake_registry_id,
        );
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &fake_registry, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(fake_registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 8, location = paperproof_publishing::publishing)]
fun test_same_registry_fake_vault_cannot_publish() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let root_id = object::id(&root);
    ts::return_shared(registry);
    ts::return_shared(root);

    let fake_vault_id = {
        let (fake_vault, fake_permit) = governance::new_vault(root_id, ADMIN, ADMIN, ts::ctx(&mut scenario));
        let id = object::id(&fake_vault);
        governance::share_vault(fake_vault);
        transfer::public_transfer(fake_permit, ADMIN);
        id
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let fake_vault = ts::take_shared_by_id<GovernanceVault>(&scenario, fake_vault_id);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &fake_vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(fake_vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 21, location = paperproof_publishing::validation)]
fun test_overlong_publishing_field_rejected() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &vault, &fee_manager,
            repeated_string(65, 257), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), no_metadata(), no_metadata(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}


