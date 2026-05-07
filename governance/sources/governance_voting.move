// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available
// Use of this source code is governed by the LICENSE file in the project root.
// Public readability and auditability do not grant rights to copy, modify,
// distribute, redeploy, or commercialize this code except as expressly permitted.

module paperproof_governance::governance_voting;

use std::string::{Self as string, String};
use paperproof_governance::governance::{Self as governance, GovernanceActionExecutorCap, GovernanceVault};
use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use pprf::pprf::{Self as pprf, PPRF};
use sui::balance::{Self as balance, Balance};
use sui::coin::{Self as coin, Coin};
use sui::event;
use sui::table::{Self as table, Table};
use sui::transfer::Receiving;

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
const E_INVALID_PROPOSAL_DURATION_EPOCHS: u64 = 25;
const E_PROPOSAL_EXECUTION_NOT_EXPIRED: u64 = 26;
const E_PROPOSAL_OUTCOME_NOT_YET_DETERMINABLE: u64 = 27;
const E_ACTION_NOT_ENABLED: u64 = 28;
const E_INVALID_ACTION_ENABLE_TARGET: u64 = 29;
const E_NOT_GOVERNANCE_CONFIG_INITIALIZER: u64 = 30;
const E_INVALID_PROPOSAL_CONFIG_BINDING: u64 = 31;
const E_EMPTY_PROPOSAL_TITLE: u64 = 32;
const E_PROPOSAL_TEXT_TOO_LONG: u64 = 33;

const PROPOSAL_TYPE_EXECUTABLE: u8 = 1;
const PROPOSAL_TYPE_SIGNAL: u8 = 2;

const ACTION_SET_COMMENTS_FEE_LEVEL: u8 = 2;
const ACTION_SET_FEE_RECIPIENT: u8 = 3;
const ACTION_NOMINATE_OPERATOR: u8 = 4;
const ACTION_SET_PROPOSAL_CREATION_PAUSED: u8 = 5;
const ACTION_SET_PROPOSER_THRESHOLD: u8 = 6;
const ACTION_SET_UPGRADE_AUTHORITY: u8 = 7;
const ACTION_SET_PROPOSAL_DURATION_EPOCHS: u8 = 8;
const ACTION_SET_ARTIFACT_TYPE_ENABLED: u8 = 9;
const ACTION_SET_ARTIFACT_FEE_LEVEL: u8 = 10;
const ACTION_ACTIVATE_ARTIFACT_TYPE: u8 = 11;
const ACTION_SET_GOVERNANCE_ACTION_ENABLED: u8 = 12;
const ACTION_SET_DIRECT_AUTHORITY_MODE: u8 = 13;
const ACTION_CANCEL_OPERATOR_TRANSFER: u8 = 14;
const ACTION_SET_GOVERNANCE_AUTHORITY: u8 = 15;

const ACTION_SIGNAL_REPLACE_OPERATOR: u8 = 101;
const ACTION_SIGNAL_FEATURE_DIRECTION: u8 = 102;
const ACTION_SIGNAL_POLICY_POSITION: u8 = 103;

const PROPOSAL_STATUS_ACTIVE: u8 = 1;
const PROPOSAL_STATUS_PASSED: u8 = 2;
const PROPOSAL_STATUS_REJECTED: u8 = 3;
const PROPOSAL_STATUS_EXECUTED: u8 = 4;
const PROPOSAL_STATUS_EXPIRED: u8 = 5;

const VOTE_SIDE_YES: u8 = 1;
const VOTE_SIDE_NO: u8 = 2;

const DEFAULT_PROPOSAL_DURATION_EPOCHS: u64 = 1;
const MIN_PROPOSAL_DURATION_EPOCHS: u64 = 7;
const MAX_PROPOSAL_DURATION_EPOCHS: u64 = 14;
const EXECUTION_VALIDITY_EPOCHS: u64 = 3;
const MIN_VOTE_STAKE: u64 = 100_000_000_000; // 100 PPRF
const DEFAULT_PROPOSER_THRESHOLD: u64 = 10_000_000_000_000_000; // 10,000,000 PPRF
const MIN_PROPOSER_THRESHOLD: u64 = 100_000_000_000_000; // 100,000 PPRF
const MAX_PROPOSER_THRESHOLD: u64 = 1_000_000_000_000_000_000; // 1,000,000,000 PPRF
const MAX_PROPOSAL_TITLE_BYTES: u64 = 256;
const MAX_PROPOSAL_DESCRIPTION_BYTES: u64 = 4096;

const GOVERNANCE_CONFIG_VERSION: u64 = 1;
const PROPOSAL_VERSION: u64 = 1;

public struct GovernanceConfig has key {
    id: UID,
    version: u64,
    registry_id: ID,
    pprf_total_supply: u64,
    proposer_threshold: u64,
    proposal_duration_epochs: u64,
    next_proposal_id: u64,
    proposal_creation_paused: bool,
    active_proposal_id: option::Option<u64>,
    proposal_id_to_object: Table<u64, ID>,
    enabled_actions: Table<u8, bool>,
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

#[allow(unused_field)]
public struct GovernanceConfigCreatedEvent has copy, drop {
    registry_id: ID,
    governance_config_id: ID,
    pprf_total_supply: u64,
    proposer_threshold: u64,
    proposal_duration_epochs: u64,
}

public struct ProposalCreatedEvent has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    proposer: address,
    proposal_type: u8,
    action_type: u8,
    proposal_object_id: ID,
    proposer_stake: u64,
}

public struct VoteCastEvent has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    voter: address,
    side: u8,
    voting_power: u64,
}

public struct ProposalFinalizedEvent has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    yes_votes: u64,
    no_votes: u64,
    status: u8,
}

public struct ProposalExecutedEvent has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    action_type: u8,
    executed_by: address,
}

public struct ProposalExpiredEvent has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    expired_at_epoch: u64,
}

public struct VoteClaimedEvent has copy, drop {
    registry_id: ID,
    proposal_id: u64,
    voter: address,
    side: u8,
    voting_power: u64,
}

public struct GovernanceConfigMigratedEvent has copy, drop {
    registry_id: ID,
    migrated_by: address,
    new_version: u64,
}

public struct ProposalMigratedEvent has copy, drop {
    proposal_id: u64,
    registry_id: ID,
    migrated_by: address,
    new_version: u64,
}

public struct ProposalCreationPausedChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_paused: bool,
    paused: bool,
}

public struct ProposerThresholdChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_threshold: u64,
    new_threshold: u64,
}

public struct ProposalDurationChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    old_duration_epochs: u64,
    new_duration_epochs: u64,
}

public struct GovernanceActionStatusChangedEvent has copy, drop {
    registry_id: ID,
    changed_by: address,
    action_type: u8,
    old_enabled: bool,
    enabled: bool,
}

public fun new_governance_config(
    vault: &mut GovernanceVault,
    ctx: &mut TxContext,
): GovernanceConfig {
    governance::assert_current_vault(vault);
    assert!(
        tx_context::sender(ctx) == governance::governance_authority(vault) ||
        tx_context::sender(ctx) == governance::upgrade_authority(vault),
        E_NOT_GOVERNANCE_CONFIG_INITIALIZER,
    );
    let pprf_total_supply = pprf::total_supply_base_units();
    assert!(pprf_total_supply > 0, E_ZERO_TOTAL_SUPPLY);

    let enabled_actions = default_enabled_actions(ctx);
    let config_uid = object::new(ctx);
    let governance_config_id = *config_uid.as_inner();
    governance::bind_governance_config(vault, governance_config_id, ctx);
    let config = GovernanceConfig {
        id: config_uid,
        version: GOVERNANCE_CONFIG_VERSION,
        registry_id: governance::registry_id(vault),
        pprf_total_supply,
        proposer_threshold: DEFAULT_PROPOSER_THRESHOLD,
        proposal_duration_epochs: DEFAULT_PROPOSAL_DURATION_EPOCHS,
        next_proposal_id: 1,
        proposal_creation_paused: false,
        active_proposal_id: option::none(),
        proposal_id_to_object: table::new(ctx),
        enabled_actions,
    };

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
    assert!(governance::governance_config_id(vault) == object::id(config), E_INVALID_VAULT_REGISTRY);
    governance::assert_upgrade_authority(vault, tx_context::sender(ctx));
    migrate_config_version(config);
    if (!table::contains(&config.enabled_actions, ACTION_SET_GOVERNANCE_AUTHORITY)) {
        table::add(&mut config.enabled_actions, ACTION_SET_GOVERNANCE_AUTHORITY, true);
    };
    event::emit(GovernanceConfigMigratedEvent {
        registry_id: config.registry_id,
        migrated_by: tx_context::sender(ctx),
        new_version: config.version,
    });
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
    event::emit(ProposalMigratedEvent {
        proposal_id: proposal.proposal_id,
        registry_id: proposal.registry_id,
        migrated_by: tx_context::sender(ctx),
        new_version: proposal.version,
    });
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
    assert_valid_proposal_text(&title, &description);
    assert_valid_proposal_action_pair(proposal_type, action_type);
    assert_action_enabled(config, action_type);
    assert_valid_proposal_payload(
        proposal_type,
        action_type,
        payload_u64_1,
        payload_u64_2,
        payload_address,
    );

    let proposer = tx_context::sender(ctx);
    let proposer_power = coin::value(&proposer_stake);
    assert!(proposer_power >= config.proposer_threshold, E_PROPOSER_STAKE_BELOW_THRESHOLD);

    let proposal_id = config.next_proposal_id;
    config.next_proposal_id = proposal_id + 1;

    let start_epoch = tx_context::epoch(ctx);
    let end_epoch = start_epoch + config.proposal_duration_epochs;

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
        registry_id: config.registry_id,
        proposal_id,
        proposer,
        proposal_type,
        action_type,
        proposal_object_id,
        proposer_stake: proposer_power,
    });
    event::emit(VoteCastEvent {
        registry_id: config.registry_id,
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
    assert_proposal_belongs_to_config(config, proposal);
    assert!(proposal.status == PROPOSAL_STATUS_ACTIVE, E_PROPOSAL_ALREADY_FINALIZED);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(tx_context::epoch(ctx) >= proposal.end_epoch, E_VOTING_NOT_ENDED);

    finalize_active_proposal(config, proposal);
}

public fun resolve_proposal_early(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
) {
    assert_current_config(config);
    assert_current_proposal(proposal);
    assert_proposal_belongs_to_config(config, proposal);
    assert!(proposal.status == PROPOSAL_STATUS_ACTIVE, E_PROPOSAL_ALREADY_FINALIZED);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(outcome_determinable(config, proposal), E_PROPOSAL_OUTCOME_NOT_YET_DETERMINABLE);

    finalize_active_proposal(config, proposal);
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
    assert_proposal_belongs_to_config(config, proposal);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::registry_id(vault) == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::governance_config_id(vault) == object::id(config), E_INVALID_VAULT_REGISTRY);
    assert!(proposal.proposal_type == PROPOSAL_TYPE_EXECUTABLE, E_PROPOSAL_NOT_EXECUTABLE);
    assert!(proposal.status == PROPOSAL_STATUS_PASSED, E_PROPOSAL_NOT_PASSED);
    assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);

    let current_epoch = tx_context::epoch(ctx);
    if (current_epoch > execution_expiry_epoch(proposal)) {
        expire_proposal_internal(proposal, current_epoch);
        return
    };

    if (proposal.action_type == ACTION_SET_FEE_RECIPIENT) {
        governance::apply_fee_recipient(vault, proposal.payload_address, tx_context::sender(ctx));
    } else if (proposal.action_type == ACTION_NOMINATE_OPERATOR) {
        governance::nominate_operator_from_vote(vault, proposal.payload_address, ctx);
    } else if (proposal.action_type == ACTION_SET_PROPOSAL_CREATION_PAUSED) {
        assert!(
            proposal.payload_u64_1 == 0 || proposal.payload_u64_1 == 1,
            E_INVALID_BOOLEAN_PAYLOAD,
        );
        let old_paused = config.proposal_creation_paused;
        config.proposal_creation_paused = proposal.payload_u64_1 == 1;
        event::emit(ProposalCreationPausedChangedEvent {
            registry_id: config.registry_id,
            changed_by: tx_context::sender(ctx),
            old_paused,
            paused: config.proposal_creation_paused,
        });
    } else if (proposal.action_type == ACTION_SET_PROPOSER_THRESHOLD) {
        assert_valid_proposer_threshold(proposal.payload_u64_1);
        let old_threshold = config.proposer_threshold;
        config.proposer_threshold = proposal.payload_u64_1;
        event::emit(ProposerThresholdChangedEvent {
            registry_id: config.registry_id,
            changed_by: tx_context::sender(ctx),
            old_threshold,
            new_threshold: config.proposer_threshold,
        });
    } else if (proposal.action_type == ACTION_SET_UPGRADE_AUTHORITY) {
        governance::apply_upgrade_authority(vault, proposal.payload_address, tx_context::sender(ctx));
    } else if (proposal.action_type == ACTION_SET_PROPOSAL_DURATION_EPOCHS) {
        assert_valid_proposal_duration_epochs(proposal.payload_u64_1);
        let old_duration_epochs = config.proposal_duration_epochs;
        config.proposal_duration_epochs = proposal.payload_u64_1;
        event::emit(ProposalDurationChangedEvent {
            registry_id: config.registry_id,
            changed_by: tx_context::sender(ctx),
            old_duration_epochs,
            new_duration_epochs: config.proposal_duration_epochs,
        });
    } else if (proposal.action_type == ACTION_SET_GOVERNANCE_ACTION_ENABLED) {
        let target_action = proposal.payload_u64_1 as u8;
        assert_valid_action_enable_target(target_action);
        assert!(
            proposal.payload_u64_2 == 0 || proposal.payload_u64_2 == 1,
            E_INVALID_BOOLEAN_PAYLOAD,
        );
        apply_action_enabled(config, target_action, proposal.payload_u64_2 == 1, tx_context::sender(ctx));
    } else if (proposal.action_type == ACTION_SET_DIRECT_AUTHORITY_MODE) {
        governance::apply_direct_authority_mode_from_vote(vault, proposal.payload_u64_1 as u8, tx_context::sender(ctx));
    } else if (proposal.action_type == ACTION_SET_GOVERNANCE_AUTHORITY) {
        governance::apply_governance_authority(vault, proposal.payload_address, tx_context::sender(ctx));
    } else if (proposal.action_type == ACTION_CANCEL_OPERATOR_TRANSFER) {
        abort E_INVALID_ACTION_TYPE
    } else {
        abort E_INVALID_ACTION_TYPE
    };

    proposal.executed = true;
    proposal.status = PROPOSAL_STATUS_EXECUTED;

    event::emit(ProposalExecutedEvent {
        registry_id: proposal.registry_id,
        proposal_id: proposal.proposal_id,
        action_type: proposal.action_type,
        executed_by: tx_context::sender(ctx),
    });
}

public fun consume_executable_proposal_action(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    vault: &GovernanceVault,
    action_executor_cap: &GovernanceActionExecutorCap,
    registry_id: ID,
    expected_action_type: u8,
    ctx: &mut TxContext,
): governance::GovernanceActionTicket {
    assert_current_config(config);
    assert_current_proposal(proposal);
    governance::assert_current_vault(vault);
    governance::assert_action_executor_cap(vault, action_executor_cap);
    assert_proposal_belongs_to_config(config, proposal);
    assert!(governance::action_executor_cap_registry_id(action_executor_cap) == registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(config.registry_id == registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::registry_id(vault) == registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::governance_config_id(vault) == object::id(config), E_INVALID_VAULT_REGISTRY);
    assert!(proposal.proposal_type == PROPOSAL_TYPE_EXECUTABLE, E_PROPOSAL_NOT_EXECUTABLE);
    assert!(proposal.status == PROPOSAL_STATUS_PASSED, E_PROPOSAL_NOT_PASSED);
    assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);
    assert!(proposal.action_type == expected_action_type, E_INVALID_ACTION_TYPE);
    assert!(
        expected_action_type == ACTION_SET_COMMENTS_FEE_LEVEL ||
        expected_action_type == ACTION_SET_ARTIFACT_TYPE_ENABLED ||
        expected_action_type == ACTION_SET_ARTIFACT_FEE_LEVEL ||
        expected_action_type == ACTION_ACTIVATE_ARTIFACT_TYPE,
        E_INVALID_ACTION_TYPE,
    );
    assert!(tx_context::epoch(ctx) <= execution_expiry_epoch(proposal), E_PROPOSAL_EXECUTION_NOT_EXPIRED);

    proposal.executed = true;
    proposal.status = PROPOSAL_STATUS_EXECUTED;

    event::emit(ProposalExecutedEvent {
        registry_id: proposal.registry_id,
        proposal_id: proposal.proposal_id,
        action_type: proposal.action_type,
        executed_by: tx_context::sender(ctx),
    });

    governance::new_action_ticket(
        registry_id,
        proposal.action_type,
        proposal.payload_u64_1,
        proposal.payload_u64_2,
        tx_context::sender(ctx),
    )
}

public fun execute_comments_fee_level_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    vault: &GovernanceVault,
    action_executor_cap: &GovernanceActionExecutorCap,
    fee_manager: &mut governance::FeeManager,
    ctx: &mut TxContext,
) {
    let ticket = consume_executable_proposal_action(
        config,
        proposal,
        vault,
        action_executor_cap,
        governance::registry_id(vault),
        ACTION_SET_COMMENTS_FEE_LEVEL,
        ctx,
    );
    governance::apply_comments_fee_level_from_ticket(vault, fee_manager, ticket);
}

public fun execute_cancel_operator_transfer_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    vault: &mut GovernanceVault,
    request: PendingOwnershipTransfer<governance::OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<governance::OperatorPermit>>,
    ctx: &mut TxContext,
) {
    assert_current_config(config);
    assert_current_proposal(proposal);
    governance::assert_current_vault(vault);
    assert_proposal_belongs_to_config(config, proposal);
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::registry_id(vault) == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(governance::governance_config_id(vault) == object::id(config), E_INVALID_VAULT_REGISTRY);
    assert!(proposal.proposal_type == PROPOSAL_TYPE_EXECUTABLE, E_PROPOSAL_NOT_EXECUTABLE);
    assert!(proposal.status == PROPOSAL_STATUS_PASSED, E_PROPOSAL_NOT_PASSED);
    assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);
    assert!(proposal.action_type == ACTION_CANCEL_OPERATOR_TRANSFER, E_INVALID_ACTION_TYPE);

    let current_epoch = tx_context::epoch(ctx);
    assert!(current_epoch <= execution_expiry_epoch(proposal), E_PROPOSAL_EXECUTION_NOT_EXPIRED);

    governance::cancel_operator_transfer_from_vote(vault, request, wrapper_ticket, ctx);
    proposal.executed = true;
    proposal.status = PROPOSAL_STATUS_EXECUTED;

    event::emit(ProposalExecutedEvent {
        registry_id: proposal.registry_id,
        proposal_id: proposal.proposal_id,
        action_type: proposal.action_type,
        executed_by: tx_context::sender(ctx),
    });
}

public fun expire_passed_proposal(
    proposal: &mut Proposal,
    ctx: &TxContext,
) {
    assert_current_proposal(proposal);
    assert!(proposal.proposal_type == PROPOSAL_TYPE_EXECUTABLE, E_PROPOSAL_NOT_EXECUTABLE);
    assert!(proposal.status == PROPOSAL_STATUS_PASSED, E_PROPOSAL_NOT_PASSED);
    assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);

    let current_epoch = tx_context::epoch(ctx);
    assert!(current_epoch > execution_expiry_epoch(proposal), E_PROPOSAL_EXECUTION_NOT_EXPIRED);
    expire_proposal_internal(proposal, current_epoch);
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
        registry_id: proposal.registry_id,
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

public fun configured_proposal_duration_epochs(config: &GovernanceConfig): u64 {
    config.proposal_duration_epochs
}

public fun proposal_creation_paused(config: &GovernanceConfig): bool {
    config.proposal_creation_paused
}

public fun action_enabled(config: &GovernanceConfig, action_type: u8): bool {
    table::contains(&config.enabled_actions, action_type) &&
    *table::borrow(&config.enabled_actions, action_type)
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

public fun remaining_voting_supply(config: &GovernanceConfig, proposal: &Proposal): u64 {
    config.pprf_total_supply - proposal.yes_votes - proposal.no_votes
}

public fun execution_expiry_epoch(proposal: &Proposal): u64 {
    proposal.end_epoch + EXECUTION_VALIDITY_EPOCHS
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

public fun can_claim_locked_tokens(proposal: &Proposal, voter: address): bool {
    proposal.status != PROPOSAL_STATUS_ACTIVE && table::contains(&proposal.votes, voter)
}

public fun is_proposal_executable(proposal: &Proposal): bool {
    proposal.proposal_type == PROPOSAL_TYPE_EXECUTABLE &&
    proposal.status == PROPOSAL_STATUS_PASSED &&
    !proposal.executed
}

public fun outcome_determinable(config: &GovernanceConfig, proposal: &Proposal): bool {
    let remaining = remaining_voting_supply(config, proposal);
    deterministic_pass(config, proposal, remaining) || deterministic_fail(config, proposal, remaining)
}

public fun execution_validity_epochs(): u64 {
    EXECUTION_VALIDITY_EPOCHS
}

public fun default_proposal_duration_epochs(): u64 {
    DEFAULT_PROPOSAL_DURATION_EPOCHS
}

public fun minimum_proposal_duration_epochs(): u64 {
    MIN_PROPOSAL_DURATION_EPOCHS
}

public fun maximum_proposal_duration_epochs(): u64 {
    MAX_PROPOSAL_DURATION_EPOCHS
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

public fun action_set_proposal_duration_epochs(): u8 {
    ACTION_SET_PROPOSAL_DURATION_EPOCHS
}

public fun action_set_artifact_type_enabled(): u8 {
    ACTION_SET_ARTIFACT_TYPE_ENABLED
}

public fun action_set_artifact_fee_level(): u8 {
    ACTION_SET_ARTIFACT_FEE_LEVEL
}

public fun action_activate_artifact_type(): u8 {
    ACTION_ACTIVATE_ARTIFACT_TYPE
}

public fun action_set_governance_action_enabled(): u8 {
    ACTION_SET_GOVERNANCE_ACTION_ENABLED
}

public fun action_set_direct_authority_mode(): u8 {
    ACTION_SET_DIRECT_AUTHORITY_MODE
}

public fun action_cancel_operator_transfer(): u8 {
    ACTION_CANCEL_OPERATOR_TRANSFER
}

public fun action_set_governance_authority(): u8 {
    ACTION_SET_GOVERNANCE_AUTHORITY
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

public fun proposal_status_expired(): u8 {
    PROPOSAL_STATUS_EXPIRED
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
        registry_id: proposal.registry_id,
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

fun assert_proposal_belongs_to_config(
    config: &GovernanceConfig,
    proposal: &Proposal,
) {
    assert!(proposal.registry_id == config.registry_id, E_INVALID_VAULT_REGISTRY);
    assert!(table::contains(&config.proposal_id_to_object, proposal.proposal_id), E_INVALID_PROPOSAL_CONFIG_BINDING);
    assert!(
        *table::borrow(&config.proposal_id_to_object, proposal.proposal_id) == object::id(proposal),
        E_INVALID_PROPOSAL_CONFIG_BINDING,
    );
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

fun default_enabled_actions(ctx: &mut TxContext): Table<u8, bool> {
    let mut actions = table::new(ctx);
    table::add(&mut actions, ACTION_SET_COMMENTS_FEE_LEVEL, true);
    table::add(&mut actions, ACTION_SET_FEE_RECIPIENT, true);
    table::add(&mut actions, ACTION_NOMINATE_OPERATOR, true);
    table::add(&mut actions, ACTION_SET_PROPOSAL_CREATION_PAUSED, true);
    table::add(&mut actions, ACTION_SET_PROPOSER_THRESHOLD, true);
    table::add(&mut actions, ACTION_SET_UPGRADE_AUTHORITY, true);
    table::add(&mut actions, ACTION_SET_PROPOSAL_DURATION_EPOCHS, true);
    table::add(&mut actions, ACTION_SET_ARTIFACT_TYPE_ENABLED, true);
    table::add(&mut actions, ACTION_SET_ARTIFACT_FEE_LEVEL, true);
    table::add(&mut actions, ACTION_ACTIVATE_ARTIFACT_TYPE, true);
    table::add(&mut actions, ACTION_SET_GOVERNANCE_ACTION_ENABLED, true);
    table::add(&mut actions, ACTION_SET_DIRECT_AUTHORITY_MODE, true);
    table::add(&mut actions, ACTION_CANCEL_OPERATOR_TRANSFER, true);
    table::add(&mut actions, ACTION_SET_GOVERNANCE_AUTHORITY, true);
    table::add(&mut actions, ACTION_SIGNAL_REPLACE_OPERATOR, true);
    table::add(&mut actions, ACTION_SIGNAL_FEATURE_DIRECTION, true);
    table::add(&mut actions, ACTION_SIGNAL_POLICY_POSITION, true);
    actions
}

fun assert_action_enabled(config: &GovernanceConfig, action_type: u8) {
    assert!(action_enabled(config, action_type), E_ACTION_NOT_ENABLED);
}

fun apply_action_enabled(
    config: &mut GovernanceConfig,
    action_type: u8,
    enabled: bool,
    changed_by: address,
) {
    assert_valid_action_enable_target(action_type);
    let old_enabled = action_enabled(config, action_type);
    if (table::contains(&config.enabled_actions, action_type)) {
        *table::borrow_mut(&mut config.enabled_actions, action_type) = enabled;
    } else {
        table::add(&mut config.enabled_actions, action_type, enabled);
    };
    event::emit(GovernanceActionStatusChangedEvent {
        registry_id: config.registry_id,
        changed_by,
        action_type,
        old_enabled,
        enabled,
    });
}

fun finalize_active_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
) {
    let passed = passage_rule_satisfied(config, proposal.yes_votes, proposal.no_votes);

    if (passed) {
        proposal.status = PROPOSAL_STATUS_PASSED;
    } else {
        proposal.status = PROPOSAL_STATUS_REJECTED;
    };

    clear_active_proposal(config, proposal.proposal_id);

    event::emit(ProposalFinalizedEvent {
        registry_id: proposal.registry_id,
        proposal_id: proposal.proposal_id,
        yes_votes: proposal.yes_votes,
        no_votes: proposal.no_votes,
        status: proposal.status,
    });
}

fun expire_proposal_internal(proposal: &mut Proposal, current_epoch: u64) {
    proposal.status = PROPOSAL_STATUS_EXPIRED;
    proposal.executed = false;
    event::emit(ProposalExpiredEvent {
        registry_id: proposal.registry_id,
        proposal_id: proposal.proposal_id,
        expired_at_epoch: current_epoch,
    });
}

fun assert_valid_proposer_threshold(new_threshold: u64) {
    assert!(
        new_threshold >= MIN_PROPOSER_THRESHOLD &&
        new_threshold <= MAX_PROPOSER_THRESHOLD,
        E_INVALID_PROPOSER_THRESHOLD,
    );
}

fun assert_valid_proposal_duration_epochs(new_duration: u64) {
    assert!(
        new_duration >= MIN_PROPOSAL_DURATION_EPOCHS &&
        new_duration <= MAX_PROPOSAL_DURATION_EPOCHS,
        E_INVALID_PROPOSAL_DURATION_EPOCHS,
    );
}

fun assert_valid_proposal_text(title: &String, description: &String) {
    assert!(string::length(title) > 0, E_EMPTY_PROPOSAL_TITLE);
    assert!(string::length(title) <= MAX_PROPOSAL_TITLE_BYTES, E_PROPOSAL_TEXT_TOO_LONG);
    assert!(string::length(description) <= MAX_PROPOSAL_DESCRIPTION_BYTES, E_PROPOSAL_TEXT_TOO_LONG);
}

fun deterministic_pass(
    config: &GovernanceConfig,
    proposal: &Proposal,
    remaining: u64,
): bool {
    passage_rule_satisfied(config, proposal.yes_votes, proposal.no_votes + remaining)
}

fun deterministic_fail(
    config: &GovernanceConfig,
    proposal: &Proposal,
    remaining: u64,
): bool {
    let max_possible_yes = proposal.yes_votes + remaining;
    !passage_rule_satisfied(config, max_possible_yes, proposal.no_votes)
}

fun passage_rule_satisfied(
    config: &GovernanceConfig,
    yes_votes: u64,
    no_votes: u64,
): bool {
    let yes_votes_u128 = yes_votes as u128;
    let no_votes_u128 = no_votes as u128;
    let total_supply_u128 = config.pprf_total_supply as u128;

    yes_votes_u128 * 3 >= no_votes_u128 * 4 &&
    yes_votes_u128 * 10 > total_supply_u128
}

fun assert_valid_proposal_action_pair(
    proposal_type: u8,
    action_type: u8,
) {
    if (proposal_type == PROPOSAL_TYPE_EXECUTABLE) {
        assert!(
            action_type == ACTION_SET_COMMENTS_FEE_LEVEL ||
            action_type == ACTION_SET_FEE_RECIPIENT ||
            action_type == ACTION_NOMINATE_OPERATOR ||
            action_type == ACTION_SET_PROPOSAL_CREATION_PAUSED ||
            action_type == ACTION_SET_PROPOSER_THRESHOLD ||
            action_type == ACTION_SET_UPGRADE_AUTHORITY ||
            action_type == ACTION_SET_PROPOSAL_DURATION_EPOCHS ||
            action_type == ACTION_SET_ARTIFACT_TYPE_ENABLED ||
            action_type == ACTION_SET_ARTIFACT_FEE_LEVEL ||
            action_type == ACTION_ACTIVATE_ARTIFACT_TYPE ||
            action_type == ACTION_SET_GOVERNANCE_ACTION_ENABLED ||
            action_type == ACTION_SET_DIRECT_AUTHORITY_MODE ||
            action_type == ACTION_CANCEL_OPERATOR_TRANSFER ||
            action_type == ACTION_SET_GOVERNANCE_AUTHORITY,
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

fun assert_known_action(action_type: u8) {
    assert!(
        action_type == ACTION_SET_COMMENTS_FEE_LEVEL ||
        action_type == ACTION_SET_FEE_RECIPIENT ||
        action_type == ACTION_NOMINATE_OPERATOR ||
        action_type == ACTION_SET_PROPOSAL_CREATION_PAUSED ||
        action_type == ACTION_SET_PROPOSER_THRESHOLD ||
        action_type == ACTION_SET_UPGRADE_AUTHORITY ||
        action_type == ACTION_SET_PROPOSAL_DURATION_EPOCHS ||
        action_type == ACTION_SET_ARTIFACT_TYPE_ENABLED ||
        action_type == ACTION_SET_ARTIFACT_FEE_LEVEL ||
        action_type == ACTION_ACTIVATE_ARTIFACT_TYPE ||
        action_type == ACTION_SET_GOVERNANCE_ACTION_ENABLED ||
        action_type == ACTION_SET_DIRECT_AUTHORITY_MODE ||
        action_type == ACTION_CANCEL_OPERATOR_TRANSFER ||
        action_type == ACTION_SET_GOVERNANCE_AUTHORITY ||
        action_type == ACTION_SIGNAL_REPLACE_OPERATOR ||
        action_type == ACTION_SIGNAL_FEATURE_DIRECTION ||
        action_type == ACTION_SIGNAL_POLICY_POSITION,
        E_INVALID_ACTION_TYPE,
    );
}

fun assert_valid_action_enable_target(action_type: u8) {
    assert_known_action(action_type);
    assert!(action_type != ACTION_SET_GOVERNANCE_ACTION_ENABLED, E_INVALID_ACTION_ENABLE_TARGET);
}

fun assert_valid_proposal_payload(
    proposal_type: u8,
    action_type: u8,
    payload_u64_1: u64,
    payload_u64_2: u64,
    payload_address: address,
) {
    if (proposal_type == PROPOSAL_TYPE_SIGNAL) {
        return
    };

    if (action_type == ACTION_SET_COMMENTS_FEE_LEVEL) {
        governance::assert_valid_fee_level(payload_u64_1 as u8);
    } else if (action_type == ACTION_SET_FEE_RECIPIENT) {
        assert!(payload_address != @0x0, E_INVALID_ACTION_TYPE);
    } else if (action_type == ACTION_NOMINATE_OPERATOR) {
        assert!(payload_address != @0x0, E_INVALID_ACTION_TYPE);
    } else if (action_type == ACTION_SET_PROPOSAL_CREATION_PAUSED) {
        assert!(payload_u64_1 == 0 || payload_u64_1 == 1, E_INVALID_BOOLEAN_PAYLOAD);
    } else if (action_type == ACTION_SET_PROPOSER_THRESHOLD) {
        assert_valid_proposer_threshold(payload_u64_1);
    } else if (action_type == ACTION_SET_UPGRADE_AUTHORITY) {
        assert!(payload_address != @0x0, E_INVALID_ACTION_TYPE);
    } else if (action_type == ACTION_SET_PROPOSAL_DURATION_EPOCHS) {
        assert_valid_proposal_duration_epochs(payload_u64_1);
    } else if (action_type == ACTION_SET_ARTIFACT_TYPE_ENABLED) {
        assert!(payload_u64_2 == 0 || payload_u64_2 == 1, E_INVALID_BOOLEAN_PAYLOAD);
    } else if (action_type == ACTION_SET_ARTIFACT_FEE_LEVEL) {
        governance::assert_valid_fee_level(payload_u64_2 as u8);
    } else if (action_type == ACTION_ACTIVATE_ARTIFACT_TYPE) {
        governance::assert_valid_fee_level(payload_u64_2 as u8);
    } else if (action_type == ACTION_SET_GOVERNANCE_ACTION_ENABLED) {
        assert_valid_action_enable_target(payload_u64_1 as u8);
        assert!(payload_u64_2 == 0 || payload_u64_2 == 1, E_INVALID_BOOLEAN_PAYLOAD);
    } else if (action_type == ACTION_SET_DIRECT_AUTHORITY_MODE) {
        governance::assert_valid_direct_authority_mode(payload_u64_1 as u8);
    } else if (action_type == ACTION_CANCEL_OPERATOR_TRANSFER) {
        // No payload required. Object arguments are checked at execution.
    } else if (action_type == ACTION_SET_GOVERNANCE_AUTHORITY) {
        assert!(payload_address != @0x0, E_INVALID_ACTION_TYPE);
    } else {
        abort E_INVALID_ACTION_TYPE
    };
}
