// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available
// Use of this source code is governed by the LICENSE file in the project root.
// Public readability and auditability do not grant rights to copy, modify,
// distribute, redeploy, or commercialize this code except as expressly permitted.

module paperproof_governance::governance_voting;

use std::string::String;
use paperproof_governance::governance::{Self as governance, GovernanceVault};
use pprf::pprf::{Self as pprf, PPRF};
use sui::balance::{Self as balance, Balance};
use sui::coin::{Self as coin, Coin};
use sui::event;
use sui::table::{Self as table, Table};

const E_ZERO_TOTAL_SUPPLY: u64 = 1;
const E_PROPOSAL_CREATION_PAUSED: u64 = 2;
const E_INVALID_PROPOSAL_TYPE: u64 = 3;
const E_INVALID_ACTION_TYPE: u64 = 4;
const E_PROPOSAL_NOT_ACTIVE: u64 = 5;
const E_ALREADY_VOTED: u64 = 6;
const E_VOTING_NOT_ENDED: u64 = 7;
const E_PROPOSAL_ALREADY_FINALIZED: u64 = 8;
const E_PROPOSAL_NOT_PASSED: u64 = 9;
const E_PROPOSAL_NOT_EXECUTABLE: u64 = 10;
const E_PROPOSAL_ALREADY_EXECUTED: u64 = 11;
const E_INVALID_BOOLEAN_PAYLOAD: u64 = 12;
const E_INVALID_VAULT_REGISTRY: u64 = 13;
const E_VOTING_ALREADY_ENDED: u64 = 14;
const E_EXECUTABLE_ACTION_NOT_ALLOWED: u64 = 15;
const E_SIGNAL_ACTION_NOT_ALLOWED: u64 = 16;
const E_ACTIVE_PROPOSAL_EXISTS: u64 = 17;
const E_PROPOSAL_NOT_FINALIZED: u64 = 18;
const E_NO_VOTE_TO_CLAIM: u64 = 19;
const E_VOTING_POWER_BELOW_MINIMUM: u64 = 20;
const E_PROPOSER_STAKE_BELOW_THRESHOLD: u64 = 21;
const E_INVALID_PROPOSER_THRESHOLD: u64 = 22;
const E_UNSUPPORTED_CONFIG_VERSION: u64 = 23;
const E_UNSUPPORTED_PROPOSAL_VERSION: u64 = 24;

const PROPOSAL_TYPE_EXECUTABLE: u8 = 1;
const PROPOSAL_TYPE_SIGNAL: u8 = 2;

const ACTION_SET_PUBLISHING_FEE_LEVEL: u8 = 1;
const ACTION_SET_COMMENTS_FEE_LEVEL: u8 = 2;
const ACTION_SET_FEE_RECIPIENT: u8 = 3;
const ACTION_NOMINATE_OPERATOR: u8 = 4;
const ACTION_SET_PROPOSAL_CREATION_PAUSED: u8 = 5;
const ACTION_SET_PROPOSER_THRESHOLD: u8 = 6;
const ACTION_SET_UPGRADE_AUTHORITY: u8 = 7;

const ACTION_SIGNAL_REPLACE_OPERATOR: u8 = 101;
const ACTION_SIGNAL_FEATURE_DIRECTION: u8 = 102;
const ACTION_SIGNAL_POLICY_POSITION: u8 = 103;

const PROPOSAL_STATUS_ACTIVE: u8 = 1;
const PROPOSAL_STATUS_PASSED: u8 = 2;
const PROPOSAL_STATUS_REJECTED: u8 = 3;
const PROPOSAL_STATUS_EXECUTED: u8 = 4;

const VOTE_SIDE_YES: u8 = 1;
const VOTE_SIDE_NO: u8 = 2;

const PROPOSAL_DURATION_EPOCHS: u64 = 14;
const MIN_VOTE_STAKE: u64 = 100_000_000_000; // 100 PPRF
const DEFAULT_PROPOSER_THRESHOLD: u64 = 10_000_000_000_000_000; // 10,000,000 PPRF
const MIN_PROPOSER_THRESHOLD: u64 = 100_000_000_000_000; // 100,000 PPRF
const MAX_PROPOSER_THRESHOLD: u64 = 1_000_000_000_000_000_000; // 1,000,000,000 PPRF

const GOVERNANCE_CONFIG_VERSION: u64 = 1;
const PROPOSAL_VERSION: u64 = 1;

public struct GovernanceConfig has key {
    id: UID,
    version: u64,
    registry_id: ID,
    pprf_total_supply: u64,
    proposer_threshold: u64,
    next_proposal_id: u64,
    proposal_creation_paused: bool,
    active_proposal_id: option::Option<u64>,
    proposal_id_to_object: Table<u64, ID>,
}

public struct VoteRecord has store, drop {
    side: u8,
    voting_power: u64,
}

public struct Proposal has key {
    id: UID,
    version: u64,
    registry_id: ID,
    proposal_id: u64,
    proposer: address,
    proposal_type: u8,
    action_type: u8,
    title: String,
    description: String,
    payload_u64_1: u64,
    payload_u64_2: u64,
    payload_address: address,
    payload_object_id: option::Option<ID>,
    payload_bytes: vector<u8>,
    yes_votes: u64,
    no_votes: u64,
    yes_locked_balance: Balance<PPRF>,
    no_locked_balance: Balance<PPRF>,
    start_epoch: u64,
    end_epoch: u64,
    status: u8,
    executed: bool,
    votes: Table<address, VoteRecord>,
}

public struct GovernanceConfigCreatedEvent has copy, drop {
    registry_id: ID,
    pprf_total_supply: u64,
    proposer_threshold: u64,
    proposal_duration_epochs: u64,
}

public struct ProposalCreatedEvent has copy, drop {
    proposal_id: u64,
    proposer: address,
    proposal_type: u8,
    action_type: u8,
    proposal_object_id: ID,
    proposer_stake: u64,
}

public struct VoteCastEvent has copy, drop {
    proposal_id: u64,
    voter: address,
    side: u8,
    voting_power: u64,
}

public struct ProposalFinalizedEvent has copy, drop {
    proposal_id: u64,
    yes_votes: u64,
    no_votes: u64,
    status: u8,
}

public struct ProposalExecutedEvent has copy, drop {
    proposal_id: u64,
    action_type: u8,
}

public struct VoteClaimedEvent has copy, drop {
    proposal_id: u64,
    voter: address,
    side: u8,
    voting_power: u64,
}

public fun new_governance_config(
    vault: &GovernanceVault,
    ctx: &mut TxContext,
): GovernanceConfig {
    governance::assert_current_vault(vault);
    let pprf_total_supply = pprf::total_supply_base_units();
    assert!(pprf_total_supply > 0, E_ZERO_TOTAL_SUPPLY);

    let config = GovernanceConfig {
        id: object::new(ctx),
        version: GOVERNANCE_CONFIG_VERSION,
        registry_id: governance::registry_id(vault),
        pprf_total_supply,
        proposer_threshold: DEFAULT_PROPOSER_THRESHOLD,
        next_proposal_id: 1,
        proposal_creation_paused: false,
        active_proposal_id: option::none(),
        proposal_id_to_object: table::new(ctx),
    };

    event::emit(GovernanceConfigCreatedEvent {
        registry_id: config.registry_id,
        pprf_total_supply,
        proposer_threshold: DEFAULT_PROPOSER_THRESHOLD,
        proposal_duration_epochs: PROPOSAL_DURATION_EPOCHS,
    });

    config
}

public fun share_governance_config(config: GovernanceConfig) {
    transfer::share_object(config)
}

public fun migrate_config(
    config: &mut GovernanceConfig,
    vault: &GovernanceVault,
    ctx: &TxContext,
) {
    governance::assert_current_vault(vault);
    assert!(config.registry_id == governance::registry_id(vault), E_INVALID_VAULT_REGISTRY);
    governance::assert_upgrade_authority(vault, tx_context::sender(ctx));
    migrate_config_version(config);
}

public fun migrate_proposal(
    proposal: &mut Proposal,
    vault: &GovernanceVault,
    ctx: &TxContext,
) {
    governance::assert_current_vault(vault);
    assert!(proposal.registry_id == governance::registry_id(vault), E_INVALID_VAULT_REGISTRY);
    governance::assert_upgrade_authority(vault, tx_context::sender(ctx));
    migrate_proposal_version(proposal);
}

public fun create_proposal(
    config: &mut GovernanceConfig,
    proposal_type: u8,
    action_type: u8,
    title: String,
    description: String,
    payload_u64_1: u64,
    payload_u64_2: u64,
    payload_address: address,
    payload_object_id: option::Option<ID>,
    payload_bytes: vector<u8>,
    proposer_stake: Coin<PPRF>,
    ctx: &mut TxContext,
): u64 {
    assert_current_config(config);
    assert!(!config.proposal_creation_paused, E_PROPOSAL_CREATION_PAUSED);
    assert!(option::is_none(&config.active_proposal_id), E_ACTIVE_PROPOSAL_EXISTS);
    assert_valid_proposal_action_pair(proposal_type, action_type);

    if (proposal_type == PROPOSAL_TYPE_EXECUTABLE && action_type == ACTION_SET_PROPOSER_THRESHOLD) {
        assert_valid_proposer_threshold(payload_u64_1);
    };

    let proposer = tx_context::sender(ctx);
    let proposer_power = coin::value(&proposer_stake);
    assert!(proposer_power >= config.proposer_threshold, E_PROPOSER_STAKE_BELOW_THRESHOLD);

    let proposal_id = config.next_proposal_id;
    config.next_proposal_id = proposal_id + 1;

    let start_epoch = tx_context::epoch(ctx);
    let end_epoch = start_epoch + PROPOSAL_DURATION_EPOCHS;

    let mut proposal = Proposal {
        id: object::new(ctx),
        version: PROPOSAL_VERSION,
        registry_id: config.registry_id,
        proposal_id,
        proposer,
        proposal_type,
        action_type,
        title,
        description,
        payload_u64_1,
        payload_u64_2,
        payload_address,
        payload_object_id,
        payload_bytes,
        yes_votes: proposer_power,
        no_votes: 0,
        yes_locked_balance: balance::zero<PPRF>(),
        no_locked_balance: balance::zero<PPRF>(),
        start_epoch,
        end_epoch,
        status: PROPOSAL_STATUS_ACTIVE,
        executed: false,
        votes: table::new(ctx),
    };

    balance::join(&mut proposal.yes_locked_balance, coin::into_balance(proposer_stake));
    table::add(
        &mut proposal.votes,
        proposer,
        VoteRecord {
            side: VOTE_SIDE_YES,
            voting_power: proposer_power,
        },
    );

    let proposal_object_id = object::id(&proposal);
    table::add(&mut config.proposal_id_to_object, proposal_id, proposal_object_id);
    option::fill(&mut config.active_proposal_id, proposal_id);

    event::emit(ProposalCreatedEvent {
        proposal_id,
        proposer,
        proposal_type,
        action_type,
        proposal_object_id,
        proposer_stake: proposer_power,
    });
    event::emit(VoteCastEvent {
        proposal_id,
        voter: proposer,
        side: VOTE_SIDE_YES,
        voting_power: proposer_power,
    });

    transfer::share_object(proposal);
    proposal_id
}

public fun vote_yes(
    proposal: &mut Proposal,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
) {
    assert_current_proposal(proposal);
    cast_vote(proposal, VOTE_SIDE_YES, locked_tokens, ctx)
}

public fun vote_no(
    proposal: &mut Proposal,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
) {
    assert_current_proposal(proposal);
    cast_vote(proposal, VOTE_SIDE_NO, locked_tokens, ctx)
}

public fun finalize_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    ctx: &TxContext,
) {
    assert_current_config(config);
    assert_current_proposal(proposal);
    assert!(proposal.status == PROPOSAL_STATUS_ACTIVE, E_PROPOSAL_ALREADY_FINALIZED);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(tx_context::epoch(ctx) >= proposal.end_epoch, E_VOTING_NOT_ENDED);

    let passed =
        proposal.yes_votes * 3 >= proposal.no_votes * 4 &&
        proposal.yes_votes * 10 > config.pprf_total_supply;

    if (passed) {
        proposal.status = PROPOSAL_STATUS_PASSED;
    } else {
        proposal.status = PROPOSAL_STATUS_REJECTED;
    };

    clear_active_proposal(config, proposal.proposal_id);

    event::emit(ProposalFinalizedEvent {
        proposal_id: proposal.proposal_id,
        yes_votes: proposal.yes_votes,
        no_votes: proposal.no_votes,
        status: proposal.status,
    });
}

public fun execute_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    vault: &mut GovernanceVault,
    ctx: &mut TxContext,
) {
    assert_current_config(config);
    assert_current_proposal(proposal);
    governance::assert_current_vault(vault);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::registry_id(vault) == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(proposal.proposal_type == PROPOSAL_TYPE_EXECUTABLE, E_PROPOSAL_NOT_EXECUTABLE);
    assert!(proposal.status == PROPOSAL_STATUS_PASSED, E_PROPOSAL_NOT_PASSED);
    assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);

    if (proposal.action_type == ACTION_SET_PUBLISHING_FEE_LEVEL) {
        governance::apply_publishing_fee_level(vault, proposal.payload_u64_1 as u8);
    } else if (proposal.action_type == ACTION_SET_COMMENTS_FEE_LEVEL) {
        governance::apply_comments_fee_level(vault, proposal.payload_u64_1 as u8);
    } else if (proposal.action_type == ACTION_SET_FEE_RECIPIENT) {
        governance::apply_fee_recipient(vault, proposal.payload_address);
    } else if (proposal.action_type == ACTION_NOMINATE_OPERATOR) {
        governance::nominate_operator_from_vote(vault, proposal.payload_address, ctx);
    } else if (proposal.action_type == ACTION_SET_PROPOSAL_CREATION_PAUSED) {
        assert!(
            proposal.payload_u64_1 == 0 || proposal.payload_u64_1 == 1,
            E_INVALID_BOOLEAN_PAYLOAD,
        );
        config.proposal_creation_paused = proposal.payload_u64_1 == 1;
    } else if (proposal.action_type == ACTION_SET_PROPOSER_THRESHOLD) {
        assert_valid_proposer_threshold(proposal.payload_u64_1);
        config.proposer_threshold = proposal.payload_u64_1;
    } else if (proposal.action_type == ACTION_SET_UPGRADE_AUTHORITY) {
        governance::apply_upgrade_authority(vault, proposal.payload_address);
    } else {
        abort E_INVALID_ACTION_TYPE
    };

    proposal.executed = true;
    proposal.status = PROPOSAL_STATUS_EXECUTED;

    event::emit(ProposalExecutedEvent {
        proposal_id: proposal.proposal_id,
        action_type: proposal.action_type,
    });
}

public fun claim_locked_tokens(
    proposal: &mut Proposal,
    ctx: &mut TxContext,
): Coin<PPRF> {
    assert_current_proposal(proposal);
    assert!(proposal.status != PROPOSAL_STATUS_ACTIVE, E_PROPOSAL_NOT_FINALIZED);

    let voter = tx_context::sender(ctx);
    assert!(table::contains(&proposal.votes, voter), E_NO_VOTE_TO_CLAIM);
    let VoteRecord { side, voting_power } = table::remove(&mut proposal.votes, voter);

    let locked_balance = if (side == VOTE_SIDE_YES) {
        balance::split(&mut proposal.yes_locked_balance, voting_power)
    } else if (side == VOTE_SIDE_NO) {
        balance::split(&mut proposal.no_locked_balance, voting_power)
    } else {
        abort E_INVALID_ACTION_TYPE
    };

    event::emit(VoteClaimedEvent {
        proposal_id: proposal.proposal_id,
        voter,
        side,
        voting_power,
    });

    coin::from_balance(locked_balance, ctx)
}

public fun config_registry_id(config: &GovernanceConfig): ID {
    config.registry_id
}

public fun config_version(config: &GovernanceConfig): u64 {
    config.version
}

public fun current_config_version(): u64 {
    GOVERNANCE_CONFIG_VERSION
}

public fun total_supply(config: &GovernanceConfig): u64 {
    config.pprf_total_supply
}

public fun proposer_threshold(config: &GovernanceConfig): u64 {
    config.proposer_threshold
}

public fun proposal_creation_paused(config: &GovernanceConfig): bool {
    config.proposal_creation_paused
}

public fun next_proposal_id(config: &GovernanceConfig): u64 {
    config.next_proposal_id
}

public fun active_proposal_id(config: &GovernanceConfig): option::Option<u64> {
    config.active_proposal_id
}

public fun proposal_object_id(config: &GovernanceConfig, proposal_id: u64): ID {
    *table::borrow(&config.proposal_id_to_object, proposal_id)
}

public fun proposal_id(proposal: &Proposal): u64 {
    proposal.proposal_id
}

public fun proposal_version(proposal: &Proposal): u64 {
    proposal.version
}

public fun current_proposal_version(): u64 {
    PROPOSAL_VERSION
}

public fun proposal_type(proposal: &Proposal): u8 {
    proposal.proposal_type
}

public fun action_type(proposal: &Proposal): u8 {
    proposal.action_type
}

public fun yes_votes(proposal: &Proposal): u64 {
    proposal.yes_votes
}

public fun no_votes(proposal: &Proposal): u64 {
    proposal.no_votes
}

public fun yes_locked_value(proposal: &Proposal): u64 {
    balance::value(&proposal.yes_locked_balance)
}

public fun no_locked_value(proposal: &Proposal): u64 {
    balance::value(&proposal.no_locked_balance)
}

public fun proposal_status(proposal: &Proposal): u8 {
    proposal.status
}

public fun proposal_executed(proposal: &Proposal): bool {
    proposal.executed
}

public fun proposal_start_epoch(proposal: &Proposal): u64 {
    proposal.start_epoch
}

public fun proposal_end_epoch(proposal: &Proposal): u64 {
    proposal.end_epoch
}

public fun has_voted(proposal: &Proposal, voter: address): bool {
    table::contains(&proposal.votes, voter)
}

public fun vote_power_of(proposal: &Proposal, voter: address): u64 {
    if (table::contains(&proposal.votes, voter)) {
        let vote = table::borrow(&proposal.votes, voter);
        vote.voting_power
    } else {
        0
    }
}

public fun proposal_duration_epochs(): u64 {
    PROPOSAL_DURATION_EPOCHS
}

public fun minimum_vote_stake(): u64 {
    MIN_VOTE_STAKE
}

public fun minimum_proposer_threshold(): u64 {
    MIN_PROPOSER_THRESHOLD
}

public fun maximum_proposer_threshold(): u64 {
    MAX_PROPOSER_THRESHOLD
}

public fun proposal_type_executable(): u8 {
    PROPOSAL_TYPE_EXECUTABLE
}

public fun proposal_type_signal(): u8 {
    PROPOSAL_TYPE_SIGNAL
}

public fun action_set_publishing_fee_level(): u8 {
    ACTION_SET_PUBLISHING_FEE_LEVEL
}

public fun action_set_comments_fee_level(): u8 {
    ACTION_SET_COMMENTS_FEE_LEVEL
}

public fun action_set_fee_recipient(): u8 {
    ACTION_SET_FEE_RECIPIENT
}

public fun action_nominate_operator(): u8 {
    ACTION_NOMINATE_OPERATOR
}

public fun action_set_proposal_creation_paused(): u8 {
    ACTION_SET_PROPOSAL_CREATION_PAUSED
}

public fun action_set_proposer_threshold(): u8 {
    ACTION_SET_PROPOSER_THRESHOLD
}

public fun action_set_upgrade_authority(): u8 {
    ACTION_SET_UPGRADE_AUTHORITY
}

public fun action_signal_replace_operator(): u8 {
    ACTION_SIGNAL_REPLACE_OPERATOR
}

public fun action_signal_feature_direction(): u8 {
    ACTION_SIGNAL_FEATURE_DIRECTION
}

public fun action_signal_policy_position(): u8 {
    ACTION_SIGNAL_POLICY_POSITION
}

public fun proposal_status_active(): u8 {
    PROPOSAL_STATUS_ACTIVE
}

public fun proposal_status_passed(): u8 {
    PROPOSAL_STATUS_PASSED
}

public fun proposal_status_rejected(): u8 {
    PROPOSAL_STATUS_REJECTED
}

public fun proposal_status_executed(): u8 {
    PROPOSAL_STATUS_EXECUTED
}

fun cast_vote(
    proposal: &mut Proposal,
    side: u8,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
) {
    assert!(proposal.status == PROPOSAL_STATUS_ACTIVE, E_PROPOSAL_NOT_ACTIVE);
    assert!(tx_context::epoch(ctx) < proposal.end_epoch, E_VOTING_ALREADY_ENDED);

    let voting_power = coin::value(&locked_tokens);
    assert!(voting_power > MIN_VOTE_STAKE, E_VOTING_POWER_BELOW_MINIMUM);

    let voter = tx_context::sender(ctx);
    assert!(!table::contains(&proposal.votes, voter), E_ALREADY_VOTED);

    let locked_balance = coin::into_balance(locked_tokens);
    if (side == VOTE_SIDE_YES) {
        proposal.yes_votes = proposal.yes_votes + voting_power;
        balance::join(&mut proposal.yes_locked_balance, locked_balance);
    } else if (side == VOTE_SIDE_NO) {
        proposal.no_votes = proposal.no_votes + voting_power;
        balance::join(&mut proposal.no_locked_balance, locked_balance);
    } else {
        abort E_INVALID_ACTION_TYPE
    };

    table::add(
        &mut proposal.votes,
        voter,
        VoteRecord {
            side,
            voting_power,
        },
    );

    event::emit(VoteCastEvent {
        proposal_id: proposal.proposal_id,
        voter,
        side,
        voting_power,
    });
}

fun clear_active_proposal(config: &mut GovernanceConfig, proposal_id: u64) {
    if (option::is_some(&config.active_proposal_id)) {
        let active_id = *option::borrow(&config.active_proposal_id);
        if (active_id == proposal_id) {
            let _ = option::extract(&mut config.active_proposal_id);
        };
    };
}

fun assert_current_config(config: &GovernanceConfig) {
    assert!(config.version == GOVERNANCE_CONFIG_VERSION, E_UNSUPPORTED_CONFIG_VERSION);
}

fun assert_current_proposal(proposal: &Proposal) {
    assert!(proposal.version == PROPOSAL_VERSION, E_UNSUPPORTED_PROPOSAL_VERSION);
}

fun migrate_config_version(config: &mut GovernanceConfig) {
    assert!(config.version <= GOVERNANCE_CONFIG_VERSION, E_UNSUPPORTED_CONFIG_VERSION);
    if (config.version < GOVERNANCE_CONFIG_VERSION) {
        config.version = GOVERNANCE_CONFIG_VERSION;
    };
}

fun migrate_proposal_version(proposal: &mut Proposal) {
    assert!(proposal.version <= PROPOSAL_VERSION, E_UNSUPPORTED_PROPOSAL_VERSION);
    if (proposal.version < PROPOSAL_VERSION) {
        proposal.version = PROPOSAL_VERSION;
    };
}

fun assert_valid_proposer_threshold(new_threshold: u64) {
    assert!(
        new_threshold >= MIN_PROPOSER_THRESHOLD &&
        new_threshold <= MAX_PROPOSER_THRESHOLD,
        E_INVALID_PROPOSER_THRESHOLD,
    );
}

fun assert_valid_proposal_action_pair(
    proposal_type: u8,
    action_type: u8,
) {
    if (proposal_type == PROPOSAL_TYPE_EXECUTABLE) {
        assert!(
            action_type == ACTION_SET_PUBLISHING_FEE_LEVEL ||
            action_type == ACTION_SET_COMMENTS_FEE_LEVEL ||
            action_type == ACTION_SET_FEE_RECIPIENT ||
            action_type == ACTION_NOMINATE_OPERATOR ||
            action_type == ACTION_SET_PROPOSAL_CREATION_PAUSED ||
            action_type == ACTION_SET_PROPOSER_THRESHOLD ||
            action_type == ACTION_SET_UPGRADE_AUTHORITY,
            E_EXECUTABLE_ACTION_NOT_ALLOWED,
        );
    } else if (proposal_type == PROPOSAL_TYPE_SIGNAL) {
        assert!(
            action_type == ACTION_SIGNAL_REPLACE_OPERATOR ||
            action_type == ACTION_SIGNAL_FEATURE_DIRECTION ||
            action_type == ACTION_SIGNAL_POLICY_POSITION,
            E_SIGNAL_ACTION_NOT_ALLOWED,
        );
    } else {
        abort E_INVALID_PROPOSAL_TYPE
    };
}
