// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module specs::publishing_spec;

#[spec_only]
use prover::prover::{asserts, ensures, implies, requires};
#[spec_only]
use prover::vector_iter::{all};

use std::string::{Self as string, String};

use paperproof_comments::comments;
use paperproof_publishing::artifact_types;
use paperproof_publishing::validation;
use paperproof_publishing::publishing;
use paperproof_governance::governance;
use paperproof_governance::governance_voting;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::sui::SUI;

#[spec_only]
fun root_publish_context_bound(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
): bool {
    publishing::root_governance_vault_id(root) == object::id(governance_vault) &&
    publishing::root_fee_manager_id(root) == governance::fee_manager_id(fee_manager) &&
    publishing::root_type_registry_id(root) == object::id(type_registry) &&
    publishing::root_comments_tree_factory_cap_registry_id(root) == object::id(root) &&
    governance::registry_id(governance_vault) == object::id(root) &&
    governance::fee_manager_registry_id(fee_manager) == object::id(root)
}

#[spec_only]
fun series_comments_tree_bound(
    series: &publishing::ArtifactSeries,
    tree: &comments::CommentsTree,
): bool {
    publishing::series_comments_tree_id(series) == comments::tree_id(tree) &&
    comments::target_series_id(tree) == object::id(series) &&
    comments::target_artifact_type(tree) == publishing::series_artifact_type(series)
}

#[spec_only]
fun series_likes_book_bound(
    series: &publishing::ArtifactSeries,
    book: &comments::LikesBook,
): bool {
    publishing::series_likes_book_id(series) == comments::likes_book_id(book) &&
    comments::likes_book_target_series_id(book) == object::id(series) &&
    comments::likes_book_target_artifact_type(book) == publishing::series_artifact_type(series)
}

#[spec_only]
fun tree_likes_book_bound(
    tree: &comments::CommentsTree,
    book: &comments::LikesBook,
): bool {
    comments::tree_likes_book_id(tree) == comments::likes_book_id(book) &&
    comments::likes_book_comments_tree_id(book) == comments::tree_id(tree) &&
    comments::likes_book_target_series_id(book) == comments::target_series_id(tree) &&
    comments::likes_book_target_artifact_type(book) == comments::target_artifact_type(tree)
}

#[spec_only]
fun series_version_head_consistent(
    series: &publishing::ArtifactSeries,
): bool {
    publishing::version_count(series) > 0 &&
    publishing::series_current_version(series) == publishing::version_count(series) &&
    publishing::series_current_version_id(series) ==
        publishing::version_id_at(series, publishing::version_count(series) - 1)
}

#[spec_only]
fun published_series_bundle_bound(
    root: &publishing::PaperProofRoot,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    artifact_type: u8,
    series: &publishing::ArtifactSeries,
    header: &publishing::CommonArtifactHeader,
    tree: &comments::CommentsTree,
    book: &comments::LikesBook,
): bool {
    publishing::series_artifact_type(series) == artifact_type &&
    publishing::series_status(series) == publishing::series_status_active() &&
    publishing::series_owner(series) == comments::owner(tree) &&
    publishing::series_owner(series) == comments::creator(tree) &&
    series_comments_tree_bound(series, tree) &&
    series_likes_book_bound(series, book) &&
    tree_likes_book_bound(tree, book) &&
    comments::registry_id(tree) == object::id(root) &&
    comments::governance_vault_id(tree) == object::id(governance_vault) &&
    comments::fee_manager_id(tree) == governance::fee_manager_id(fee_manager) &&
    publishing::header_series_id(header) == object::id(series) &&
    publishing::header_artifact_type(header) == artifact_type &&
    publishing::header_version(header) == 1 &&
    series_version_head_consistent(series)
}

#[spec_only]
fun reservation_owner_bound(
    reservation: &publishing::PreprintReservation,
    sender: address,
): bool {
    publishing::preprint_reservation_reserver(reservation) == sender
}

#[spec_only]
fun reservation_code_bound_to_series(
    reservation: &publishing::PreprintReservation,
    expected_epoch: u64,
): bool {
    publishing::preprint_reservation_artifact_code(reservation) ==
        artifact_types::code(
            artifact_types::preprint(),
            expected_epoch,
            &publishing::preprint_reservation_series_id(reservation)
        )
}

#[spec_only]
fun reserved_publish_bundle_bound(
    root: &publishing::PaperProofRoot,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    reservation: &publishing::PreprintReservation,
    series: &publishing::ArtifactSeries,
    header: &publishing::CommonArtifactHeader,
    tree: &comments::CommentsTree,
    book: &comments::LikesBook,
): bool {
    published_series_bundle_bound(
        root,
        governance_vault,
        fee_manager,
        artifact_types::preprint(),
        series,
        header,
        tree,
        book,
    ) &&
    publishing::series_artifact_code(series) == publishing::preprint_reservation_artifact_code(reservation) &&
    publishing::header_series_id(header) == publishing::preprint_reservation_series_id(reservation)
}

#[spec_only]
fun reserved_publish_bundle_bound_cached(
    root: &publishing::PaperProofRoot,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    reservation_code: String,
    reservation_series_id: ID,
    series: &publishing::ArtifactSeries,
    header: &publishing::CommonArtifactHeader,
    tree: &comments::CommentsTree,
    book: &comments::LikesBook,
): bool {
    published_series_bundle_bound(
        root,
        governance_vault,
        fee_manager,
        artifact_types::preprint(),
        series,
        header,
        tree,
        book,
    ) &&
    publishing::series_artifact_code(series) == reservation_code &&
    publishing::header_series_id(header) == reservation_series_id
}

#[spec_only]
fun series_metadata_shape_respected(
    series: &publishing::ArtifactSeries,
): bool {
    publishing::series_metadata_count(series) <= 4
}

#[spec_only]
#[ext(pure)]
fun metadata_attribute_shape(
    attribute: &publishing::MetadataAttribute,
): bool {
    string::length(publishing::metadata_attribute_key(attribute)) > 0 &&
    string::length(publishing::metadata_attribute_key(attribute)) <= 64 &&
    string::length(publishing::metadata_attribute_value(attribute)) <= 511
}

#[spec_only]
fun series_head_and_metadata_lightweight(
    series: &publishing::ArtifactSeries,
): bool {
    series_version_head_consistent(series) &&
    publishing::series_metadata_count(series) <= 4
}

#[spec_only]
fun proposal_bound_to_root_config(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
    root: &publishing::PaperProofRoot,
): bool {
    governance_voting::config_registry_id(config) == object::id(root) &&
    governance_voting::proposal_registry_id(proposal) == object::id(root) &&
    governance_voting::proposal_binding_exists(config, governance_voting::proposal_id(proposal)) &&
    governance_voting::proposal_object_id(config, governance_voting::proposal_id(proposal)) == object::id(proposal)
}

#[spec(prove, target = paperproof_publishing::artifact_types::assert_supported)]
fun assert_supported_spec(artifact_type: u8) {
    asserts(
        artifact_type == artifact_types::preprint() ||
        artifact_type == artifact_types::blog_post() ||
        artifact_type == artifact_types::technical_report() ||
        artifact_type == artifact_types::dataset() ||
        artifact_type == artifact_types::software_release() ||
        artifact_type == artifact_types::generic_file()
    );
    artifact_types::assert_supported(artifact_type)
}

#[spec(prove, target = paperproof_publishing::artifact_types::name)]
fun name_spec(artifact_type: u8): String {
    asserts(
        artifact_type == artifact_types::preprint() ||
        artifact_type == artifact_types::blog_post() ||
        artifact_type == artifact_types::technical_report() ||
        artifact_type == artifact_types::dataset() ||
        artifact_type == artifact_types::software_release() ||
        artifact_type == artifact_types::generic_file()
    );
    asserts(
        (artifact_type == artifact_types::preprint()) ||
        (artifact_type == artifact_types::blog_post()) ||
        (artifact_type == artifact_types::technical_report()) ||
        (artifact_type == artifact_types::dataset()) ||
        (artifact_type == artifact_types::software_release()) ||
        (artifact_type == artifact_types::generic_file())
    );
    let result = artifact_types::name(artifact_type);
    ensures(implies(artifact_type == artifact_types::preprint(), result == string::utf8(b"preprint")));
    ensures(implies(artifact_type == artifact_types::blog_post(), result == string::utf8(b"blog_post")));
    ensures(implies(artifact_type == artifact_types::technical_report(), result == string::utf8(b"technical_report")));
    ensures(implies(artifact_type == artifact_types::dataset(), result == string::utf8(b"dataset")));
    ensures(implies(artifact_type == artifact_types::software_release(), result == string::utf8(b"software_release")));
    ensures(implies(artifact_type == artifact_types::generic_file(), result == string::utf8(b"generic_file")));
    result
}

#[spec(prove, target = paperproof_publishing::validation::title)]
fun title_spec(title: &String) {
    asserts(string::length(title) > 0);
    asserts(string::length(title) <= 256);
    validation::title(title);
}

#[spec(prove, target = paperproof_publishing::validation::content_fields)]
fun content_fields_spec(
    content_hash: &String,
    walrus_blob_id: &String,
    walrus_blob_object_id: &String,
    content_type: &String,
) {
    asserts(string::length(content_hash) > 0);
    asserts(string::length(content_hash) <= 128);
    asserts(string::length(walrus_blob_id) > 0);
    asserts(string::length(walrus_blob_id) <= 128);
    asserts(string::length(walrus_blob_object_id) > 0);
    asserts(string::length(walrus_blob_object_id) <= 128);
    asserts(string::length(content_type) > 0);
    asserts(string::length(content_type) <= 64);
    validation::content_fields(content_hash, walrus_blob_id, walrus_blob_object_id, content_type);
}

#[spec(prove, target = paperproof_publishing::validation::authors)]
fun authors_spec(authors: &vector<String>) {
    asserts(vector::length(authors) > 0);
    asserts(vector::length(authors) <= 20);
    validation::authors(authors);
}

#[spec(prove, target = paperproof_publishing::validation::keywords)]
fun keywords_spec(keywords: &vector<String>) {
    asserts(vector::length(keywords) <= 10);
    validation::keywords(keywords);
}

#[spec(prove, target = paperproof_publishing::validation::tags)]
fun tags_spec(tags: &vector<String>) {
    asserts(vector::length(tags) <= 20);
    validation::tags(tags);
}

#[spec(prove, target = paperproof_publishing::validation::long_text)]
fun long_text_spec(text: &String) {
    asserts(string::length(text) > 0);
    asserts(string::length(text) <= 4096);
    validation::long_text(text);
}

#[spec(prove, target = paperproof_publishing::validation::medium_text)]
fun medium_text_spec(text: &String) {
    asserts(string::length(text) > 0);
    asserts(string::length(text) <= 1024);
    validation::medium_text(text);
}

#[spec(prove, target = paperproof_publishing::validation::short_text)]
fun short_text_spec(text: &String) {
    asserts(string::length(text) > 0);
    asserts(string::length(text) <= 256);
    validation::short_text(text);
}

#[spec(prove, target = paperproof_publishing::publishing::series_current_version)]
fun series_current_version_spec(series: &publishing::ArtifactSeries): u64 {
    let result = publishing::series_current_version(series);
    ensures(implies(result > 0, publishing::series_current_version_id(series) == publishing::series_current_version_id(series)));
    result
}

#[spec(prove, target = paperproof_publishing::publishing::version_count)]
fun version_count_spec(series: &publishing::ArtifactSeries): u64 {
    let result = publishing::version_count(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::version_id_at)]
fun version_id_at_spec(series: &publishing::ArtifactSeries, index: u64): ID {
    requires(index < publishing::version_count(series));
    let result = publishing::version_id_at(series, index);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_current_version_id)]
fun series_current_version_id_spec(series: &publishing::ArtifactSeries): ID {
    requires(publishing::version_count(series) > 0);
    let result = publishing::series_current_version_id(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_metadata_count)]
fun series_metadata_count_spec(series: &publishing::ArtifactSeries): u64 {
    let result = publishing::series_metadata_count(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_metadata_key_at)]
fun series_metadata_key_at_spec(series: &publishing::ArtifactSeries, index: u64): String {
    requires(index < publishing::series_metadata_count(series));
    let result = publishing::series_metadata_key_at(series, index);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_metadata_value_at)]
fun series_metadata_value_at_spec(series: &publishing::ArtifactSeries, index: u64): String {
    requires(index < publishing::series_metadata_count(series));
    let result = publishing::series_metadata_value_at(series, index);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_comments_tree_id)]
fun series_comments_tree_id_spec(series: &publishing::ArtifactSeries): ID {
    let result = publishing::series_comments_tree_id(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_likes_book_id)]
fun series_likes_book_id_spec(series: &publishing::ArtifactSeries): ID {
    let result = publishing::series_likes_book_id(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_series_id)]
fun header_series_id_spec(header: &publishing::CommonArtifactHeader): ID {
    let result = publishing::header_series_id(header);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_artifact_type)]
fun header_artifact_type_spec(header: &publishing::CommonArtifactHeader): u8 {
    let result = publishing::header_artifact_type(header);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_version)]
fun header_version_spec(header: &publishing::CommonArtifactHeader): u64 {
    let result = publishing::header_version(header);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_metadata_count)]
fun header_metadata_count_spec(header: &publishing::CommonArtifactHeader): u64 {
    let result = publishing::header_metadata_count(header);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_metadata_key_at)]
fun header_metadata_key_at_spec(header: &publishing::CommonArtifactHeader, index: u64): String {
    requires(index < publishing::header_metadata_count(header));
    let result = publishing::header_metadata_key_at(header, index);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_metadata_value_at)]
fun header_metadata_value_at_spec(header: &publishing::CommonArtifactHeader, index: u64): String {
    requires(index < publishing::header_metadata_count(header));
    let result = publishing::header_metadata_value_at(header, index);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::header_content_hash)]
fun header_content_hash_spec(header: &publishing::CommonArtifactHeader): String {
    let result = publishing::header_content_hash(header);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::preprint_reservation_artifact_code)]
fun preprint_reservation_artifact_code_spec(reservation: &publishing::PreprintReservation): String {
    let result = publishing::preprint_reservation_artifact_code(reservation);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::preprint_reservation_series_id)]
fun preprint_reservation_series_id_spec(reservation: &publishing::PreprintReservation): ID {
    let result = publishing::preprint_reservation_series_id(reservation);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::preprint_reservation_reserver)]
fun preprint_reservation_reserver_spec(reservation: &publishing::PreprintReservation): address {
    let result = publishing::preprint_reservation_reserver(reservation);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::preprint_reservation_created_at_ms)]
fun preprint_reservation_created_at_ms_spec(reservation: &publishing::PreprintReservation): u64 {
    let result = publishing::preprint_reservation_created_at_ms(reservation);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_version)]
fun root_version_spec(root: &publishing::PaperProofRoot): u64 {
    let result = publishing::root_version(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_governance_vault_id)]
fun root_governance_vault_id_spec(root: &publishing::PaperProofRoot): ID {
    let result = publishing::root_governance_vault_id(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_fee_manager_id)]
fun root_fee_manager_id_spec(root: &publishing::PaperProofRoot): ID {
    let result = publishing::root_fee_manager_id(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_type_registry_id)]
fun root_type_registry_id_spec(root: &publishing::PaperProofRoot): ID {
    let result = publishing::root_type_registry_id(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_comments_tree_factory_cap_registry_id)]
fun root_comments_tree_factory_cap_registry_id_spec(root: &publishing::PaperProofRoot): ID {
    let result = publishing::root_comments_tree_factory_cap_registry_id(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_governance_action_executor_cap_registry_id)]
fun root_governance_action_executor_cap_registry_id_spec(root: &publishing::PaperProofRoot): ID {
    let result = publishing::root_governance_action_executor_cap_registry_id(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_governance_action_executor_cap_vault_id)]
fun root_governance_action_executor_cap_vault_id_spec(root: &publishing::PaperProofRoot): ID {
    let result = publishing::root_governance_action_executor_cap_vault_id(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::root_paused)]
fun root_paused_spec(root: &publishing::PaperProofRoot): bool {
    let result = publishing::root_paused(root);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::type_registry_registry_id)]
fun type_registry_registry_id_spec(type_registry: &publishing::TypeRegistry): ID {
    let result = publishing::type_registry_registry_id(type_registry);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::type_registry_version)]
fun type_registry_version_spec(type_registry: &publishing::TypeRegistry): u64 {
    let result = publishing::type_registry_version(type_registry);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::type_entry_exists)]
fun type_entry_exists_spec(type_registry: &publishing::TypeRegistry, artifact_type: u8): bool {
    let result = publishing::type_entry_exists(type_registry, artifact_type);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::type_enabled)]
fun type_enabled_spec(type_registry: &publishing::TypeRegistry, artifact_type: u8): bool {
    requires(publishing::type_entry_exists(type_registry, artifact_type));
    let result = publishing::type_enabled(type_registry, artifact_type);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::type_enabled_or_false)]
fun type_enabled_or_false_spec(type_registry: &publishing::TypeRegistry, artifact_type: u8): bool {
    let result = publishing::type_enabled_or_false(type_registry, artifact_type);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::type_index_object_id)]
fun type_index_object_id_spec(type_registry: &publishing::TypeRegistry, artifact_type: u8): ID {
    requires(publishing::type_entry_exists(type_registry, artifact_type));
    let result = publishing::type_index_object_id(type_registry, artifact_type);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::index_artifact_type)]
fun index_artifact_type_spec(index: &publishing::TypeIndex): u8 {
    let result = publishing::index_artifact_type(index);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_preprint)]
fun artifact_type_preprint_spec(): u8 {
    let result = publishing::artifact_type_preprint();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_blog_post)]
fun artifact_type_blog_post_spec(): u8 {
    let result = publishing::artifact_type_blog_post();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_technical_report)]
fun artifact_type_technical_report_spec(): u8 {
    let result = publishing::artifact_type_technical_report();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_dataset)]
fun artifact_type_dataset_spec(): u8 {
    let result = publishing::artifact_type_dataset();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_software_release)]
fun artifact_type_software_release_spec(): u8 {
    let result = publishing::artifact_type_software_release();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_generic_file)]
fun artifact_type_generic_file_spec(): u8 {
    let result = publishing::artifact_type_generic_file();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::artifact_type_name)]
fun artifact_type_name_spec(artifact_type: u8): String {
    let result = publishing::artifact_type_name(artifact_type);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_ui_status)]
fun series_ui_status_spec(series: &publishing::ArtifactSeries): u8 {
    let result = publishing::series_ui_status(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::ui_status_normal)]
fun ui_status_normal_spec(): u8 {
    let result = publishing::ui_status_normal();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::ui_status_hidden_in_official_ui)]
fun ui_status_hidden_in_official_ui_spec(): u8 {
    let result = publishing::ui_status_hidden_in_official_ui();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::ui_status_flagged)]
fun ui_status_flagged_spec(): u8 {
    let result = publishing::ui_status_flagged();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_status_active)]
fun series_status_active_spec(): u8 {
    let result = publishing::series_status_active();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_status_locked)]
fun series_status_locked_spec(): u8 {
    let result = publishing::series_status_locked();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_status_hidden)]
fun series_status_hidden_spec(): u8 {
    let result = publishing::series_status_hidden();
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_artifact_type)]
fun series_artifact_type_spec(series: &publishing::ArtifactSeries): u8 {
    let result = publishing::series_artifact_type(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_artifact_code)]
fun series_artifact_code_spec(series: &publishing::ArtifactSeries): String {
    let result = publishing::series_artifact_code(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_owner)]
fun series_owner_spec(series: &publishing::ArtifactSeries): address {
    let result = publishing::series_owner(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::series_status)]
fun series_status_spec(series: &publishing::ArtifactSeries): u8 {
    let result = publishing::series_status(series);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::assert_valid_artifact_type)]
fun assert_valid_artifact_type_wrapper_spec(artifact_type: u8) {
    asserts(
        artifact_type == artifact_types::preprint() ||
        artifact_type == artifact_types::blog_post() ||
        artifact_type == artifact_types::technical_report() ||
        artifact_type == artifact_types::dataset() ||
        artifact_type == artifact_types::software_release() ||
        artifact_type == artifact_types::generic_file()
    );
    publishing::assert_valid_artifact_type(artifact_type)
}

#[spec(prove, target = paperproof_publishing::publishing::assert_current_root)]
fun assert_current_root_spec(root: &publishing::PaperProofRoot) {
    asserts(publishing::root_version(root) == 1);
    publishing::assert_current_root(root)
}

#[spec(prove, target = paperproof_publishing::publishing::assert_current_registry)]
fun assert_current_registry_spec(type_registry: &publishing::TypeRegistry) {
    publishing::assert_current_registry(type_registry)
}

#[spec(prove, target = paperproof_publishing::publishing::assert_current_series)]
fun assert_current_series_spec(series: &publishing::ArtifactSeries) {
    publishing::assert_current_series(series)
}

#[spec(prove, target = paperproof_publishing::publishing::metadata_attribute)]
fun metadata_attribute_spec(
    key: String,
    value: String,
): publishing::MetadataAttribute {
    asserts(string::length(&key) > 0);
    asserts(string::length(&key) <= 64);
    asserts(string::length(&value) <= 511);
    let result = publishing::metadata_attribute(key, value);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::metadata_attribute_key)]
fun metadata_attribute_key_spec(attribute: &publishing::MetadataAttribute): &String {
    let result = publishing::metadata_attribute_key(attribute);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::metadata_attribute_value)]
fun metadata_attribute_value_spec(attribute: &publishing::MetadataAttribute): &String {
    let result = publishing::metadata_attribute_value(attribute);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::preprint_header)]
fun preprint_header_spec(record: &publishing::PreprintVersionRecord): &publishing::CommonArtifactHeader {
    let result = publishing::preprint_header(record);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::blog_post_header)]
fun blog_post_header_spec(record: &publishing::BlogPostVersionRecord): &publishing::CommonArtifactHeader {
    let result = publishing::blog_post_header(record);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::technical_report_header)]
fun technical_report_header_spec(record: &publishing::TechnicalReportVersionRecord): &publishing::CommonArtifactHeader {
    let result = publishing::technical_report_header(record);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::dataset_header)]
fun dataset_header_spec(record: &publishing::DatasetVersionRecord): &publishing::CommonArtifactHeader {
    let result = publishing::dataset_header(record);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::software_release_header)]
fun software_release_header_spec(record: &publishing::SoftwareReleaseVersionRecord): &publishing::CommonArtifactHeader {
    let result = publishing::software_release_header(record);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::generic_file_header)]
fun generic_file_header_spec(record: &publishing::GenericFileVersionRecord): &publishing::CommonArtifactHeader {
    let result = publishing::generic_file_header(record);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::expected_artifact_code_for_testing)]
fun expected_artifact_code_for_testing_spec(
    artifact_type: u8,
    epoch: u64,
    series_id: ID,
): String {
    let result = publishing::expected_artifact_code_for_testing(artifact_type, epoch, series_id);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::share_test_type_registry_with_same_registry_id)]
fun share_test_type_registry_with_same_registry_id_spec(
    root: &publishing::PaperProofRoot,
    ctx: &mut TxContext,
): ID {
    let root_id = object::id(root);
    let result = publishing::share_test_type_registry_with_same_registry_id(root, ctx);
    ensures(result == result);
    ensures(object::id(root) == root_id);
    result
}

#[spec(prove, target = paperproof_publishing::publishing::init_for_testing)]
fun init_for_testing_spec(ctx: &mut TxContext) {
    publishing::init_for_testing(ctx)
}

#[spec(prove, target = paperproof_publishing::publishing::init_share_local_objects_for_testing)]
fun init_share_local_objects_for_testing_spec(
    root: publishing::PaperProofRoot,
    preprint_index: publishing::TypeIndex,
    blog_post_index: publishing::TypeIndex,
    technical_report_index: publishing::TypeIndex,
    dataset_index: publishing::TypeIndex,
    software_release_index: publishing::TypeIndex,
    generic_file_index: publishing::TypeIndex,
    type_registry: publishing::TypeRegistry,
) {
    publishing::init_share_local_objects_for_testing(
        root,
        preprint_index,
        blog_post_index,
        technical_report_index,
        dataset_index,
        software_release_index,
        generic_file_index,
        type_registry,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::init_share_governance_for_testing)]
fun init_share_governance_for_testing_spec(
    fee_manager: governance::FeeManager,
    vault: governance::GovernanceVault,
) {
    publishing::init_share_governance_for_testing(fee_manager, vault)
}

#[spec(prove, target = paperproof_publishing::publishing::init_transfer_operator_for_testing)]
fun init_transfer_operator_for_testing_spec(
    operator_permit: governance::OperatorPermit,
    sender: address,
) {
    publishing::init_transfer_operator_for_testing(operator_permit, sender)
}

#[spec(prove, target = paperproof_publishing::publishing::publish_preprint)]
fun publish_preprint_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    keywords: vector<String>,
    field: String,
    license: String,
    page_count: u64,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    publishing::publish_preprint(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        title,
        abstract_text,
        authors,
        keywords,
        field,
        license,
        page_count,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::reserve_preprint_code)]
fun reserve_preprint_code_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): publishing::PreprintReservation {
    requires(publishing::root_version(root) == 1);
    requires(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    requires(!publishing::root_paused(root));
    requires(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    let reservation = publishing::reserve_preprint_code(root, type_registry, governance_vault, fee_manager, clock_ref, ctx);
    ensures(reservation_owner_bound(&reservation, tx_context::sender(ctx)));
    ensures(
        reservation_code_bound_to_series(
            &reservation,
            tx_context::epoch(ctx),
        )
    );
    reservation
}

#[spec(prove, target = paperproof_publishing::publishing::finalize_reserved_preprint)]
fun finalize_reserved_preprint_spec(
    reservation: publishing::PreprintReservation,
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    keywords: vector<String>,
    field: String,
    license: String,
    page_count: u64,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    requires(publishing::root_version(root) == 1);
    requires(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    requires(!publishing::root_paused(root));
    requires(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    requires(string::length(&title) > 0 && string::length(&title) <= 256);
    requires(string::length(&abstract_text) > 0 && string::length(&abstract_text) <= 4096);
    requires(vector::length(&authors) > 0 && vector::length(&authors) <= 20);
    requires(vector::length(&keywords) <= 10);
    requires(string::length(&field) > 0 && string::length(&field) <= 256);
    requires(string::length(&license) > 0 && string::length(&license) <= 256);
    requires(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    requires(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    requires(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    requires(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    requires(vector::length(&series_metadata_extensions) <= 4);
    requires(vector::length(&version_metadata_extensions) <= 4);
    publishing::finalize_reserved_preprint(
        reservation,
        root,
        type_registry,
        governance_vault,
        fee_manager,
        title,
        abstract_text,
        authors,
        keywords,
        field,
        license,
        page_count,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::publish_reserved_preprint_common)]
fun publish_reserved_preprint_common_zero_fee_spec(
    reservation: publishing::PreprintReservation,
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    version_id: ID,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): (
    publishing::ArtifactSeries,
    publishing::CommonArtifactHeader,
    comments::CommentsTree,
    comments::LikesBook
) {
    requires(publishing::root_version(root) == 1);
    requires(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    requires(!publishing::root_paused(root));
    requires(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    requires(governance::artifact_fee_level(fee_manager, artifact_types::preprint()) <= 5);
    requires(governance::artifact_fee_amount(fee_manager, artifact_types::preprint()) == 0);
    requires(option::is_none(&payment));
    requires(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    requires(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    requires(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    requires(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    requires(vector::length(&series_metadata_extensions) <= 4);
    requires(vector::length(&version_metadata_extensions) <= 4);
    let reservation_owner = publishing::preprint_reservation_reserver(&reservation);
    let reservation_code = publishing::preprint_reservation_artifact_code(&reservation);
    let reservation_series_id = publishing::preprint_reservation_series_id(&reservation);
    requires(reservation_owner == tx_context::sender(ctx));
    let (series, header, tree, book) = publishing::publish_reserved_preprint_common(
        reservation,
        root,
        type_registry,
        governance_vault,
        fee_manager,
        version_id,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
    ensures(
        reserved_publish_bundle_bound_cached(
            root,
            governance_vault,
            fee_manager,
            reservation_code,
            reservation_series_id,
            &series,
            &header,
            &tree,
            &book,
        )
    );
    ensures(publishing::series_owner(&series) == reservation_owner);
    ensures(publishing::series_artifact_code(&series) == reservation_code);
    ensures(publishing::header_series_id(&header) == reservation_series_id);
    ensures(publishing::header_version(&header) == 1);
    (series, header, tree, book)
}


#[spec(prove, target = paperproof_publishing::publishing::publish_blog_post)]
fun publish_blog_post_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    summary: String,
    tags: vector<String>,
    language: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&summary) > 0 && string::length(&summary) <= 1024);
    asserts(vector::length(&tags) <= 20);
    asserts(string::length(&language) > 0 && string::length(&language) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&series_metadata_extensions) <= 4);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::publish_blog_post(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        title,
        summary,
        tags,
        language,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::publish_technical_report)]
fun publish_technical_report_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    organization: String,
    report_number: String,
    keywords: vector<String>,
    license: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&abstract_text) > 0 && string::length(&abstract_text) <= 4096);
    asserts(vector::length(&authors) > 0 && vector::length(&authors) <= 20);
    asserts(string::length(&organization) > 0 && string::length(&organization) <= 256);
    asserts(string::length(&report_number) > 0 && string::length(&report_number) <= 256);
    asserts(vector::length(&keywords) <= 10);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&series_metadata_extensions) <= 4);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::publish_technical_report(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        title,
        abstract_text,
        authors,
        organization,
        report_number,
        keywords,
        license,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::publish_dataset)]
fun publish_dataset_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    description: String,
    format: String,
    file_count: u64,
    size_bytes: u64,
    license: String,
    keywords: vector<String>,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&description) > 0 && string::length(&description) <= 4096);
    asserts(string::length(&format) > 0 && string::length(&format) <= 256);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(vector::length(&keywords) <= 10);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&series_metadata_extensions) <= 4);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::publish_dataset(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        title,
        description,
        format,
        file_count,
        size_bytes,
        license,
        keywords,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::publish_software_release)]
fun publish_software_release_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    project_name: String,
    version_name: String,
    source_hash: String,
    package_hash: String,
    changelog: String,
    license: String,
    repository_url: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(string::length(&project_name) > 0 && string::length(&project_name) <= 256);
    asserts(string::length(&version_name) > 0 && string::length(&version_name) <= 256);
    asserts(string::length(&source_hash) > 0 && string::length(&source_hash) <= 256);
    asserts(string::length(&package_hash) > 0 && string::length(&package_hash) <= 256);
    asserts(string::length(&changelog) > 0 && string::length(&changelog) <= 1024);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&repository_url) > 0 && string::length(&repository_url) <= 1024);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&series_metadata_extensions) <= 4);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::publish_software_release(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        project_name,
        version_name,
        source_hash,
        package_hash,
        changelog,
        license,
        repository_url,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::publish_generic_file)]
fun publish_generic_file_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    description: String,
    filename: String,
    file_size: u64,
    license: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<publishing::MetadataAttribute>,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&description) > 0 && string::length(&description) <= 4096);
    asserts(string::length(&filename) > 0 && string::length(&filename) <= 256);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&series_metadata_extensions) <= 4);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::publish_generic_file(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        title,
        description,
        filename,
        file_size,
        license,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        series_metadata_extensions,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    )
}

#[spec(prove, target = paperproof_publishing::publishing::add_preprint_version)]
fun add_preprint_version_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    keywords: vector<String>,
    field: String,
    license: String,
    page_count: u64,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(publishing::series_artifact_type(series) == artifact_types::preprint());
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&abstract_text) > 0 && string::length(&abstract_text) <= 4096);
    asserts(vector::length(&authors) > 0 && vector::length(&authors) <= 20);
    asserts(vector::length(&keywords) <= 10);
    asserts(string::length(&field) > 0 && string::length(&field) <= 256);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::add_preprint_version(
        root,
        type_registry,
        series,
        governance_vault,
        fee_manager,
        title,
        abstract_text,
        authors,
        keywords,
        field,
        license,
        page_count,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
}

#[spec(prove, target = paperproof_publishing::publishing::add_blog_post_version)]
fun add_blog_post_version_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    summary: String,
    tags: vector<String>,
    language: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(publishing::series_artifact_type(series) == artifact_types::blog_post());
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&summary) > 0 && string::length(&summary) <= 1024);
    asserts(vector::length(&tags) <= 20);
    asserts(string::length(&language) > 0 && string::length(&language) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::add_blog_post_version(
        root,
        type_registry,
        series,
        governance_vault,
        fee_manager,
        title,
        summary,
        tags,
        language,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
    ensures(series_version_head_consistent(series));
    ensures(publishing::series_status(series) == publishing::series_status_active());
}

#[spec(prove, target = paperproof_publishing::publishing::add_technical_report_version)]
fun add_technical_report_version_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    organization: String,
    report_number: String,
    keywords: vector<String>,
    license: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(publishing::series_artifact_type(series) == artifact_types::technical_report());
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&abstract_text) > 0 && string::length(&abstract_text) <= 4096);
    asserts(vector::length(&authors) > 0 && vector::length(&authors) <= 20);
    asserts(string::length(&organization) > 0 && string::length(&organization) <= 256);
    asserts(string::length(&report_number) > 0 && string::length(&report_number) <= 256);
    asserts(vector::length(&keywords) <= 10);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::add_technical_report_version(
        root,
        type_registry,
        series,
        governance_vault,
        fee_manager,
        title,
        abstract_text,
        authors,
        organization,
        report_number,
        keywords,
        license,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
    ensures(series_version_head_consistent(series));
    ensures(publishing::series_status(series) == publishing::series_status_active());
}

#[spec(prove, target = paperproof_publishing::publishing::add_dataset_version)]
fun add_dataset_version_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    description: String,
    format: String,
    file_count: u64,
    size_bytes: u64,
    license: String,
    keywords: vector<String>,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(publishing::series_artifact_type(series) == artifact_types::dataset());
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&description) > 0 && string::length(&description) <= 4096);
    asserts(string::length(&format) > 0 && string::length(&format) <= 256);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(vector::length(&keywords) <= 10);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::add_dataset_version(
        root,
        type_registry,
        series,
        governance_vault,
        fee_manager,
        title,
        description,
        format,
        file_count,
        size_bytes,
        license,
        keywords,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
    ensures(series_version_head_consistent(series));
    ensures(series_metadata_shape_respected(series));
}

#[spec(prove, target = paperproof_publishing::publishing::add_software_release_version)]
fun add_software_release_version_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    project_name: String,
    version_name: String,
    source_hash: String,
    package_hash: String,
    changelog: String,
    license: String,
    repository_url: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(publishing::series_artifact_type(series) == artifact_types::software_release());
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    asserts(string::length(&project_name) > 0 && string::length(&project_name) <= 256);
    asserts(string::length(&version_name) > 0 && string::length(&version_name) <= 256);
    asserts(string::length(&source_hash) > 0 && string::length(&source_hash) <= 256);
    asserts(string::length(&package_hash) > 0 && string::length(&package_hash) <= 256);
    asserts(string::length(&changelog) > 0 && string::length(&changelog) <= 1024);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&repository_url) > 0 && string::length(&repository_url) <= 1024);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::add_software_release_version(
        root,
        type_registry,
        series,
        governance_vault,
        fee_manager,
        project_name,
        version_name,
        source_hash,
        package_hash,
        changelog,
        license,
        repository_url,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
    ensures(series_version_head_consistent(series));
    ensures(series_metadata_shape_respected(series));
}

#[spec(prove, target = paperproof_publishing::publishing::add_generic_file_version)]
fun add_generic_file_version_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &publishing::TypeRegistry,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    title: String,
    description: String,
    filename: String,
    file_size: u64,
    license: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<publishing::MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(!publishing::root_paused(root));
    asserts(root_publish_context_bound(root, type_registry, governance_vault, fee_manager));
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(publishing::series_artifact_type(series) == artifact_types::generic_file());
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    asserts(string::length(&title) > 0 && string::length(&title) <= 256);
    asserts(string::length(&description) > 0 && string::length(&description) <= 4096);
    asserts(string::length(&filename) > 0 && string::length(&filename) <= 256);
    asserts(string::length(&license) > 0 && string::length(&license) <= 256);
    asserts(string::length(&content_hash) > 0 && string::length(&content_hash) <= 128);
    asserts(string::length(&walrus_blob_id) > 0 && string::length(&walrus_blob_id) <= 128);
    asserts(string::length(&walrus_blob_object_id) > 0 && string::length(&walrus_blob_object_id) <= 128);
    asserts(string::length(&content_type) > 0 && string::length(&content_type) <= 64);
    asserts(vector::length(&version_metadata_extensions) <= 4);
    publishing::add_generic_file_version(
        root,
        type_registry,
        series,
        governance_vault,
        fee_manager,
        title,
        description,
        filename,
        file_size,
        license,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        version_metadata_extensions,
        payment,
        clock_ref,
        ctx,
    );
    ensures(series_version_head_consistent(series));
    ensures(series_metadata_shape_respected(series));
}

#[spec(prove, target = paperproof_publishing::publishing::transfer_artifact_owner)]
fun transfer_artifact_owner_spec(
    series: &mut publishing::ArtifactSeries,
    comments_tree: &mut comments::CommentsTree,
    new_owner: address,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    requires(publishing::series_status(series) == publishing::series_status_active());
    requires(publishing::series_owner(series) == tx_context::sender(ctx));
    requires(comments::tree_version(comments_tree) == comments::current_tree_version());
    requires(comments::tree_id(comments_tree) == publishing::series_comments_tree_id(series));
    requires(comments::target_series_id(comments_tree) == object::id(series));
    requires(comments::target_artifact_type(comments_tree) == publishing::series_artifact_type(series));
    requires(comments::tree_owned_by(comments_tree, publishing::series_owner(series)));
    requires(new_owner != @0x0);
    publishing::transfer_artifact_owner(series, comments_tree, new_owner, clock_ref, ctx);
    ensures(publishing::series_owner(series) == new_owner);
    ensures(comments::owner(comments_tree) == new_owner);
}

#[spec(prove, target = paperproof_publishing::publishing::set_series_status)]
fun set_series_status_spec(
    root: &publishing::PaperProofRoot,
    series: &mut publishing::ArtifactSeries,
    governance_vault: &governance::GovernanceVault,
    operator_permit: &governance::OperatorPermit,
    new_status: u8,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(publishing::root_governance_vault_id(root) == object::id(governance_vault));
    requires(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    requires(governance::registry_id(governance_vault) == object::id(root));
    requires(governance::operator_permit_registry_matches(operator_permit, object::id(root)));
    requires(governance::active_operator(governance_vault) == tx_context::sender(ctx));
    requires(governance::operator_epoch(operator_permit) == governance::active_operator_epoch(governance_vault));
    requires(
        new_status == publishing::series_status_active() ||
        new_status == publishing::series_status_locked() ||
        new_status == publishing::series_status_hidden()
    );
    let owner = publishing::series_owner(series);
    let artifact_type = publishing::series_artifact_type(series);
    let artifact_code = publishing::series_artifact_code(series);
    let comments_tree_id = publishing::series_comments_tree_id(series);
    let likes_book_id = publishing::series_likes_book_id(series);
    let current_version_id = publishing::series_current_version_id(series);
    publishing::set_series_status(root, series, governance_vault, operator_permit, new_status, clock_ref, ctx);
    ensures(publishing::series_status(series) == new_status);
    ensures(publishing::series_owner(series) == owner);
    ensures(publishing::series_artifact_type(series) == artifact_type);
    ensures(publishing::series_artifact_code(series) == artifact_code);
    ensures(publishing::series_comments_tree_id(series) == comments_tree_id);
    ensures(publishing::series_likes_book_id(series) == likes_book_id);
    ensures(publishing::series_current_version_id(series) == current_version_id);
    ensures(series_head_and_metadata_lightweight(series));
}

#[spec(prove, target = paperproof_publishing::publishing::update_series_metadata_extensions)]
fun update_series_metadata_extensions_spec(
    series: &mut publishing::ArtifactSeries,
    metadata_extensions: vector<publishing::MetadataAttribute>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::series_status(series) == publishing::series_status_active());
    asserts(publishing::series_owner(series) == tx_context::sender(ctx));
    requires(vector::length(&metadata_extensions) <= 1);
    requires(all!<publishing::MetadataAttribute>(&metadata_extensions, |a| metadata_attribute_shape(a)));
    let owner = publishing::series_owner(series);
    let artifact_type = publishing::series_artifact_type(series);
    let artifact_code = publishing::series_artifact_code(series);
    let comments_tree_id = publishing::series_comments_tree_id(series);
    let likes_book_id = publishing::series_likes_book_id(series);
    let current_version_id = publishing::series_current_version_id(series);
    publishing::update_series_metadata_extensions(series, metadata_extensions, clock_ref, ctx);
    ensures(publishing::series_status(series) == publishing::series_status_active());
    ensures(publishing::series_owner(series) == owner);
    ensures(publishing::series_artifact_type(series) == artifact_type);
    ensures(publishing::series_artifact_code(series) == artifact_code);
    ensures(publishing::series_comments_tree_id(series) == comments_tree_id);
    ensures(publishing::series_likes_book_id(series) == likes_book_id);
    ensures(publishing::series_current_version_id(series) == current_version_id);
}

#[spec(prove, target = paperproof_publishing::publishing::execute_artifact_type_enabled_proposal)]
fun execute_artifact_type_enabled_proposal_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &mut publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    governance_config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(publishing::root_type_registry_id(root) == object::id(type_registry));
    asserts(publishing::root_governance_vault_id(root) == object::id(governance_vault));
    asserts(publishing::type_registry_registry_id(type_registry) == object::id(root));
    asserts(governance::registry_id(governance_vault) == object::id(root));
    asserts(governance::governance_vault_version(governance_vault) == 1);
    asserts(governance::governance_config_id(governance_vault) == object::id(governance_config));
    asserts(publishing::root_governance_action_executor_cap_registry_id(root) == object::id(root));
    asserts(publishing::root_governance_action_executor_cap_vault_id(root) == object::id(governance_vault));
    asserts(governance_voting::config_registry_id(governance_config) == object::id(root));
    asserts(governance_voting::config_version(governance_config) == governance_voting::current_config_version());
    requires(proposal_bound_to_root_config(governance_config, proposal, root));
    asserts(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    asserts(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    asserts(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    asserts(governance_voting::proposal_end_epoch(proposal) <= 18446744073709551612);
    asserts(tx_context::epoch(ctx) <= governance_voting::execution_expiry_epoch(proposal));
    asserts(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_blog_post() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_technical_report() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_dataset() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_software_release() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_generic_file() as u64
    );
    asserts(governance_voting::proposal_payload_u64_2(proposal) == 0 || governance_voting::proposal_payload_u64_2(proposal) == 1);
    asserts(publishing::type_entry_exists(type_registry, governance_voting::proposal_payload_u64_1(proposal) as u8));
    asserts(governance_voting::action_type(proposal) == governance_voting::action_set_artifact_type_enabled());
    asserts(!governance_voting::proposal_executed(proposal));
    publishing::execute_artifact_type_enabled_proposal(
        root,
        type_registry,
        governance_vault,
        governance_config,
        proposal,
        clock_ref,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_preprint()) == (governance_voting::proposal_payload_u64_2(proposal) == 1)
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_blog_post() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_blog_post()) == (governance_voting::proposal_payload_u64_2(proposal) == 1)
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_technical_report() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_technical_report()) == (governance_voting::proposal_payload_u64_2(proposal) == 1)
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_dataset() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_dataset()) == (governance_voting::proposal_payload_u64_2(proposal) == 1)
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_software_release() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_software_release()) == (governance_voting::proposal_payload_u64_2(proposal) == 1)
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_generic_file() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_generic_file()) == (governance_voting::proposal_payload_u64_2(proposal) == 1)
    ));
    ensures(publishing::root_type_registry_id(root) == object::id(type_registry));
    ensures(governance_voting::config_registry_id(governance_config) == object::id(root));
}

#[spec(prove, target = paperproof_publishing::publishing::execute_comments_fee_level_proposal)]
fun execute_comments_fee_level_proposal_spec(
    root: &publishing::PaperProofRoot,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &mut governance::FeeManager,
    governance_config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(publishing::root_governance_vault_id(root) == object::id(governance_vault));
    asserts(publishing::root_fee_manager_id(root) == governance::fee_manager_id(fee_manager));
    asserts(governance::registry_id(governance_vault) == object::id(root));
    asserts(governance::governance_vault_version(governance_vault) == 1);
    asserts(governance::governance_config_id(governance_vault) == object::id(governance_config));
    asserts(publishing::root_governance_action_executor_cap_registry_id(root) == object::id(root));
    asserts(publishing::root_governance_action_executor_cap_vault_id(root) == object::id(governance_vault));
    asserts(governance::fee_manager_registry_id(fee_manager) == object::id(root));
    asserts(governance_voting::config_registry_id(governance_config) == object::id(root));
    asserts(governance_voting::config_version(governance_config) == governance_voting::current_config_version());
    requires(proposal_bound_to_root_config(governance_config, proposal, root));
    asserts(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    asserts(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    asserts(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    asserts(governance_voting::proposal_end_epoch(proposal) <= 18446744073709551612);
    asserts(tx_context::epoch(ctx) <= governance_voting::execution_expiry_epoch(proposal));
    asserts(governance_voting::proposal_payload_u64_1(proposal) <= 5);
    asserts(governance_voting::action_type(proposal) == governance_voting::action_set_comments_fee_level());
    asserts(!governance_voting::proposal_executed(proposal));
    publishing::execute_comments_fee_level_proposal(
        root,
        governance_vault,
        fee_manager,
        governance_config,
        proposal,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(implies(governance_voting::proposal_payload_u64_1(proposal) == 0, governance::comments_fee_level(fee_manager) == 0));
    ensures(implies(governance_voting::proposal_payload_u64_1(proposal) == 1, governance::comments_fee_level(fee_manager) == 1));
    ensures(implies(governance_voting::proposal_payload_u64_1(proposal) == 2, governance::comments_fee_level(fee_manager) == 2));
    ensures(implies(governance_voting::proposal_payload_u64_1(proposal) == 3, governance::comments_fee_level(fee_manager) == 3));
    ensures(implies(governance_voting::proposal_payload_u64_1(proposal) == 4, governance::comments_fee_level(fee_manager) == 4));
    ensures(implies(governance_voting::proposal_payload_u64_1(proposal) == 5, governance::comments_fee_level(fee_manager) == 5));
    ensures(governance::registry_id(governance_vault) == object::id(root));
    ensures(governance::fee_manager_registry_id(fee_manager) == object::id(root));
}

#[spec(prove, target = paperproof_publishing::publishing::set_paused)]
fun set_paused_spec(
    root: &mut publishing::PaperProofRoot,
    governance_vault: &governance::GovernanceVault,
    operator_permit: &governance::OperatorPermit,
    paused: bool,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    requires(publishing::root_version(root) == 1);
    requires(publishing::root_governance_vault_id(root) == object::id(governance_vault));
    requires(governance::registry_id(governance_vault) == object::id(root));
    requires(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    requires(governance::operator_permit_registry_matches(operator_permit, object::id(root)));
    requires(governance::active_operator(governance_vault) == tx_context::sender(ctx));
    requires(governance::operator_epoch(operator_permit) == governance::active_operator_epoch(governance_vault));
    let root_id = object::id(root);
    let governance_vault_id = publishing::root_governance_vault_id(root);
    let fee_manager_id = publishing::root_fee_manager_id(root);
    let type_registry_id = publishing::root_type_registry_id(root);
    let comments_tree_factory_cap_registry_id = publishing::root_comments_tree_factory_cap_registry_id(root);
    let action_executor_cap_registry_id = publishing::root_governance_action_executor_cap_registry_id(root);
    let action_executor_cap_vault_id = publishing::root_governance_action_executor_cap_vault_id(root);
    publishing::set_paused(root, governance_vault, operator_permit, paused, clock_ref, ctx);
    ensures(publishing::root_paused(root) == paused);
    ensures(object::id(root) == root_id);
    ensures(publishing::root_governance_vault_id(root) == governance_vault_id);
    ensures(publishing::root_fee_manager_id(root) == fee_manager_id);
    ensures(publishing::root_type_registry_id(root) == type_registry_id);
    ensures(publishing::root_comments_tree_factory_cap_registry_id(root) == comments_tree_factory_cap_registry_id);
    ensures(publishing::root_governance_action_executor_cap_registry_id(root) == action_executor_cap_registry_id);
    ensures(publishing::root_governance_action_executor_cap_vault_id(root) == action_executor_cap_vault_id);
}

#[spec(prove, target = paperproof_publishing::publishing::execute_artifact_fee_level_proposal)]
fun execute_artifact_fee_level_proposal_spec(
    root: &publishing::PaperProofRoot,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &mut governance::FeeManager,
    governance_config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(publishing::root_governance_vault_id(root) == object::id(governance_vault));
    asserts(publishing::root_fee_manager_id(root) == governance::fee_manager_id(fee_manager));
    asserts(governance::registry_id(governance_vault) == object::id(root));
    asserts(governance::governance_vault_version(governance_vault) == 1);
    asserts(governance::governance_config_id(governance_vault) == object::id(governance_config));
    asserts(publishing::root_governance_action_executor_cap_registry_id(root) == object::id(root));
    asserts(publishing::root_governance_action_executor_cap_vault_id(root) == object::id(governance_vault));
    asserts(governance::fee_manager_registry_id(fee_manager) == object::id(root));
    asserts(governance_voting::config_registry_id(governance_config) == object::id(root));
    asserts(governance_voting::config_version(governance_config) == governance_voting::current_config_version());
    requires(proposal_bound_to_root_config(governance_config, proposal, root));
    asserts(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    asserts(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    asserts(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    asserts(governance_voting::proposal_end_epoch(proposal) <= 18446744073709551612);
    asserts(tx_context::epoch(ctx) <= governance_voting::execution_expiry_epoch(proposal));
    asserts(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_blog_post() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_technical_report() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_dataset() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_software_release() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_generic_file() as u64
    );
    asserts(governance_voting::proposal_payload_u64_2(proposal) <= 5);
    asserts(governance_voting::action_type(proposal) == governance_voting::action_set_artifact_fee_level());
    asserts(!governance_voting::proposal_executed(proposal));
    publishing::execute_artifact_fee_level_proposal(
        root,
        governance_vault,
        fee_manager,
        governance_config,
        proposal,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 0,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 0
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 1,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 1
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 2,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 2
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 3,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 3
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 4,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 4
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 5,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 5
    ));
    ensures(governance::registry_id(governance_vault) == object::id(root));
    ensures(governance::fee_manager_registry_id(fee_manager) == object::id(root));
}

#[spec(prove, target = paperproof_publishing::publishing::execute_artifact_type_activation_proposal)]
fun execute_artifact_type_activation_proposal_spec(
    root: &publishing::PaperProofRoot,
    type_registry: &mut publishing::TypeRegistry,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &mut governance::FeeManager,
    governance_config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    asserts(publishing::root_version(root) == 1);
    asserts(publishing::root_type_registry_id(root) == object::id(type_registry));
    asserts(publishing::root_governance_vault_id(root) == object::id(governance_vault));
    asserts(publishing::root_fee_manager_id(root) == governance::fee_manager_id(fee_manager));
    asserts(publishing::type_registry_registry_id(type_registry) == object::id(root));
    asserts(governance::registry_id(governance_vault) == object::id(root));
    asserts(governance::governance_vault_version(governance_vault) == 1);
    asserts(governance::governance_config_id(governance_vault) == object::id(governance_config));
    asserts(publishing::root_governance_action_executor_cap_registry_id(root) == object::id(root));
    asserts(publishing::root_governance_action_executor_cap_vault_id(root) == object::id(governance_vault));
    asserts(governance::fee_manager_registry_id(fee_manager) == object::id(root));
    asserts(governance_voting::config_registry_id(governance_config) == object::id(root));
    asserts(governance_voting::config_version(governance_config) == governance_voting::current_config_version());
    requires(proposal_bound_to_root_config(governance_config, proposal, root));
    asserts(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    asserts(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    asserts(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    asserts(governance_voting::proposal_end_epoch(proposal) <= 18446744073709551612);
    asserts(tx_context::epoch(ctx) <= governance_voting::execution_expiry_epoch(proposal));
    asserts(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_blog_post() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_technical_report() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_dataset() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_software_release() as u64 ||
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_generic_file() as u64
    );
    asserts(governance_voting::proposal_payload_u64_2(proposal) <= 5);
    asserts(publishing::type_entry_exists(type_registry, governance_voting::proposal_payload_u64_1(proposal) as u8));
    asserts(governance_voting::action_type(proposal) == governance_voting::action_activate_artifact_type());
    asserts(!governance_voting::proposal_executed(proposal));
    publishing::execute_artifact_type_activation_proposal(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        governance_config,
        proposal,
        clock_ref,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_preprint())
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_blog_post() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_blog_post())
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_technical_report() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_technical_report())
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_dataset() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_dataset())
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_software_release() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_software_release())
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_generic_file() as u64,
        publishing::type_enabled_or_false(type_registry, publishing::artifact_type_generic_file())
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 0,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 0
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 1,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 1
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 2,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 2
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 3,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 3
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 4,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 4
    ));
    ensures(implies(
        governance_voting::proposal_payload_u64_1(proposal) == publishing::artifact_type_preprint() as u64 && governance_voting::proposal_payload_u64_2(proposal) == 5,
        governance::artifact_fee_level(fee_manager, publishing::artifact_type_preprint()) == 5
    ));
    ensures(publishing::root_type_registry_id(root) == object::id(type_registry));
    ensures(governance::registry_id(governance_vault) == object::id(root));
    ensures(governance::fee_manager_registry_id(fee_manager) == object::id(root));
}
