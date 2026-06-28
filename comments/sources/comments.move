// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available
// Use of this source code is governed by the LICENSE file in the project root.
// Public readability and auditability do not grant rights to copy, modify,
// distribute, redeploy, or commercialize this code except as expressly permitted.

module paperproof_comments::comments;

use paperproof_shared_controller::controller;
use paperproof_shared_controller::controller::{ArtifactControlRecord, ControllerNFT};
use paperproof_governance::governance::{Self as governance, FeeManager, GovernanceVault};
use pprf::pprf::PPRF;
use std::string::{Self as string, String};
use sui::clock::{Self as clock, Clock};
use sui::coin::{Self as coin, Coin};
use sui::event;
use sui::sui::SUI;
use sui::table::{Self as table, Table};

const E_EMPTY_TARGET_KEY: u64 = 1;
const E_TREE_NOT_OPEN: u64 = 2;
const E_PARENT_NOT_FOUND: u64 = 3;
const E_EMPTY_ONCHAIN_CONTENT: u64 = 4;
const E_ONCHAIN_CONTENT_TOO_LARGE: u64 = 5;
const E_EMPTY_BLOB_ID: u64 = 6;
const E_EMPTY_BLOB_DIGEST: u64 = 7;
const E_NOT_TREE_OWNER: u64 = 8;
const E_INVALID_TREE_STATUS: u64 = 9;
const E_INVALID_COMMENT_STATUS: u64 = 10;
const E_COMMENT_NOT_FOUND: u64 = 11;
const E_NOT_COMMENT_OWNER_OR_TREE_OWNER: u64 = 12;
const E_COMMENT_DEPTH_LIMIT: u64 = 13;
const E_INVALID_GOVERNANCE_VAULT: u64 = 14;
const E_INVALID_NEW_OWNER: u64 = 15;
const E_INSUFFICIENT_PPRF_LIKE_BALANCE: u64 = 16;
const E_ALREADY_LIKED: u64 = 17;
const E_NOT_LIKED: u64 = 18;
const E_UNSUPPORTED_TREE_VERSION: u64 = 19;
const E_PARENT_NOT_ACTIVE: u64 = 20;
const E_BLOB_ID_TOO_LONG: u64 = 21;
const E_BLOB_DIGEST_TOO_LONG: u64 = 22;
const E_CONTENT_PREVIEW_TOO_LONG: u64 = 23;
const E_INVALID_TREE_FACTORY_CAP: u64 = 24;
const E_ROOT_COMMENT_IMMUTABLE: u64 = 25;
const E_DELETED_COMMENT_FINAL: u64 = 26;

const MIN_PPRF_FOR_LIKE: u64 = 1_000_000_000; // 1 PPRF
const COMMENTS_TREE_VERSION: u64 = 1;
const MAX_BLOB_ID_BYTES: u64 = 128;
const MAX_BLOB_DIGEST_BYTES: u64 = 128;
const MAX_CONTENT_PREVIEW_BYTES: u64 = 256;

public struct CommentsTree has key {
    id: UID,
    version: u64,
    creator: address,
    owner: address,
    registry_id: ID,
    governance_vault_id: ID,
    fee_manager_id: ID,
    target_key: String,
    target_series_id: ID,
    target_artifact_type: u8,
    root_comment_id: u64,
    next_comment_id: u64,
    total_comments: u64,
    status: u8,
    max_onchain_comment_bytes: u64,
    max_comment_depth: u16,
    created_at_ms: u64,
    likes_book_id: ID,
    nodes: Table<u64, CommentNode>,
}

public struct LikesBook has key {
    id: UID,
    version: u64,
    registry_id: ID,
    comments_tree_id: ID,
    target_series_id: ID,
    target_artifact_type: u8,
    like_count: u64,
    likes: Table<address, bool>,
}

public struct TreeFactoryCap has drop, store {
    registry_id: ID,
    governance_vault_id: ID,
    fee_manager_id: ID,
}

public struct CommentNode has store {
    comment_id: u64,
    parent_comment_id: Option<u64>,
    author: address,
    depth: u16,
    content_mode: u8,
    inline_content: vector<u8>,
    content_preview: vector<u8>,
    blob_id: vector<u8>,
    blob_object_id: Option<ID>,
    blob_digest: vector<u8>,
    children_count: u64,
    created_at_ms: u64,
    edited_at_ms: Option<u64>,
    status: u8,
}

#[allow(unused_field)]
public struct TreeCreatedEvent has copy, drop {
    tree_id: ID,
    creator: address,
    owner: address,
    registry_id: ID,
    governance_vault_id: ID,
    fee_manager_id: ID,
    target_key: String,
    target_series_id: ID,
    target_artifact_type: u8,
    created_at_ms: u64,
    likes_book_id: ID,
}

public struct CommentAddedEvent has copy, drop {
    tree_id: ID,
    comment_id: u64,
    parent_comment_id: u64,
    author: address,
    depth: u16,
    content_mode: u8,
    created_at_ms: u64,
}

public struct TreeStatusChangedEvent has copy, drop {
    registry_id: ID,
    tree_id: ID,
    changed_by: address,
    old_status: u8,
    new_status: u8,
}

public struct CommentStatusChangedEvent has copy, drop {
    registry_id: ID,
    tree_id: ID,
    comment_id: u64,
    changed_by: address,
    old_status: u8,
    new_status: u8,
}

public struct TreeOwnerTransferredEvent has copy, drop {
    registry_id: ID,
    tree_id: ID,
    changed_by: address,
    old_owner: address,
    new_owner: address,
}

public struct CommentsTreeMigratedEvent has copy, drop {
    registry_id: ID,
    tree_id: ID,
    migrated_by: address,
    new_version: u64,
}

public struct PaperLikedEvent has copy, drop {
    tree_id: ID,
    likes_book_id: ID,
    target_series_id: ID,
    liker: address,
    like_count: u64,
}

public struct PaperUnlikedEvent has copy, drop {
    tree_id: ID,
    likes_book_id: ID,
    target_series_id: ID,
    liker: address,
    like_count: u64,
}

const ROOT_COMMENT_ID: u64 = 0;

const COMMENT_MODE_ONCHAIN: u8 = 1;
const COMMENT_MODE_BLOB: u8 = 2;

const TREE_STATUS_OPEN: u8 = 0;
const TREE_STATUS_LOCKED: u8 = 1;
const TREE_STATUS_ARCHIVED: u8 = 2;

const COMMENT_STATUS_ACTIVE: u8 = 0;
const COMMENT_STATUS_HIDDEN: u8 = 1;
const COMMENT_STATUS_DELETED: u8 = 2;

const DEFAULT_MAX_ONCHAIN_COMMENT_BYTES: u64 = 512;
const DEFAULT_MAX_COMMENT_DEPTH: u16 = 64;

public fun new_tree_factory_cap(
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    ctx: &mut TxContext,
): TreeFactoryCap {
    governance::assert_current_vault(governance_vault);
    let sender = tx_context::sender(ctx);
    assert!(
        sender == governance::governance_authority(governance_vault) ||
        sender == governance::upgrade_authority(governance_vault),
        E_INVALID_TREE_FACTORY_CAP,
    );
    assert!(
        governance::fee_manager_registry_id(fee_manager) == governance::registry_id(governance_vault),
        E_INVALID_TREE_FACTORY_CAP,
    );

    TreeFactoryCap {
        registry_id: governance::registry_id(governance_vault),
        governance_vault_id: object::id(governance_vault),
        fee_manager_id: governance::fee_manager_id(fee_manager),
    }
}

public fun new_tree(
    tree_factory_cap: &TreeFactoryCap,
    registry_id: ID,
    governance_vault_id: ID,
    fee_manager_id: ID,
    owner: address,
    target_key: String,
    target_series_id: ID,
    target_artifact_type: u8,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): (CommentsTree, LikesBook) {
    assert_tree_factory_cap(tree_factory_cap, registry_id, governance_vault_id, fee_manager_id);
    assert!(!string::is_empty(&target_key), E_EMPTY_TARGET_KEY);

    let tree_uid = object::new(ctx);
    let tree_id = *tree_uid.as_inner();
    let likes_book_uid = object::new(ctx);
    let likes_book_id = *likes_book_uid.as_inner();

    let mut tree = CommentsTree {
        id: tree_uid,
        version: COMMENTS_TREE_VERSION,
        creator: tx_context::sender(ctx),
        owner,
        registry_id,
        governance_vault_id,
        fee_manager_id,
        target_key,
        target_series_id,
        target_artifact_type,
        root_comment_id: ROOT_COMMENT_ID,
        next_comment_id: 1,
        total_comments: 0,
        status: TREE_STATUS_OPEN,
        max_onchain_comment_bytes: DEFAULT_MAX_ONCHAIN_COMMENT_BYTES,
        max_comment_depth: DEFAULT_MAX_COMMENT_DEPTH,
        created_at_ms: clock::timestamp_ms(clock_ref),
        likes_book_id,
        nodes: table::new(ctx),
    };

    let likes_book = LikesBook {
        id: likes_book_uid,
        version: COMMENTS_TREE_VERSION,
        registry_id,
        comments_tree_id: tree_id,
        target_series_id,
        target_artifact_type,
        like_count: 0,
        likes: table::new(ctx),
    };

    let root = CommentNode {
        comment_id: ROOT_COMMENT_ID,
        parent_comment_id: option::none(),
        author: tx_context::sender(ctx),
        depth: 0,
        content_mode: COMMENT_MODE_ONCHAIN,
        inline_content: vector[],
        content_preview: vector[],
        blob_id: vector[],
        blob_object_id: option::none(),
        blob_digest: vector[],
        children_count: 0,
        created_at_ms: tree.created_at_ms,
        edited_at_ms: option::none(),
        status: COMMENT_STATUS_ACTIVE,
    };
    table::add(&mut tree.nodes, ROOT_COMMENT_ID, root);

    (tree, likes_book)
}

public fun share_tree(tree: CommentsTree) {
    transfer::share_object(tree);
}

public fun share_likes_book(book: LikesBook) {
    transfer::share_object(book);
}

public fun add_onchain_comment(
    tree: &mut CommentsTree,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    parent_comment_id: u64,
    content: vector<u8>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_tree(tree);
    governance::assert_current_vault(governance_vault);
    assert_tree_open(tree);
    assert!(table::contains(&tree.nodes, parent_comment_id), E_PARENT_NOT_FOUND);
    assert!(!content.is_empty(), E_EMPTY_ONCHAIN_CONTENT);
    assert!(content.length() <= tree.max_onchain_comment_bytes, E_ONCHAIN_CONTENT_TOO_LARGE);
    assert!(governance::registry_id(governance_vault) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_registry_id(fee_manager) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(object::id(governance_vault) == tree.governance_vault_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_id(fee_manager) == tree.fee_manager_id, E_INVALID_GOVERNANCE_VAULT);

    let parent_depth = {
        let parent = table::borrow(&tree.nodes, parent_comment_id);
        assert!(parent.status == COMMENT_STATUS_ACTIVE, E_PARENT_NOT_ACTIVE);
        parent.depth
    };
    let depth = parent_depth + 1;
    assert!(depth <= tree.max_comment_depth, E_COMMENT_DEPTH_LIMIT);
    governance::collect_comments_fee(governance_vault, fee_manager, payment, ctx);

    let comment_id = tree.next_comment_id;
    tree.next_comment_id = comment_id + 1;
    tree.total_comments = tree.total_comments + 1;

    {
        let parent = table::borrow_mut(&mut tree.nodes, parent_comment_id);
        parent.children_count = parent.children_count + 1;
    };

    let now = clock::timestamp_ms(clock_ref);
    let node = CommentNode {
        comment_id,
        parent_comment_id: option::some(parent_comment_id),
        author: tx_context::sender(ctx),
        depth,
        content_mode: COMMENT_MODE_ONCHAIN,
        inline_content: content,
        content_preview: vector[],
        blob_id: vector[],
        blob_object_id: option::none(),
        blob_digest: vector[],
        children_count: 0,
        created_at_ms: now,
        edited_at_ms: option::none(),
        status: COMMENT_STATUS_ACTIVE,
    };
    table::add(&mut tree.nodes, comment_id, node);

    event::emit(CommentAddedEvent {
        tree_id: *tree.id.as_inner(),
        comment_id,
        parent_comment_id,
        author: tx_context::sender(ctx),
        depth,
        content_mode: COMMENT_MODE_ONCHAIN,
        created_at_ms: now,
    });
}

public fun add_blob_comment(
    tree: &mut CommentsTree,
    governance_vault: &GovernanceVault,
    fee_manager: &FeeManager,
    parent_comment_id: u64,
    blob_id: vector<u8>,
    blob_object_id: Option<ID>,
    blob_digest: vector<u8>,
    content_preview: vector<u8>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_current_tree(tree);
    governance::assert_current_vault(governance_vault);
    assert_tree_open(tree);
    assert!(table::contains(&tree.nodes, parent_comment_id), E_PARENT_NOT_FOUND);
    assert!(!blob_id.is_empty(), E_EMPTY_BLOB_ID);
    assert!(!blob_digest.is_empty(), E_EMPTY_BLOB_DIGEST);
    assert!(blob_id.length() <= MAX_BLOB_ID_BYTES, E_BLOB_ID_TOO_LONG);
    assert!(blob_digest.length() <= MAX_BLOB_DIGEST_BYTES, E_BLOB_DIGEST_TOO_LONG);
    assert!(content_preview.length() <= MAX_CONTENT_PREVIEW_BYTES, E_CONTENT_PREVIEW_TOO_LONG);
    assert!(governance::registry_id(governance_vault) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_registry_id(fee_manager) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(object::id(governance_vault) == tree.governance_vault_id, E_INVALID_GOVERNANCE_VAULT);
    assert!(governance::fee_manager_id(fee_manager) == tree.fee_manager_id, E_INVALID_GOVERNANCE_VAULT);

    let parent_depth = {
        let parent = table::borrow(&tree.nodes, parent_comment_id);
        assert!(parent.status == COMMENT_STATUS_ACTIVE, E_PARENT_NOT_ACTIVE);
        parent.depth
    };
    let depth = parent_depth + 1;
    assert!(depth <= tree.max_comment_depth, E_COMMENT_DEPTH_LIMIT);
    governance::collect_comments_fee(governance_vault, fee_manager, payment, ctx);

    let comment_id = tree.next_comment_id;
    tree.next_comment_id = comment_id + 1;
    tree.total_comments = tree.total_comments + 1;

    {
        let parent = table::borrow_mut(&mut tree.nodes, parent_comment_id);
        parent.children_count = parent.children_count + 1;
    };

    let now = clock::timestamp_ms(clock_ref);
    let node = CommentNode {
        comment_id,
        parent_comment_id: option::some(parent_comment_id),
        author: tx_context::sender(ctx),
        depth,
        content_mode: COMMENT_MODE_BLOB,
        inline_content: vector[],
        content_preview,
        blob_id,
        blob_object_id,
        blob_digest,
        children_count: 0,
        created_at_ms: now,
        edited_at_ms: option::none(),
        status: COMMENT_STATUS_ACTIVE,
    };
    table::add(&mut tree.nodes, comment_id, node);

    event::emit(CommentAddedEvent {
        tree_id: *tree.id.as_inner(),
        comment_id,
        parent_comment_id,
        author: tx_context::sender(ctx),
        depth,
        content_mode: COMMENT_MODE_BLOB,
        created_at_ms: now,
    });
}

public fun like_paper(
    book: &mut LikesBook,
    pprf_proof: &Coin<PPRF>,
    ctx: &TxContext,
) {
    assert_current_likes_book(book);
    let liker = tx_context::sender(ctx);
    assert!(coin::value(pprf_proof) >= MIN_PPRF_FOR_LIKE, E_INSUFFICIENT_PPRF_LIKE_BALANCE);
    assert!(!table::contains(&book.likes, liker), E_ALREADY_LIKED);

    table::add(&mut book.likes, liker, true);
    book.like_count = book.like_count + 1;

    event::emit(PaperLikedEvent {
        tree_id: book.comments_tree_id,
        likes_book_id: object::id(book),
        target_series_id: book.target_series_id,
        liker,
        like_count: book.like_count,
    });
}

public fun unlike_paper(
    book: &mut LikesBook,
    pprf_proof: &Coin<PPRF>,
    ctx: &TxContext,
) {
    assert_current_likes_book(book);
    let liker = tx_context::sender(ctx);
    assert!(coin::value(pprf_proof) >= MIN_PPRF_FOR_LIKE, E_INSUFFICIENT_PPRF_LIKE_BALANCE);
    assert!(table::contains(&book.likes, liker), E_NOT_LIKED);

    let _ = table::remove(&mut book.likes, liker);
    book.like_count = book.like_count - 1;

    event::emit(PaperUnlikedEvent {
        tree_id: book.comments_tree_id,
        likes_book_id: object::id(book),
        target_series_id: book.target_series_id,
        liker,
        like_count: book.like_count,
    });
}

public fun set_tree_status(
    tree: &mut CommentsTree,
    new_status: u8,
    ctx: &TxContext,
) {
    assert_current_tree(tree);
    controller::assert_tree_legacy_write_allowed(&tree.id);
    assert_tree_owner(tree, ctx);
    assert_valid_tree_status(new_status);

    let old_status = tree.status;
    tree.status = new_status;

    event::emit(TreeStatusChangedEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        changed_by: tx_context::sender(ctx),
        old_status,
        new_status,
    });
}

public fun set_tree_status_with_controller(
    tree: &mut CommentsTree,
    control_record: &mut ArtifactControlRecord,
    controller_nft: &ControllerNFT,
    new_status: u8,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_tree(tree);
    controller::assert_controller_for_tree(&tree.id, tree_id(tree), tree.target_series_id, tree.target_artifact_type, control_record, controller_nft, ctx);
    assert_valid_tree_status(new_status);

    let old_status = tree.status;
    tree.status = new_status;
    controller::sync_legacy_comments_owner_mirror(control_record, controller_nft, tree.owner, clock_ref, ctx);

    event::emit(TreeStatusChangedEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        changed_by: tx_context::sender(ctx),
        old_status,
        new_status,
    });
}

public fun set_comment_status(
    tree: &mut CommentsTree,
    comment_id: u64,
    new_status: u8,
    ctx: &TxContext,
) {
    assert_current_tree(tree);
    assert_valid_comment_status(new_status);
    assert!(table::contains(&tree.nodes, comment_id), E_COMMENT_NOT_FOUND);
    assert!(comment_id != ROOT_COMMENT_ID, E_ROOT_COMMENT_IMMUTABLE);

    let sender = tx_context::sender(ctx);
    let legacy_tree_owner_allowed = !controller::is_tree_control_enabled(&tree.id) ||
        controller::tree_authority_mode(&tree.id) == controller::authority_mode_dual() ||
        controller::tree_authority_mode(&tree.id) == controller::authority_mode_legacy_owner_only();
    let author_is_self_service_delete = {
        let node_ref = table::borrow(&tree.nodes, comment_id);
        sender == node_ref.author && new_status == COMMENT_STATUS_DELETED
    };
    assert!(
        author_is_self_service_delete ||
        (legacy_tree_owner_allowed && sender == tree.owner),
        E_NOT_COMMENT_OWNER_OR_TREE_OWNER,
    );

    let node = table::borrow_mut(&mut tree.nodes, comment_id);
    assert!(node.status != COMMENT_STATUS_DELETED, E_DELETED_COMMENT_FINAL);
    let old_status = node.status;
    node.status = new_status;
    node.edited_at_ms = option::none<u64>();

    event::emit(CommentStatusChangedEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        comment_id,
        changed_by: tx_context::sender(ctx),
        old_status,
        new_status,
    });
}

public fun set_comment_status_with_controller(
    tree: &mut CommentsTree,
    control_record: &mut ArtifactControlRecord,
    controller_nft: &ControllerNFT,
    comment_id: u64,
    new_status: u8,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_tree(tree);
    assert_valid_comment_status(new_status);
    assert!(table::contains(&tree.nodes, comment_id), E_COMMENT_NOT_FOUND);
    assert!(comment_id != ROOT_COMMENT_ID, E_ROOT_COMMENT_IMMUTABLE);

    let sender = tx_context::sender(ctx);
    let mut controller_authorized = false;
    if (controller::is_tree_control_enabled(&tree.id)) {
        controller::assert_controller_for_tree(&tree.id, tree_id(tree), tree.target_series_id, tree.target_artifact_type, control_record, controller_nft, ctx);
        controller::sync_legacy_comments_owner_mirror(control_record, controller_nft, tree.owner, clock_ref, ctx);
        controller_authorized = true;
    };
    let node = table::borrow_mut(&mut tree.nodes, comment_id);
    assert!(node.status != COMMENT_STATUS_DELETED, E_DELETED_COMMENT_FINAL);
    if (!controller_authorized && sender != node.author) {
        assert!(sender == tree.owner, E_NOT_COMMENT_OWNER_OR_TREE_OWNER);
    } else if (!controller_authorized) {
        assert!(new_status == COMMENT_STATUS_DELETED, E_NOT_COMMENT_OWNER_OR_TREE_OWNER);
    };

    let old_status = node.status;
    node.status = new_status;
    node.edited_at_ms = option::none<u64>();

    event::emit(CommentStatusChangedEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        comment_id,
        changed_by: tx_context::sender(ctx),
        old_status,
        new_status,
    });
}

public fun transfer_tree_owner(
    tree: &mut CommentsTree,
    new_owner: address,
    ctx: &TxContext,
) {
    assert_current_tree(tree);
    controller::assert_tree_legacy_write_allowed(&tree.id);
    assert!(tx_context::sender(ctx) == tree.owner, E_NOT_TREE_OWNER);
    assert!(new_owner != @0x0, E_INVALID_NEW_OWNER);

    let old_owner = tree.owner;
    tree.owner = new_owner;

    event::emit(TreeOwnerTransferredEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        changed_by: tx_context::sender(ctx),
        old_owner,
        new_owner,
    });
}

public fun transfer_tree_owner_with_controller(
    tree: &mut CommentsTree,
    control_record: &mut ArtifactControlRecord,
    controller_nft: &ControllerNFT,
    new_owner: address,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_tree(tree);
    controller::assert_controller_for_tree(&tree.id, tree_id(tree), tree.target_series_id, tree.target_artifact_type, control_record, controller_nft, ctx);
    assert!(new_owner != @0x0, E_INVALID_NEW_OWNER);

    let old_owner = tree.owner;
    tree.owner = new_owner;
    controller::sync_legacy_comments_owner_mirror(control_record, controller_nft, tree.owner, clock_ref, ctx);

    event::emit(TreeOwnerTransferredEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        changed_by: tx_context::sender(ctx),
        old_owner,
        new_owner,
    });
}

public fun tree_uid_mut(tree: &mut CommentsTree): &mut UID {
    &mut tree.id
}

public fun tree_uid(tree: &CommentsTree): &UID {
    &tree.id
}

public fun tree_control_enabled(tree: &CommentsTree): bool {
    controller::is_tree_control_enabled(&tree.id)
}

public fun tree_authority_mode(tree: &CommentsTree): u8 {
    controller::tree_authority_mode(&tree.id)
}

public fun tree_control_record_id(tree: &CommentsTree): Option<ID> {
    controller::tree_control_record_id(&tree.id)
}

public fun tree_controller_nft_id(tree: &CommentsTree): Option<ID> {
    controller::tree_controller_nft_id(&tree.id)
}

public fun tree_id(tree: &CommentsTree): ID {
    *tree.id.as_inner()
}

public fun tree_version(tree: &CommentsTree): u64 {
    tree.version
}

public fun current_tree_version(): u64 {
    COMMENTS_TREE_VERSION
}

public fun creator(tree: &CommentsTree): address {
    tree.creator
}

public fun owner(tree: &CommentsTree): address {
    tree.owner
}

public fun registry_id(tree: &CommentsTree): ID {
    tree.registry_id
}

public fun governance_vault_id(tree: &CommentsTree): ID {
    tree.governance_vault_id
}

public fun fee_manager_id(tree: &CommentsTree): ID {
    tree.fee_manager_id
}

public fun tree_factory_cap_registry_id(cap: &TreeFactoryCap): ID {
    cap.registry_id
}

public fun target_key(tree: &CommentsTree): &String {
    &tree.target_key
}

public fun target_series_id(tree: &CommentsTree): ID {
    tree.target_series_id
}

public fun target_artifact_type(tree: &CommentsTree): u8 {
    tree.target_artifact_type
}

public fun tree_likes_book_id(tree: &CommentsTree): ID {
    tree.likes_book_id
}

public fun root_comment_id(tree: &CommentsTree): u64 {
    tree.root_comment_id
}

public fun total_comments(tree: &CommentsTree): u64 {
    tree.total_comments
}

public fun next_comment_id(tree: &CommentsTree): u64 {
    tree.next_comment_id
}

public fun tree_status(tree: &CommentsTree): u8 {
    tree.status
}

public fun max_onchain_comment_bytes(tree: &CommentsTree): u64 {
    tree.max_onchain_comment_bytes
}

public fun max_comment_depth(tree: &CommentsTree): u16 {
    tree.max_comment_depth
}

public fun likes_book_id(book: &LikesBook): ID {
    object::id(book)
}

public fun likes_book_version(book: &LikesBook): u64 {
    book.version
}

public fun likes_book_registry_id(book: &LikesBook): ID {
    book.registry_id
}

public fun likes_book_comments_tree_id(book: &LikesBook): ID {
    book.comments_tree_id
}

public fun likes_book_target_series_id(book: &LikesBook): ID {
    book.target_series_id
}

public fun likes_book_target_artifact_type(book: &LikesBook): u8 {
    book.target_artifact_type
}

public fun like_count(book: &LikesBook): u64 {
    book.like_count
}

public fun has_liked(book: &LikesBook, liker: address): bool {
    table::contains(&book.likes, liker)
}

public fun has_comment(tree: &CommentsTree, comment_id: u64): bool {
    table::contains(&tree.nodes, comment_id)
}

public fun borrow_comment(tree: &CommentsTree, comment_id: u64): &CommentNode {
    assert!(table::contains(&tree.nodes, comment_id), E_COMMENT_NOT_FOUND);
    table::borrow(&tree.nodes, comment_id)
}

public fun borrow_comment_mut(tree: &mut CommentsTree, comment_id: u64): &mut CommentNode {
    assert!(table::contains(&tree.nodes, comment_id), E_COMMENT_NOT_FOUND);
    table::borrow_mut(&mut tree.nodes, comment_id)
}

public fun comment_id(node: &CommentNode): u64 {
    node.comment_id
}

public fun parent_comment_id(node: &CommentNode): &Option<u64> {
    &node.parent_comment_id
}

public fun comment_author(node: &CommentNode): address {
    node.author
}

public fun comment_depth(node: &CommentNode): u16 {
    node.depth
}

public fun content_mode(node: &CommentNode): u8 {
    node.content_mode
}

public fun inline_content(node: &CommentNode): &vector<u8> {
    &node.inline_content
}

public fun content_preview(node: &CommentNode): &vector<u8> {
    &node.content_preview
}

public fun blob_id(node: &CommentNode): &vector<u8> {
    &node.blob_id
}

public fun blob_object_id(node: &CommentNode): &Option<ID> {
    &node.blob_object_id
}

public fun blob_digest(node: &CommentNode): &vector<u8> {
    &node.blob_digest
}

public fun children_count(node: &CommentNode): u64 {
    node.children_count
}

public fun created_at_ms(node: &CommentNode): u64 {
    node.created_at_ms
}

public fun status(node: &CommentNode): u8 {
    node.status
}

public fun comment_mode_onchain(): u8 {
    COMMENT_MODE_ONCHAIN
}

public fun comment_mode_blob(): u8 {
    COMMENT_MODE_BLOB
}

public fun tree_status_open(): u8 {
    TREE_STATUS_OPEN
}

public fun tree_status_locked(): u8 {
    TREE_STATUS_LOCKED
}

public fun tree_status_archived(): u8 {
    TREE_STATUS_ARCHIVED
}

public fun comment_status_active(): u8 {
    COMMENT_STATUS_ACTIVE
}

public fun comment_status_hidden(): u8 {
    COMMENT_STATUS_HIDDEN
}

public fun comment_status_deleted(): u8 {
    COMMENT_STATUS_DELETED
}

public fun minimum_pprf_for_like(): u64 {
    MIN_PPRF_FOR_LIKE
}

public fun migrate_tree(
    tree: &mut CommentsTree,
    governance_vault: &GovernanceVault,
    ctx: &TxContext,
) {
    governance::assert_current_vault(governance_vault);
    assert!(governance::registry_id(governance_vault) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);
    governance::assert_upgrade_authority(governance_vault, tx_context::sender(ctx));
    migrate_tree_version(tree);
    event::emit(CommentsTreeMigratedEvent {
        registry_id: tree.registry_id,
        tree_id: *tree.id.as_inner(),
        migrated_by: tx_context::sender(ctx),
        new_version: tree.version,
    });
}

fun assert_tree_open(tree: &CommentsTree) {
    assert!(tree.status == TREE_STATUS_OPEN, E_TREE_NOT_OPEN);
}

fun assert_tree_owner(tree: &CommentsTree, ctx: &TxContext) {
    assert!(tree.owner == tx_context::sender(ctx), E_NOT_TREE_OWNER);
}

fun assert_valid_tree_status(status: u8) {
    assert!(
        status == TREE_STATUS_OPEN ||
        status == TREE_STATUS_LOCKED ||
        status == TREE_STATUS_ARCHIVED,
        E_INVALID_TREE_STATUS,
    );
}

fun assert_valid_comment_status(status: u8) {
    assert!(
        status == COMMENT_STATUS_ACTIVE ||
        status == COMMENT_STATUS_HIDDEN ||
        status == COMMENT_STATUS_DELETED,
        E_INVALID_COMMENT_STATUS,
    );
}

fun assert_current_tree(tree: &CommentsTree) {
    assert!(tree.version == COMMENTS_TREE_VERSION, E_UNSUPPORTED_TREE_VERSION);
}

fun assert_current_likes_book(book: &LikesBook) {
    assert!(book.version == COMMENTS_TREE_VERSION, E_UNSUPPORTED_TREE_VERSION);
}

fun assert_tree_factory_cap(
    cap: &TreeFactoryCap,
    registry_id: ID,
    governance_vault_id: ID,
    fee_manager_id: ID,
) {
    assert!(cap.registry_id == registry_id, E_INVALID_TREE_FACTORY_CAP);
    assert!(cap.governance_vault_id == governance_vault_id, E_INVALID_TREE_FACTORY_CAP);
    assert!(cap.fee_manager_id == fee_manager_id, E_INVALID_TREE_FACTORY_CAP);
}

fun migrate_tree_version(tree: &mut CommentsTree) {
    assert!(tree.version <= COMMENTS_TREE_VERSION, E_UNSUPPORTED_TREE_VERSION);
    if (tree.version < COMMENTS_TREE_VERSION) {
        tree.version = COMMENTS_TREE_VERSION;
    };
}
