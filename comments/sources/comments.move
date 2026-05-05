// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available
// Use of this source code is governed by the LICENSE file in the project root.
// Public readability and auditability do not grant rights to copy, modify,
// distribute, redeploy, or commercialize this code except as expressly permitted.

module paperproof_comments::comments;

use paperproof_governance::governance::{Self as governance, GovernanceVault};
use pprf::pprf::PPRF;
use std::string::{Self as string, String};
use sui::clock::{Self as clock, Clock};
use sui::coin::{Self as coin, Coin};
use sui::event;
use sui::sui::SUI;
use sui::table::{Self as table, Table};

const E_EMPTY_PAPER_KEY: u64 = 1;
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

const MIN_PPRF_FOR_LIKE: u64 = 1_000_000_000; // 1 PPRF

public struct CommentsTree has key {
    id: UID,
    creator: address,
    owner: address,
    registry_id: ID,
    paper_key: String,
    paper_object_id: ID,
    root_comment_id: u64,
    next_comment_id: u64,
    total_comments: u64,
    status: u8,
    max_onchain_comment_bytes: u64,
    max_comment_depth: u16,
    created_at_ms: u64,
    like_count: u64,
    likes: Table<address, bool>,
    nodes: Table<u64, CommentNode>,
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

public struct TreeCreatedEvent has copy, drop {
    tree_id: ID,
    creator: address,
    owner: address,
    paper_key: String,
    created_at_ms: u64,
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
    tree_id: ID,
    old_status: u8,
    new_status: u8,
}

public struct CommentStatusChangedEvent has copy, drop {
    tree_id: ID,
    comment_id: u64,
    old_status: u8,
    new_status: u8,
}

public struct TreeOwnerTransferredEvent has copy, drop {
    tree_id: ID,
    old_owner: address,
    new_owner: address,
}

public struct PaperLikedEvent has copy, drop {
    tree_id: ID,
    liker: address,
    like_count: u64,
}

public struct PaperUnlikedEvent has copy, drop {
    tree_id: ID,
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

public fun new_tree(
    registry_id: ID,
    owner: address,
    paper_key: String,
    paper_object_id: ID,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): CommentsTree {
    assert!(!string::is_empty(&paper_key), E_EMPTY_PAPER_KEY);

    let mut tree = CommentsTree {
        id: object::new(ctx),
        creator: tx_context::sender(ctx),
        owner,
        registry_id,
        paper_key,
        paper_object_id,
        root_comment_id: ROOT_COMMENT_ID,
        next_comment_id: 1,
        total_comments: 0,
        status: TREE_STATUS_OPEN,
        max_onchain_comment_bytes: DEFAULT_MAX_ONCHAIN_COMMENT_BYTES,
        max_comment_depth: DEFAULT_MAX_COMMENT_DEPTH,
        created_at_ms: clock::timestamp_ms(clock_ref),
        like_count: 0,
        likes: table::new(ctx),
        nodes: table::new(ctx),
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

    event::emit(TreeCreatedEvent {
        tree_id: *tree.id.as_inner(),
        creator: tree.creator,
        owner: tree.owner,
        paper_key: tree.paper_key,
        created_at_ms: tree.created_at_ms,
    });

    tree
}

public fun share_tree(tree: CommentsTree) {
    transfer::share_object(tree);
}

public fun add_onchain_comment(
    tree: &mut CommentsTree,
    governance_vault: &GovernanceVault,
    parent_comment_id: u64,
    content: vector<u8>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_tree_open(tree);
    assert!(table::contains(&tree.nodes, parent_comment_id), E_PARENT_NOT_FOUND);
    assert!(!content.is_empty(), E_EMPTY_ONCHAIN_CONTENT);
    assert!(content.length() <= tree.max_onchain_comment_bytes, E_ONCHAIN_CONTENT_TOO_LARGE);
    assert!(governance::registry_id(governance_vault) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);

    let parent_depth = {
        let parent = table::borrow(&tree.nodes, parent_comment_id);
        parent.depth
    };
    let depth = parent_depth + 1;
    assert!(depth <= tree.max_comment_depth, E_COMMENT_DEPTH_LIMIT);
    governance::collect_comments_fee(governance_vault, payment, ctx);

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
    parent_comment_id: u64,
    blob_id: vector<u8>,
    blob_object_id: Option<ID>,
    blob_digest: vector<u8>,
    content_preview: vector<u8>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    assert_tree_open(tree);
    assert!(table::contains(&tree.nodes, parent_comment_id), E_PARENT_NOT_FOUND);
    assert!(!blob_id.is_empty(), E_EMPTY_BLOB_ID);
    assert!(!blob_digest.is_empty(), E_EMPTY_BLOB_DIGEST);
    assert!(governance::registry_id(governance_vault) == tree.registry_id, E_INVALID_GOVERNANCE_VAULT);

    let parent_depth = {
        let parent = table::borrow(&tree.nodes, parent_comment_id);
        parent.depth
    };
    let depth = parent_depth + 1;
    assert!(depth <= tree.max_comment_depth, E_COMMENT_DEPTH_LIMIT);
    governance::collect_comments_fee(governance_vault, payment, ctx);

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
    tree: &mut CommentsTree,
    pprf_proof: &Coin<PPRF>,
    ctx: &TxContext,
) {
    let liker = tx_context::sender(ctx);
    assert!(coin::value(pprf_proof) >= MIN_PPRF_FOR_LIKE, E_INSUFFICIENT_PPRF_LIKE_BALANCE);
    assert!(!table::contains(&tree.likes, liker), E_ALREADY_LIKED);

    table::add(&mut tree.likes, liker, true);
    tree.like_count = tree.like_count + 1;

    event::emit(PaperLikedEvent {
        tree_id: *tree.id.as_inner(),
        liker,
        like_count: tree.like_count,
    });
}

public fun unlike_paper(
    tree: &mut CommentsTree,
    pprf_proof: &Coin<PPRF>,
    ctx: &TxContext,
) {
    let liker = tx_context::sender(ctx);
    assert!(coin::value(pprf_proof) >= MIN_PPRF_FOR_LIKE, E_INSUFFICIENT_PPRF_LIKE_BALANCE);
    assert!(table::contains(&tree.likes, liker), E_NOT_LIKED);

    let _ = table::remove(&mut tree.likes, liker);
    tree.like_count = tree.like_count - 1;

    event::emit(PaperUnlikedEvent {
        tree_id: *tree.id.as_inner(),
        liker,
        like_count: tree.like_count,
    });
}

public fun set_tree_status(
    tree: &mut CommentsTree,
    new_status: u8,
    ctx: &TxContext,
) {
    assert_tree_owner(tree, ctx);
    assert_valid_tree_status(new_status);

    let old_status = tree.status;
    tree.status = new_status;

    event::emit(TreeStatusChangedEvent {
        tree_id: *tree.id.as_inner(),
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
    assert_valid_comment_status(new_status);
    assert!(table::contains(&tree.nodes, comment_id), E_COMMENT_NOT_FOUND);

    let node = table::borrow_mut(&mut tree.nodes, comment_id);
    assert!(node.author == tx_context::sender(ctx) || tree.owner == tx_context::sender(ctx), E_NOT_COMMENT_OWNER_OR_TREE_OWNER);

    let old_status = node.status;
    node.status = new_status;
    node.edited_at_ms = option::none<u64>();

    event::emit(CommentStatusChangedEvent {
        tree_id: *tree.id.as_inner(),
        comment_id,
        old_status,
        new_status,
    });
}

public fun transfer_tree_owner(
    tree: &mut CommentsTree,
    new_owner: address,
    ctx: &TxContext,
) {
    assert!(tx_context::sender(ctx) == tree.owner, E_NOT_TREE_OWNER);
    assert!(new_owner != @0x0, E_INVALID_NEW_OWNER);

    let old_owner = tree.owner;
    tree.owner = new_owner;

    event::emit(TreeOwnerTransferredEvent {
        tree_id: *tree.id.as_inner(),
        old_owner,
        new_owner,
    });
}

public fun tree_id(tree: &CommentsTree): ID {
    *tree.id.as_inner()
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

public fun paper_key(tree: &CommentsTree): &String {
    &tree.paper_key
}

public fun paper_object_id(tree: &CommentsTree): ID {
    tree.paper_object_id
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

public fun like_count(tree: &CommentsTree): u64 {
    tree.like_count
}

public fun has_liked(tree: &CommentsTree, liker: address): bool {
    table::contains(&tree.likes, liker)
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
