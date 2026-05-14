// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module specs::comments_spec;

#[spec_only]
use prover::prover::{asserts, ensures, requires};

use std::string::{Self as string, String};
use paperproof_comments::comments;
use paperproof_governance::governance;
use pprf::pprf::PPRF;
use sui::clock::Clock;
use sui::coin::{Self as coin, Coin};
use sui::sui::SUI;

#[spec_only]
fun comments_fee_context_bound(
    tree: &comments::CommentsTree,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
): bool {
    comments::registry_id(tree) == governance::registry_id(governance_vault) &&
    comments::registry_id(tree) == governance::fee_manager_registry_id(fee_manager) &&
    comments::governance_vault_id(tree) == object::id(governance_vault) &&
    comments::fee_manager_id(tree) == governance::fee_manager_id(fee_manager)
}

#[spec(prove, target = paperproof_comments::comments::new_tree_factory_cap)]
fun new_tree_factory_cap_spec(
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    ctx: &mut TxContext,
): comments::TreeFactoryCap {
    let sender = tx_context::sender(ctx);
    asserts(
        sender == governance::governance_authority(governance_vault) ||
        sender == governance::upgrade_authority(governance_vault)
    );
    asserts(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(governance_vault));
    comments::new_tree_factory_cap(governance_vault, fee_manager, ctx)
}

#[spec(prove, target = paperproof_comments::comments::new_tree)]
fun new_tree_spec(
    tree_factory_cap: &comments::TreeFactoryCap,
    registry_id: ID,
    governance_vault_id: ID,
    fee_manager_id: ID,
    owner: address,
    target_key: String,
    target_series_id: ID,
    target_artifact_type: u8,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): (comments::CommentsTree, comments::LikesBook) {
    asserts(comments::tree_factory_cap_registry_id(tree_factory_cap) == registry_id);
    asserts(string::length(&target_key) > 0);
    let (tree, book) = comments::new_tree(
        tree_factory_cap,
        registry_id,
        governance_vault_id,
        fee_manager_id,
        owner,
        target_key,
        target_series_id,
        target_artifact_type,
        clock_ref,
        ctx,
    );
    ensures(comments::registry_id(&tree) == registry_id);
    ensures(comments::governance_vault_id(&tree) == governance_vault_id);
    ensures(comments::fee_manager_id(&tree) == fee_manager_id);
    ensures(comments::target_series_id(&tree) == target_series_id);
    ensures(comments::target_artifact_type(&tree) == target_artifact_type);
    ensures(comments::likes_book_registry_id(&book) == registry_id);
    ensures(comments::likes_book_target_series_id(&book) == target_series_id);
    ensures(comments::likes_book_target_artifact_type(&book) == target_artifact_type);
    ensures(comments::root_comment_id(&tree) == 0);
    ensures(comments::next_comment_id(&tree) == 1);
    ensures(comments::total_comments(&tree) == 0);
    ensures(comments::tree_status(&tree) == comments::tree_status_open());
    (tree, book)
}

#[spec(prove, target = paperproof_comments::comments::add_onchain_comment)]
fun add_onchain_comment_spec(
    tree: &mut comments::CommentsTree,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    parent_comment_id: u64,
    content: vector<u8>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    requires(comments::tree_version(tree) == comments::current_tree_version());
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(comments::tree_status(tree) == comments::tree_status_open());
    asserts(parent_comment_id == comments::root_comment_id(tree));
    asserts(comments::comment_depth(comments::borrow_comment(tree, parent_comment_id)) == 0);
    asserts(comments::comment_author(comments::borrow_comment(tree, parent_comment_id)) == comments::creator(tree));
    asserts(vector::length(&content) > 0);
    asserts(vector::length(&content) <= comments::max_onchain_comment_bytes(tree));
    asserts(comments::max_comment_depth(tree) >= 1);
    asserts(comments::total_comments(tree) == 0);
    asserts(comments::next_comment_id(tree) == 1);
    asserts(comments_fee_context_bound(tree, governance_vault, fee_manager));
    let registry_id = comments::registry_id(tree);
    let governance_vault_id = comments::governance_vault_id(tree);
    let fee_manager_id = comments::fee_manager_id(tree);
    let target_series_id = comments::target_series_id(tree);
    let target_artifact_type = comments::target_artifact_type(tree);
    let likes_book_id = comments::tree_likes_book_id(tree);
    let old_root_children = comments::children_count(comments::borrow_comment(tree, parent_comment_id));
    comments::add_onchain_comment(
        tree,
        governance_vault,
        fee_manager,
        parent_comment_id,
        content,
        payment,
        clock_ref,
        ctx,
    );
    ensures(comments::total_comments(tree) == 1);
    ensures(comments::next_comment_id(tree) == 2);
    ensures(comments::has_comment(tree, 1));
    ensures(comments::comment_depth(comments::borrow_comment(tree, 1)) == 1);
    ensures(comments::comment_author(comments::borrow_comment(tree, 1)) == tx_context::sender(ctx));
    ensures(comments::content_mode(comments::borrow_comment(tree, 1)) == comments::comment_mode_onchain());
    ensures(comments::comment_status_is(tree, 1, comments::comment_status_active()));
    ensures(comments::registry_id(tree) == registry_id);
    ensures(comments::governance_vault_id(tree) == governance_vault_id);
    ensures(comments::fee_manager_id(tree) == fee_manager_id);
    ensures(comments::target_series_id(tree) == target_series_id);
    ensures(comments::target_artifact_type(tree) == target_artifact_type);
    ensures(comments::tree_likes_book_id(tree) == likes_book_id);
    ensures(comments::children_count(comments::borrow_comment(tree, parent_comment_id)) == old_root_children + 1);
}

#[spec(prove, target = paperproof_comments::comments::add_blob_comment)]
fun add_blob_comment_spec(
    tree: &mut comments::CommentsTree,
    governance_vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    parent_comment_id: u64,
    blob_id: vector<u8>,
    blob_object_id: Option<ID>,
    blob_digest: vector<u8>,
    content_preview: vector<u8>,
    payment: Option<Coin<SUI>>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
) {
    requires(comments::tree_version(tree) == comments::current_tree_version());
    asserts(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    asserts(comments::tree_status(tree) == comments::tree_status_open());
    asserts(parent_comment_id == comments::root_comment_id(tree));
    asserts(comments::comment_depth(comments::borrow_comment(tree, parent_comment_id)) == 0);
    asserts(comments::comment_author(comments::borrow_comment(tree, parent_comment_id)) == comments::creator(tree));
    asserts(vector::length(&blob_id) > 0);
    asserts(vector::length(&blob_id) <= 128);
    asserts(vector::length(&blob_digest) > 0);
    asserts(vector::length(&blob_digest) <= 128);
    asserts(vector::length(&content_preview) <= 256);
    asserts(comments::max_comment_depth(tree) >= 1);
    asserts(comments::total_comments(tree) == 0);
    asserts(comments::next_comment_id(tree) == 1);
    asserts(comments_fee_context_bound(tree, governance_vault, fee_manager));
    let registry_id = comments::registry_id(tree);
    let governance_vault_id = comments::governance_vault_id(tree);
    let fee_manager_id = comments::fee_manager_id(tree);
    let target_series_id = comments::target_series_id(tree);
    let target_artifact_type = comments::target_artifact_type(tree);
    let likes_book_id = comments::tree_likes_book_id(tree);
    let old_root_children = comments::children_count(comments::borrow_comment(tree, parent_comment_id));
    comments::add_blob_comment(
        tree,
        governance_vault,
        fee_manager,
        parent_comment_id,
        blob_id,
        blob_object_id,
        blob_digest,
        content_preview,
        payment,
        clock_ref,
        ctx,
    );
    ensures(comments::total_comments(tree) == 1);
    ensures(comments::next_comment_id(tree) == 2);
    ensures(comments::has_comment(tree, 1));
    ensures(comments::comment_depth(comments::borrow_comment(tree, 1)) == 1);
    ensures(comments::comment_author(comments::borrow_comment(tree, 1)) == tx_context::sender(ctx));
    ensures(comments::content_mode(comments::borrow_comment(tree, 1)) == comments::comment_mode_blob());
    ensures(comments::comment_status_is(tree, 1, comments::comment_status_active()));
    ensures(comments::registry_id(tree) == registry_id);
    ensures(comments::governance_vault_id(tree) == governance_vault_id);
    ensures(comments::fee_manager_id(tree) == fee_manager_id);
    ensures(comments::target_series_id(tree) == target_series_id);
    ensures(comments::target_artifact_type(tree) == target_artifact_type);
    ensures(comments::tree_likes_book_id(tree) == likes_book_id);
    ensures(comments::children_count(comments::borrow_comment(tree, parent_comment_id)) == old_root_children + 1);
}

#[spec(prove, target = paperproof_comments::comments::set_comment_status)]
fun set_comment_status_spec(
    tree: &mut comments::CommentsTree,
    comment_id: u64,
    new_status: u8,
    ctx: &TxContext,
) {
    requires(comments::tree_version(tree) == comments::current_tree_version());
    requires(new_status == comments::comment_status_deleted());
    requires(comments::root_comment_id(tree) == 0);
    requires(comment_id == 1);
    requires(comments::has_comment(tree, comment_id));
    requires(comments::comment_owned_by(tree, comment_id, tx_context::sender(ctx)));
    requires(!comments::comment_status_is(tree, comment_id, comments::comment_status_deleted()));
    let sender = tx_context::sender(ctx);
    let tree_status = comments::tree_status(tree);
    let total_comments = comments::total_comments(tree);
    let next_comment_id = comments::next_comment_id(tree);
    let old_depth = comments::comment_depth(comments::borrow_comment(tree, comment_id));
    comments::set_comment_status(tree, comment_id, new_status, ctx);
    ensures(comments::comment_status_is(tree, comment_id, comments::comment_status_deleted()));
    ensures(comment_id != comments::root_comment_id(tree));
    ensures(comments::comment_owned_by(tree, comment_id, sender));
    ensures(comments::comment_depth(comments::borrow_comment(tree, comment_id)) == old_depth);
    ensures(comments::tree_status(tree) == tree_status);
    ensures(comments::total_comments(tree) == total_comments);
    ensures(comments::next_comment_id(tree) == next_comment_id);
}

#[spec(prove, target = paperproof_comments::comments::transfer_tree_owner)]
fun transfer_tree_owner_spec(
    tree: &mut comments::CommentsTree,
    new_owner: address,
    ctx: &TxContext,
) {
    requires(comments::tree_version(tree) == comments::current_tree_version());
    requires(comments::tree_owned_by(tree, tx_context::sender(ctx)));
    requires(new_owner != @0x0);
    let registry_id = comments::registry_id(tree);
    let governance_vault_id = comments::governance_vault_id(tree);
    let fee_manager_id = comments::fee_manager_id(tree);
    let target_series_id = comments::target_series_id(tree);
    let target_artifact_type = comments::target_artifact_type(tree);
    let likes_book_id = comments::tree_likes_book_id(tree);
    comments::transfer_tree_owner(tree, new_owner, ctx);
    ensures(comments::tree_owned_by(tree, new_owner));
    ensures(comments::registry_id(tree) == registry_id);
    ensures(comments::governance_vault_id(tree) == governance_vault_id);
    ensures(comments::fee_manager_id(tree) == fee_manager_id);
    ensures(comments::target_series_id(tree) == target_series_id);
    ensures(comments::target_artifact_type(tree) == target_artifact_type);
    ensures(comments::tree_likes_book_id(tree) == likes_book_id);
}

#[spec(prove, target = paperproof_comments::comments::borrow_comment)]
fun borrow_comment_spec(
    tree: &comments::CommentsTree,
    comment_id: u64,
): &comments::CommentNode {
    requires(comments::has_comment(tree, comment_id));
    let result = comments::borrow_comment(tree, comment_id);
    ensures(comments::comment_id(result) == comment_id);
    result
}

#[spec(prove, target = paperproof_comments::comments::borrow_comment_mut)]
fun borrow_comment_mut_spec(
    tree: &mut comments::CommentsTree,
    comment_id: u64,
): &mut comments::CommentNode {
    requires(comments::has_comment(tree, comment_id));
    let result = comments::borrow_comment_mut(tree, comment_id);
    ensures(comments::comment_id(result) == comment_id);
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_id)]
fun tree_id_spec(tree: &comments::CommentsTree): ID {
    let result = comments::tree_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_version)]
fun tree_version_spec(tree: &comments::CommentsTree): u64 {
    let result = comments::tree_version(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::current_tree_version)]
fun current_tree_version_spec(): u64 {
    let result = comments::current_tree_version();
    result
}

#[spec(prove, target = paperproof_comments::comments::owner)]
fun owner_spec(tree: &comments::CommentsTree): address {
    let result = comments::owner(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::creator)]
fun creator_spec(tree: &comments::CommentsTree): address {
    let result = comments::creator(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::registry_id)]
fun registry_id_spec(tree: &comments::CommentsTree): ID {
    let result = comments::registry_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::governance_vault_id)]
fun governance_vault_id_spec(tree: &comments::CommentsTree): ID {
    let result = comments::governance_vault_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::fee_manager_id)]
fun fee_manager_id_spec(tree: &comments::CommentsTree): ID {
    let result = comments::fee_manager_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_factory_cap_registry_id)]
fun tree_factory_cap_registry_id_spec(cap: &comments::TreeFactoryCap): ID {
    let result = comments::tree_factory_cap_registry_id(cap);
    result
}

#[spec(prove, target = paperproof_comments::comments::target_key)]
fun target_key_spec(tree: &comments::CommentsTree): &String {
    let result = comments::target_key(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::target_series_id)]
fun target_series_id_spec(tree: &comments::CommentsTree): ID {
    let result = comments::target_series_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::target_artifact_type)]
fun target_artifact_type_spec(tree: &comments::CommentsTree): u8 {
    let result = comments::target_artifact_type(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_likes_book_id)]
fun tree_likes_book_id_spec(tree: &comments::CommentsTree): ID {
    let result = comments::tree_likes_book_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::root_comment_id)]
fun root_comment_id_spec(tree: &comments::CommentsTree): u64 {
    let result = comments::root_comment_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::total_comments)]
fun total_comments_spec(tree: &comments::CommentsTree): u64 {
    let result = comments::total_comments(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::next_comment_id)]
fun next_comment_id_spec(tree: &comments::CommentsTree): u64 {
    let result = comments::next_comment_id(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::max_onchain_comment_bytes)]
fun max_onchain_comment_bytes_spec(tree: &comments::CommentsTree): u64 {
    let result = comments::max_onchain_comment_bytes(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::max_comment_depth)]
fun max_comment_depth_spec(tree: &comments::CommentsTree): u16 {
    let result = comments::max_comment_depth(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::likes_book_id)]
fun likes_book_id_spec(book: &comments::LikesBook): ID {
    let result = comments::likes_book_id(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::likes_book_version)]
fun likes_book_version_spec(book: &comments::LikesBook): u64 {
    let result = comments::likes_book_version(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::likes_book_registry_id)]
fun likes_book_registry_id_spec(book: &comments::LikesBook): ID {
    let result = comments::likes_book_registry_id(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::likes_book_comments_tree_id)]
fun likes_book_comments_tree_id_spec(book: &comments::LikesBook): ID {
    let result = comments::likes_book_comments_tree_id(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::likes_book_target_series_id)]
fun likes_book_target_series_id_spec(book: &comments::LikesBook): ID {
    let result = comments::likes_book_target_series_id(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::likes_book_target_artifact_type)]
fun likes_book_target_artifact_type_spec(book: &comments::LikesBook): u8 {
    let result = comments::likes_book_target_artifact_type(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::like_count)]
fun like_count_spec(book: &comments::LikesBook): u64 {
    let result = comments::like_count(book);
    result
}

#[spec(prove, target = paperproof_comments::comments::has_liked)]
fun has_liked_spec(book: &comments::LikesBook, liker: address): bool {
    let result = comments::has_liked(book, liker);
    result
}

#[spec(prove, target = paperproof_comments::comments::has_comment)]
fun has_comment_spec(tree: &comments::CommentsTree, comment_id: u64): bool {
    let result = comments::has_comment(tree, comment_id);
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_id)]
fun comment_id_spec(node: &comments::CommentNode): u64 {
    let result = comments::comment_id(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::parent_comment_id)]
fun parent_comment_id_spec(node: &comments::CommentNode): &Option<u64> {
    let result = comments::parent_comment_id(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_author)]
fun comment_author_spec(node: &comments::CommentNode): address {
    let result = comments::comment_author(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_depth)]
fun comment_depth_spec(node: &comments::CommentNode): u16 {
    let result = comments::comment_depth(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::content_mode)]
fun content_mode_spec(node: &comments::CommentNode): u8 {
    let result = comments::content_mode(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::inline_content)]
fun inline_content_spec(node: &comments::CommentNode): &vector<u8> {
    let result = comments::inline_content(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::content_preview)]
fun content_preview_spec(node: &comments::CommentNode): &vector<u8> {
    let result = comments::content_preview(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::blob_id)]
fun blob_id_spec(node: &comments::CommentNode): &vector<u8> {
    let result = comments::blob_id(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::blob_object_id)]
fun blob_object_id_spec(node: &comments::CommentNode): &Option<ID> {
    let result = comments::blob_object_id(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::blob_digest)]
fun blob_digest_spec(node: &comments::CommentNode): &vector<u8> {
    let result = comments::blob_digest(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::children_count)]
fun children_count_spec(node: &comments::CommentNode): u64 {
    let result = comments::children_count(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::created_at_ms)]
fun created_at_ms_spec(node: &comments::CommentNode): u64 {
    let result = comments::created_at_ms(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::status)]
fun status_spec(node: &comments::CommentNode): u8 {
    let result = comments::status(node);
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_owned_by)]
fun comment_owned_by_spec(
    tree: &comments::CommentsTree,
    comment_id: u64,
    author: address,
): bool {
    let result = comments::comment_owned_by(tree, comment_id, author);
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_status_is)]
fun comment_status_is_spec(
    tree: &comments::CommentsTree,
    comment_id: u64,
    status: u8,
): bool {
    let result = comments::comment_status_is(tree, comment_id, status);
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_owned_by)]
fun tree_owned_by_spec(tree: &comments::CommentsTree, owner: address): bool {
    let result = comments::tree_owned_by(tree, owner);
    result
}

#[spec(prove, target = paperproof_comments::comments::minimum_pprf_for_like)]
fun minimum_pprf_for_like_spec(): u64 {
    let result = comments::minimum_pprf_for_like();
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_status)]
fun tree_status_spec(tree: &comments::CommentsTree): u8 {
    let result = comments::tree_status(tree);
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_status_open)]
fun tree_status_open_spec(): u8 {
    let result = comments::tree_status_open();
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_status_locked)]
fun tree_status_locked_spec(): u8 {
    let result = comments::tree_status_locked();
    result
}

#[spec(prove, target = paperproof_comments::comments::tree_status_archived)]
fun tree_status_archived_spec(): u8 {
    let result = comments::tree_status_archived();
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_mode_onchain)]
fun comment_mode_onchain_spec(): u8 {
    let result = comments::comment_mode_onchain();
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_mode_blob)]
fun comment_mode_blob_spec(): u8 {
    let result = comments::comment_mode_blob();
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_status_active)]
fun comment_status_active_spec(): u8 {
    let result = comments::comment_status_active();
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_status_hidden)]
fun comment_status_hidden_spec(): u8 {
    let result = comments::comment_status_hidden();
    result
}

#[spec(prove, target = paperproof_comments::comments::comment_status_deleted)]
fun comment_status_deleted_spec(): u8 {
    let result = comments::comment_status_deleted();
    result
}

#[spec(prove, target = paperproof_comments::comments::set_tree_status)]
fun set_tree_status_spec(
    tree: &mut comments::CommentsTree,
    new_status: u8,
    ctx: &TxContext,
) {
    asserts(comments::tree_version(tree) == comments::current_tree_version());
    requires(comments::tree_owned_by(tree, tx_context::sender(ctx)));
    requires(
        new_status == comments::tree_status_open() ||
        new_status == comments::tree_status_locked() ||
        new_status == comments::tree_status_archived()
    );
    let sender = tx_context::sender(ctx);
    let total_comments = comments::total_comments(tree);
    let next_comment_id = comments::next_comment_id(tree);
    comments::set_tree_status(tree, new_status, ctx);
    ensures(comments::tree_status(tree) == new_status);
    ensures(comments::tree_owned_by(tree, sender));
    ensures(comments::total_comments(tree) == total_comments);
    ensures(comments::next_comment_id(tree) == next_comment_id);
}

#[spec(prove, target = paperproof_comments::comments::like_paper)]
fun like_paper_spec(
    book: &mut comments::LikesBook,
    pprf_proof: &Coin<PPRF>,
    ctx: &TxContext,
) {
    requires(comments::likes_book_version(book) == comments::current_tree_version());
    requires(coin::value(pprf_proof) >= comments::minimum_pprf_for_like());
    requires(!comments::has_liked(book, tx_context::sender(ctx)));
    requires(comments::like_count(book) < std::u64::max_value!());
    let old_count = comments::like_count(book);
    comments::like_paper(book, pprf_proof, ctx);
    ensures(comments::has_liked(book, tx_context::sender(ctx)));
    ensures(comments::like_count(book) == old_count + 1);
}

#[spec(prove, target = paperproof_comments::comments::unlike_paper)]
fun unlike_paper_spec(
    book: &mut comments::LikesBook,
    pprf_proof: &Coin<PPRF>,
    ctx: &TxContext,
) {
    requires(comments::likes_book_version(book) == comments::current_tree_version());
    requires(coin::value(pprf_proof) >= comments::minimum_pprf_for_like());
    requires(comments::has_liked(book, tx_context::sender(ctx)));
    requires(comments::like_count(book) > 0);
    let old_count = comments::like_count(book);
    comments::unlike_paper(book, pprf_proof, ctx);
    ensures(!comments::has_liked(book, tx_context::sender(ctx)));
    ensures(comments::like_count(book) == old_count - 1);
}

#[spec(prove, target = paperproof_comments::comments::migrate_tree)]
fun migrate_tree_spec(
    tree: &mut comments::CommentsTree,
    governance_vault: &governance::GovernanceVault,
    ctx: &TxContext,
) {
    requires(governance::governance_vault_version(governance_vault) == governance::current_governance_vault_version());
    requires(comments::registry_id(tree) == governance::registry_id(governance_vault));
    requires(tx_context::sender(ctx) == governance::upgrade_authority(governance_vault));
    requires(comments::tree_version(tree) <= comments::current_tree_version());
    let tree_id = comments::tree_id(tree);
    let owner = comments::owner(tree);
    let registry_id = comments::registry_id(tree);
    let governance_vault_id = comments::governance_vault_id(tree);
    let fee_manager_id = comments::fee_manager_id(tree);
    let target_series_id = comments::target_series_id(tree);
    let target_artifact_type = comments::target_artifact_type(tree);
    let likes_book_id = comments::tree_likes_book_id(tree);
    let root_comment_id = comments::root_comment_id(tree);
    let total_comments = comments::total_comments(tree);
    let next_comment_id = comments::next_comment_id(tree);
    comments::migrate_tree(tree, governance_vault, ctx);
    ensures(comments::tree_version(tree) == comments::current_tree_version());
    ensures(comments::tree_id(tree) == tree_id);
    ensures(comments::owner(tree) == owner);
    ensures(comments::registry_id(tree) == registry_id);
    ensures(comments::governance_vault_id(tree) == governance_vault_id);
    ensures(comments::fee_manager_id(tree) == fee_manager_id);
    ensures(comments::target_series_id(tree) == target_series_id);
    ensures(comments::target_artifact_type(tree) == target_artifact_type);
    ensures(comments::tree_likes_book_id(tree) == likes_book_id);
    ensures(comments::root_comment_id(tree) == root_comment_id);
    ensures(comments::total_comments(tree) == total_comments);
    ensures(comments::next_comment_id(tree) == next_comment_id);
}

#[spec(prove, target = paperproof_comments::comments::share_tree)]
fun share_tree_spec(tree: comments::CommentsTree) {
    comments::share_tree(tree)
}

#[spec(prove, target = paperproof_comments::comments::share_likes_book)]
fun share_likes_book_spec(book: comments::LikesBook) {
    comments::share_likes_book(book)
}
