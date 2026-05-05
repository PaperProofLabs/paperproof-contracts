// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available
// Use of this source code is governed by the LICENSE file in the project root.
// Public readability and auditability do not grant rights to copy, modify,
// distribute, redeploy, or commercialize this code except as expressly permitted.

module paperproof_publishing::publishing;

use std::string::{Self as string, String};

use paperproof_comments::comments::{Self as comments, CommentsTree};
use paperproof_governance::governance::{
    Self as governance,
    GovernanceVault,
    OperatorPermit,
};

use sui::clock::{Self as clock, Clock};
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;
use sui::table::{Self as table, Table};

/* ============================================================
   PaperProof Publishing Registry

   Design:
   1. reserve_code():
      - Generates OriginPaper-{sui_epoch}-{epoch_seq}
      - Creates a PaperRecord in RESERVED state
      - No expiry, no cancellation, no reuse

   2. finalize_paper():
      - Only reserver can finalize
      - Binds metadata + Walrus blob info + PDF hash
      - Creates and binds one CommentsTree for the paper
      - Changes state from RESERVED to PUBLISHED

   3. add_version():
      - Only owner can add a new PDF version
      - Old versions are never deleted or overwritten

   4. record_storage_extension():
      - Anyone can update storage_end_epoch upward
      - Intended for shared Walrus blobs that anyone can extend

   5. admin capability custody:
      - Admin authority is held inside governance::GovernanceVault
      - Routine execution is performed by the holder of a current OperatorPermit
      - Operator nomination/accept/cancel is handled by the governance package
   ============================================================ */

const E_PAUSED: u64 = 2;
const E_EMPTY_TITLE: u64 = 3;
const E_EMPTY_ABSTRACT: u64 = 4;
const E_TOO_MANY_KEYWORDS: u64 = 5;
const E_TOO_MANY_AUTHORS: u64 = 6;
const E_NO_AUTHOR: u64 = 7;
const E_FILE_TOO_LARGE: u64 = 8;
const E_PAGE_COUNT_TOO_SMALL: u64 = 9;
const E_PAGE_COUNT_TOO_LARGE: u64 = 10;
const E_EMPTY_BLOB_ID: u64 = 11;
const E_EMPTY_BLOB_OBJECT_ID: u64 = 12;
const E_EMPTY_FILE_HASH: u64 = 13;
const E_NOT_RESERVER: u64 = 14;
const E_NOT_OWNER: u64 = 15;
const E_ALREADY_PUBLISHED: u64 = 16;
const E_NOT_PUBLISHED: u64 = 17;
const E_STORAGE_NOT_EXTENDED: u64 = 18;
const E_INVALID_NEW_OWNER: u64 = 19;
const E_INVALID_STATUS: u64 = 20;
const E_EPOCH_REGRESSION: u64 = 21;
const E_WALRUS_EXTENSION_NOT_IMPLEMENTED: u64 = 22;
const E_INVALID_GOVERNANCE_VAULT: u64 = 23;
const E_INVALID_COMMENTS_TREE: u64 = 24;

const STATUS_RESERVED: u8 = 0;
const STATUS_PUBLISHED: u8 = 1;

const UI_NORMAL: u8 = 0;
const UI_FLAGGED: u8 = 1;
const UI_HIDDEN_IN_OFFICIAL_UI: u8 = 2;

public struct PaperRegistry has key {
    id: UID,
    current_epoch: u64,
    epoch_counter: u64,
    next_record_number: u64,
    code_prefix: String,
    max_file_size: u64,
    min_page_count: u64,
    max_page_count: u64,
    max_keywords: u64,
    max_authors: u64,
    paused: bool,
    code_to_record: Table<String, ID>,
}

public struct PaperRecord has key {
    id: UID,
    paper_code: String,
    paper_epoch: u64,
    epoch_seq: u64,
    record_number: u64,
    reserver: address,
    owner: address,
    status: u8,
    ui_status: u8,
    title: String,
    abstract_text: String,
    keywords: vector<String>,
    authors: vector<String>,
    field: String,
    license: String,
    current_version: u64,
    version_ids: vector<ID>,
    comments_tree_id: option::Option<ID>,
    reserved_at_ms: u64,
    published_at_ms: u64,
    updated_at_ms: u64,
}

public struct PaperVersion has key {
    id: UID,
    paper_record_id: ID,
    paper_code: String,
    version_number: u64,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    file_hash: String,
    file_size: u64,
    page_count: u64,
    storage_end_epoch: u64,
    is_shared_blob: bool,
    title_snapshot: String,
    abstract_snapshot: String,
    keywords_snapshot: vector<String>,
    authors_snapshot: vector<String>,
    field_snapshot: String,
    license_snapshot: String,
    tx_sender: address,
    created_at_ms: u64,
}

public struct CodeReserved has copy, drop {
    paper_record_id: ID,
    paper_code: String,
    paper_epoch: u64,
    epoch_seq: u64,
    record_number: u64,
    reserver: address,
    reserved_at_ms: u64,
}

public struct PaperFinalized has copy, drop {
    paper_record_id: ID,
    version_id: ID,
    paper_code: String,
    paper_epoch: u64,
    epoch_seq: u64,
    record_number: u64,
    owner: address,
    title: String,
    authors: vector<String>,
    field: String,
    keywords: vector<String>,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    file_hash: String,
    comments_tree_id: ID,
    published_at_ms: u64,
}

public struct PaperVersionAdded has copy, drop {
    paper_record_id: ID,
    version_id: ID,
    paper_code: String,
    version_number: u64,
    submitter: address,
    title: String,
    walrus_blob_id: String,
    walrus_blob_object_id: String,
    file_hash: String,
    created_at_ms: u64,
}

public struct StorageExtended has copy, drop {
    paper_record_id: ID,
    version_id: ID,
    paper_code: String,
    old_storage_end_epoch: u64,
    new_storage_end_epoch: u64,
    extender: address,
    updated_at_ms: u64,
}

public struct PaperOwnerTransferred has copy, drop {
    paper_record_id: ID,
    paper_code: String,
    old_owner: address,
    new_owner: address,
    timestamp_ms: u64,
}

public struct ConfigUpdated has copy, drop {
    admin: address,
    timestamp_ms: u64,
}

fun init(ctx: &mut TxContext) {
    let registry = PaperRegistry {
        id: object::new(ctx),
        current_epoch: 0,
        epoch_counter: 0,
        next_record_number: 1,
        code_prefix: string::utf8(b"OriginPaper"),
        max_file_size: 50_000_000,
        min_page_count: 2,
        max_page_count: 200,
        max_keywords: 10,
        max_authors: 20,
        paused: false,
        code_to_record: table::new<String, ID>(ctx),
    };

    let sender = tx_context::sender(ctx);
    let (vault, operator_permit) = governance::new_vault(
        object::id(&registry),
        sender,
        sender,
        ctx,
    );
    transfer::share_object(registry);
    governance::share_vault(vault);
    transfer::public_transfer(operator_permit, sender);
}

public fun reserve_code(
    registry: &mut PaperRegistry,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert!(!registry.paused, E_PAUSED);

    let sender = tx_context::sender(ctx);
    let now = clock::timestamp_ms(clock_ref);
    let epoch = tx_context::epoch(ctx);

    assert!(epoch >= registry.current_epoch, E_EPOCH_REGRESSION);

    if (epoch != registry.current_epoch) {
        registry.current_epoch = epoch;
        registry.epoch_counter = 0;
    };

    registry.epoch_counter = registry.epoch_counter + 1;
    let epoch_seq = registry.epoch_counter;

    let record_number = registry.next_record_number;
    registry.next_record_number = record_number + 1;

    let paper_code = make_paper_code(&registry.code_prefix, epoch, epoch_seq);

    let record = PaperRecord {
        id: object::new(ctx),
        paper_code,
        paper_epoch: epoch,
        epoch_seq,
        record_number,
        reserver: sender,
        owner: sender,
        status: STATUS_RESERVED,
        ui_status: UI_NORMAL,
        title: string::utf8(b""),
        abstract_text: string::utf8(b""),
        keywords: vector::empty<String>(),
        authors: vector::empty<String>(),
        field: string::utf8(b""),
        license: string::utf8(b""),
        current_version: 0,
        version_ids: vector::empty<ID>(),
        comments_tree_id: option::none<ID>(),
        reserved_at_ms: now,
        published_at_ms: 0,
        updated_at_ms: now,
    };

    let record_id = object::id(&record);

    table::add<String, ID>(
        &mut registry.code_to_record,
        record.paper_code,
        record_id,
    );

    event::emit(CodeReserved {
        paper_record_id: record_id,
        paper_code: record.paper_code,
        paper_epoch: epoch,
        epoch_seq,
        record_number,
        reserver: sender,
        reserved_at_ms: now,
    });

    transfer::share_object(record);
}

public fun finalize_paper(
    registry: &PaperRegistry,
    record: &mut PaperRecord,
    governance_vault: &GovernanceVault,

    title: String,
    abstract_text: String,
    keywords: vector<String>,
    authors: vector<String>,
    field: String,
    license: String,

    walrus_blob_id: String,
    walrus_blob_object_id: String,
    file_hash: String,
    file_size: u64,
    page_count: u64,
    storage_end_epoch: u64,
    is_shared_blob: bool,

    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert!(!registry.paused, E_PAUSED);
    assert!(governance::registry_id(governance_vault) == object::id(registry), E_INVALID_GOVERNANCE_VAULT);

    let sender = tx_context::sender(ctx);
    assert!(sender == record.reserver, E_NOT_RESERVER);
    assert!(record.status == STATUS_RESERVED, E_ALREADY_PUBLISHED);

    validate_metadata(registry, &title, &abstract_text, &keywords, &authors);
    validate_file(
        registry,
        &walrus_blob_id,
        &walrus_blob_object_id,
        &file_hash,
        file_size,
        page_count,
    );
    governance::collect_publishing_fee(governance_vault, payment, ctx);

    let now = clock::timestamp_ms(clock_ref);

    record.title = title;
    record.abstract_text = abstract_text;
    record.keywords = keywords;
    record.authors = authors;
    record.field = field;
    record.license = license;
    record.status = STATUS_PUBLISHED;
    record.current_version = 1;
    record.published_at_ms = now;
    record.updated_at_ms = now;

    let record_id = object::id(record);

    let comments_tree = comments::new_tree(
        object::id(registry),
        record.owner,
        record.paper_code,
        record_id,
        clock_ref,
        ctx,
    );
    let comments_tree_id = comments::tree_id(&comments_tree);
    record.comments_tree_id = option::some<ID>(comments_tree_id);

    let version = PaperVersion {
        id: object::new(ctx),
        paper_record_id: record_id,
        paper_code: record.paper_code,
        version_number: 1,
        walrus_blob_id,
        walrus_blob_object_id,
        file_hash,
        file_size,
        page_count,
        storage_end_epoch,
        is_shared_blob,
        title_snapshot: record.title,
        abstract_snapshot: record.abstract_text,
        keywords_snapshot: record.keywords,
        authors_snapshot: record.authors,
        field_snapshot: record.field,
        license_snapshot: record.license,
        tx_sender: sender,
        created_at_ms: now,
    };

    let version_id = object::id(&version);
    vector::push_back(&mut record.version_ids, version_id);

    event::emit(PaperFinalized {
        paper_record_id: record_id,
        version_id,
        paper_code: record.paper_code,
        paper_epoch: record.paper_epoch,
        epoch_seq: record.epoch_seq,
        record_number: record.record_number,
        owner: record.owner,
        title: record.title,
        authors: record.authors,
        field: record.field,
        keywords: record.keywords,
        walrus_blob_id: version.walrus_blob_id,
        walrus_blob_object_id: version.walrus_blob_object_id,
        file_hash: version.file_hash,
        comments_tree_id,
        published_at_ms: now,
    });

    comments::share_tree(comments_tree);
    transfer::share_object(version);
}

public fun add_version(
    registry: &PaperRegistry,
    record: &mut PaperRecord,
    governance_vault: &GovernanceVault,

    title: String,
    abstract_text: String,
    keywords: vector<String>,
    authors: vector<String>,
    field: String,
    license: String,

    walrus_blob_id: String,
    walrus_blob_object_id: String,
    file_hash: String,
    file_size: u64,
    page_count: u64,
    storage_end_epoch: u64,
    is_shared_blob: bool,

    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert!(!registry.paused, E_PAUSED);
    assert!(governance::registry_id(governance_vault) == object::id(registry), E_INVALID_GOVERNANCE_VAULT);

    let sender = tx_context::sender(ctx);
    assert!(record.status == STATUS_PUBLISHED, E_NOT_PUBLISHED);
    assert!(sender == record.owner, E_NOT_OWNER);

    validate_metadata(registry, &title, &abstract_text, &keywords, &authors);
    validate_file(
        registry,
        &walrus_blob_id,
        &walrus_blob_object_id,
        &file_hash,
        file_size,
        page_count,
    );
    governance::collect_publishing_fee(governance_vault, payment, ctx);

    let now = clock::timestamp_ms(clock_ref);
    let new_version_number = record.current_version + 1;

    record.title = title;
    record.abstract_text = abstract_text;
    record.keywords = keywords;
    record.authors = authors;
    record.field = field;
    record.license = license;
    record.current_version = new_version_number;
    record.updated_at_ms = now;

    let record_id = object::id(record);

    let version = PaperVersion {
        id: object::new(ctx),
        paper_record_id: record_id,
        paper_code: record.paper_code,
        version_number: new_version_number,
        walrus_blob_id,
        walrus_blob_object_id,
        file_hash,
        file_size,
        page_count,
        storage_end_epoch,
        is_shared_blob,
        title_snapshot: record.title,
        abstract_snapshot: record.abstract_text,
        keywords_snapshot: record.keywords,
        authors_snapshot: record.authors,
        field_snapshot: record.field,
        license_snapshot: record.license,
        tx_sender: sender,
        created_at_ms: now,
    };

    let version_id = object::id(&version);
    vector::push_back(&mut record.version_ids, version_id);

    event::emit(PaperVersionAdded {
        paper_record_id: record_id,
        version_id,
        paper_code: record.paper_code,
        version_number: new_version_number,
        submitter: sender,
        title: record.title,
        walrus_blob_id: version.walrus_blob_id,
        walrus_blob_object_id: version.walrus_blob_object_id,
        file_hash: version.file_hash,
        created_at_ms: now,
    });

    transfer::share_object(version);
}

public fun transfer_paper_owner(
    record: &mut PaperRecord,
    comments_tree: &mut CommentsTree,
    new_owner: address,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(sender == record.owner, E_NOT_OWNER);
    assert!(new_owner != @0x0, E_INVALID_NEW_OWNER);
    assert!(record.status == STATUS_PUBLISHED, E_NOT_PUBLISHED);
    assert!(comments::paper_object_id(comments_tree) == object::id(record), E_INVALID_COMMENTS_TREE);
    assert!(comments::owner(comments_tree) == record.owner, E_INVALID_COMMENTS_TREE);

    let old_owner = record.owner;
    comments::transfer_tree_owner(comments_tree, new_owner, ctx);
    record.owner = new_owner;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);

    event::emit(PaperOwnerTransferred {
        paper_record_id: object::id(record),
        paper_code: record.paper_code,
        old_owner,
        new_owner,
        timestamp_ms: record.updated_at_ms,
    });
}

public fun record_storage_extension(
    record: &PaperRecord,
    version: &mut PaperVersion,
    new_storage_end_epoch: u64,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert!(record.status == STATUS_PUBLISHED, E_NOT_PUBLISHED);
    assert!(version.paper_record_id == object::id(record), E_INVALID_STATUS);
    assert!(new_storage_end_epoch > version.storage_end_epoch, E_STORAGE_NOT_EXTENDED);

    let old = version.storage_end_epoch;
    version.storage_end_epoch = new_storage_end_epoch;

    event::emit(StorageExtended {
        paper_record_id: object::id(record),
        version_id: object::id(version),
        paper_code: record.paper_code,
        old_storage_end_epoch: old,
        new_storage_end_epoch,
        extender: tx_context::sender(ctx),
        updated_at_ms: clock::timestamp_ms(clock_ref),
    });
}

public fun extend_walrus_storage_and_record(
    _registry: &PaperRegistry,
    _record: &PaperRecord,
    _version: &mut PaperVersion,
    _epochs_extended: u64,
    _clock_ref: &Clock,
    _ctx: &mut TxContext,
) {
    abort E_WALRUS_EXTENSION_NOT_IMPLEMENTED
}

public fun set_paused(
    registry: &mut PaperRegistry,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    paused: bool,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        governance_vault,
        operator_permit,
        tx_context::sender(ctx),
    );
    registry.paused = paused;

    event::emit(ConfigUpdated {
        admin: tx_context::sender(ctx),
        timestamp_ms: clock::timestamp_ms(clock_ref),
    });
}

public fun update_limits(
    registry: &mut PaperRegistry,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    max_file_size: u64,
    min_page_count: u64,
    max_page_count: u64,
    max_keywords: u64,
    max_authors: u64,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        governance_vault,
        operator_permit,
        tx_context::sender(ctx),
    );

    registry.max_file_size = max_file_size;
    registry.min_page_count = min_page_count;
    registry.max_page_count = max_page_count;
    registry.max_keywords = max_keywords;
    registry.max_authors = max_authors;

    event::emit(ConfigUpdated {
        admin: tx_context::sender(ctx),
        timestamp_ms: clock::timestamp_ms(clock_ref),
    });
}

public fun set_ui_status(
    registry: &PaperRegistry,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    record: &mut PaperRecord,
    ui_status: u8,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_admin(
        registry,
        governance_vault,
        operator_permit,
        tx_context::sender(ctx),
    );
    assert!(
        ui_status == UI_NORMAL ||
        ui_status == UI_FLAGGED ||
        ui_status == UI_HIDDEN_IN_OFFICIAL_UI,
        E_INVALID_STATUS,
    );

    record.ui_status = ui_status;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
}

public fun get_record_id_by_code(
    registry: &PaperRegistry,
    paper_code: String,
): ID {
    *table::borrow<String, ID>(&registry.code_to_record, paper_code)
}

public fun paper_code(record: &PaperRecord): String {
    record.paper_code
}

public fun paper_epoch(record: &PaperRecord): u64 {
    record.paper_epoch
}

public fun epoch_seq(record: &PaperRecord): u64 {
    record.epoch_seq
}

public fun record_status(record: &PaperRecord): u8 {
    record.status
}

public fun ui_status(record: &PaperRecord): u8 {
    record.ui_status
}

public fun paper_owner(record: &PaperRecord): address {
    record.owner
}

public fun current_version(record: &PaperRecord): u64 {
    record.current_version
}

public fun version_count(record: &PaperRecord): u64 {
    vector::length(&record.version_ids)
}

public fun version_id_at(record: &PaperRecord, index: u64): ID {
    *vector::borrow(&record.version_ids, index)
}

public fun comments_tree_id(record: &PaperRecord): &option::Option<ID> {
    &record.comments_tree_id
}

fun assert_admin(
    registry: &PaperRegistry,
    governance_vault: &GovernanceVault,
    operator_permit: &OperatorPermit,
    sender: address,
) {
    governance::assert_active_operator(
        governance_vault,
        operator_permit,
        object::id(registry),
        sender,
    );
}

fun validate_metadata(
    registry: &PaperRegistry,
    title: &String,
    abstract_text: &String,
    keywords: &vector<String>,
    authors: &vector<String>,
) {
    assert!(string::length(title) > 0, E_EMPTY_TITLE);
    assert!(string::length(abstract_text) > 0, E_EMPTY_ABSTRACT);
    assert!(
        vector::length(keywords) <= registry.max_keywords,
        E_TOO_MANY_KEYWORDS,
    );
    assert!(vector::length(authors) > 0, E_NO_AUTHOR);
    assert!(
        vector::length(authors) <= registry.max_authors,
        E_TOO_MANY_AUTHORS,
    );
}

fun validate_file(
    registry: &PaperRegistry,
    walrus_blob_id: &String,
    walrus_blob_object_id: &String,
    file_hash: &String,
    file_size: u64,
    page_count: u64,
) {
    assert!(string::length(walrus_blob_id) > 0, E_EMPTY_BLOB_ID);
    assert!(string::length(walrus_blob_object_id) > 0, E_EMPTY_BLOB_OBJECT_ID);
    assert!(string::length(file_hash) > 0, E_EMPTY_FILE_HASH);
    assert!(file_size <= registry.max_file_size, E_FILE_TOO_LARGE);
    assert!(page_count >= registry.min_page_count, E_PAGE_COUNT_TOO_SMALL);
    assert!(page_count <= registry.max_page_count, E_PAGE_COUNT_TOO_LARGE);
}

fun make_paper_code(prefix: &String, epoch: u64, seq: u64): String {
    let mut code = *prefix;
    string::append(&mut code, string::utf8(b"-"));
    string::append(&mut code, u64_to_string(epoch));
    string::append(&mut code, string::utf8(b"-"));
    string::append(&mut code, u64_to_string(seq));
    code
}

fun u64_to_string(n: u64): String {
    if (n == 0) {
        return string::utf8(b"0")
    };

    let mut x = n;
    let mut digits_reversed = vector::empty<u8>();

    while (x > 0) {
        let digit = (x % 10) as u8;
        vector::push_back(&mut digits_reversed, 48 + digit);
        x = x / 10;
    };

    let len = vector::length(&digits_reversed);
    let mut i = len;
    let mut digits = vector::empty<u8>();

    while (i > 0) {
        i = i - 1;
        let b = *vector::borrow(&digits_reversed, i);
        vector::push_back(&mut digits, b);
    };

    string::utf8(digits)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
