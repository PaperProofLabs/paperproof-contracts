#[test_only]
module paperproof_publishing::publishing_tests;

use std::string;

use paperproof_comments::comments::{Self as comments, CommentsTree};
use paperproof_governance::governance::{Self as governance, FeeManager, GovernanceVault, OperatorPermit};
use paperproof_governance::governance_voting::{Self as voting, GovernanceConfig, Proposal};
use paperproof_publishing::publishing::{
    Self as publishing,
    ArtifactSeries,
    BlogPostVersionRecord,
    DatasetVersionRecord,
    GenericFileVersionRecord,
    PaperProofRoot,
    PreprintVersionRecord,
    SoftwareReleaseVersionRecord,
    TechnicalReportVersionRecord,
    TypeIndex,
    TypeRegistry,
};
use pprf::pprf::PPRF;
use sui::clock;
use sui::coin::{Self as coin, Coin};
use sui::sui::SUI;
use sui::test_scenario as ts;

const ADMIN: address = @0xA;
const USER1: address = @0xB;
const USER2: address = @0xC;
const PROPOSER_THRESHOLD: u64 = 10_000_000_000_000_000;
const QUORUM_PASS_VOTES: u64 = 1_500_000_000_000_000_000;

fun common_hash(): string::String { string::utf8(b"sha256:test") }
fun common_blob(): string::String { string::utf8(b"walrus_blob") }
fun common_blob_object(): string::String { string::utf8(b"walrus_blob_object") }
fun common_content_type(): string::String { string::utf8(b"application/octet-stream") }

fun mint_votes(amount: u64, scenario: &mut ts::Scenario): Coin<PPRF> {
    coin::mint_for_testing<PPRF>(amount, ts::ctx(scenario))
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

#[test]
fun test_publish_all_builtin_artifact_types() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let preprint_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_preprint());
    let blog_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_blog_post());
    let report_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_technical_report());
    let dataset_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_dataset());
    let release_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_software_release());
    let file_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, preprint_index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::publish_preprint(
            &root,
            &registry,
            &mut index,
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
            option::none(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );

        assert!(publishing::index_next_number(&index) == 2, 1);
        let series_id = publishing::get_series_id_by_code(&index, string::utf8(b"PaperProof-preprint-1"));

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);

        ts::next_tx(&mut scenario, USER1);
        let series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
        let tree = ts::take_shared_by_id<CommentsTree>(&scenario, publishing::series_comments_tree_id(&series));
        let record = ts::take_shared<PreprintVersionRecord>(&scenario);
        assert!(publishing::series_current_version(&series) == 1, 2);
        assert!(comments::target_series_id(&tree) == object::id(&series), 3);
        assert!(comments::target_artifact_type(&tree) == publishing::artifact_type_preprint(), 4);
        assert!(publishing::header_artifact_type(publishing::preprint_header(&record)) == publishing::artifact_type_preprint(), 5);
        ts::return_shared(series);
        ts::return_shared(tree);
        ts::return_shared(record);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut blog_index = ts::take_shared_by_id<TypeIndex>(&scenario, blog_index_id);
        let mut report_index = ts::take_shared_by_id<TypeIndex>(&scenario, report_index_id);
        let mut dataset_index = ts::take_shared_by_id<TypeIndex>(&scenario, dataset_index_id);
        let mut release_index = ts::take_shared_by_id<TypeIndex>(&scenario, release_index_id);
        let mut file_index = ts::take_shared_by_id<TypeIndex>(&scenario, file_index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));

        publishing::publish_blog_post(
            &root, &registry, &mut blog_index, &vault, &fee_manager,
            string::utf8(b"Blog title"), string::utf8(b"Blog summary"), vector[string::utf8(b"tag")], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_technical_report(
            &root, &registry, &mut report_index, &vault, &fee_manager,
            string::utf8(b"Report title"), string::utf8(b"Report abstract"), vector[string::utf8(b"Alice")],
            string::utf8(b"PaperProof Labs"), string::utf8(b"TR-1"), vector[string::utf8(b"protocol")], string::utf8(b"CC-BY"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"application/pdf"), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_dataset(
            &root, &registry, &mut dataset_index, &vault, &fee_manager,
            string::utf8(b"Dataset title"), string::utf8(b"Dataset description"), string::utf8(b"csv"), 2, 1000, string::utf8(b"CC0"), vector[string::utf8(b"data")],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_software_release(
            &root, &registry, &mut release_index, &vault, &fee_manager,
            string::utf8(b"Project"), string::utf8(b"v1.0.0"), string::utf8(b"source_hash"), string::utf8(b"package_hash"),
            string::utf8(b"Initial release"), string::utf8(b"MIT"), string::utf8(b"https://example.com/repo"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"application/zip"), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        publishing::publish_generic_file(
            &root, &registry, &mut file_index, &vault, &fee_manager,
            string::utf8(b"File title"), string::utf8(b"File description"), string::utf8(b"archive.zip"), 1000, string::utf8(b"CC-BY"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );

        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(blog_index);
        ts::return_shared(report_index);
        ts::return_shared(dataset_index);
        ts::return_shared(release_index);
        ts::return_shared(file_index);
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
fun test_add_version_and_transfer_owner_keep_comments_tree() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
    };

    ts::next_tx(&mut scenario, USER1);
    let index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
    let series_id = publishing::get_series_id_by_code(&index, string::utf8(b"PaperProof-generic_file-1"));
    ts::return_shared(index);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let original_tree_id = publishing::series_comments_tree_id(&series);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        assert!(publishing::series_current_version(&series) == 2, 20);
        assert!(publishing::version_count(&series) == 2, 21);
        assert!(publishing::series_comments_tree_id(&series) == original_tree_id, 22);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
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
#[expected_failure(abort_code = 23, location = paperproof_publishing::publishing)]
fun test_transfer_owner_requires_official_comments_tree() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
    };

    ts::next_tx(&mut scenario, USER1);
    let index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
    let series_id = publishing::get_series_id_by_code(&index, string::utf8(b"PaperProof-generic_file-1"));
    ts::return_shared(index);

    ts::next_tx(&mut scenario, USER1);
    {
        let mut series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        let mut fake_tree = comments::new_tree(
            object::id_from_address(@0xFA),
            USER1,
            publishing::series_artifact_code(&series),
            series_id,
            publishing::artifact_type_generic_file(),
            &clock_ref,
            ts::ctx(&mut scenario),
        );
        publishing::transfer_artifact_owner(&mut series, &mut fake_tree, USER2, &clock_ref, ts::ctx(&mut scenario));
        comments::share_tree(fake_tree);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(series);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
    };

    ts::next_tx(&mut scenario, USER1);
    let index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
    let series_id = publishing::get_series_id_by_code(&index, string::utf8(b"PaperProof-generic_file-1"));
    ts::return_shared(index);

    ts::next_tx(&mut scenario, ADMIN);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let permit = ts::take_from_sender<OperatorPermit>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::set_series_status(
            &root, &mut series, &vault, &permit, 1, &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        transfer::public_transfer(permit, ADMIN);
        ts::return_shared(root);
        ts::return_shared(series);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &mut series, &vault, &fee_manager,
            string::utf8(b"File v2"), string::utf8(b"Description v2"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_blog_post());
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
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_blog_post(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"Blog"), string::utf8(b"Summary"), vector[], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_dataset());
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
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let payment = coin::mint_for_testing<SUI>(10_000, ts::ctx(&mut scenario));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_dataset(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"Paid dataset"), string::utf8(b"Description"), string::utf8(b"csv"), 1, 100, string::utf8(b"CC0"), vector[],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::some(payment), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_blog_post());
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
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let payment = coin::mint_for_testing<SUI>(10_000, ts::ctx(&mut scenario));
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_blog_post(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"Reenabled blog"), string::utf8(b"Summary"), vector[], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), option::some(payment), &clock_ref, ts::ctx(&mut scenario),
        );
        assert!(publishing::index_next_number(&index) == 2, 42);
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
    };

    ts::next_tx(&mut scenario, USER1);
    let index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
    let series_id = publishing::get_series_id_by_code(&index, string::utf8(b"PaperProof-generic_file-1"));
    ts::return_shared(index);

    ts::next_tx(&mut scenario, USER2);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let mut series = ts::take_shared_by_id<ArtifactSeries>(&scenario, series_id);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::add_generic_file_version(
            &root, &mut series, &vault, &fee_manager,
            string::utf8(b"Bad v2"), string::utf8(b"Description"), string::utf8(b"file-v2.zip"), 200, string::utf8(b"MIT"),
            string::utf8(b"sha256:v2"), string::utf8(b"blob_v2"), string::utf8(b"blob_object_v2"), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(series);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 7, location = paperproof_publishing::publishing)]
fun test_wrong_type_index_rejects_publish() {
    let mut scenario = ts::begin(ADMIN);
    publishing::init_for_testing(ts::ctx(&mut scenario));

    ts::next_tx(&mut scenario, ADMIN);
    let root = ts::take_shared<PaperProofRoot>(&scenario);
    let registry = ts::take_shared<TypeRegistry>(&scenario);
    let preprint_index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_preprint());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut wrong_index = ts::take_shared_by_id<TypeIndex>(&scenario, preprint_index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_blog_post(
            &root, &registry, &mut wrong_index, &vault, &fee_manager,
            string::utf8(b"Wrong index"), string::utf8(b"Summary"), vector[], string::utf8(b"en"),
            common_hash(), common_blob(), common_blob_object(), string::utf8(b"text/markdown"), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(wrong_index);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_dataset());
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
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_dataset(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b"Unpaid dataset"), string::utf8(b"Description"), string::utf8(b"csv"), 1, 100, string::utf8(b"CC0"), vector[],
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    ts::next_tx(&mut scenario, USER1);
    {
        let root = ts::take_shared<PaperProofRoot>(&scenario);
        let registry = ts::take_shared<TypeRegistry>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &mut index, &vault, &fee_manager,
            string::utf8(b""), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_shared(index);
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
    let index_id = publishing::type_index_object_id(&registry, publishing::artifact_type_generic_file());
    ts::return_shared(registry);
    ts::return_shared(root);

    let foreign_fee_manager_id = {
        let foreign_fee_manager = governance::new_fee_manager(object::id_from_address(@0x999), ts::ctx(&mut scenario));
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
        let mut index = ts::take_shared_by_id<TypeIndex>(&scenario, index_id);
        let clock_ref = clock::create_for_testing(ts::ctx(&mut scenario));
        publishing::publish_generic_file(
            &root, &registry, &mut index, &vault, &foreign_fee_manager,
            string::utf8(b"File"), string::utf8(b"Description"), string::utf8(b"file.zip"), 100, string::utf8(b"MIT"),
            common_hash(), common_blob(), common_blob_object(), common_content_type(), option::none(), &clock_ref, ts::ctx(&mut scenario),
        );
        clock::destroy_for_testing(clock_ref);
        ts::return_shared(root);
        ts::return_shared(registry);
        ts::return_shared(vault);
        ts::return_shared(foreign_fee_manager);
        ts::return_shared(index);
    };

    ts::end(scenario);
}
