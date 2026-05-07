// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_publishing::publishing;

use std::string::{Self as string, String};

use paperproof_publishing::artifact_types;
use paperproof_publishing::validation;
use paperproof_comments::comments::{Self as comments, CommentsTree, LikesBook, TreeFactoryCap};
use paperproof_governance::governance::{
    Self as governance,
    FeeManager,
    GovernanceActionExecutorCap,
    GovernanceVault,
    OperatorPermit,
};
use paperproof_governance::governance_voting::{Self as voting, GovernanceConfig, Proposal};

use sui::clock::{Self as clock, Clock};
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;
use sui::table::{Self as table, Table};

const E_PAUSED: u64 = 1;
const E_UNSUPPORTED_ROOT_VERSION: u64 = 2;
const E_UNSUPPORTED_REGISTRY_VERSION: u64 = 3;
const E_UNSUPPORTED_SERIES_VERSION: u64 = 4;
const E_INVALID_ARTIFACT_TYPE: u64 = 5;
const E_ARTIFACT_TYPE_DISABLED: u64 = 6;
const E_INVALID_INDEX: u64 = 7;
const E_INVALID_GOVERNANCE_VAULT: u64 = 8;
const E_INVALID_FEE_MANAGER: u64 = 9;
const E_NOT_OWNER: u64 = 21;
const E_INVALID_STATUS: u64 = 22;
const E_INVALID_COMMENTS_TREE: u64 = 23;
const E_INVALID_GOVERNANCE_ACTION: u64 = 24;
const E_TOO_MANY_VERSIONS: u64 = 25;
const E_TOO_MANY_METADATA_ATTRIBUTES: u64 = 26;
const E_EMPTY_METADATA_KEY: u64 = 27;
const E_METADATA_TEXT_TOO_LONG: u64 = 28;
const E_DUPLICATE_METADATA_KEY: u64 = 29;

const PAPERPROOF_ROOT_VERSION: u64 = 1;
const TYPE_REGISTRY_VERSION: u64 = 1;
const TYPE_INDEX_VERSION: u64 = 1;
const ARTIFACT_SERIES_VERSION: u64 = 1;
const MAX_VERSIONS_PER_SERIES: u64 = 168;
const MAX_METADATA_ATTRIBUTES: u64 = 4;
const MAX_METADATA_KEY_BYTES: u64 = 64;
const MAX_METADATA_VALUE_BYTES: u64 = 511;

const SERIES_STATUS_ACTIVE: u8 = 0;
const SERIES_STATUS_LOCKED: u8 = 1;
const SERIES_STATUS_HIDDEN: u8 = 2;

const UI_NORMAL: u8 = 0;
const UI_FLAGGED: u8 = 1;
const UI_HIDDEN_IN_OFFICIAL_UI: u8 = 2;

const VERSION_STATUS_VALID: u8 = 0;

public struct PaperProofRoot has key {
    id: UID,
    version: u64,
    paused: bool,
    governance_vault_id: ID,
    fee_manager_id: ID,
    type_registry_id: ID,
    comments_tree_factory_cap: TreeFactoryCap,
    governance_action_executor_cap: GovernanceActionExecutorCap,
}

public struct TypeInfo has store {
    artifact_type: u8,
    index_object_id: ID,
    enabled: bool,
    schema_version: u64,
    min_protocol_version: u64,
    created_at_ms: u64,
    updated_at_ms: u64,
}

public struct TypeRegistry has key {
    id: UID,
    version: u64,
    registry_id: ID,
    types: Table<u8, TypeInfo>,
}

public struct TypeIndex has key {
    id: UID,
    version: u64,
    registry_id: ID,
    artifact_type: u8,
}

public struct MetadataAttribute has copy, drop, store {
    key: String,
    value: String,
}

public struct ArtifactSeries has key {
    id: UID,
    version: u64,
    artifact_type: u8,
    artifact_code: String,
    owner: address,
    current_version: u64,
    current_version_id: ID,
    version_ids: vector<ID>,
    metadata_extensions: vector<MetadataAttribute>,
    comments_tree_id: ID,
    likes_book_id: ID,
    status: u8,
    ui_status: u8,
    created_at_ms: u64,
    updated_at_ms: u64,
}

public struct CommonArtifactHeader has store {
    series_id: ID,
    artifact_type: u8,
    version: u64,
    previous_version_id: Option<ID>,
    author: address,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    metadata_extensions: vector<MetadataAttribute>,
    status: u8,
    created_at_ms: u64,
}

public struct PreprintVersionRecord has key {
    id: UID,
    header: CommonArtifactHeader,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    keywords: vector<String>,
    field: String,
    license: String,
    page_count: u64,
}

public struct BlogPostVersionRecord has key {
    id: UID,
    header: CommonArtifactHeader,
    title: String,
    summary: String,
    tags: vector<String>,
    language: String,
}

public struct TechnicalReportVersionRecord has key {
    id: UID,
    header: CommonArtifactHeader,
    title: String,
    abstract_text: String,
    authors: vector<String>,
    organization: String,
    report_number: String,
    keywords: vector<String>,
    license: String,
}

public struct DatasetVersionRecord has key {
    id: UID,
    header: CommonArtifactHeader,
    title: String,
    description: String,
    format: String,
    file_count: u64,
    size_bytes: u64,
    license: String,
    keywords: vector<String>,
}

public struct SoftwareReleaseVersionRecord has key {
    id: UID,
    header: CommonArtifactHeader,
    project_name: String,
    version_name: String,
    source_hash: String,
    package_hash: String,
    changelog: String,
    license: String,
    repository_url: String,
}

public struct GenericFileVersionRecord has key {
    id: UID,
    header: CommonArtifactHeader,
    title: String,
    description: String,
    filename: String,
    file_size: u64,
    license: String,
}

public struct ArtifactPublishedEvent has copy, drop {
    series_id: ID,
    version_id: ID,
    artifact_type: u8,
    artifact_code: String,
    author: address,
    content_hash: String,
    walrus_blob_id: String,
    content_type: String,
    version: u64,
    comments_tree_id: ID,
    likes_book_id: ID,
    created_at_ms: u64,
}

public struct ArtifactVersionAddedEvent has copy, drop {
    series_id: ID,
    old_version_id: ID,
    new_version_id: ID,
    artifact_type: u8,
    artifact_code: String,
    author: address,
    content_hash: String,
    walrus_blob_id: String,
    content_type: String,
    version: u64,
    created_at_ms: u64,
}

public struct ArtifactStatusChangedEvent has copy, drop {
    series_id: ID,
    artifact_type: u8,
    changed_by: address,
    old_status: u8,
    new_status: u8,
    changed_at_ms: u64,
}

public struct ArtifactSeriesMetadataUpdatedEvent has copy, drop {
    series_id: ID,
    artifact_type: u8,
    updated_by: address,
    metadata_count: u64,
    updated_at_ms: u64,
}

public struct ArtifactTypeStatusChangedEvent has copy, drop {
    registry_id: ID,
    artifact_type: u8,
    changed_by: address,
    old_enabled: bool,
    enabled: bool,
    changed_at_ms: u64,
}

public struct ProtocolPausedChangedEvent has copy, drop {
    root_id: ID,
    changed_by: address,
    old_paused: bool,
    new_paused: bool,
    changed_at_ms: u64,
}

public struct PaperProofRootCreatedEvent has copy, drop {
    root_id: ID,
    created_by: address,
    governance_vault_id: ID,
    fee_manager_id: ID,
    type_registry_id: ID,
    comments_tree_factory_cap_registry_id: ID,
    governance_action_executor_cap_registry_id: ID,
}

public struct TypeRegistryCreatedEvent has copy, drop {
    root_id: ID,
    type_registry_id: ID,
    created_by: address,
}

public struct TypeIndexCreatedEvent has copy, drop {
    root_id: ID,
    artifact_type: u8,
    type_index_id: ID,
    created_by: address,
}

fun init(ctx: &mut TxContext) {
    let root_uid = object::new(ctx);
    let root_id = *root_uid.as_inner();
    let sender = tx_context::sender(ctx);
    let now = 0;

    let preprint_index = new_index(root_id, artifact_types::preprint(), ctx);
    let blog_post_index = new_index(root_id, artifact_types::blog_post(), ctx);
    let technical_report_index = new_index(root_id, artifact_types::technical_report(), ctx);
    let dataset_index = new_index(root_id, artifact_types::dataset(), ctx);
    let software_release_index = new_index(root_id, artifact_types::software_release(), ctx);
    let generic_file_index = new_index(root_id, artifact_types::generic_file(), ctx);

    let preprint_index_id = object::id(&preprint_index);
    let blog_post_index_id = object::id(&blog_post_index);
    let technical_report_index_id = object::id(&technical_report_index);
    let dataset_index_id = object::id(&dataset_index);
    let software_release_index_id = object::id(&software_release_index);
    let generic_file_index_id = object::id(&generic_file_index);

    let mut type_registry = TypeRegistry {
        id: object::new(ctx),
        version: TYPE_REGISTRY_VERSION,
        registry_id: root_id,
        types: table::new(ctx),
    };
    add_type_info(&mut type_registry, artifact_types::preprint(), preprint_index_id, now);
    add_type_info(&mut type_registry, artifact_types::blog_post(), blog_post_index_id, now);
    add_type_info(&mut type_registry, artifact_types::technical_report(), technical_report_index_id, now);
    add_type_info(&mut type_registry, artifact_types::dataset(), dataset_index_id, now);
    add_type_info(&mut type_registry, artifact_types::software_release(), software_release_index_id, now);
    add_type_info(&mut type_registry, artifact_types::generic_file(), generic_file_index_id, now);

    let fee_manager = governance::new_fee_manager(root_id, ctx);
    let (vault, operator_permit, governance_action_executor_cap) =
        governance::new_vault_with_action_executor_cap(root_id, sender, sender, ctx);

    let comments_tree_factory_cap = comments::new_tree_factory_cap(&vault, &fee_manager, ctx);

    let root = PaperProofRoot {
        id: root_uid,
        version: PAPERPROOF_ROOT_VERSION,
        paused: false,
        governance_vault_id: object::id(&vault),
        fee_manager_id: governance::fee_manager_id(&fee_manager),
        type_registry_id: object::id(&type_registry),
        comments_tree_factory_cap,
        governance_action_executor_cap,
    };
    let governance_vault_id = root.governance_vault_id;
    let fee_manager_id = root.fee_manager_id;
    let type_registry_id = root.type_registry_id;
    let comments_tree_factory_cap_registry_id = comments::tree_factory_cap_registry_id(&root.comments_tree_factory_cap);

    event::emit(PaperProofRootCreatedEvent {
        root_id,
        created_by: sender,
        governance_vault_id,
        fee_manager_id,
        type_registry_id,
        comments_tree_factory_cap_registry_id,
        governance_action_executor_cap_registry_id: root_id,
    });
    event::emit(TypeRegistryCreatedEvent { root_id, type_registry_id, created_by: sender });
    event::emit(TypeIndexCreatedEvent { root_id, artifact_type: artifact_types::preprint(), type_index_id: preprint_index_id, created_by: sender });
    event::emit(TypeIndexCreatedEvent { root_id, artifact_type: artifact_types::blog_post(), type_index_id: blog_post_index_id, created_by: sender });
    event::emit(TypeIndexCreatedEvent { root_id, artifact_type: artifact_types::technical_report(), type_index_id: technical_report_index_id, created_by: sender });
    event::emit(TypeIndexCreatedEvent { root_id, artifact_type: artifact_types::dataset(), type_index_id: dataset_index_id, created_by: sender });
    event::emit(TypeIndexCreatedEvent { root_id, artifact_type: artifact_types::software_release(), type_index_id: software_release_index_id, created_by: sender });
    event::emit(TypeIndexCreatedEvent { root_id, artifact_type: artifact_types::generic_file(), type_index_id: generic_file_index_id, created_by: sender });

    transfer::share_object(root);
    transfer::share_object(preprint_index);
    transfer::share_object(blog_post_index);
    transfer::share_object(technical_report_index);
    transfer::share_object(dataset_index);
    transfer::share_object(software_release_index);
    transfer::share_object(generic_file_index);
    transfer::share_object(type_registry);
    governance::share_fee_manager(fee_manager);
    governance::share_vault(vault);
    transfer::public_transfer(operator_permit, sender);
}

public fun publish_preprint(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&abstract_text);
    validate_authors(&authors);
    validate_keywords(&keywords);
    validate_short_text(&field);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let (series, header, comments_tree, likes_book) = publish_common(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        artifact_types::preprint(),
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
    let record = PreprintVersionRecord {
        id: version_uid,
        header,
        title,
        abstract_text,
        authors,
        keywords,
        field,
        license,
        page_count,
    };
    transfer::share_object(series);
    comments::share_tree(comments_tree);
    comments::share_likes_book(likes_book);
    transfer::share_object(record);
}

public fun publish_blog_post(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    title: String,
    summary: String,
    tags: vector<String>,
    language: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_medium_text(&summary);
    validate_tags(&tags);
    validate_short_text(&language);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let (series, header, comments_tree, likes_book) = publish_common(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        artifact_types::blog_post(),
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
    let record = BlogPostVersionRecord { id: version_uid, header, title, summary, tags, language };
    transfer::share_object(series);
    comments::share_tree(comments_tree);
    comments::share_likes_book(likes_book);
    transfer::share_object(record);
}

public fun publish_technical_report(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&abstract_text);
    validate_authors(&authors);
    validate_keywords(&keywords);
    validate_short_text(&organization);
    validate_short_text(&report_number);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let (series, header, comments_tree, likes_book) = publish_common(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        artifact_types::technical_report(),
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
    let record = TechnicalReportVersionRecord {
        id: version_uid,
        header,
        title,
        abstract_text,
        authors,
        organization,
        report_number,
        keywords,
        license,
    };
    transfer::share_object(series);
    comments::share_tree(comments_tree);
    comments::share_likes_book(likes_book);
    transfer::share_object(record);
}

public fun publish_dataset(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&description);
    validate_keywords(&keywords);
    validate_short_text(&format);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let (series, header, comments_tree, likes_book) = publish_common(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        artifact_types::dataset(),
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
    let record = DatasetVersionRecord {
        id: version_uid,
        header,
        title,
        description,
        format,
        file_count,
        size_bytes,
        license,
        keywords,
    };
    transfer::share_object(series);
    comments::share_tree(comments_tree);
    comments::share_likes_book(likes_book);
    transfer::share_object(record);
}

public fun publish_software_release(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&project_name);
    validate_short_text(&version_name);
    validate_short_text(&source_hash);
    validate_short_text(&package_hash);
    validate_medium_text(&changelog);
    validate_short_text(&license);
    validate_medium_text(&repository_url);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let (series, header, comments_tree, likes_book) = publish_common(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        artifact_types::software_release(),
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
    let record = SoftwareReleaseVersionRecord {
        id: version_uid,
        header,
        project_name,
        version_name,
        source_hash,
        package_hash,
        changelog,
        license,
        repository_url,
    };
    transfer::share_object(series);
    comments::share_tree(comments_tree);
    comments::share_likes_book(likes_book);
    transfer::share_object(record);
}

public fun publish_generic_file(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    title: String,
    description: String,
    filename: String,
    file_size: u64,
    license: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&description);
    validate_short_text(&filename);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let (series, header, comments_tree, likes_book) = publish_common(
        root,
        type_registry,
        governance_vault,
        fee_manager,
        artifact_types::generic_file(),
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
    let record = GenericFileVersionRecord {
        id: version_uid,
        header,
        title,
        description,
        filename,
        file_size,
        license,
    };
    transfer::share_object(series);
    comments::share_tree(comments_tree);
    comments::share_likes_book(likes_book);
    transfer::share_object(record);
}

public fun add_preprint_version(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&abstract_text);
    validate_authors(&authors);
    validate_keywords(&keywords);
    validate_short_text(&field);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let header = add_version_common(
        root, type_registry, series, governance_vault, fee_manager, artifact_types::preprint(),
        version_id,
        content_hash, walrus_blob_id, walrus_blob_object_id, content_type, version_metadata_extensions, payment, clock_ref, ctx,
    );
    transfer::share_object(PreprintVersionRecord {
        id: version_uid,
        header,
        title,
        abstract_text,
        authors,
        keywords,
        field,
        license,
        page_count,
    });
}

public fun add_blog_post_version(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    title: String,
    summary: String,
    tags: vector<String>,
    language: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_medium_text(&summary);
    validate_tags(&tags);
    validate_short_text(&language);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let header = add_version_common(
        root, type_registry, series, governance_vault, fee_manager, artifact_types::blog_post(),
        version_id,
        content_hash, walrus_blob_id, walrus_blob_object_id, content_type, version_metadata_extensions, payment, clock_ref, ctx,
    );
    transfer::share_object(BlogPostVersionRecord { id: version_uid, header, title, summary, tags, language });
}

public fun add_technical_report_version(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&abstract_text);
    validate_authors(&authors);
    validate_keywords(&keywords);
    validate_short_text(&organization);
    validate_short_text(&report_number);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let header = add_version_common(
        root, type_registry, series, governance_vault, fee_manager, artifact_types::technical_report(),
        version_id,
        content_hash, walrus_blob_id, walrus_blob_object_id, content_type, version_metadata_extensions, payment, clock_ref, ctx,
    );
    transfer::share_object(TechnicalReportVersionRecord {
        id: version_uid,
        header,
        title,
        abstract_text,
        authors,
        organization,
        report_number,
        keywords,
        license,
    });
}

public fun add_dataset_version(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&description);
    validate_keywords(&keywords);
    validate_short_text(&format);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let header = add_version_common(
        root, type_registry, series, governance_vault, fee_manager, artifact_types::dataset(),
        version_id,
        content_hash, walrus_blob_id, walrus_blob_object_id, content_type, version_metadata_extensions, payment, clock_ref, ctx,
    );
    transfer::share_object(DatasetVersionRecord {
        id: version_uid,
        header,
        title,
        description,
        format,
        file_count,
        size_bytes,
        license,
        keywords,
    });
}

public fun add_software_release_version(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
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
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&project_name);
    validate_short_text(&version_name);
    validate_short_text(&source_hash);
    validate_short_text(&package_hash);
    validate_medium_text(&changelog);
    validate_short_text(&license);
    validate_medium_text(&repository_url);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let header = add_version_common(
        root, type_registry, series, governance_vault, fee_manager, artifact_types::software_release(),
        version_id,
        content_hash, walrus_blob_id, walrus_blob_object_id, content_type, version_metadata_extensions, payment, clock_ref, ctx,
    );
    transfer::share_object(SoftwareReleaseVersionRecord {
        id: version_uid,
        header,
        project_name,
        version_name,
        source_hash,
        package_hash,
        changelog,
        license,
        repository_url,
    });
}

public fun add_generic_file_version(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    title: String,
    description: String,
    filename: String,
    file_size: u64,
    license: String,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    validate_title(&title);
    validate_long_text(&description);
    validate_short_text(&filename);
    validate_short_text(&license);
    let version_uid = object::new(ctx);
    let version_id = *version_uid.as_inner();
    let header = add_version_common(
        root, type_registry, series, governance_vault, fee_manager, artifact_types::generic_file(),
        version_id,
        content_hash, walrus_blob_id, walrus_blob_object_id, content_type, version_metadata_extensions, payment, clock_ref, ctx,
    );
    transfer::share_object(GenericFileVersionRecord {
        id: version_uid,
        header,
        title,
        description,
        filename,
        file_size,
        license,
    });
}

public fun transfer_artifact_owner(
    series: &mut ArtifactSeries,
    comments_tree: &mut CommentsTree,
    new_owner: address,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_series(series);
    assert!(tx_context::sender(ctx) == series.owner, E_NOT_OWNER);
    assert!(comments::tree_id(comments_tree) == series.comments_tree_id, E_INVALID_COMMENTS_TREE);
    assert!(comments::target_series_id(comments_tree) == object::id(series), E_INVALID_COMMENTS_TREE);
    assert!(comments::target_artifact_type(comments_tree) == series.artifact_type, E_INVALID_COMMENTS_TREE);
    assert!(comments::owner(comments_tree) == series.owner, E_INVALID_COMMENTS_TREE);
    comments::transfer_tree_owner(comments_tree, new_owner, ctx);
    series.owner = new_owner;
    series.updated_at_ms = clock::timestamp_ms(clock_ref);
}

public fun set_paused(
    root: &mut PaperProofRoot,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    paused: bool,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_root(root);
    assert_admin(root, governance_vault, operator_permit, tx_context::sender(ctx));
    let old_paused = root.paused;
    root.paused = paused;
    event::emit(ProtocolPausedChangedEvent {
        root_id: object::id(root),
        changed_by: tx_context::sender(ctx),
        old_paused,
        new_paused: paused,
        changed_at_ms: clock::timestamp_ms(clock_ref),
    });
}

public fun execute_artifact_type_enabled_proposal(
    root: &PaperProofRoot,
    type_registry: &mut TypeRegistry,
    governance_vault: &GovernanceVault,
    governance_config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_root(root);
    assert_current_registry(type_registry);
    assert!(type_registry.registry_id == object::id(root), E_INVALID_INDEX);
    assert!(root.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE_VAULT);

    let ticket = voting::consume_executable_proposal_action(
        governance_config,
        proposal,
        governance_vault,
        &root.governance_action_executor_cap,
        object::id(root),
        voting::action_set_artifact_type_enabled(),
        ctx,
    );
    let (ticket_registry_id, artifact_type_payload, enabled_payload, _) =
        governance::unpack_artifact_type_enabled_ticket(ticket);
    assert!(ticket_registry_id == object::id(root), E_INVALID_GOVERNANCE_ACTION);
    let artifact_type = artifact_type_payload as u8;
    assert!(enabled_payload == 0 || enabled_payload == 1, E_INVALID_GOVERNANCE_ACTION);
    apply_artifact_type_enabled(type_registry, artifact_type, enabled_payload == 1, tx_context::sender(ctx), clock_ref);
}

public fun execute_comments_fee_level_proposal(
    root: &PaperProofRoot,
    governance_vault: &GovernanceVault,
    fee_manager: &mut FeeManager,
    governance_config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    ctx: &mut TxContext,
) {
    assert_current_root(root);
    assert!(root.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE_VAULT);
    assert!(root.fee_manager_id == governance::fee_manager_id(fee_manager), E_INVALID_FEE_MANAGER);

    voting::execute_comments_fee_level_proposal(
        governance_config,
        proposal,
        governance_vault,
        &root.governance_action_executor_cap,
        fee_manager,
        ctx,
    );
}

public fun execute_artifact_fee_level_proposal(
    root: &PaperProofRoot,
    governance_vault: &GovernanceVault,
    fee_manager: &mut FeeManager,
    governance_config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    ctx: &mut TxContext,
) {
    assert_current_root(root);
    assert!(root.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE_VAULT);
    assert!(root.fee_manager_id == governance::fee_manager_id(fee_manager), E_INVALID_FEE_MANAGER);

    let ticket = voting::consume_executable_proposal_action(
        governance_config,
        proposal,
        governance_vault,
        &root.governance_action_executor_cap,
        object::id(root),
        voting::action_set_artifact_fee_level(),
        ctx,
    );
    assert_valid_artifact_type(governance::action_ticket_payload_u64_1(&ticket) as u8);
    governance::apply_artifact_fee_level_from_ticket(governance_vault, fee_manager, ticket);
}

public fun execute_artifact_type_activation_proposal(
    root: &PaperProofRoot,
    type_registry: &mut TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &mut FeeManager,
    governance_config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_root(root);
    assert_current_registry(type_registry);
    assert!(type_registry.registry_id == object::id(root), E_INVALID_INDEX);
    assert!(root.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE_VAULT);
    assert!(root.fee_manager_id == governance::fee_manager_id(fee_manager), E_INVALID_FEE_MANAGER);

    let ticket = voting::consume_executable_proposal_action(
        governance_config,
        proposal,
        governance_vault,
        &root.governance_action_executor_cap,
        object::id(root),
        voting::action_activate_artifact_type(),
        ctx,
    );
    let artifact_type = governance::action_ticket_payload_u64_1(&ticket) as u8;
    apply_artifact_type_enabled(type_registry, artifact_type, true, tx_context::sender(ctx), clock_ref);
    governance::apply_artifact_fee_level_from_ticket(governance_vault, fee_manager, ticket);
}

public fun set_series_status(
    root: &PaperProofRoot,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    new_status: u8,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_root(root);
    assert_current_series(series);
    assert_admin(root, governance_vault, operator_permit, tx_context::sender(ctx));
    assert_valid_series_status(new_status);
    let old_status = series.status;
    series.status = new_status;
    series.updated_at_ms = clock::timestamp_ms(clock_ref);
    event::emit(ArtifactStatusChangedEvent {
        series_id: object::id(series),
        artifact_type: series.artifact_type,
        changed_by: tx_context::sender(ctx),
        old_status,
        new_status,
        changed_at_ms: series.updated_at_ms,
    });
}

public fun update_series_metadata_extensions(
    series: &mut ArtifactSeries,
    metadata_extensions: vector<MetadataAttribute>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_series(series);
    assert!(tx_context::sender(ctx) == series.owner, E_NOT_OWNER);
    assert!(series.status == SERIES_STATUS_ACTIVE, E_INVALID_STATUS);
    validate_metadata_extensions(&metadata_extensions);
    series.metadata_extensions = metadata_extensions;
    series.updated_at_ms = clock::timestamp_ms(clock_ref);
    event::emit(ArtifactSeriesMetadataUpdatedEvent {
        series_id: object::id(series),
        artifact_type: series.artifact_type,
        updated_by: tx_context::sender(ctx),
        metadata_count: vector::length(&series.metadata_extensions),
        updated_at_ms: series.updated_at_ms,
    });
}

public fun root_version(root: &PaperProofRoot): u64 { root.version }
public fun root_paused(root: &PaperProofRoot): bool { root.paused }
public fun root_governance_vault_id(root: &PaperProofRoot): ID { root.governance_vault_id }
public fun root_fee_manager_id(root: &PaperProofRoot): ID { root.fee_manager_id }
public fun root_type_registry_id(root: &PaperProofRoot): ID { root.type_registry_id }
public fun root_comments_tree_factory_cap_registry_id(root: &PaperProofRoot): ID {
    comments::tree_factory_cap_registry_id(&root.comments_tree_factory_cap)
}

public fun artifact_type_preprint(): u8 { artifact_types::preprint() }
public fun artifact_type_blog_post(): u8 { artifact_types::blog_post() }
public fun artifact_type_technical_report(): u8 { artifact_types::technical_report() }
public fun artifact_type_dataset(): u8 { artifact_types::dataset() }
public fun artifact_type_software_release(): u8 { artifact_types::software_release() }
public fun artifact_type_generic_file(): u8 { artifact_types::generic_file() }
public fun ui_status_normal(): u8 { UI_NORMAL }
public fun ui_status_flagged(): u8 { UI_FLAGGED }
public fun ui_status_hidden_in_official_ui(): u8 { UI_HIDDEN_IN_OFFICIAL_UI }
public fun series_status_active(): u8 { SERIES_STATUS_ACTIVE }
public fun series_status_locked(): u8 { SERIES_STATUS_LOCKED }
public fun series_status_hidden(): u8 { SERIES_STATUS_HIDDEN }

public fun artifact_type_name(artifact_type: u8): String {
    artifact_types::name(artifact_type)
}

public fun type_enabled(type_registry: &TypeRegistry, artifact_type: u8): bool {
    table::borrow(&type_registry.types, artifact_type).enabled
}

public fun type_index_object_id(type_registry: &TypeRegistry, artifact_type: u8): ID {
    table::borrow(&type_registry.types, artifact_type).index_object_id
}

public fun index_artifact_type(index: &TypeIndex): u8 { index.artifact_type }
public fun series_artifact_type(series: &ArtifactSeries): u8 { series.artifact_type }
public fun series_artifact_code(series: &ArtifactSeries): String { series.artifact_code }
public fun series_owner(series: &ArtifactSeries): address { series.owner }
public fun series_current_version(series: &ArtifactSeries): u64 { series.current_version }
public fun series_current_version_id(series: &ArtifactSeries): ID { series.current_version_id }
public fun series_comments_tree_id(series: &ArtifactSeries): ID { series.comments_tree_id }
public fun series_likes_book_id(series: &ArtifactSeries): ID { series.likes_book_id }
public fun series_status(series: &ArtifactSeries): u8 { series.status }
public fun series_ui_status(series: &ArtifactSeries): u8 { series.ui_status }
public fun series_metadata_count(series: &ArtifactSeries): u64 { vector::length(&series.metadata_extensions) }
public fun series_metadata_key_at(series: &ArtifactSeries, index: u64): String { vector::borrow(&series.metadata_extensions, index).key }
public fun series_metadata_value_at(series: &ArtifactSeries, index: u64): String { vector::borrow(&series.metadata_extensions, index).value }
public fun version_count(series: &ArtifactSeries): u64 { vector::length(&series.version_ids) }
public fun version_id_at(series: &ArtifactSeries, index: u64): ID { *vector::borrow(&series.version_ids, index) }
public fun header_series_id(header: &CommonArtifactHeader): ID { header.series_id }
public fun header_artifact_type(header: &CommonArtifactHeader): u8 { header.artifact_type }
public fun header_version(header: &CommonArtifactHeader): u64 { header.version }
public fun header_content_hash(header: &CommonArtifactHeader): String { header.content_hash }
public fun header_metadata_count(header: &CommonArtifactHeader): u64 { vector::length(&header.metadata_extensions) }
public fun header_metadata_key_at(header: &CommonArtifactHeader, index: u64): String { vector::borrow(&header.metadata_extensions, index).key }
public fun header_metadata_value_at(header: &CommonArtifactHeader, index: u64): String { vector::borrow(&header.metadata_extensions, index).value }

public fun metadata_attribute(key: String, value: String): MetadataAttribute {
    let attribute = MetadataAttribute { key, value };
    validate_metadata_attribute(&attribute);
    attribute
}

public fun preprint_header(record: &PreprintVersionRecord): &CommonArtifactHeader { &record.header }
public fun blog_post_header(record: &BlogPostVersionRecord): &CommonArtifactHeader { &record.header }
public fun technical_report_header(record: &TechnicalReportVersionRecord): &CommonArtifactHeader { &record.header }
public fun dataset_header(record: &DatasetVersionRecord): &CommonArtifactHeader { &record.header }
public fun software_release_header(record: &SoftwareReleaseVersionRecord): &CommonArtifactHeader { &record.header }
public fun generic_file_header(record: &GenericFileVersionRecord): &CommonArtifactHeader { &record.header }

fun publish_common(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    artifact_type: u8,
    version_id: ID,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    series_metadata_extensions: vector<MetadataAttribute>,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): (ArtifactSeries, CommonArtifactHeader, CommentsTree, LikesBook) {
    assert_publish_context(root, type_registry, governance_vault, fee_manager, artifact_type);
    validate_content_fields(&content_hash, &walrus_blob_id, &walrus_blob_object_id, &content_type);
    validate_metadata_extensions(&series_metadata_extensions);
    validate_metadata_extensions(&version_metadata_extensions);
    governance::collect_artifact_fee(governance_vault, fee_manager, artifact_type, payment, ctx);

    let now = clock::timestamp_ms(clock_ref);
    let sender = tx_context::sender(ctx);
    let series_uid = object::new(ctx);
    let series_id = *series_uid.as_inner();
    let artifact_code = make_artifact_code(artifact_type, tx_context::epoch(ctx), &series_id);

    let (comments_tree, likes_book) = comments::new_tree(
        &root.comments_tree_factory_cap,
        object::id(root),
        root.governance_vault_id,
        root.fee_manager_id,
        sender,
        artifact_code,
        series_id,
        artifact_type,
        clock_ref,
        ctx,
    );
    let comments_tree_id = comments::tree_id(&comments_tree);
    let likes_book_id = comments::likes_book_id(&likes_book);

    let mut version_ids = vector::empty<ID>();
    vector::push_back(&mut version_ids, version_id);
    let series = ArtifactSeries {
        id: series_uid,
        version: ARTIFACT_SERIES_VERSION,
        artifact_type,
        artifact_code,
        owner: sender,
        current_version: 1,
        current_version_id: version_id,
        version_ids,
        metadata_extensions: series_metadata_extensions,
        comments_tree_id,
        likes_book_id,
        status: SERIES_STATUS_ACTIVE,
        ui_status: UI_NORMAL,
        created_at_ms: now,
        updated_at_ms: now,
    };

    let header = CommonArtifactHeader {
        series_id,
        artifact_type,
        version: 1,
        previous_version_id: option::none(),
        author: sender,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        metadata_extensions: version_metadata_extensions,
        status: VERSION_STATUS_VALID,
        created_at_ms: now,
    };

    event::emit(ArtifactPublishedEvent {
        series_id,
        version_id,
        artifact_type,
        artifact_code,
        author: sender,
        content_hash: header.content_hash,
        walrus_blob_id: header.walrus_blob_id,
        content_type: header.content_type,
        version: 1,
        comments_tree_id,
        likes_book_id,
        created_at_ms: now,
    });

    (series, header, comments_tree, likes_book)
}

fun add_version_common(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    series: &mut ArtifactSeries,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    artifact_type: u8,
    version_id: ID,
    content_hash: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    content_type: String,
    version_metadata_extensions: vector<MetadataAttribute>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): CommonArtifactHeader {
    assert_current_root(root);
    assert_current_registry(type_registry);
    assert_current_series(series);
    assert!(!root.paused, E_PAUSED);
    assert!(type_registry.registry_id == object::id(root), E_INVALID_INDEX);
    let type_info = table::borrow(&type_registry.types, artifact_type);
    assert!(type_info.enabled, E_ARTIFACT_TYPE_DISABLED);
    assert!(series.artifact_type == artifact_type, E_INVALID_ARTIFACT_TYPE);
    assert!(series.status == SERIES_STATUS_ACTIVE, E_INVALID_STATUS);
    assert!(vector::length(&series.version_ids) < MAX_VERSIONS_PER_SERIES, E_TOO_MANY_VERSIONS);
    assert!(tx_context::sender(ctx) == series.owner, E_NOT_OWNER);
    assert!(governance::registry_id(governance_vault) == object::id(root), E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_registry_id(fee_manager) == object::id(root), E_INVALID_FEE_MANAGER);
    assert!(object::id(governance_vault) == root.governance_vault_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_id(fee_manager) == root.fee_manager_id, E_INVALID_FEE_MANAGER);
    validate_content_fields(&content_hash, &walrus_blob_id, &walrus_blob_object_id, &content_type);
    validate_metadata_extensions(&version_metadata_extensions);
    governance::collect_artifact_fee(governance_vault, fee_manager, artifact_type, payment, ctx);

    let now = clock::timestamp_ms(clock_ref);
    let sender = tx_context::sender(ctx);
    let old_version_id = series.current_version_id;
    let new_version = series.current_version + 1;
    series.current_version = new_version;
    series.current_version_id = version_id;
    vector::push_back(&mut series.version_ids, version_id);
    series.updated_at_ms = now;

    let header = CommonArtifactHeader {
        series_id: object::id(series),
        artifact_type,
        version: new_version,
        previous_version_id: option::some(old_version_id),
        author: sender,
        content_hash,
        walrus_blob_id,
        walrus_blob_object_id,
        content_type,
        metadata_extensions: version_metadata_extensions,
        status: VERSION_STATUS_VALID,
        created_at_ms: now,
    };

    event::emit(ArtifactVersionAddedEvent {
        series_id: object::id(series),
        old_version_id,
        new_version_id: version_id,
        artifact_type,
        artifact_code: series.artifact_code,
        author: sender,
        content_hash: header.content_hash,
        walrus_blob_id: header.walrus_blob_id,
        content_type: header.content_type,
        version: new_version,
        created_at_ms: now,
    });

    header
}

fun assert_publish_context(
    root: &PaperProofRoot,
    type_registry: &TypeRegistry,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    artifact_type: u8,
) {
    assert_current_root(root);
    assert_current_registry(type_registry);
    assert!(!root.paused, E_PAUSED);
    assert_valid_artifact_type(artifact_type);
    assert!(type_registry.registry_id == object::id(root), E_INVALID_INDEX);
    let info = table::borrow(&type_registry.types, artifact_type);
    assert!(info.enabled, E_ARTIFACT_TYPE_DISABLED);
    assert!(governance::registry_id(governance_vault) == object::id(root), E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_registry_id(fee_manager) == object::id(root), E_INVALID_FEE_MANAGER);
    assert!(object::id(governance_vault) == root.governance_vault_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_id(fee_manager) == root.fee_manager_id, E_INVALID_FEE_MANAGER);
    assert!(comments::tree_factory_cap_registry_id(&root.comments_tree_factory_cap) == object::id(root), E_INVALID_COMMENTS_TREE);
}

fun assert_admin(
    root: &PaperProofRoot,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    sender: address,
) {
    assert!(root.governance_vault_id == object::id(governance_vault), E_INVALID_GOVERNANCE_VAULT);
    governance::assert_active_operator(governance_vault, operator_permit, object::id(root), sender);
}

fun assert_current_root(root: &PaperProofRoot) {
    assert!(root.version == PAPERPROOF_ROOT_VERSION, E_UNSUPPORTED_ROOT_VERSION);
}

fun assert_current_registry(type_registry: &TypeRegistry) {
    assert!(type_registry.version == TYPE_REGISTRY_VERSION, E_UNSUPPORTED_REGISTRY_VERSION);
}

fun assert_current_series(series: &ArtifactSeries) {
    assert!(series.version == ARTIFACT_SERIES_VERSION, E_UNSUPPORTED_SERIES_VERSION);
}

fun assert_valid_artifact_type(artifact_type: u8) {
    artifact_types::assert_supported(artifact_type)
}

fun assert_valid_series_status(status: u8) {
    assert!(
        status == SERIES_STATUS_ACTIVE ||
        status == SERIES_STATUS_LOCKED ||
        status == SERIES_STATUS_HIDDEN,
        E_INVALID_STATUS,
    );
}

fun new_index(
    registry_id: ID,
    artifact_type: u8,
    ctx: &mut TxContext,
): TypeIndex {
    TypeIndex {
        id: object::new(ctx),
        version: TYPE_INDEX_VERSION,
        registry_id,
        artifact_type,
    }
}

fun add_type_info(
    type_registry: &mut TypeRegistry,
    artifact_type: u8,
    index_object_id: ID,
    now: u64,
) {
    table::add(
        &mut type_registry.types,
        artifact_type,
        TypeInfo {
            artifact_type,
            index_object_id,
            enabled: true,
            schema_version: 1,
            min_protocol_version: PAPERPROOF_ROOT_VERSION,
            created_at_ms: now,
            updated_at_ms: now,
        },
    );
}

fun apply_artifact_type_enabled(
    type_registry: &mut TypeRegistry,
    artifact_type: u8,
    enabled: bool,
    changed_by: address,
    clock_ref: &Clock,
) {
    assert_valid_artifact_type(artifact_type);
    let info = table::borrow_mut(&mut type_registry.types, artifact_type);
    let old_enabled = info.enabled;
    info.enabled = enabled;
    info.updated_at_ms = clock::timestamp_ms(clock_ref);
    event::emit(ArtifactTypeStatusChangedEvent {
        registry_id: type_registry.registry_id,
        artifact_type,
        changed_by,
        old_enabled,
        enabled,
        changed_at_ms: info.updated_at_ms,
    });
}

fun validate_content_fields(
    content_hash: &String,
    walrus_blob_id: &String,
    walrus_blob_object_id: &String,
    content_type: &String,
) {
    validation::content_fields(content_hash, walrus_blob_id, walrus_blob_object_id, content_type)
}

fun validate_title(title: &String) {
    validation::title(title)
}

fun validate_long_text(text: &String) {
    validation::long_text(text)
}

fun validate_medium_text(text: &String) {
    validation::medium_text(text)
}

fun validate_short_text(text: &String) {
    validation::short_text(text)
}

fun validate_authors(authors: &vector<String>) {
    validation::authors(authors)
}

fun validate_keywords(keywords: &vector<String>) {
    validation::keywords(keywords)
}

fun validate_tags(tags: &vector<String>) {
    validation::tags(tags)
}

fun validate_metadata_extensions(metadata_extensions: &vector<MetadataAttribute>) {
    let len = vector::length(metadata_extensions);
    assert!(len <= MAX_METADATA_ATTRIBUTES, E_TOO_MANY_METADATA_ATTRIBUTES);

    let mut i = 0;
    while (i < len) {
        let attribute = vector::borrow(metadata_extensions, i);
        validate_metadata_attribute(attribute);

        let mut j = i + 1;
        while (j < len) {
            assert!(
                attribute.key != vector::borrow(metadata_extensions, j).key,
                E_DUPLICATE_METADATA_KEY,
            );
            j = j + 1;
        };
        i = i + 1;
    };
}

fun validate_metadata_attribute(attribute: &MetadataAttribute) {
    assert!(string::length(&attribute.key) > 0, E_EMPTY_METADATA_KEY);
    assert!(string::length(&attribute.key) <= MAX_METADATA_KEY_BYTES, E_METADATA_TEXT_TOO_LONG);
    assert!(string::length(&attribute.value) < MAX_METADATA_VALUE_BYTES + 1, E_METADATA_TEXT_TOO_LONG);
}

fun make_artifact_code(artifact_type: u8, epoch: u64, series_id: &ID): String {
    artifact_types::code(artifact_type, epoch, series_id)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun expected_artifact_code_for_testing(artifact_type: u8, epoch: u64, series_id: ID): String {
    artifact_types::code(artifact_type, epoch, &series_id)
}
