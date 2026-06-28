// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_shared_controller::controller;

use std::string::{Self as string, String};
use sui::clock::{Self as clock, Clock};
use sui::dynamic_field as df;
use sui::event;

const E_UNSUPPORTED_CONTROLLER_NFT_VERSION: u64 = 1;
const E_UNSUPPORTED_CONTROL_RECORD_VERSION: u64 = 2;
const E_CONTROL_ALREADY_ENABLED: u64 = 3;
const E_CONTROL_NOT_ENABLED: u64 = 4;
const E_INVALID_AUTHORITY_MODE: u64 = 5;
const E_LEGACY_WRITE_DISABLED: u64 = 6;
const E_INVALID_CONTROL_RECORD: u64 = 7;
const E_INVALID_CONTROLLER_NFT: u64 = 8;
const E_TRANSFER_LOCKED: u64 = 9;
const E_INVALID_TREE_BINDING: u64 = 10;

const CONTROLLER_NFT_VERSION: u64 = 1;
const CONTROL_RECORD_VERSION: u64 = 1;

const AUTHORITY_MODE_LEGACY_OWNER_ONLY: u8 = 0;
const AUTHORITY_MODE_DUAL: u8 = 1;
const AUTHORITY_MODE_CONTROLLER_PRIMARY: u8 = 2;
const AUTHORITY_MODE_CONTROLLER_ONLY: u8 = 3;

const CONTROLLER_IMAGE_URL_BYTES: vector<u8> =
    b"https://aggregator.walrus-mainnet.walrus.space/v1/blobs/46egR1yyhHVRNdNx72ICBQ99AiywUaMwfi00CDYznUI";
const CONTROL_RIGHT_ARTIFACT_CONTROLLER_BYTES: vector<u8> = b"artifact_controller";
const AUTHORITY_MODE_LEGACY_OWNER_ONLY_BYTES: vector<u8> = b"legacy_owner_only";
const AUTHORITY_MODE_DUAL_BYTES: vector<u8> = b"dual_mode";
const AUTHORITY_MODE_CONTROLLER_PRIMARY_BYTES: vector<u8> = b"controller_primary";
const AUTHORITY_MODE_CONTROLLER_ONLY_BYTES: vector<u8> = b"controller_only";

public struct ControllerNFT has key, store {
    id: UID,
    version: u64,
    series_id: ID,
    artifact_code: String,
    artifact_type_name: String,
    control_right: String,
    authority_mode_name: String,
    image_url: String,
    artifact_type: u8,
    control_record_id: ID,
    issued_at_ms: u64,
}

public struct ArtifactControlRecord has key {
    id: UID,
    version: u64,
    series_id: ID,
    comments_tree_id: ID,
    artifact_type: u8,
    controller_nft_id: ID,
    current_controller_mirror: address,
    legacy_series_owner_mirror: address,
    legacy_comments_owner_mirror: address,
    authority_mode: u8,
    transfer_locked: bool,
    created_at_ms: u64,
    updated_at_ms: u64,
}

public struct SeriesControlStateKey has copy, drop, store {}
public struct TreeControlStateKey has copy, drop, store {}

public struct SeriesControlState has copy, drop, store {
    control_record_id: ID,
    controller_nft_id: ID,
    artifact_type: u8,
    authority_mode: u8,
}

public struct TreeControlState has copy, drop, store {
    control_record_id: ID,
    controller_nft_id: ID,
    series_id: ID,
    artifact_type: u8,
    authority_mode: u8,
}

public struct ControllerNftMintedForSeriesEvent has copy, drop {
    series_id: ID,
    comments_tree_id: ID,
    artifact_type: u8,
    controller_nft_id: ID,
    control_record_id: ID,
    minted_to: address,
    authority_mode: u8,
    created_at_ms: u64,
}

public struct ArtifactControlRecordCreatedEvent has copy, drop {
    series_id: ID,
    comments_tree_id: ID,
    artifact_type: u8,
    control_record_id: ID,
    controller_nft_id: ID,
    current_controller_mirror: address,
    authority_mode: u8,
    created_at_ms: u64,
}

public struct ArtifactControllerModeChangedEvent has copy, drop {
    series_id: ID,
    comments_tree_id: ID,
    artifact_type: u8,
    control_record_id: ID,
    controller_nft_id: ID,
    changed_by: address,
    old_mode: u8,
    new_mode: u8,
    changed_at_ms: u64,
}

public struct ArtifactControllerMirrorSyncedEvent has copy, drop {
    series_id: ID,
    comments_tree_id: ID,
    artifact_type: u8,
    control_record_id: ID,
    controller_nft_id: ID,
    synced_by: address,
    controller_mirror: address,
    legacy_series_owner_mirror: address,
    legacy_comments_owner_mirror: address,
    synced_at_ms: u64,
}

public struct ArtifactControllerMirrorRepairEvent has copy, drop {
    series_id: ID,
    comments_tree_id: ID,
    artifact_type: u8,
    control_record_id: ID,
    controller_nft_id: ID,
    repaired_by: address,
    controller_mirror: address,
    legacy_series_owner_mirror: address,
    legacy_comments_owner_mirror: address,
    repaired_at_ms: u64,
}

public fun enable_control(
    series_uid: &mut UID,
    tree_uid: &mut UID,
    series_id: ID,
    comments_tree_id: ID,
    artifact_code: String,
    artifact_type_name: String,
    artifact_type: u8,
    legacy_series_owner: address,
    legacy_comments_owner: address,
    initial_mode: u8,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): (ArtifactControlRecord, ControllerNFT) {
    assert_valid_authority_mode(initial_mode);
    assert!(initial_mode != AUTHORITY_MODE_LEGACY_OWNER_ONLY, E_INVALID_AUTHORITY_MODE);
    assert!(!df::exists<SeriesControlStateKey>(series_uid, SeriesControlStateKey {}), E_CONTROL_ALREADY_ENABLED);
    assert!(!df::exists<TreeControlStateKey>(tree_uid, TreeControlStateKey {}), E_CONTROL_ALREADY_ENABLED);

    let now = clock::timestamp_ms(clock_ref);
    let sender = tx_context::sender(ctx);
    let record_uid = object::new(ctx);
    let record_id = *record_uid.as_inner();
    let nft_uid = object::new(ctx);
    let nft_id = *nft_uid.as_inner();

    let record = ArtifactControlRecord {
        id: record_uid,
        version: CONTROL_RECORD_VERSION,
        series_id,
        comments_tree_id,
        artifact_type,
        controller_nft_id: nft_id,
        current_controller_mirror: sender,
        legacy_series_owner_mirror: legacy_series_owner,
        legacy_comments_owner_mirror: legacy_comments_owner,
        authority_mode: initial_mode,
        transfer_locked: false,
        created_at_ms: now,
        updated_at_ms: now,
    };

    let nft = ControllerNFT {
        id: nft_uid,
        version: CONTROLLER_NFT_VERSION,
        series_id,
        artifact_code,
        artifact_type_name,
        control_right: string::utf8(CONTROL_RIGHT_ARTIFACT_CONTROLLER_BYTES),
        authority_mode_name: authority_mode_name(initial_mode),
        image_url: string::utf8(CONTROLLER_IMAGE_URL_BYTES),
        artifact_type,
        control_record_id: record_id,
        issued_at_ms: now,
    };

    df::add(series_uid, SeriesControlStateKey {}, SeriesControlState {
        control_record_id: record_id,
        controller_nft_id: nft_id,
        artifact_type,
        authority_mode: initial_mode,
    });
    df::add(tree_uid, TreeControlStateKey {}, TreeControlState {
        control_record_id: record_id,
        controller_nft_id: nft_id,
        series_id,
        artifact_type,
        authority_mode: initial_mode,
    });

    event::emit(ArtifactControlRecordCreatedEvent {
        series_id,
        comments_tree_id,
        artifact_type,
        control_record_id: record_id,
        controller_nft_id: nft_id,
        current_controller_mirror: sender,
        authority_mode: initial_mode,
        created_at_ms: now,
    });
    event::emit(ControllerNftMintedForSeriesEvent {
        series_id,
        comments_tree_id,
        artifact_type,
        controller_nft_id: nft_id,
        control_record_id: record_id,
        minted_to: sender,
        authority_mode: initial_mode,
        created_at_ms: now,
    });

    (record, nft)
}

public fun is_series_control_enabled(series_uid: &UID): bool {
    df::exists<SeriesControlStateKey>(series_uid, SeriesControlStateKey {})
}

public fun is_tree_control_enabled(tree_uid: &UID): bool {
    df::exists<TreeControlStateKey>(tree_uid, TreeControlStateKey {})
}

public fun series_authority_mode(series_uid: &UID): u8 {
    if (!is_series_control_enabled(series_uid)) {
        AUTHORITY_MODE_LEGACY_OWNER_ONLY
    } else {
        df::borrow<SeriesControlStateKey, SeriesControlState>(series_uid, SeriesControlStateKey {}).authority_mode
    }
}

public fun tree_authority_mode(tree_uid: &UID): u8 {
    if (!is_tree_control_enabled(tree_uid)) {
        AUTHORITY_MODE_LEGACY_OWNER_ONLY
    } else {
        df::borrow<TreeControlStateKey, TreeControlState>(tree_uid, TreeControlStateKey {}).authority_mode
    }
}

public fun series_control_record_id(series_uid: &UID): Option<ID> {
    if (!is_series_control_enabled(series_uid)) {
        option::none()
    } else {
        option::some(df::borrow<SeriesControlStateKey, SeriesControlState>(series_uid, SeriesControlStateKey {}).control_record_id)
    }
}

public fun series_controller_nft_id(series_uid: &UID): Option<ID> {
    if (!is_series_control_enabled(series_uid)) {
        option::none()
    } else {
        option::some(df::borrow<SeriesControlStateKey, SeriesControlState>(series_uid, SeriesControlStateKey {}).controller_nft_id)
    }
}

public fun tree_control_record_id(tree_uid: &UID): Option<ID> {
    if (!is_tree_control_enabled(tree_uid)) {
        option::none()
    } else {
        option::some(df::borrow<TreeControlStateKey, TreeControlState>(tree_uid, TreeControlStateKey {}).control_record_id)
    }
}

public fun tree_controller_nft_id(tree_uid: &UID): Option<ID> {
    if (!is_tree_control_enabled(tree_uid)) {
        option::none()
    } else {
        option::some(df::borrow<TreeControlStateKey, TreeControlState>(tree_uid, TreeControlStateKey {}).controller_nft_id)
    }
}

public fun assert_series_legacy_write_allowed(series_uid: &UID) {
    if (is_series_control_enabled(series_uid)) {
        let state = df::borrow<SeriesControlStateKey, SeriesControlState>(series_uid, SeriesControlStateKey {});
        assert!(
            state.authority_mode == AUTHORITY_MODE_LEGACY_OWNER_ONLY ||
            state.authority_mode == AUTHORITY_MODE_DUAL,
            E_LEGACY_WRITE_DISABLED,
        );
    };
}

public fun assert_tree_legacy_write_allowed(tree_uid: &UID) {
    if (is_tree_control_enabled(tree_uid)) {
        let state = df::borrow<TreeControlStateKey, TreeControlState>(tree_uid, TreeControlStateKey {});
        assert!(
            state.authority_mode == AUTHORITY_MODE_LEGACY_OWNER_ONLY ||
            state.authority_mode == AUTHORITY_MODE_DUAL,
            E_LEGACY_WRITE_DISABLED,
        );
    };
}

public fun assert_controller_for_series(
    series_uid: &UID,
    series_id: ID,
    expected_artifact_type: u8,
    record: &ArtifactControlRecord,
    nft: &ControllerNFT,
    _ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(is_series_control_enabled(series_uid), E_CONTROL_NOT_ENABLED);
    let state = df::borrow<SeriesControlStateKey, SeriesControlState>(series_uid, SeriesControlStateKey {});
    assert!(state.control_record_id == object::id(record), E_INVALID_CONTROL_RECORD);
    assert!(state.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    assert!(state.artifact_type == expected_artifact_type, E_INVALID_CONTROLLER_NFT);
    assert!(record.series_id == series_id, E_INVALID_CONTROL_RECORD);
    assert!(record.artifact_type == expected_artifact_type, E_INVALID_CONTROL_RECORD);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROL_RECORD);
    assert!(record.authority_mode == state.authority_mode, E_INVALID_CONTROL_RECORD);
    assert!(nft.series_id == series_id, E_INVALID_CONTROLLER_NFT);
    assert!(nft.artifact_type == expected_artifact_type, E_INVALID_CONTROLLER_NFT);
    assert!(nft.control_record_id == object::id(record), E_INVALID_CONTROLLER_NFT);
    assert!(record.authority_mode != AUTHORITY_MODE_LEGACY_OWNER_ONLY, E_INVALID_AUTHORITY_MODE);
    assert!(!record.transfer_locked, E_TRANSFER_LOCKED);
}

public fun assert_controller_for_tree(
    tree_uid: &UID,
    tree_id: ID,
    expected_series_id: ID,
    expected_artifact_type: u8,
    record: &ArtifactControlRecord,
    nft: &ControllerNFT,
    _ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(is_tree_control_enabled(tree_uid), E_CONTROL_NOT_ENABLED);
    let state = df::borrow<TreeControlStateKey, TreeControlState>(tree_uid, TreeControlStateKey {});
    assert!(state.control_record_id == object::id(record), E_INVALID_CONTROL_RECORD);
    assert!(state.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    assert!(state.series_id == expected_series_id, E_INVALID_TREE_BINDING);
    assert!(state.artifact_type == expected_artifact_type, E_INVALID_TREE_BINDING);
    assert!(record.comments_tree_id == tree_id, E_INVALID_TREE_BINDING);
    assert!(record.series_id == expected_series_id, E_INVALID_CONTROL_RECORD);
    assert!(record.artifact_type == expected_artifact_type, E_INVALID_CONTROL_RECORD);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROL_RECORD);
    assert!(record.authority_mode == state.authority_mode, E_INVALID_CONTROL_RECORD);
    assert!(nft.series_id == expected_series_id, E_INVALID_CONTROLLER_NFT);
    assert!(nft.artifact_type == expected_artifact_type, E_INVALID_CONTROLLER_NFT);
    assert!(nft.control_record_id == object::id(record), E_INVALID_CONTROLLER_NFT);
    assert!(record.authority_mode != AUTHORITY_MODE_LEGACY_OWNER_ONLY, E_INVALID_AUTHORITY_MODE);
    assert!(!record.transfer_locked, E_TRANSFER_LOCKED);
}

public fun sync_controller_mirror(
    record: &mut ArtifactControlRecord,
    nft: &ControllerNFT,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    let sender = tx_context::sender(ctx);
    record.current_controller_mirror = sender;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
    event::emit(ArtifactControllerMirrorSyncedEvent {
        series_id: record.series_id,
        comments_tree_id: record.comments_tree_id,
        artifact_type: record.artifact_type,
        control_record_id: object::id(record),
        controller_nft_id: object::id(nft),
        synced_by: sender,
        controller_mirror: record.current_controller_mirror,
        legacy_series_owner_mirror: record.legacy_series_owner_mirror,
        legacy_comments_owner_mirror: record.legacy_comments_owner_mirror,
        synced_at_ms: record.updated_at_ms,
    });
}

public fun sync_legacy_series_owner_mirror(
    record: &mut ArtifactControlRecord,
    nft: &ControllerNFT,
    legacy_series_owner: address,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    record.current_controller_mirror = tx_context::sender(ctx);
    record.legacy_series_owner_mirror = legacy_series_owner;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
}

public fun sync_legacy_comments_owner_mirror(
    record: &mut ArtifactControlRecord,
    nft: &ControllerNFT,
    legacy_comments_owner: address,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    record.current_controller_mirror = tx_context::sender(ctx);
    record.legacy_comments_owner_mirror = legacy_comments_owner;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
}

public fun sync_legacy_owner_mirrors(
    record: &mut ArtifactControlRecord,
    nft: &ControllerNFT,
    legacy_series_owner: address,
    legacy_comments_owner: address,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    record.current_controller_mirror = tx_context::sender(ctx);
    record.legacy_series_owner_mirror = legacy_series_owner;
    record.legacy_comments_owner_mirror = legacy_comments_owner;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
    event::emit(ArtifactControllerMirrorSyncedEvent {
        series_id: record.series_id,
        comments_tree_id: record.comments_tree_id,
        artifact_type: record.artifact_type,
        control_record_id: object::id(record),
        controller_nft_id: object::id(nft),
        synced_by: tx_context::sender(ctx),
        controller_mirror: record.current_controller_mirror,
        legacy_series_owner_mirror: record.legacy_series_owner_mirror,
        legacy_comments_owner_mirror: record.legacy_comments_owner_mirror,
        synced_at_ms: record.updated_at_ms,
    });
}

public fun repair_legacy_owner_mirrors(
    record: &mut ArtifactControlRecord,
    nft: &ControllerNFT,
    legacy_series_owner: address,
    legacy_comments_owner: address,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    record.current_controller_mirror = tx_context::sender(ctx);
    record.legacy_series_owner_mirror = legacy_series_owner;
    record.legacy_comments_owner_mirror = legacy_comments_owner;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
    event::emit(ArtifactControllerMirrorRepairEvent {
        series_id: record.series_id,
        comments_tree_id: record.comments_tree_id,
        artifact_type: record.artifact_type,
        control_record_id: object::id(record),
        controller_nft_id: object::id(nft),
        repaired_by: tx_context::sender(ctx),
        controller_mirror: record.current_controller_mirror,
        legacy_series_owner_mirror: record.legacy_series_owner_mirror,
        legacy_comments_owner_mirror: record.legacy_comments_owner_mirror,
        repaired_at_ms: record.updated_at_ms,
    });
}

public fun set_authority_mode(
    series_uid: &mut UID,
    tree_uid: &mut UID,
    record: &mut ArtifactControlRecord,
    nft: &mut ControllerNFT,
    new_mode: u8,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_valid_authority_mode(new_mode);
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(is_series_control_enabled(series_uid), E_CONTROL_NOT_ENABLED);
    assert!(is_tree_control_enabled(tree_uid), E_CONTROL_NOT_ENABLED);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    let sender = tx_context::sender(ctx);
    let old_mode = record.authority_mode;
    record.authority_mode = new_mode;
    record.current_controller_mirror = sender;
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
    nft.authority_mode_name = authority_mode_name(new_mode);
    let series_state = df::borrow_mut<SeriesControlStateKey, SeriesControlState>(series_uid, SeriesControlStateKey {});
    series_state.authority_mode = new_mode;
    let tree_state = df::borrow_mut<TreeControlStateKey, TreeControlState>(tree_uid, TreeControlStateKey {});
    tree_state.authority_mode = new_mode;
    event::emit(ArtifactControllerModeChangedEvent {
        series_id: record.series_id,
        comments_tree_id: record.comments_tree_id,
        artifact_type: record.artifact_type,
        control_record_id: object::id(record),
        controller_nft_id: object::id(nft),
        changed_by: sender,
        old_mode,
        new_mode,
        changed_at_ms: record.updated_at_ms,
    });
}

public fun set_transfer_locked(
    record: &mut ArtifactControlRecord,
    nft: &ControllerNFT,
    locked: bool,
    clock_ref: &Clock,
    ctx: &TxContext,
) {
    assert_current_record(record);
    assert_current_nft(nft);
    assert!(record.controller_nft_id == object::id(nft), E_INVALID_CONTROLLER_NFT);
    record.transfer_locked = locked;
    record.current_controller_mirror = tx_context::sender(ctx);
    record.updated_at_ms = clock::timestamp_ms(clock_ref);
}

public fun share_record_and_transfer_nft(
    record: ArtifactControlRecord,
    nft: ControllerNFT,
    recipient: address,
) {
    transfer::share_object(record);
    transfer::public_transfer(nft, recipient);
}

public fun controller_nft_name(nft: &ControllerNFT): String {
    let mut name = string::utf8(b"PaperProof Artifact Controller: ");
    string::append(&mut name, nft.artifact_code);
    name
}

public fun controller_nft_series_id(nft: &ControllerNFT): ID { nft.series_id }
public fun controller_nft_artifact_code(nft: &ControllerNFT): String { nft.artifact_code }
public fun controller_nft_artifact_type_name(nft: &ControllerNFT): String { nft.artifact_type_name }
public fun controller_nft_control_right(nft: &ControllerNFT): String { nft.control_right }
public fun controller_nft_authority_mode_name(nft: &ControllerNFT): String { nft.authority_mode_name }
public fun controller_nft_image_url(nft: &ControllerNFT): String { nft.image_url }
public fun controller_nft_artifact_type(nft: &ControllerNFT): u8 { nft.artifact_type }
public fun controller_nft_control_record_id(nft: &ControllerNFT): ID { nft.control_record_id }
public fun controller_nft_issued_at_ms(nft: &ControllerNFT): u64 { nft.issued_at_ms }

public fun control_record_series_id(record: &ArtifactControlRecord): ID { record.series_id }
public fun control_record_comments_tree_id(record: &ArtifactControlRecord): ID { record.comments_tree_id }
public fun control_record_artifact_type(record: &ArtifactControlRecord): u8 { record.artifact_type }
public fun control_record_controller_nft_id(record: &ArtifactControlRecord): ID { record.controller_nft_id }
public fun control_record_current_controller_mirror(record: &ArtifactControlRecord): address { record.current_controller_mirror }
public fun control_record_legacy_series_owner_mirror(record: &ArtifactControlRecord): address { record.legacy_series_owner_mirror }
public fun control_record_legacy_comments_owner_mirror(record: &ArtifactControlRecord): address { record.legacy_comments_owner_mirror }
public fun control_record_authority_mode(record: &ArtifactControlRecord): u8 { record.authority_mode }
public fun control_record_transfer_locked(record: &ArtifactControlRecord): bool { record.transfer_locked }
public fun control_record_created_at_ms(record: &ArtifactControlRecord): u64 { record.created_at_ms }
public fun control_record_updated_at_ms(record: &ArtifactControlRecord): u64 { record.updated_at_ms }
public fun is_series_in_dual_mode(series_uid: &UID): bool { series_authority_mode(series_uid) == AUTHORITY_MODE_DUAL }
public fun is_series_in_controller_primary_mode(series_uid: &UID): bool { series_authority_mode(series_uid) == AUTHORITY_MODE_CONTROLLER_PRIMARY }
public fun is_series_in_controller_only_mode(series_uid: &UID): bool { series_authority_mode(series_uid) == AUTHORITY_MODE_CONTROLLER_ONLY }
public fun is_tree_in_dual_mode(tree_uid: &UID): bool { tree_authority_mode(tree_uid) == AUTHORITY_MODE_DUAL }
public fun is_tree_in_controller_primary_mode(tree_uid: &UID): bool { tree_authority_mode(tree_uid) == AUTHORITY_MODE_CONTROLLER_PRIMARY }
public fun is_tree_in_controller_only_mode(tree_uid: &UID): bool { tree_authority_mode(tree_uid) == AUTHORITY_MODE_CONTROLLER_ONLY }
public fun is_control_mirror_stale(record: &ArtifactControlRecord, nft_holder: address): bool {
    record.current_controller_mirror != nft_holder ||
    record.legacy_series_owner_mirror != nft_holder ||
    record.legacy_comments_owner_mirror != nft_holder
}

public fun authority_mode_legacy_owner_only(): u8 { AUTHORITY_MODE_LEGACY_OWNER_ONLY }
public fun authority_mode_dual(): u8 { AUTHORITY_MODE_DUAL }
public fun authority_mode_controller_primary(): u8 { AUTHORITY_MODE_CONTROLLER_PRIMARY }
public fun authority_mode_controller_only(): u8 { AUTHORITY_MODE_CONTROLLER_ONLY }

fun assert_valid_authority_mode(mode: u8) {
    assert!(
        mode == AUTHORITY_MODE_LEGACY_OWNER_ONLY ||
        mode == AUTHORITY_MODE_DUAL ||
        mode == AUTHORITY_MODE_CONTROLLER_PRIMARY ||
        mode == AUTHORITY_MODE_CONTROLLER_ONLY,
        E_INVALID_AUTHORITY_MODE,
    );
}

fun assert_current_nft(nft: &ControllerNFT) {
    assert!(nft.version == CONTROLLER_NFT_VERSION, E_UNSUPPORTED_CONTROLLER_NFT_VERSION);
}

fun assert_current_record(record: &ArtifactControlRecord) {
    assert!(record.version == CONTROL_RECORD_VERSION, E_UNSUPPORTED_CONTROL_RECORD_VERSION);
}

fun authority_mode_name(mode: u8): String {
    if (mode == AUTHORITY_MODE_LEGACY_OWNER_ONLY) {
        string::utf8(AUTHORITY_MODE_LEGACY_OWNER_ONLY_BYTES)
    } else if (mode == AUTHORITY_MODE_DUAL) {
        string::utf8(AUTHORITY_MODE_DUAL_BYTES)
    } else if (mode == AUTHORITY_MODE_CONTROLLER_PRIMARY) {
        string::utf8(AUTHORITY_MODE_CONTROLLER_PRIMARY_BYTES)
    } else if (mode == AUTHORITY_MODE_CONTROLLER_ONLY) {
        string::utf8(AUTHORITY_MODE_CONTROLLER_ONLY_BYTES)
    } else {
        abort E_INVALID_AUTHORITY_MODE
    }
}
