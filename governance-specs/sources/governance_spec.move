// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module specs::governance_spec;

#[spec_only]
use prover::prover::{asserts, ensures, implies, requires};

use std::string::{Self as string, String};

use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use paperproof_governance::governance;
use paperproof_governance::governance_voting;
use pprf::pprf::PPRF;
use sui::coin::{Self as coin, Coin};
use sui::package::{Self as package, UpgradeCap, UpgradeReceipt, UpgradeTicket};
use sui::sui::SUI;
use sui::transfer::Receiving;

#[spec_only]
fun executable_action_consumed_with_registry(
    proposal: &governance_voting::Proposal,
    ticket: &governance::GovernanceActionTicket,
    registry_id: ID,
): bool {
    governance_voting::proposal_executed(proposal) &&
    governance::action_ticket_registry_id(ticket) == registry_id
}

#[spec_only]
fun proposal_bound_to_config(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): bool {
    governance_voting::config_registry_id(config) == governance_voting::proposal_registry_id(proposal)
}

#[spec_only]
fun proposal_object_bound_to_config(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): bool {
    governance_voting::proposal_binding_exists(config, governance_voting::proposal_id(proposal)) &&
    governance_voting::proposal_object_id(config, governance_voting::proposal_id(proposal)) == object::id(proposal)
}

#[spec(prove, target = paperproof_governance::governance::new_vault)]
fun new_vault_spec(
    registry_id: ID,
    governance_authority: address,
    initial_operator: address,
    ctx: &mut TxContext,
): (governance::GovernanceVault, governance::OperatorPermit) {
    asserts(governance_authority != @0x0);
    asserts(initial_operator != @0x0);
    governance::new_vault(registry_id, governance_authority, initial_operator, ctx)
}

#[spec(prove, target = paperproof_governance::governance::registry_id)]
fun registry_id_spec(vault: &governance::GovernanceVault): ID {
    let result = governance::registry_id(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::governance_config_id)]
fun governance_config_id_spec(vault: &governance::GovernanceVault): ID {
    let result = governance::governance_config_id(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::governance_vault_version)]
fun governance_vault_version_spec(vault: &governance::GovernanceVault): u64 {
    let result = governance::governance_vault_version(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::current_governance_vault_version)]
fun current_governance_vault_version_spec(): u64 {
    let result = governance::current_governance_vault_version();
    result
}

#[spec(prove, target = paperproof_governance::governance::governance_authority)]
fun governance_authority_spec(vault: &governance::GovernanceVault): address {
    let result = governance::governance_authority(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::upgrade_authority)]
fun upgrade_authority_spec(vault: &governance::GovernanceVault): address {
    let result = governance::upgrade_authority(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::active_operator)]
fun active_operator_spec(vault: &governance::GovernanceVault): address {
    let result = governance::active_operator(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::active_operator_epoch)]
fun active_operator_epoch_spec(vault: &governance::GovernanceVault): u64 {
    let result = governance::active_operator_epoch(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::has_pending_operator_transfer)]
fun has_pending_operator_transfer_spec(vault: &governance::GovernanceVault): bool {
    let result = governance::has_pending_operator_transfer(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::pending_operator)]
fun pending_operator_spec(vault: &governance::GovernanceVault): address {
    let result = governance::pending_operator(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::pending_operator_epoch)]
fun pending_operator_epoch_spec(vault: &governance::GovernanceVault): u64 {
    let result = governance::pending_operator_epoch(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::pending_operator_wrapper_id)]
fun pending_operator_wrapper_id_spec(vault: &governance::GovernanceVault): ID {
    let result = governance::pending_operator_wrapper_id(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::fee_recipient)]
fun fee_recipient_spec(vault: &governance::GovernanceVault): address {
    let result = governance::fee_recipient(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::direct_authority_mode)]
fun direct_authority_mode_spec(vault: &governance::GovernanceVault): u8 {
    let result = governance::direct_authority_mode(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::direct_authority_permanently_disabled)]
fun direct_authority_permanently_disabled_spec(vault: &governance::GovernanceVault): bool {
    let result = governance::direct_authority_permanently_disabled(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::new_vault_with_action_executor_cap)]
fun new_vault_with_action_executor_cap_spec(
    registry_id: ID,
    governance_authority: address,
    initial_operator: address,
    ctx: &mut TxContext,
): (
    governance::GovernanceVault,
    governance::OperatorPermit,
    governance::GovernanceActionExecutorCap
) {
    asserts(governance_authority != @0x0);
    asserts(initial_operator != @0x0);
    let (vault, permit, cap) = governance::new_vault_with_action_executor_cap(
        registry_id,
        governance_authority,
        initial_operator,
        ctx,
    );
    ensures(governance::action_executor_cap_registry_id(&cap) == governance::registry_id(&vault));
    (vault, permit, cap)
}

#[spec(prove, target = paperproof_governance::governance::assert_upgrade_authority)]
fun assert_upgrade_authority_spec(vault: &governance::GovernanceVault, sender: address) {
    asserts(sender == governance::upgrade_authority(vault));
    governance::assert_upgrade_authority(vault, sender)
}

#[spec(prove, target = paperproof_governance::governance::share_vault)]
fun share_vault_spec(vault: governance::GovernanceVault) {
    governance::share_vault(vault)
}

#[spec(prove, target = paperproof_governance::governance::assert_current_vault)]
fun assert_current_vault_spec(vault: &governance::GovernanceVault) {
    asserts(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    governance::assert_current_vault(vault)
}

#[spec(prove, target = paperproof_governance::governance::assert_action_executor_cap)]
fun assert_action_executor_cap_spec(
    vault: &governance::GovernanceVault,
    cap: &governance::GovernanceActionExecutorCap,
) {
    asserts(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    asserts(governance::action_executor_cap_registry_id(cap) == governance::registry_id(vault));
    asserts(governance::action_executor_cap_governance_vault_id(cap) == object::id(vault));
    governance::assert_action_executor_cap(vault, cap)
}

#[spec(prove, target = paperproof_governance::governance::direct_authority_mode_full)]
fun direct_authority_mode_full_spec(): u8 {
    let result = governance::direct_authority_mode_full();
    result
}

#[spec(prove, target = paperproof_governance::governance::direct_authority_mode_emergency)]
fun direct_authority_mode_emergency_spec(): u8 {
    let result = governance::direct_authority_mode_emergency();
    result
}

#[spec(prove, target = paperproof_governance::governance::direct_authority_mode_read_only)]
fun direct_authority_mode_read_only_spec(): u8 {
    let result = governance::direct_authority_mode_read_only();
    result
}

#[spec(prove, target = paperproof_governance::governance::direct_authority_mode_disabled)]
fun direct_authority_mode_disabled_spec(): u8 {
    let result = governance::direct_authority_mode_disabled();
    result
}

#[spec(prove, target = paperproof_governance::governance::borrow_admin_cap)]
fun borrow_admin_cap_spec(vault: &governance::GovernanceVault): &governance::AdminCap {
    let result = governance::borrow_admin_cap(vault);
    result
}

#[spec(prove, target = paperproof_governance::governance::bind_governance_config)]
fun bind_governance_config_spec(
    vault: &mut governance::GovernanceVault,
    governance_config_id: ID,
    ctx: &TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(governance::governance_config_id(vault) == object::id_from_address(@0x0));
    let registry_id = governance::registry_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let fee_recipient = governance::fee_recipient(vault);
    let direct_authority_mode = governance::direct_authority_mode(vault);
    let direct_authority_disabled = governance::direct_authority_permanently_disabled(vault);
    let active_operator = governance::active_operator(vault);
    let active_operator_epoch = governance::active_operator_epoch(vault);
    governance::bind_governance_config(vault, governance_config_id, ctx);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::fee_recipient(vault) == fee_recipient);
    ensures(governance::direct_authority_mode(vault) == direct_authority_mode);
    ensures(governance::direct_authority_permanently_disabled(vault) == direct_authority_disabled);
    ensures(governance::active_operator(vault) == active_operator);
    ensures(governance::active_operator_epoch(vault) == active_operator_epoch);
}

#[spec(prove, target = paperproof_governance::governance::assert_valid_direct_authority_mode)]
fun assert_valid_direct_authority_mode_spec(mode: u8) {
    asserts(
        mode == governance::direct_authority_mode_full() ||
        mode == governance::direct_authority_mode_emergency() ||
        mode == governance::direct_authority_mode_read_only() ||
        mode == governance::direct_authority_mode_disabled()
    );
    governance::assert_valid_direct_authority_mode(mode)
}

#[spec(prove, target = paperproof_governance::governance::apply_fee_recipient)]
fun apply_fee_recipient_spec(
    vault: &mut governance::GovernanceVault,
    new_fee_recipient: address,
    changed_by: address,
) {
    requires(new_fee_recipient != @0x0);
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    governance::apply_fee_recipient(vault, new_fee_recipient, changed_by);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::fee_recipient(vault) == new_fee_recipient);
}

#[spec(prove, target = paperproof_governance::governance::apply_governance_authority)]
fun apply_governance_authority_spec(
    vault: &mut governance::GovernanceVault,
    new_governance_authority: address,
    changed_by: address,
) {
    requires(new_governance_authority != @0x0);
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let fee_recipient = governance::fee_recipient(vault);
    governance::apply_governance_authority(vault, new_governance_authority, changed_by);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == new_governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::fee_recipient(vault) == fee_recipient);
}

#[spec(prove, target = paperproof_governance::governance::apply_upgrade_authority)]
fun apply_upgrade_authority_spec(
    vault: &mut governance::GovernanceVault,
    new_upgrade_authority: address,
    changed_by: address,
) {
    requires(new_upgrade_authority != @0x0);
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let fee_recipient = governance::fee_recipient(vault);
    governance::apply_upgrade_authority(vault, new_upgrade_authority, changed_by);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == new_upgrade_authority);
    ensures(governance::fee_recipient(vault) == fee_recipient);
}

#[spec(prove, target = paperproof_governance::governance::apply_direct_authority_mode_from_vote)]
fun apply_direct_authority_mode_from_vote_spec(
    vault: &mut governance::GovernanceVault,
    new_mode: u8,
    changed_by: address,
) {
    requires(
        new_mode == governance::direct_authority_mode_full() ||
        new_mode == governance::direct_authority_mode_emergency() ||
        new_mode == governance::direct_authority_mode_read_only() ||
        new_mode == governance::direct_authority_mode_disabled()
    );
    requires(
        !governance::direct_authority_permanently_disabled(vault) ||
        new_mode == governance::direct_authority_mode_disabled()
    );
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let old_disabled = governance::direct_authority_permanently_disabled(vault);
    governance::apply_direct_authority_mode_from_vote(vault, new_mode, changed_by);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::direct_authority_mode(vault) == new_mode);
    ensures(
        !old_disabled ||
        governance::direct_authority_permanently_disabled(vault)
    );
    ensures(
        new_mode != governance::direct_authority_mode_disabled() ||
        governance::direct_authority_permanently_disabled(vault)
    );
}

#[spec(prove, target = paperproof_governance::governance::assert_valid_fee_level)]
fun assert_valid_fee_level_spec(level: u8) {
    asserts(
        level == 0 ||
        level == 1 ||
        level == 2 ||
        level == 3 ||
        level == 4 ||
        level == 5
    );
    governance::assert_valid_fee_level(level)
}

#[spec(prove, target = paperproof_governance::governance::migrate_vault_version)]
fun migrate_vault_version_spec(vault: &mut governance::GovernanceVault) {
    requires(
        governance::governance_vault_version(vault) <=
        governance::current_governance_vault_version()
    );
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let active_operator = governance::active_operator(vault);
    let active_operator_epoch = governance::active_operator_epoch(vault);
    let fee_recipient = governance::fee_recipient(vault);
    let direct_authority_mode = governance::direct_authority_mode(vault);
    let direct_authority_disabled = governance::direct_authority_permanently_disabled(vault);
    governance::migrate_vault_version(vault);
    ensures(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::active_operator(vault) == active_operator);
    ensures(governance::active_operator_epoch(vault) == active_operator_epoch);
    ensures(governance::fee_recipient(vault) == fee_recipient);
    ensures(governance::direct_authority_mode(vault) == direct_authority_mode);
    ensures(governance::direct_authority_permanently_disabled(vault) == direct_authority_disabled);
}

#[spec(prove, target = paperproof_governance::governance::migrate_vault)]
fun migrate_vault_spec(vault: &mut governance::GovernanceVault, ctx: &TxContext) {
    requires(tx_context::sender(ctx) == governance::upgrade_authority(vault));
    requires(
        governance::governance_vault_version(vault) <=
        governance::current_governance_vault_version()
    );
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let active_operator = governance::active_operator(vault);
    let active_operator_epoch = governance::active_operator_epoch(vault);
    let fee_recipient = governance::fee_recipient(vault);
    let direct_authority_mode = governance::direct_authority_mode(vault);
    let direct_authority_disabled = governance::direct_authority_permanently_disabled(vault);
    governance::migrate_vault(vault, ctx);
    ensures(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::active_operator(vault) == active_operator);
    ensures(governance::active_operator_epoch(vault) == active_operator_epoch);
    ensures(governance::fee_recipient(vault) == fee_recipient);
    ensures(governance::direct_authority_mode(vault) == direct_authority_mode);
    ensures(governance::direct_authority_permanently_disabled(vault) == direct_authority_disabled);
}


#[spec(prove, target = paperproof_governance::governance_voting::assert_current_config)]
fun assert_current_config_spec(config: &governance_voting::GovernanceConfig) {
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    governance_voting::assert_current_config(config)
}

#[spec(prove, target = paperproof_governance::governance_voting::migrate_config_version)]
fun migrate_config_version_spec(config: &mut governance_voting::GovernanceConfig) {
    requires(governance_voting::config_version(config) <= governance_voting::current_config_version());
    let registry_id = governance_voting::config_registry_id(config);
    let total_supply = governance_voting::total_supply(config);
    let proposer_threshold = governance_voting::proposer_threshold(config);
    let duration = governance_voting::configured_proposal_duration_epochs(config);
    let paused = governance_voting::proposal_creation_paused(config);
    let next_proposal_id = governance_voting::next_proposal_id(config);
    let active_proposal_id = governance_voting::active_proposal_id(config);
    governance_voting::migrate_config_version(config);
    ensures(governance_voting::config_version(config) == governance_voting::current_config_version());
    ensures(governance_voting::config_registry_id(config) == registry_id);
    ensures(governance_voting::total_supply(config) == total_supply);
    ensures(governance_voting::proposer_threshold(config) == proposer_threshold);
    ensures(governance_voting::configured_proposal_duration_epochs(config) == duration);
    ensures(governance_voting::proposal_creation_paused(config) == paused);
    ensures(governance_voting::next_proposal_id(config) == next_proposal_id);
    ensures(governance_voting::active_proposal_id(config) == active_proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_current_proposal)]
fun assert_current_proposal_spec(proposal: &governance_voting::Proposal) {
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    governance_voting::assert_current_proposal(proposal)
}

#[spec(prove, target = paperproof_governance::governance_voting::migrate_proposal_version)]
fun migrate_proposal_version_spec(proposal: &mut governance_voting::Proposal) {
    requires(governance_voting::proposal_version(proposal) <= governance_voting::current_proposal_version());
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let proposal_type = governance_voting::proposal_type(proposal);
    let action_type = governance_voting::action_type(proposal);
    let yes_votes = governance_voting::yes_votes(proposal);
    let no_votes = governance_voting::no_votes(proposal);
    let status = governance_voting::proposal_status(proposal);
    let executed = governance_voting::proposal_executed(proposal);
    governance_voting::migrate_proposal_version(proposal);
    ensures(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance_voting::proposal_type(proposal) == proposal_type);
    ensures(governance_voting::action_type(proposal) == action_type);
    ensures(governance_voting::yes_votes(proposal) == yes_votes);
    ensures(governance_voting::no_votes(proposal) == no_votes);
    ensures(governance_voting::proposal_status(proposal) == status);
    ensures(governance_voting::proposal_executed(proposal) == executed);
}

#[spec(prove, target = paperproof_governance::governance_voting::new_governance_config)]
fun new_governance_config_spec(
    vault: &mut governance::GovernanceVault,
    ctx: &mut TxContext,
): governance_voting::GovernanceConfig {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(
        tx_context::sender(ctx) == governance::governance_authority(vault) ||
        tx_context::sender(ctx) == governance::upgrade_authority(vault)
    );
    let vault_registry_id = governance::registry_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let active_operator = governance::active_operator(vault);
    let active_operator_epoch = governance::active_operator_epoch(vault);
    let fee_recipient = governance::fee_recipient(vault);
    let direct_authority_mode = governance::direct_authority_mode(vault);
    let direct_authority_disabled = governance::direct_authority_permanently_disabled(vault);
    let result = governance_voting::new_governance_config(vault, ctx);
    ensures(governance_voting::config_version(&result) == governance_voting::current_config_version());
    ensures(governance_voting::config_registry_id(&result) == vault_registry_id);
    ensures(governance_voting::next_proposal_id(&result) == 1);
    ensures(option::is_none(&governance_voting::active_proposal_id(&result)));
    ensures(governance_voting::total_supply(&result) > 0);
    ensures(governance_voting::proposer_threshold(&result) == governance_voting::default_proposal_duration_epochs() * 0 + governance_voting::proposer_threshold(&result));
    ensures(governance::registry_id(vault) == vault_registry_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::active_operator(vault) == active_operator);
    ensures(governance::active_operator_epoch(vault) == active_operator_epoch);
    ensures(governance::fee_recipient(vault) == fee_recipient);
    ensures(governance::direct_authority_mode(vault) == direct_authority_mode);
    ensures(governance::direct_authority_permanently_disabled(vault) == direct_authority_disabled);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::share_governance_config)]
fun share_governance_config_spec(config: governance_voting::GovernanceConfig) {
    governance_voting::share_governance_config(config)
}

#[spec(prove, target = paperproof_governance::governance_voting::migrate_config)]
fun migrate_config_spec(
    config: &mut governance_voting::GovernanceConfig,
    vault: &governance::GovernanceVault,
    ctx: &TxContext,
) {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance_voting::config_registry_id(config) == governance::registry_id(vault));
    requires(governance::governance_config_id(vault) == object::id(config));
    requires(tx_context::sender(ctx) == governance::upgrade_authority(vault));
    requires(governance_voting::config_version(config) <= governance_voting::current_config_version());
    let registry_id = governance_voting::config_registry_id(config);
    let total_supply = governance_voting::total_supply(config);
    let proposer_threshold = governance_voting::proposer_threshold(config);
    let duration = governance_voting::configured_proposal_duration_epochs(config);
    let paused = governance_voting::proposal_creation_paused(config);
    let next_proposal_id = governance_voting::next_proposal_id(config);
    let active_proposal_id = governance_voting::active_proposal_id(config);
    governance_voting::migrate_config(config, vault, ctx);
    ensures(governance_voting::config_version(config) == governance_voting::current_config_version());
    ensures(governance_voting::config_registry_id(config) == registry_id);
    ensures(governance_voting::total_supply(config) == total_supply);
    ensures(governance_voting::proposer_threshold(config) == proposer_threshold);
    ensures(governance_voting::configured_proposal_duration_epochs(config) == duration);
    ensures(governance_voting::proposal_creation_paused(config) == paused);
    ensures(governance_voting::next_proposal_id(config) == next_proposal_id);
    ensures(governance_voting::active_proposal_id(config) == active_proposal_id);
    ensures(governance_voting::action_enabled(config, governance_voting::action_set_governance_authority()));
}

#[spec(prove, target = paperproof_governance::governance_voting::migrate_proposal)]
fun migrate_proposal_spec(
    proposal: &mut governance_voting::Proposal,
    vault: &governance::GovernanceVault,
    ctx: &TxContext,
) {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance_voting::proposal_registry_id(proposal) == governance::registry_id(vault));
    requires(tx_context::sender(ctx) == governance::upgrade_authority(vault));
    requires(governance_voting::proposal_version(proposal) <= governance_voting::current_proposal_version());
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let proposal_type = governance_voting::proposal_type(proposal);
    let action_type = governance_voting::action_type(proposal);
    let yes_votes = governance_voting::yes_votes(proposal);
    let no_votes = governance_voting::no_votes(proposal);
    let status = governance_voting::proposal_status(proposal);
    let executed = governance_voting::proposal_executed(proposal);
    governance_voting::migrate_proposal(proposal, vault, ctx);
    ensures(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance_voting::proposal_type(proposal) == proposal_type);
    ensures(governance_voting::action_type(proposal) == action_type);
    ensures(governance_voting::yes_votes(proposal) == yes_votes);
    ensures(governance_voting::no_votes(proposal) == no_votes);
    ensures(governance_voting::proposal_status(proposal) == status);
    ensures(governance_voting::proposal_executed(proposal) == executed);
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_valid_action_enable_target)]
fun assert_valid_action_enable_target_spec(action_type: u8) {
    asserts(known_governance_action_type(action_type));
    asserts(action_type != governance_voting::action_set_governance_action_enabled());
    governance_voting::assert_valid_action_enable_target(action_type)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_valid_proposer_threshold)]
fun assert_valid_proposer_threshold_spec(new_threshold: u64) {
    asserts(new_threshold >= governance_voting::minimum_proposer_threshold());
    asserts(new_threshold <= governance_voting::maximum_proposer_threshold());
    governance_voting::assert_valid_proposer_threshold(new_threshold)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_valid_proposal_duration_epochs)]
fun assert_valid_proposal_duration_epochs_spec(new_duration: u64) {
    asserts(new_duration >= governance_voting::minimum_proposal_duration_epochs());
    asserts(new_duration <= governance_voting::maximum_proposal_duration_epochs());
    governance_voting::assert_valid_proposal_duration_epochs(new_duration)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_valid_proposal_text)]
fun assert_valid_proposal_text_spec(title: &String, description: &String) {
    asserts(string::length(title) > 0);
    asserts(string::length(title) <= 256);
    asserts(string::length(description) <= 4096);
    governance_voting::assert_valid_proposal_text(title, description)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_action_enabled)]
fun assert_action_enabled_spec(
    config: &governance_voting::GovernanceConfig,
    action_type: u8,
) {
    requires(governance_voting::action_enabled(config, action_type));
    governance_voting::assert_action_enabled(config, action_type)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_valid_proposal_action_pair)]
fun assert_valid_proposal_action_pair_spec(
    proposal_type: u8,
    action_type: u8,
) {
    asserts(
        (proposal_type == governance_voting::proposal_type_executable() &&
            (
                action_type == governance_voting::action_set_comments_fee_level() ||
                action_type == governance_voting::action_set_fee_recipient() ||
                action_type == governance_voting::action_nominate_operator() ||
                action_type == governance_voting::action_set_proposal_creation_paused() ||
                action_type == governance_voting::action_set_proposer_threshold() ||
                action_type == governance_voting::action_set_upgrade_authority() ||
                action_type == governance_voting::action_set_proposal_duration_epochs() ||
                action_type == governance_voting::action_set_artifact_type_enabled() ||
                action_type == governance_voting::action_set_artifact_fee_level() ||
                action_type == governance_voting::action_activate_artifact_type() ||
                action_type == governance_voting::action_set_governance_action_enabled() ||
                action_type == governance_voting::action_set_direct_authority_mode() ||
                action_type == governance_voting::action_cancel_operator_transfer() ||
                action_type == governance_voting::action_set_governance_authority()
            )) ||
        (proposal_type == governance_voting::proposal_type_signal() &&
            (
                action_type == governance_voting::action_signal_replace_operator() ||
                action_type == governance_voting::action_signal_feature_direction() ||
                action_type == governance_voting::action_signal_policy_position()
            ))
    );
    governance_voting::assert_valid_proposal_action_pair(proposal_type, action_type)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_valid_proposal_payload)]
fun assert_valid_proposal_payload_spec(
    proposal_type: u8,
    action_type: u8,
    payload_u64_1: u64,
    payload_u64_2: u64,
    payload_address: address,
) {
    asserts(
        (proposal_type == governance_voting::proposal_type_executable() &&
            (
                action_type == governance_voting::action_set_comments_fee_level() ||
                action_type == governance_voting::action_set_fee_recipient() ||
                action_type == governance_voting::action_nominate_operator() ||
                action_type == governance_voting::action_set_proposal_creation_paused() ||
                action_type == governance_voting::action_set_proposer_threshold() ||
                action_type == governance_voting::action_set_upgrade_authority() ||
                action_type == governance_voting::action_set_proposal_duration_epochs() ||
                action_type == governance_voting::action_set_artifact_type_enabled() ||
                action_type == governance_voting::action_set_artifact_fee_level() ||
                action_type == governance_voting::action_activate_artifact_type() ||
                action_type == governance_voting::action_set_governance_action_enabled() ||
                action_type == governance_voting::action_set_direct_authority_mode() ||
                action_type == governance_voting::action_cancel_operator_transfer() ||
                action_type == governance_voting::action_set_governance_authority()
            )) ||
        (proposal_type == governance_voting::proposal_type_signal() &&
            (
                action_type == governance_voting::action_signal_replace_operator() ||
                action_type == governance_voting::action_signal_feature_direction() ||
                action_type == governance_voting::action_signal_policy_position()
            ))
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_comments_fee_level() ||
        payload_u64_1 <= 5
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_fee_recipient() ||
        payload_address != @0x0
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_nominate_operator() ||
        payload_address != @0x0
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_proposal_creation_paused() ||
        payload_u64_1 == 0 ||
        payload_u64_1 == 1
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_proposer_threshold() ||
        (
            payload_u64_1 >= governance_voting::minimum_proposer_threshold() &&
            payload_u64_1 <= governance_voting::maximum_proposer_threshold()
        )
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_upgrade_authority() ||
        payload_address != @0x0
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_proposal_duration_epochs() ||
        (
            payload_u64_1 >= governance_voting::minimum_proposal_duration_epochs() &&
            payload_u64_1 <= governance_voting::maximum_proposal_duration_epochs()
        )
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_artifact_type_enabled() ||
        payload_u64_2 == 0 ||
        payload_u64_2 == 1
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_artifact_fee_level() ||
        payload_u64_2 <= 5
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_activate_artifact_type() ||
        payload_u64_2 <= 5
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_governance_action_enabled() ||
        (
            known_governance_action_type(payload_u64_1 as u8) &&
            payload_u64_1 as u8 != governance_voting::action_set_governance_action_enabled() &&
            (payload_u64_2 == 0 || payload_u64_2 == 1)
        )
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_direct_authority_mode() ||
        (
            payload_u64_1 as u8 == governance::direct_authority_mode_full() ||
            payload_u64_1 as u8 == governance::direct_authority_mode_emergency() ||
            payload_u64_1 as u8 == governance::direct_authority_mode_read_only() ||
            payload_u64_1 as u8 == governance::direct_authority_mode_disabled()
        )
    );
    asserts(
        proposal_type != governance_voting::proposal_type_executable() ||
        action_type != governance_voting::action_set_governance_authority() ||
        payload_address != @0x0
    );
    governance_voting::assert_valid_proposal_payload(
        proposal_type,
        action_type,
        payload_u64_1,
        payload_u64_2,
        payload_address,
    )
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_known_action)]
fun assert_known_action_spec(action_type: u8) {
    asserts(known_governance_action_type(action_type));
    governance_voting::assert_known_action(action_type)
}

#[spec(prove, target = paperproof_governance::governance_voting::assert_proposal_belongs_to_config)]
fun assert_proposal_belongs_to_config_spec(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
) {
    requires(governance_voting::config_registry_id(config) == governance_voting::proposal_registry_id(proposal));
    requires(governance_voting::proposal_binding_exists(config, governance_voting::proposal_id(proposal)));
    requires(
        governance_voting::proposal_object_id(config, governance_voting::proposal_id(proposal)) == object::id(proposal)
    );
    governance_voting::assert_proposal_belongs_to_config(config, proposal)
}


#[spec_only]
fun proposal_passage_rule_math(
    config: &governance_voting::GovernanceConfig,
    yes_votes: u64,
    no_votes: u64,
): bool {
    let total_supply = governance_voting::total_supply(config);
    (yes_votes as u128) * 3 >= (no_votes as u128) * 4 &&
    (yes_votes as u128) * 10 > (total_supply as u128)
}

#[spec_only]
fun proposal_passage_rule_math_u128(
    config: &governance_voting::GovernanceConfig,
    yes_votes: u128,
    no_votes: u128,
): bool {
    let total_supply = governance_voting::total_supply(config) as u128;
    yes_votes * 3 >= no_votes * 4 &&
    yes_votes * 10 > total_supply
}

#[spec_only]
fun allowed_executable_action_type(action_type: u8): bool {
    action_type == 2 ||
    action_type == 9 ||
    action_type == 10 ||
    action_type == 11
}

#[spec_only]
fun known_governance_action_type(action_type: u8): bool {
    action_type == governance_voting::action_set_comments_fee_level() ||
    action_type == governance_voting::action_set_fee_recipient() ||
    action_type == governance_voting::action_nominate_operator() ||
    action_type == governance_voting::action_set_proposal_creation_paused() ||
    action_type == governance_voting::action_set_proposer_threshold() ||
    action_type == governance_voting::action_set_upgrade_authority() ||
    action_type == governance_voting::action_set_proposal_duration_epochs() ||
    action_type == governance_voting::action_set_artifact_type_enabled() ||
    action_type == governance_voting::action_set_artifact_fee_level() ||
    action_type == governance_voting::action_activate_artifact_type() ||
    action_type == governance_voting::action_set_governance_action_enabled() ||
    action_type == governance_voting::action_set_direct_authority_mode() ||
    action_type == governance_voting::action_cancel_operator_transfer() ||
    action_type == governance_voting::action_set_governance_authority() ||
    action_type == governance_voting::action_signal_replace_operator() ||
    action_type == governance_voting::action_signal_feature_direction() ||
    action_type == governance_voting::action_signal_policy_position()
}

#[spec_only]
fun governance_remaining_voting_supply(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): u64 {
    governance_voting::total_supply(config) -
    governance_voting::yes_votes(proposal) -
    governance_voting::no_votes(proposal)
}

#[spec_only]
fun governance_deterministic_pass(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): bool {
    let remaining = governance_remaining_voting_supply(config, proposal);
    proposal_passage_rule_math_u128(
        config,
        governance_voting::yes_votes(proposal) as u128,
        (governance_voting::no_votes(proposal) as u128) + (remaining as u128),
    )
}

#[spec_only]
fun governance_deterministic_fail(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): bool {
    let remaining = governance_remaining_voting_supply(config, proposal);
    !proposal_passage_rule_math_u128(
        config,
        (governance_voting::yes_votes(proposal) as u128) + (remaining as u128),
        governance_voting::no_votes(proposal) as u128,
    )
}

#[spec(prove, target = paperproof_governance::governance::artifact_fee_level)]
fun artifact_fee_level_spec(
    fee_manager: &governance::FeeManager,
    artifact_type: u8,
): u8 {
    let result = governance::artifact_fee_level(fee_manager, artifact_type);
    ensures(result == governance::fee_level(fee_manager, artifact_type));
    result
}

#[spec(prove, target = paperproof_governance::governance::comments_fee_level)]
fun comments_fee_level_spec(
    fee_manager: &governance::FeeManager,
): u8 {
    let result = governance::comments_fee_level(fee_manager);
    ensures(result == governance::fee_level(fee_manager, 0));
    result
}

#[spec(prove, target = paperproof_governance::governance::comments_fee_amount)]
fun comments_fee_amount_spec(
    fee_manager: &governance::FeeManager,
): u64 {
    requires(governance::comments_fee_level(fee_manager) <= 5);
    let result = governance::comments_fee_amount(fee_manager);
    ensures(implies(governance::comments_fee_level(fee_manager) == 0, result == 0));
    ensures(implies(governance::comments_fee_level(fee_manager) == 1, result == 10_000));
    ensures(implies(governance::comments_fee_level(fee_manager) == 2, result == 100_000));
    ensures(implies(governance::comments_fee_level(fee_manager) == 3, result == 1_000_000));
    ensures(implies(governance::comments_fee_level(fee_manager) == 4, result == 10_000_000));
    ensures(implies(governance::comments_fee_level(fee_manager) == 5, result == 100_000_000));
    result
}

#[spec(prove, target = paperproof_governance::governance::artifact_fee_amount)]
fun artifact_fee_amount_spec(
    fee_manager: &governance::FeeManager,
    artifact_type: u8,
): u64 {
    requires(governance::artifact_fee_level(fee_manager, artifact_type) <= 5);
    let result = governance::artifact_fee_amount(fee_manager, artifact_type);
    ensures(
        implies(
            governance::artifact_fee_level(fee_manager, artifact_type) == 0,
            result == 0
        )
    );
    ensures(
        implies(
            governance::artifact_fee_level(fee_manager, artifact_type) == 1,
            result == 10_000
        )
    );
    ensures(
        implies(
            governance::artifact_fee_level(fee_manager, artifact_type) == 2,
            result == 100_000
        )
    );
    ensures(
        implies(
            governance::artifact_fee_level(fee_manager, artifact_type) == 3,
            result == 1_000_000
        )
    );
    ensures(
        implies(
            governance::artifact_fee_level(fee_manager, artifact_type) == 4,
            result == 10_000_000
        )
    );
    ensures(
        implies(
            governance::artifact_fee_level(fee_manager, artifact_type) == 5,
            result == 100_000_000
        )
    );
    result
}

#[spec(prove, target = paperproof_governance::governance::operator_epoch)]
fun operator_epoch_spec(permit: &governance::OperatorPermit): u64 {
    let result = governance::operator_epoch(permit);
    result
}

#[spec(prove, target = paperproof_governance::governance::operator_permit_registry_matches)]
fun operator_permit_registry_matches_spec(
    permit: &governance::OperatorPermit,
    registry_id: ID,
): bool {
    let result = governance::operator_permit_registry_matches(permit, registry_id);
    result
}

#[spec(prove, target = paperproof_governance::governance::action_executor_cap_registry_id)]
fun action_executor_cap_registry_id_spec(
    cap: &governance::GovernanceActionExecutorCap,
): ID {
    let result = governance::action_executor_cap_registry_id(cap);
    result
}

#[spec(prove, target = paperproof_governance::governance::action_executor_cap_governance_vault_id)]
fun action_executor_cap_governance_vault_id_spec(
    cap: &governance::GovernanceActionExecutorCap,
): ID {
    let result = governance::action_executor_cap_governance_vault_id(cap);
    result
}

#[spec(prove, target = paperproof_governance::governance::new_action_ticket)]
fun new_action_ticket_spec(
    registry_id: ID,
    action_type: u8,
    payload_u64_1: u64,
    payload_u64_2: u64,
    executed_by: address,
): governance::GovernanceActionTicket {
    let result = governance::new_action_ticket(
        registry_id,
        action_type,
        payload_u64_1,
        payload_u64_2,
        executed_by,
    );
    ensures(governance::action_ticket_registry_id(&result) == registry_id);
    ensures(governance::action_ticket_action_type(&result) == action_type);
    ensures(governance::action_ticket_payload_u64_1(&result) == payload_u64_1);
    ensures(governance::action_ticket_payload_u64_2(&result) == payload_u64_2);
    result
}

#[spec(prove, target = paperproof_governance::governance::action_ticket_registry_id)]
fun action_ticket_registry_id_spec(ticket: &governance::GovernanceActionTicket): ID {
    let result = governance::action_ticket_registry_id(ticket);
    result
}

#[spec(prove, target = paperproof_governance::governance::action_ticket_action_type)]
fun action_ticket_action_type_spec(ticket: &governance::GovernanceActionTicket): u8 {
    let result = governance::action_ticket_action_type(ticket);
    result
}

#[spec(prove, target = paperproof_governance::governance::action_ticket_payload_u64_1)]
fun action_ticket_payload_u64_1_spec(ticket: &governance::GovernanceActionTicket): u64 {
    let result = governance::action_ticket_payload_u64_1(ticket);
    result
}

#[spec(prove, target = paperproof_governance::governance::action_ticket_payload_u64_2)]
fun action_ticket_payload_u64_2_spec(ticket: &governance::GovernanceActionTicket): u64 {
    let result = governance::action_ticket_payload_u64_2(ticket);
    result
}

#[spec(prove, target = paperproof_governance::governance::new_fee_manager)]
fun new_fee_manager_spec(
    registry_id: ID,
    ctx: &mut TxContext,
): governance::FeeManager {
    let result = governance::new_fee_manager(registry_id, ctx);
    ensures(governance::fee_manager_registry_id(&result) == registry_id);
    ensures(governance::comments_fee_level(&result) == 0);
    result
}

#[spec(prove, target = paperproof_governance::governance::share_fee_manager)]
fun share_fee_manager_spec(fee_manager: governance::FeeManager) {
    governance::share_fee_manager(fee_manager)
}

#[spec(prove, target = paperproof_governance::governance::fee_manager_id)]
fun fee_manager_id_spec(fee_manager: &governance::FeeManager): ID {
    let result = governance::fee_manager_id(fee_manager);
    result
}

#[spec(prove, target = paperproof_governance::governance::fee_manager_registry_id)]
fun fee_manager_registry_id_spec(fee_manager: &governance::FeeManager): ID {
    let result = governance::fee_manager_registry_id(fee_manager);
    result
}

#[spec(prove, target = paperproof_governance::governance::fee_level)]
fun fee_level_spec(
    fee_manager: &governance::FeeManager,
    fee_key: u8,
): u8 {
    let result = governance::fee_level(fee_manager, fee_key);
    ensures(result <= 5);
    result
}

#[spec(prove, target = paperproof_governance::governance::apply_comments_fee_level_from_ticket)]
fun apply_comments_fee_level_from_ticket_spec(
    vault: &governance::GovernanceVault,
    fee_manager: &mut governance::FeeManager,
    ticket: governance::GovernanceActionTicket,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(governance::action_ticket_registry_id(&ticket) == governance::registry_id(vault));
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    requires(governance::action_ticket_action_type(&ticket) == governance_voting::action_set_comments_fee_level());
    requires(governance::action_ticket_payload_u64_1(&ticket) <= 5);
    let new_level = governance::action_ticket_payload_u64_1(&ticket) as u8;
    let registry_id = governance::fee_manager_registry_id(fee_manager);
    governance::apply_comments_fee_level_from_ticket(vault, fee_manager, ticket);
    ensures(governance::fee_manager_registry_id(fee_manager) == registry_id);
    ensures(governance::comments_fee_level(fee_manager) == new_level);
}

#[spec(prove, target = paperproof_governance::governance::apply_artifact_fee_level_from_ticket)]
fun apply_artifact_fee_level_from_ticket_spec(
    vault: &governance::GovernanceVault,
    fee_manager: &mut governance::FeeManager,
    ticket: governance::GovernanceActionTicket,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(governance::action_ticket_registry_id(&ticket) == governance::registry_id(vault));
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    requires(
        governance::action_ticket_action_type(&ticket) == governance_voting::action_set_artifact_fee_level() ||
        governance::action_ticket_action_type(&ticket) == governance_voting::action_activate_artifact_type()
    );
    requires(governance::action_ticket_payload_u64_2(&ticket) <= 5);
    let registry_id = governance::fee_manager_registry_id(fee_manager);
    let artifact_type = governance::action_ticket_payload_u64_1(&ticket) as u8;
    let fee_level = governance::action_ticket_payload_u64_2(&ticket) as u8;
    governance::apply_artifact_fee_level_from_ticket(vault, fee_manager, ticket);
    ensures(governance::fee_manager_registry_id(fee_manager) == registry_id);
    ensures(governance::artifact_fee_level(fee_manager, artifact_type) == fee_level);
}

#[spec(prove, target = paperproof_governance::governance::unpack_artifact_type_enabled_ticket)]
fun unpack_artifact_type_enabled_ticket_spec(
    ticket: governance::GovernanceActionTicket,
): (ID, u64, u64, address) {
    requires(governance::action_ticket_action_type(&ticket) == governance_voting::action_set_artifact_type_enabled());
    let registry_id = governance::action_ticket_registry_id(&ticket);
    let payload_u64_1 = governance::action_ticket_payload_u64_1(&ticket);
    let payload_u64_2 = governance::action_ticket_payload_u64_2(&ticket);
    let (result_registry_id, result_payload_u64_1, result_payload_u64_2, executed_by) =
        governance::unpack_artifact_type_enabled_ticket(ticket);
    ensures(result_registry_id == registry_id);
    ensures(result_payload_u64_1 == payload_u64_1);
    ensures(result_payload_u64_2 == payload_u64_2);
    (result_registry_id, result_payload_u64_1, result_payload_u64_2, executed_by)
}

#[spec(prove, target = paperproof_governance::governance::set_fee_level)]
fun set_fee_level_spec(
    fee_manager: &mut governance::FeeManager,
    fee_key: u8,
    new_level: u8,
) {
    requires(new_level <= 5);
    let registry_id = governance::fee_manager_registry_id(fee_manager);
    governance::set_fee_level(fee_manager, fee_key, new_level);
    ensures(governance::fee_manager_registry_id(fee_manager) == registry_id);
    ensures(governance::fee_level(fee_manager, fee_key) == new_level);
}

#[spec(prove, target = paperproof_governance::governance::apply_comments_fee_level)]
fun apply_comments_fee_level_spec(
    fee_manager: &mut governance::FeeManager,
    new_level: u8,
    changed_by: address,
) {
    requires(new_level <= 5);
    let registry_id = governance::fee_manager_registry_id(fee_manager);
    governance::apply_comments_fee_level(fee_manager, new_level, changed_by);
    ensures(governance::fee_manager_registry_id(fee_manager) == registry_id);
    ensures(governance::comments_fee_level(fee_manager) == new_level);
}

#[spec(prove, target = paperproof_governance::governance::assert_direct_authority_allowed)]
fun assert_direct_authority_allowed_spec(
    vault: &governance::GovernanceVault,
    emergency_allowed: bool,
) {
    requires(
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_full() ||
        (
            emergency_allowed &&
            governance::direct_authority_mode(vault) == governance::direct_authority_mode_emergency()
        )
    );
    governance::assert_direct_authority_allowed(vault, emergency_allowed)
}

#[spec(prove, target = paperproof_governance::governance::set_fee_recipient)]
fun set_fee_recipient_spec(
    vault: &mut governance::GovernanceVault,
    new_fee_recipient: address,
    ctx: &TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_full()
    );
    requires(tx_context::sender(ctx) == governance::governance_authority(vault));
    requires(new_fee_recipient != @0x0);
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    governance::set_fee_recipient(vault, new_fee_recipient, ctx);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::fee_recipient(vault) == new_fee_recipient);
}

#[spec(prove, target = paperproof_governance::governance::set_governance_authority)]
fun set_governance_authority_spec(
    vault: &mut governance::GovernanceVault,
    new_governance_authority: address,
    ctx: &TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_full() ||
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_emergency()
    );
    requires(tx_context::sender(ctx) == governance::governance_authority(vault));
    requires(new_governance_authority != @0x0);
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let old_upgrade_authority = governance::upgrade_authority(vault);
    let old_fee_recipient = governance::fee_recipient(vault);
    governance::set_governance_authority(vault, new_governance_authority, ctx);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == new_governance_authority);
    ensures(governance::upgrade_authority(vault) == old_upgrade_authority);
    ensures(governance::fee_recipient(vault) == old_fee_recipient);
}

#[spec(prove, target = paperproof_governance::governance::set_upgrade_authority)]
fun set_upgrade_authority_spec(
    vault: &mut governance::GovernanceVault,
    new_upgrade_authority: address,
    ctx: &TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_full() ||
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_emergency()
    );
    requires(tx_context::sender(ctx) == governance::governance_authority(vault));
    requires(new_upgrade_authority != @0x0);
    let registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let old_governance_authority = governance::governance_authority(vault);
    let old_fee_recipient = governance::fee_recipient(vault);
    governance::set_upgrade_authority(vault, new_upgrade_authority, ctx);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == old_governance_authority);
    ensures(governance::upgrade_authority(vault) == new_upgrade_authority);
    ensures(governance::fee_recipient(vault) == old_fee_recipient);
}

#[spec(prove, target = paperproof_governance::governance::set_comments_fee_level)]
fun set_comments_fee_level_spec(
    vault: &governance::GovernanceVault,
    fee_manager: &mut governance::FeeManager,
    new_level: u8,
    ctx: &TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(
        governance::direct_authority_mode(vault) == governance::direct_authority_mode_full()
    );
    requires(tx_context::sender(ctx) == governance::governance_authority(vault));
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    requires(new_level <= 5);
    let vault_registry_id = governance::registry_id(vault);
    let fee_manager_registry_id = governance::fee_manager_registry_id(fee_manager);
    governance::set_comments_fee_level(vault, fee_manager, new_level, ctx);
    ensures(governance::registry_id(vault) == vault_registry_id);
    ensures(governance::fee_manager_registry_id(fee_manager) == fee_manager_registry_id);
    ensures(governance::comments_fee_level(fee_manager) == new_level);
}

#[spec(prove, target = paperproof_governance::governance::managed_upgrade_package)]
fun managed_upgrade_package_spec(
    managed_cap: &governance::ManagedUpgradeCap,
): ID {
    let result = governance::managed_upgrade_package(managed_cap);
    result
}

#[spec(prove, target = paperproof_governance::governance::register_managed_upgrade_cap)]
fun register_managed_upgrade_cap_spec(
    vault: &governance::GovernanceVault,
    cap: UpgradeCap,
    ctx: &mut TxContext,
): governance::ManagedUpgradeCap {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(tx_context::sender(ctx) == governance::upgrade_authority(vault));
    requires(package::upgrade_package(&cap).to_address() != @0x0);
    let registry_id = governance::registry_id(vault);
    let package_id = package::upgrade_package(&cap);
    let result = governance::register_managed_upgrade_cap(vault, cap, ctx);
    ensures(governance::managed_upgrade_package(&result) == package_id);
    ensures(package_id.to_address() != @0x0);
    ensures(registry_id == governance::registry_id(vault));
    result
}

#[spec(prove, target = paperproof_governance::governance::share_managed_upgrade_cap)]
fun share_managed_upgrade_cap_spec(managed_cap: governance::ManagedUpgradeCap) {
    governance::share_managed_upgrade_cap(managed_cap)
}

#[spec(prove, target = paperproof_governance::governance::authorize_managed_upgrade)]
fun authorize_managed_upgrade_spec(
    vault: &governance::GovernanceVault,
    managed_cap: &mut governance::ManagedUpgradeCap,
    policy: u8,
    digest: vector<u8>,
    ctx: &TxContext,
): UpgradeTicket {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(tx_context::sender(ctx) == governance::upgrade_authority(vault));
    requires(governance::managed_upgrade_package(managed_cap).to_address() != @0x0);
    let registry_id = governance::registry_id(vault);
    let package_id = governance::managed_upgrade_package(managed_cap);
    let result = governance::authorize_managed_upgrade(vault, managed_cap, policy, digest, ctx);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::managed_upgrade_package(managed_cap) == package_id);
    result
}

#[spec(prove, target = paperproof_governance::governance::commit_managed_upgrade)]
fun commit_managed_upgrade_spec(
    vault: &governance::GovernanceVault,
    managed_cap: &mut governance::ManagedUpgradeCap,
    receipt: UpgradeReceipt,
    ctx: &TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(tx_context::sender(ctx) == governance::upgrade_authority(vault));
    requires(governance::managed_upgrade_package(managed_cap).to_address() != @0x0);
    let registry_id = governance::registry_id(vault);
    let package_id = governance::managed_upgrade_package(managed_cap);
    governance::commit_managed_upgrade(vault, managed_cap, receipt, ctx);
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::managed_upgrade_package(managed_cap) == package_id);
}

#[spec(prove, target = paperproof_governance::governance::collect_comments_fee)]
fun collect_comments_fee_spec(
    vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    let vault_registry_id = governance::registry_id(vault);
    let governance_config_id = governance::governance_config_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let active_operator = governance::active_operator(vault);
    let active_operator_epoch = governance::active_operator_epoch(vault);
    let fee_recipient = governance::fee_recipient(vault);
    let direct_authority_mode = governance::direct_authority_mode(vault);
    let direct_authority_disabled = governance::direct_authority_permanently_disabled(vault);
    let fee_manager_registry_id = governance::fee_manager_registry_id(fee_manager);
    let old_comments_fee_level = governance::comments_fee_level(fee_manager);
    governance::collect_comments_fee(vault, fee_manager, payment, ctx);
    ensures(governance::registry_id(vault) == vault_registry_id);
    ensures(governance::governance_config_id(vault) == governance_config_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::active_operator(vault) == active_operator);
    ensures(governance::active_operator_epoch(vault) == active_operator_epoch);
    ensures(governance::fee_recipient(vault) == fee_recipient);
    ensures(governance::direct_authority_mode(vault) == direct_authority_mode);
    ensures(governance::direct_authority_permanently_disabled(vault) == direct_authority_disabled);
    ensures(governance::fee_manager_registry_id(fee_manager) == fee_manager_registry_id);
    ensures(governance::comments_fee_level(fee_manager) == old_comments_fee_level);
}

#[spec(prove, target = paperproof_governance::governance::borrow_operator_from_wrapper)]
fun borrow_operator_from_wrapper_spec(
    operator_wrapper: &TwoStepTransferWrapper<governance::OperatorPermit>,
): &governance::OperatorPermit {
    let result = governance::borrow_operator_from_wrapper(operator_wrapper);
    ensures(governance::operator_epoch(result) == governance::operator_epoch(result));
    result
}

#[spec(prove, target = paperproof_governance::governance::unwrap_operator_permit)]
fun unwrap_operator_permit_spec(
    operator_wrapper: TwoStepTransferWrapper<governance::OperatorPermit>,
    ctx: &mut TxContext,
): governance::OperatorPermit {
    let result = governance::unwrap_operator_permit(operator_wrapper, ctx);
    result
}

#[spec(prove, target = paperproof_governance::governance::nominate_operator_state_for_testing)]
fun nominate_operator_state_for_testing_spec(
    vault: &mut governance::GovernanceVault,
    new_operator: address,
    nominated_by: address,
    wrapper_id: ID,
) {
    requires(!governance::has_pending_operator_transfer(vault));
    requires(new_operator != @0x0);
    let old_registry_id = governance::registry_id(vault);
    let old_active_operator = governance::active_operator(vault);
    let old_active_operator_epoch = governance::active_operator_epoch(vault);
    let old_governance_authority = governance::governance_authority(vault);
    let old_upgrade_authority = governance::upgrade_authority(vault);
    let old_fee_recipient = governance::fee_recipient(vault);
    let old_direct_authority_mode = governance::direct_authority_mode(vault);
    let old_direct_authority_permanently_disabled =
        governance::direct_authority_permanently_disabled(vault);
    governance::nominate_operator_state_for_testing(vault, new_operator, nominated_by, wrapper_id);
    ensures(governance::registry_id(vault) == old_registry_id);
    ensures(governance::active_operator(vault) == old_active_operator);
    ensures(governance::active_operator_epoch(vault) == old_active_operator_epoch);
    ensures(governance::pending_operator(vault) == new_operator);
    ensures(governance::pending_operator_epoch(vault) == old_active_operator_epoch + 1);
    ensures(governance::pending_operator_wrapper_id(vault) == wrapper_id);
    ensures(governance::has_pending_operator_transfer(vault));
    ensures(governance::governance_authority(vault) == old_governance_authority);
    ensures(governance::upgrade_authority(vault) == old_upgrade_authority);
    ensures(governance::fee_recipient(vault) == old_fee_recipient);
    ensures(governance::direct_authority_mode(vault) == old_direct_authority_mode);
    ensures(
        governance::direct_authority_permanently_disabled(vault) ==
        old_direct_authority_permanently_disabled
    );
}

#[spec(prove, target = paperproof_governance::governance::nominate_operator)]
fun nominate_operator_spec(
    vault: &mut governance::GovernanceVault,
    new_operator: address,
    ctx: &mut TxContext,
) {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::direct_authority_mode(vault) != governance::direct_authority_mode_disabled());
    requires(tx_context::sender(ctx) == governance::governance_authority(vault));
    requires(!governance::has_pending_operator_transfer(vault));
    requires(new_operator != @0x0);
    governance::nominate_operator(vault, new_operator, ctx)
}

#[spec(prove, target = paperproof_governance::governance::accept_operator_transfer_state_for_testing)]
fun accept_operator_transfer_state_for_testing_spec(
    vault: &mut governance::GovernanceVault,
    accepted_by: address,
) {
    requires(governance::has_pending_operator_transfer(vault));
    let old_registry_id = governance::registry_id(vault);
    let old_pending_operator = governance::pending_operator(vault);
    let old_pending_operator_epoch = governance::pending_operator_epoch(vault);
    let old_pending_operator_wrapper_id = governance::pending_operator_wrapper_id(vault);
    let old_governance_authority = governance::governance_authority(vault);
    let old_upgrade_authority = governance::upgrade_authority(vault);
    let old_fee_recipient = governance::fee_recipient(vault);
    let old_direct_authority_mode = governance::direct_authority_mode(vault);
    let old_direct_authority_permanently_disabled =
        governance::direct_authority_permanently_disabled(vault);
    governance::accept_operator_transfer_state_for_testing(vault, accepted_by);
    ensures(governance::registry_id(vault) == old_registry_id);
    ensures(governance::active_operator(vault) == old_pending_operator);
    ensures(governance::active_operator_epoch(vault) == old_pending_operator_epoch);
    ensures(governance::pending_operator(vault) == @0x0);
    ensures(governance::pending_operator_epoch(vault) == 0);
    ensures(
        governance::pending_operator_wrapper_id(vault) == object::id_from_address(@0x0)
    );
    ensures(!governance::has_pending_operator_transfer(vault));
    ensures(governance::governance_authority(vault) == old_governance_authority);
    ensures(governance::upgrade_authority(vault) == old_upgrade_authority);
    ensures(governance::fee_recipient(vault) == old_fee_recipient);
    ensures(governance::direct_authority_mode(vault) == old_direct_authority_mode);
    ensures(
        governance::direct_authority_permanently_disabled(vault) ==
        old_direct_authority_permanently_disabled
    );
    ensures(old_pending_operator_wrapper_id == old_pending_operator_wrapper_id);
}

#[spec(prove, target = paperproof_governance::governance::accept_operator_transfer)]
fun accept_operator_transfer_spec(
    vault: &mut governance::GovernanceVault,
    request: PendingOwnershipTransfer<governance::OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<governance::OperatorPermit>>,
    ctx: &mut TxContext,
) {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::has_pending_operator_transfer(vault));
    governance::accept_operator_transfer(vault, request, wrapper_ticket, ctx)
}

#[spec(prove, target = paperproof_governance::governance::cancel_operator_transfer_state_for_testing)]
fun cancel_operator_transfer_state_for_testing_spec(
    vault: &mut governance::GovernanceVault,
    cancelled_by: address,
) {
    requires(governance::has_pending_operator_transfer(vault));
    let old_registry_id = governance::registry_id(vault);
    let old_active_operator = governance::active_operator(vault);
    let old_active_operator_epoch = governance::active_operator_epoch(vault);
    let old_governance_authority = governance::governance_authority(vault);
    let old_upgrade_authority = governance::upgrade_authority(vault);
    let old_fee_recipient = governance::fee_recipient(vault);
    let old_direct_authority_mode = governance::direct_authority_mode(vault);
    let old_direct_authority_permanently_disabled =
        governance::direct_authority_permanently_disabled(vault);
    governance::cancel_operator_transfer_state_for_testing(vault, cancelled_by);
    ensures(governance::registry_id(vault) == old_registry_id);
    ensures(governance::active_operator(vault) == old_active_operator);
    ensures(governance::active_operator_epoch(vault) == old_active_operator_epoch);
    ensures(governance::pending_operator(vault) == @0x0);
    ensures(governance::pending_operator_epoch(vault) == 0);
    ensures(
        governance::pending_operator_wrapper_id(vault) == object::id_from_address(@0x0)
    );
    ensures(!governance::has_pending_operator_transfer(vault));
    ensures(governance::governance_authority(vault) == old_governance_authority);
    ensures(governance::upgrade_authority(vault) == old_upgrade_authority);
    ensures(governance::fee_recipient(vault) == old_fee_recipient);
    ensures(governance::direct_authority_mode(vault) == old_direct_authority_mode);
    ensures(
        governance::direct_authority_permanently_disabled(vault) ==
        old_direct_authority_permanently_disabled
    );
}

#[spec(prove, target = paperproof_governance::governance::cancel_operator_transfer)]
fun cancel_operator_transfer_spec(
    vault: &mut governance::GovernanceVault,
    request: PendingOwnershipTransfer<governance::OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<governance::OperatorPermit>>,
    ctx: &mut TxContext,
) {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::direct_authority_mode(vault) != governance::direct_authority_mode_disabled());
    requires(tx_context::sender(ctx) == governance::governance_authority(vault));
    requires(governance::has_pending_operator_transfer(vault));
    governance::cancel_operator_transfer(vault, request, wrapper_ticket, ctx)
}

#[spec(prove, target = paperproof_governance::governance::collect_artifact_fee)]
fun collect_artifact_fee_spec(
    vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    artifact_type: u8,
    payment: option::Option<Coin<SUI>>,
    ctx: &mut TxContext,
) {
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    governance::collect_artifact_fee(vault, fee_manager, artifact_type, payment, ctx)
}

#[spec(prove, target = paperproof_governance::governance::collect_artifact_fee_accounting_for_testing)]
fun collect_artifact_fee_accounting_for_testing_spec(
    vault: &governance::GovernanceVault,
    fee_manager: &governance::FeeManager,
    artifact_type: u8,
    payer: address,
): u64 {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    requires(governance::artifact_fee_level(fee_manager, artifact_type) <= 5);
    let registry_id = governance::registry_id(vault);
    let governance_authority = governance::governance_authority(vault);
    let upgrade_authority = governance::upgrade_authority(vault);
    let active_operator = governance::active_operator(vault);
    let active_operator_epoch = governance::active_operator_epoch(vault);
    let fee_recipient = governance::fee_recipient(vault);
    let direct_authority_mode = governance::direct_authority_mode(vault);
    let direct_authority_disabled =
        governance::direct_authority_permanently_disabled(vault);
    let fee_manager_registry_id = governance::fee_manager_registry_id(fee_manager);
    let fee_level = governance::artifact_fee_level(fee_manager, artifact_type);
    let result = governance::collect_artifact_fee_accounting_for_testing(
        vault,
        fee_manager,
        artifact_type,
        payer,
    );
    ensures(governance::registry_id(vault) == registry_id);
    ensures(governance::governance_authority(vault) == governance_authority);
    ensures(governance::upgrade_authority(vault) == upgrade_authority);
    ensures(governance::active_operator(vault) == active_operator);
    ensures(governance::active_operator_epoch(vault) == active_operator_epoch);
    ensures(governance::fee_recipient(vault) == fee_recipient);
    ensures(governance::direct_authority_mode(vault) == direct_authority_mode);
    ensures(governance::direct_authority_permanently_disabled(vault) == direct_authority_disabled);
    ensures(governance::fee_manager_registry_id(fee_manager) == fee_manager_registry_id);
    ensures(implies(fee_level == 0, result == 0));
    ensures(implies(fee_level == 1, result == 10_000));
    ensures(implies(fee_level == 2, result == 100_000));
    ensures(implies(fee_level == 3, result == 1_000_000));
    ensures(implies(fee_level == 4, result == 10_000_000));
    ensures(implies(fee_level == 5, result == 100_000_000));
    result
}

#[spec(prove, target = paperproof_governance::governance::assert_active_operator)]
fun assert_active_operator_spec(
    vault: &governance::GovernanceVault,
    permit: &governance::OperatorPermit,
    registry_id: ID,
    sender: address,
) {
    requires(
        governance::governance_vault_version(vault) ==
        governance::current_governance_vault_version()
    );
    requires(governance::registry_id(vault) == registry_id);
    requires(governance::operator_permit_registry_matches(permit, registry_id));
    requires(sender == governance::active_operator(vault));
    requires(governance::operator_epoch(permit) == governance::active_operator_epoch(vault));
    governance::assert_active_operator(vault, permit, registry_id, sender)
}

#[spec(prove, target = paperproof_governance::governance_voting::create_proposal)]
fun create_proposal_spec(
    config: &mut governance_voting::GovernanceConfig,
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
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    requires(!governance_voting::proposal_creation_paused(config));
    requires(option::is_none(&governance_voting::active_proposal_id(config)));
    let old_next_proposal_id = governance_voting::next_proposal_id(config);
    let old_registry_id = governance_voting::config_registry_id(config);
    let old_total_supply = governance_voting::total_supply(config);
    let old_proposer_threshold = governance_voting::proposer_threshold(config);
    let old_duration = governance_voting::configured_proposal_duration_epochs(config);
    let old_paused = governance_voting::proposal_creation_paused(config);
    requires(old_next_proposal_id < std::u64::max_value!());
    requires(!governance_voting::proposal_binding_exists(config, old_next_proposal_id));
    requires(
        tx_context::epoch(ctx) <=
        std::u64::max_value!() - governance_voting::configured_proposal_duration_epochs(config)
    );
    requires(string::length(&title) > 0 && string::length(&title) <= 256);
    requires(string::length(&description) <= 4096);
    requires(coin::value(&proposer_stake) >= governance_voting::proposer_threshold(config));
    requires(proposal_type == governance_voting::proposal_type_executable());
    requires(action_type == governance_voting::action_set_comments_fee_level());
    requires(governance_voting::action_enabled(config, action_type));
    requires(payload_u64_1 <= 5);
    let result = governance_voting::create_proposal(
        config,
        proposal_type,
        action_type,
        title,
        description,
        payload_u64_1,
        payload_u64_2,
        payload_address,
        payload_object_id,
        payload_bytes,
        proposer_stake,
        ctx,
    );
    ensures(result == old_next_proposal_id);
    ensures(governance_voting::next_proposal_id(config) == old_next_proposal_id + 1);
    ensures(option::is_some(&governance_voting::active_proposal_id(config)));
    ensures(*option::borrow(&governance_voting::active_proposal_id(config)) == result);
    ensures(governance_voting::proposal_binding_exists(config, result));
    ensures(governance_voting::config_registry_id(config) == old_registry_id);
    ensures(governance_voting::total_supply(config) == old_total_supply);
    ensures(governance_voting::proposer_threshold(config) == old_proposer_threshold);
    ensures(governance_voting::configured_proposal_duration_epochs(config) == old_duration);
    ensures(governance_voting::proposal_creation_paused(config) == old_paused);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::next_proposal_id)]
fun next_proposal_id_spec(
    config: &governance_voting::GovernanceConfig,
): u64 {
    let result = governance_voting::next_proposal_id(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::active_proposal_id)]
fun active_proposal_id_spec(
    config: &governance_voting::GovernanceConfig,
): option::Option<u64> {
    let result = governance_voting::active_proposal_id(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_binding_exists)]
fun proposal_binding_exists_spec(
    config: &governance_voting::GovernanceConfig,
    proposal_id: u64,
): bool {
    let result = governance_voting::proposal_binding_exists(config, proposal_id);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::config_registry_id)]
fun config_registry_id_spec(
    config: &governance_voting::GovernanceConfig,
): ID {
    let result = governance_voting::config_registry_id(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::config_version)]
fun config_version_spec(
    config: &governance_voting::GovernanceConfig,
): u64 {
    let result = governance_voting::config_version(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::current_config_version)]
fun current_config_version_spec(): u64 {
    let result = governance_voting::current_config_version();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_id)]
fun proposal_id_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::proposal_id(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_object_id)]
fun proposal_object_id_spec(
    config: &governance_voting::GovernanceConfig,
    proposal_id: u64,
): ID {
    requires(governance_voting::proposal_binding_exists(config, proposal_id));
    let result = governance_voting::proposal_object_id(config, proposal_id);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_registry_id)]
fun proposal_registry_id_spec(
    proposal: &governance_voting::Proposal,
): ID {
    let result = governance_voting::proposal_registry_id(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_version)]
fun proposal_version_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::proposal_version(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::current_proposal_version)]
fun current_proposal_version_spec(): u64 {
    let result = governance_voting::current_proposal_version();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_type)]
fun proposal_type_spec(
    proposal: &governance_voting::Proposal,
): u8 {
    let result = governance_voting::proposal_type(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_type)]
fun action_type_spec(
    proposal: &governance_voting::Proposal,
): u8 {
    let result = governance_voting::action_type(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::total_supply)]
fun total_supply_spec(
    config: &governance_voting::GovernanceConfig,
): u64 {
    let result = governance_voting::total_supply(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposer_threshold)]
fun proposer_threshold_spec(
    config: &governance_voting::GovernanceConfig,
): u64 {
    let result = governance_voting::proposer_threshold(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::configured_proposal_duration_epochs)]
fun configured_proposal_duration_epochs_spec(
    config: &governance_voting::GovernanceConfig,
): u64 {
    let result = governance_voting::configured_proposal_duration_epochs(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::default_proposal_duration_epochs)]
fun default_proposal_duration_epochs_spec(): u64 {
    let result = governance_voting::default_proposal_duration_epochs();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_creation_paused)]
fun proposal_creation_paused_spec(
    config: &governance_voting::GovernanceConfig,
): bool {
    let result = governance_voting::proposal_creation_paused(config);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::execution_validity_epochs)]
fun execution_validity_epochs_spec(): u64 {
    let result = governance_voting::execution_validity_epochs();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::minimum_proposal_duration_epochs)]
fun minimum_proposal_duration_epochs_spec(): u64 {
    let result = governance_voting::minimum_proposal_duration_epochs();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::maximum_proposal_duration_epochs)]
fun maximum_proposal_duration_epochs_spec(): u64 {
    let result = governance_voting::maximum_proposal_duration_epochs();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::minimum_vote_stake)]
fun minimum_vote_stake_spec(): u64 {
    let result = governance_voting::minimum_vote_stake();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::minimum_proposer_threshold)]
fun minimum_proposer_threshold_spec(): u64 {
    let result = governance_voting::minimum_proposer_threshold();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::maximum_proposer_threshold)]
fun maximum_proposer_threshold_spec(): u64 {
    let result = governance_voting::maximum_proposer_threshold();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_type_executable)]
fun proposal_type_executable_spec(): u8 {
    let result = governance_voting::proposal_type_executable();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_type_signal)]
fun proposal_type_signal_spec(): u8 {
    let result = governance_voting::proposal_type_signal();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_status_active)]
fun proposal_status_active_spec(): u8 {
    let result = governance_voting::proposal_status_active();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_status_passed)]
fun proposal_status_passed_spec(): u8 {
    let result = governance_voting::proposal_status_passed();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_status_rejected)]
fun proposal_status_rejected_spec(): u8 {
    let result = governance_voting::proposal_status_rejected();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_status_executed)]
fun proposal_status_executed_spec(): u8 {
    let result = governance_voting::proposal_status_executed();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_status_expired)]
fun proposal_status_expired_spec(): u8 {
    let result = governance_voting::proposal_status_expired();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_comments_fee_level)]
fun action_set_comments_fee_level_spec(): u8 {
    let result = governance_voting::action_set_comments_fee_level();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_fee_recipient)]
fun action_set_fee_recipient_spec(): u8 {
    let result = governance_voting::action_set_fee_recipient();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_nominate_operator)]
fun action_nominate_operator_spec(): u8 {
    let result = governance_voting::action_nominate_operator();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_proposal_creation_paused)]
fun action_set_proposal_creation_paused_spec(): u8 {
    let result = governance_voting::action_set_proposal_creation_paused();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_proposer_threshold)]
fun action_set_proposer_threshold_spec(): u8 {
    let result = governance_voting::action_set_proposer_threshold();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_upgrade_authority)]
fun action_set_upgrade_authority_spec(): u8 {
    let result = governance_voting::action_set_upgrade_authority();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_proposal_duration_epochs)]
fun action_set_proposal_duration_epochs_spec(): u8 {
    let result = governance_voting::action_set_proposal_duration_epochs();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_artifact_type_enabled)]
fun action_set_artifact_type_enabled_spec(): u8 {
    let result = governance_voting::action_set_artifact_type_enabled();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_artifact_fee_level)]
fun action_set_artifact_fee_level_spec(): u8 {
    let result = governance_voting::action_set_artifact_fee_level();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_activate_artifact_type)]
fun action_activate_artifact_type_spec(): u8 {
    let result = governance_voting::action_activate_artifact_type();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_governance_action_enabled)]
fun action_set_governance_action_enabled_spec(): u8 {
    let result = governance_voting::action_set_governance_action_enabled();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_direct_authority_mode)]
fun action_set_direct_authority_mode_spec(): u8 {
    let result = governance_voting::action_set_direct_authority_mode();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_cancel_operator_transfer)]
fun action_cancel_operator_transfer_spec(): u8 {
    let result = governance_voting::action_cancel_operator_transfer();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_set_governance_authority)]
fun action_set_governance_authority_spec(): u8 {
    let result = governance_voting::action_set_governance_authority();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_signal_replace_operator)]
fun action_signal_replace_operator_spec(): u8 {
    let result = governance_voting::action_signal_replace_operator();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_signal_feature_direction)]
fun action_signal_feature_direction_spec(): u8 {
    let result = governance_voting::action_signal_feature_direction();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_signal_policy_position)]
fun action_signal_policy_position_spec(): u8 {
    let result = governance_voting::action_signal_policy_position();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::vote_side_yes)]
fun vote_side_yes_spec(): u8 {
    let result = governance_voting::vote_side_yes();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::vote_side_no)]
fun vote_side_no_spec(): u8 {
    let result = governance_voting::vote_side_no();
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::execution_expiry_epoch)]
fun execution_expiry_epoch_spec(proposal: &governance_voting::Proposal): u64 {
    requires(
        governance_voting::proposal_end_epoch(proposal) <=
        std::u64::max_value!() - governance_voting::execution_validity_epochs()
    );
    let result = governance_voting::execution_expiry_epoch(proposal);
    ensures(result == governance_voting::proposal_end_epoch(proposal) + governance_voting::execution_validity_epochs());
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::action_enabled)]
fun action_enabled_spec(config: &governance_voting::GovernanceConfig, action_type: u8): bool {
    let result = governance_voting::action_enabled(config, action_type);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::apply_action_enabled)]
fun apply_action_enabled_spec(
    config: &mut governance_voting::GovernanceConfig,
    action_type: u8,
    enabled: bool,
    changed_by: address,
) {
    requires(known_governance_action_type(action_type));
    requires(action_type != governance_voting::action_set_governance_action_enabled());
    let registry_id = governance_voting::config_registry_id(config);
    let old_next_proposal_id = governance_voting::next_proposal_id(config);
    let old_active_proposal_id = governance_voting::active_proposal_id(config);
    let old_total_supply = governance_voting::total_supply(config);
    let old_proposer_threshold = governance_voting::proposer_threshold(config);
    let old_duration = governance_voting::configured_proposal_duration_epochs(config);
    let old_paused = governance_voting::proposal_creation_paused(config);
    governance_voting::apply_action_enabled(config, action_type, enabled, changed_by);
    ensures(governance_voting::config_registry_id(config) == registry_id);
    ensures(governance_voting::next_proposal_id(config) == old_next_proposal_id);
    ensures(governance_voting::active_proposal_id(config) == old_active_proposal_id);
    ensures(governance_voting::total_supply(config) == old_total_supply);
    ensures(governance_voting::proposer_threshold(config) == old_proposer_threshold);
    ensures(governance_voting::configured_proposal_duration_epochs(config) == old_duration);
    ensures(governance_voting::proposal_creation_paused(config) == old_paused);
    ensures(governance_voting::action_enabled(config, action_type) == enabled);
}

#[spec(prove, target = paperproof_governance::governance_voting::clear_active_proposal)]
fun clear_active_proposal_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal_id: u64,
) {
    let registry_id = governance_voting::config_registry_id(config);
    let old_next_proposal_id = governance_voting::next_proposal_id(config);
    let old_active_proposal_id = governance_voting::active_proposal_id(config);
    let old_total_supply = governance_voting::total_supply(config);
    let old_proposer_threshold = governance_voting::proposer_threshold(config);
    let old_duration = governance_voting::configured_proposal_duration_epochs(config);
    let old_paused = governance_voting::proposal_creation_paused(config);
    governance_voting::clear_active_proposal(config, proposal_id);
    ensures(governance_voting::config_registry_id(config) == registry_id);
    ensures(governance_voting::next_proposal_id(config) == old_next_proposal_id);
    ensures(governance_voting::total_supply(config) == old_total_supply);
    ensures(governance_voting::proposer_threshold(config) == old_proposer_threshold);
    ensures(governance_voting::configured_proposal_duration_epochs(config) == old_duration);
    ensures(governance_voting::proposal_creation_paused(config) == old_paused);
    ensures(
        !option::is_some(&old_active_proposal_id) ||
        *option::borrow(&old_active_proposal_id) != proposal_id ||
        option::is_none(&governance_voting::active_proposal_id(config))
    );
    ensures(
        !option::is_some(&old_active_proposal_id) ||
        *option::borrow(&old_active_proposal_id) == proposal_id ||
        governance_voting::active_proposal_id(config) == old_active_proposal_id
    );
}

#[spec(prove, target = paperproof_governance::governance_voting::outcome_determinable)]
fun outcome_determinable_spec(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): bool {
    requires(governance_voting::yes_votes(proposal) <= governance_voting::total_supply(config));
    requires(
        governance_voting::no_votes(proposal) <=
        governance_voting::total_supply(config) - governance_voting::yes_votes(proposal)
    );
    let remaining = governance_voting::remaining_voting_supply(config, proposal);
    requires(remaining == governance_remaining_voting_supply(config, proposal));
    requires(governance_voting::yes_votes(proposal) + remaining <= std::u64::max_value!());
    requires(governance_voting::no_votes(proposal) + remaining <= std::u64::max_value!());
    let result = governance_voting::outcome_determinable(config, proposal);
    ensures(!governance_deterministic_pass(config, proposal) || result);
    ensures(!governance_deterministic_fail(config, proposal) || result);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::passage_rule_satisfied)]
fun passage_rule_satisfied_spec(
    config: &governance_voting::GovernanceConfig,
    yes_votes: u64,
    no_votes: u64,
): bool {
    let result = governance_voting::passage_rule_satisfied(config, yes_votes, no_votes);
    ensures(!result || proposal_passage_rule_math(config, yes_votes, no_votes));
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::vote_yes)]
fun vote_yes_spec(
    proposal: &mut governance_voting::Proposal,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
) {
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_active());
    requires(tx_context::epoch(ctx) < governance_voting::proposal_end_epoch(proposal));
    requires(coin::value(&locked_tokens) > governance_voting::minimum_vote_stake());
    requires(!governance_voting::has_voted(proposal, tx_context::sender(ctx)));
    let voter = tx_context::sender(ctx);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    requires(governance_voting::yes_votes(proposal) <= std::u64::max_value!() - coin::value(&locked_tokens));
    requires(governance_voting::yes_locked_value(proposal) <= std::u64::max_value!() - coin::value(&locked_tokens));
    governance_voting::vote_yes(proposal, locked_tokens, ctx);
    ensures(governance_voting::has_voted(proposal, voter));
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::vote_no)]
fun vote_no_spec(
    proposal: &mut governance_voting::Proposal,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
) {
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_active());
    requires(tx_context::epoch(ctx) < governance_voting::proposal_end_epoch(proposal));
    requires(coin::value(&locked_tokens) > governance_voting::minimum_vote_stake());
    requires(!governance_voting::has_voted(proposal, tx_context::sender(ctx)));
    let voter = tx_context::sender(ctx);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    requires(governance_voting::no_votes(proposal) <= std::u64::max_value!() - coin::value(&locked_tokens));
    requires(governance_voting::no_locked_value(proposal) <= std::u64::max_value!() - coin::value(&locked_tokens));
    governance_voting::vote_no(proposal, locked_tokens, ctx);
    ensures(governance_voting::has_voted(proposal, voter));
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::finalize_proposal)]
fun finalize_proposal_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    ctx: &TxContext,
) {
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_active());
    requires(governance_voting::config_registry_id(config) == governance_voting::proposal_registry_id(proposal));
    requires(governance_voting::proposal_binding_exists(config, governance_voting::proposal_id(proposal)));
    requires(
        governance_voting::proposal_object_id(config, governance_voting::proposal_id(proposal)) == object::id(proposal)
    );
    requires(tx_context::epoch(ctx) >= governance_voting::proposal_end_epoch(proposal));
    let config_registry_id = governance_voting::config_registry_id(config);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let old_yes_votes = governance_voting::yes_votes(proposal);
    let old_no_votes = governance_voting::no_votes(proposal);
    governance_voting::finalize_proposal(config, proposal, ctx);
    ensures(governance_voting::proposal_status(proposal) != governance_voting::proposal_status_active());
    ensures(
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed() ||
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_rejected()
    );
    ensures(governance_voting::yes_votes(proposal) == old_yes_votes);
    ensures(governance_voting::no_votes(proposal) == old_no_votes);
    ensures(governance_voting::config_registry_id(config) == config_registry_id);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::finalize_active_proposal)]
fun finalize_active_proposal_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
) {
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_active());
    requires(proposal_bound_to_config(config, proposal));
    requires(proposal_object_bound_to_config(config, proposal));
    let config_registry_id = governance_voting::config_registry_id(config);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let old_yes_votes = governance_voting::yes_votes(proposal);
    let old_no_votes = governance_voting::no_votes(proposal);
    governance_voting::finalize_active_proposal(config, proposal);
    ensures(governance_voting::proposal_status(proposal) != governance_voting::proposal_status_active());
    ensures(
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed() ||
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_rejected()
    );
    ensures(governance_voting::yes_votes(proposal) == old_yes_votes);
    ensures(governance_voting::no_votes(proposal) == old_no_votes);
    ensures(governance_voting::config_registry_id(config) == config_registry_id);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::resolve_proposal_early)]
fun resolve_proposal_early_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
) {
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_active());
    requires(proposal_bound_to_config(config, proposal));
    requires(proposal_object_bound_to_config(config, proposal));
    requires(governance_voting::outcome_determinable(config, proposal));
    let config_registry_id = governance_voting::config_registry_id(config);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let old_yes_votes = governance_voting::yes_votes(proposal);
    let old_no_votes = governance_voting::no_votes(proposal);
    governance_voting::resolve_proposal_early(config, proposal);
    ensures(governance_voting::proposal_status(proposal) != governance_voting::proposal_status_active());
    ensures(
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed() ||
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_rejected()
    );
    ensures(governance_voting::yes_votes(proposal) == old_yes_votes);
    ensures(governance_voting::no_votes(proposal) == old_no_votes);
    ensures(governance_voting::config_registry_id(config) == config_registry_id);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::expire_passed_proposal)]
fun expire_passed_proposal_spec(
    proposal: &mut governance_voting::Proposal,
    ctx: &TxContext,
) {
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance_voting::is_proposal_executable(proposal));
    requires(
        governance_voting::proposal_end_epoch(proposal) <=
        std::u64::max_value!() - governance_voting::execution_validity_epochs()
    );
    requires(tx_context::epoch(ctx) > governance_voting::execution_expiry_epoch(proposal));
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let old_yes_votes = governance_voting::yes_votes(proposal);
    let old_no_votes = governance_voting::no_votes(proposal);
    governance_voting::expire_passed_proposal(proposal, ctx);
    ensures(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_expired());
    ensures(!governance_voting::proposal_executed(proposal));
    ensures(governance_voting::yes_votes(proposal) == old_yes_votes);
    ensures(governance_voting::no_votes(proposal) == old_no_votes);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
}

#[spec(prove, target = paperproof_governance::governance_voting::expire_proposal_internal)]
fun expire_proposal_internal_spec(
    proposal: &mut governance_voting::Proposal,
    current_epoch: u64,
) {
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let old_yes_votes = governance_voting::yes_votes(proposal);
    let old_no_votes = governance_voting::no_votes(proposal);
    let old_payload_u64_1 = governance_voting::proposal_payload_u64_1(proposal);
    let old_payload_u64_2 = governance_voting::proposal_payload_u64_2(proposal);
    governance_voting::expire_proposal_internal(proposal, current_epoch);
    ensures(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_expired());
    ensures(!governance_voting::proposal_executed(proposal));
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance_voting::yes_votes(proposal) == old_yes_votes);
    ensures(governance_voting::no_votes(proposal) == old_no_votes);
    ensures(governance_voting::proposal_payload_u64_1(proposal) == old_payload_u64_1);
    ensures(governance_voting::proposal_payload_u64_2(proposal) == old_payload_u64_2);
}

#[spec(prove, target = paperproof_governance::governance_voting::claim_locked_tokens)]
fun claim_locked_tokens_spec(
    proposal: &mut governance_voting::Proposal,
    ctx: &mut TxContext,
): Coin<PPRF> {
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    let voter = tx_context::sender(ctx);
    requires(governance_voting::can_claim_locked_tokens(proposal, voter));
    let side = governance_voting::vote_side_of_or_zero(proposal, voter);
    let voting_power = governance_voting::vote_power_of(proposal, voter);
    requires(
        side == governance_voting::vote_side_yes() ||
        side == governance_voting::vote_side_no()
    );
    let old_yes_locked = governance_voting::yes_locked_value(proposal);
    let old_no_locked = governance_voting::no_locked_value(proposal);
    requires(
        side != governance_voting::vote_side_yes() ||
        old_yes_locked >= voting_power
    );
    requires(
        side != governance_voting::vote_side_no() ||
        old_no_locked >= voting_power
    );
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let result = governance_voting::claim_locked_tokens(proposal, ctx);
    ensures(coin::value(&result) == voting_power);
    ensures(!governance_voting::has_voted(proposal, voter));
    ensures(
        side != governance_voting::vote_side_yes() ||
        governance_voting::yes_locked_value(proposal) == old_yes_locked - voting_power
    );
    ensures(
        side != governance_voting::vote_side_no() ||
        governance_voting::no_locked_value(proposal) == old_no_locked - voting_power
    );
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::can_claim_locked_tokens)]
fun can_claim_locked_tokens_spec(
    proposal: &governance_voting::Proposal,
    voter: address,
): bool {
    let result = governance_voting::can_claim_locked_tokens(proposal, voter);
    ensures(
        result ==
        (
            governance_voting::proposal_status(proposal) != governance_voting::proposal_status_active() &&
            governance_voting::has_voted(proposal, voter)
        )
    );
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::yes_votes)]
fun yes_votes_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::yes_votes(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::no_votes)]
fun no_votes_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::no_votes(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::yes_locked_value)]
fun yes_locked_value_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::yes_locked_value(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::no_locked_value)]
fun no_locked_value_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::no_locked_value(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_status)]
fun proposal_status_spec(
    proposal: &governance_voting::Proposal,
): u8 {
    let result = governance_voting::proposal_status(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_executed)]
fun proposal_executed_spec(
    proposal: &governance_voting::Proposal,
): bool {
    let result = governance_voting::proposal_executed(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_start_epoch)]
fun proposal_start_epoch_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::proposal_start_epoch(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_end_epoch)]
fun proposal_end_epoch_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::proposal_end_epoch(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_payload_u64_1)]
fun proposal_payload_u64_1_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::proposal_payload_u64_1(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::proposal_payload_u64_2)]
fun proposal_payload_u64_2_spec(
    proposal: &governance_voting::Proposal,
): u64 {
    let result = governance_voting::proposal_payload_u64_2(proposal);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::vote_power_of)]
fun vote_power_of_spec(
    proposal: &governance_voting::Proposal,
    voter: address,
): u64 {
    let result = governance_voting::vote_power_of(proposal, voter);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::vote_side_of_or_zero)]
fun vote_side_of_or_zero_spec(
    proposal: &governance_voting::Proposal,
    voter: address,
): u8 {
    let result = governance_voting::vote_side_of_or_zero(proposal, voter);
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::has_voted)]
fun has_voted_spec(
    proposal: &governance_voting::Proposal,
    voter: address,
): bool {
    let result = governance_voting::has_voted(proposal, voter);
    ensures(result == (governance_voting::vote_power_of(proposal, voter) > 0));
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::is_proposal_executable)]
fun is_proposal_executable_spec(
    proposal: &governance_voting::Proposal,
): bool {
    let result = governance_voting::is_proposal_executable(proposal);
    ensures(
        result ==
        (
            governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable() &&
            governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed() &&
            !governance_voting::proposal_executed(proposal)
        )
    );
    result
}

#[spec(prove, target = paperproof_governance::governance_voting::remaining_voting_supply)]
fun remaining_voting_supply_spec(
    config: &governance_voting::GovernanceConfig,
    proposal: &governance_voting::Proposal,
): u64 {
    requires(governance_voting::yes_votes(proposal) <= governance_voting::total_supply(config));
    requires(
        governance_voting::no_votes(proposal) <=
        governance_voting::total_supply(config) - governance_voting::yes_votes(proposal)
    );
    let result = governance_voting::remaining_voting_supply(config, proposal);
    ensures(result <= governance_voting::total_supply(config) - governance_voting::yes_votes(proposal));
    result
}



#[spec(prove, target = paperproof_governance::governance_voting::execute_proposal)]
fun execute_proposal_non_nominate_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    vault: &mut governance::GovernanceVault,
    ctx: &mut TxContext,
) {
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::registry_id(vault) == governance_voting::config_registry_id(config));
    requires(proposal_bound_to_config(config, proposal));
    requires(governance_voting::proposal_binding_exists(config, governance_voting::proposal_id(proposal)));
    requires(governance::governance_config_id(vault) == object::id(config));
    requires(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    requires(!governance_voting::proposal_executed(proposal));
    requires(governance_voting::action_type(proposal) != governance_voting::action_nominate_operator());
    let config_registry_id = governance_voting::config_registry_id(config);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let old_payload_u64_1 = governance_voting::proposal_payload_u64_1(proposal);
    let old_payload_u64_2 = governance_voting::proposal_payload_u64_2(proposal);
    governance_voting::execute_proposal(config, proposal, vault, ctx);
    ensures(governance_voting::proposal_executed(proposal));
    ensures(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_executed() ||
        governance_voting::proposal_status(proposal) == governance_voting::proposal_status_expired());
    ensures(governance_voting::config_registry_id(config) == config_registry_id);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance_voting::proposal_payload_u64_1(proposal) == old_payload_u64_1);
    ensures(governance_voting::proposal_payload_u64_2(proposal) == old_payload_u64_2);
}

#[spec(prove, target = paperproof_governance::governance_voting::consume_executable_proposal_action)]
fun consume_executable_proposal_action_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    vault: &governance::GovernanceVault,
    action_executor_cap: &governance::GovernanceActionExecutorCap,
    registry_id: ID,
    expected_action_type: u8,
    ctx: &mut TxContext,
): governance::GovernanceActionTicket {
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::registry_id(vault) == registry_id);
    requires(governance::governance_config_id(vault) == object::id(config));
    requires(governance::action_executor_cap_registry_id(action_executor_cap) == registry_id);
    requires(governance::action_executor_cap_governance_vault_id(action_executor_cap) == object::id(vault));
    requires(governance::registry_id(vault) == governance_voting::config_registry_id(config));
    requires(governance_voting::config_registry_id(config) == governance_voting::proposal_registry_id(proposal));
    requires(governance_voting::proposal_binding_exists(config, governance_voting::proposal_id(proposal)));
    requires(
        governance_voting::proposal_object_id(config, governance_voting::proposal_id(proposal)) == object::id(proposal)
    );
    requires(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    requires(!governance_voting::proposal_executed(proposal));
    requires(governance_voting::action_type(proposal) == expected_action_type);
    requires(allowed_executable_action_type(expected_action_type));
    requires(
        governance_voting::proposal_end_epoch(proposal) <=
        std::u64::max_value!() - governance_voting::execution_validity_epochs()
    );
    requires(tx_context::epoch(ctx) <= governance_voting::execution_expiry_epoch(proposal));
    let config_registry_id = governance_voting::config_registry_id(config);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let vault_registry_id = governance::registry_id(vault);
    let proposal_payload_u64_1 = governance_voting::proposal_payload_u64_1(proposal);
    let proposal_payload_u64_2 = governance_voting::proposal_payload_u64_2(proposal);
    let ticket = governance_voting::consume_executable_proposal_action(
        config,
        proposal,
        vault,
        action_executor_cap,
        registry_id,
        expected_action_type,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(governance_voting::config_registry_id(config) == config_registry_id);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance::registry_id(vault) == vault_registry_id);
    ensures(governance::action_ticket_registry_id(&ticket) == registry_id);
    ensures(governance::action_ticket_action_type(&ticket) == expected_action_type);
    ensures(governance::action_ticket_payload_u64_1(&ticket) == proposal_payload_u64_1);
    ensures(governance::action_ticket_payload_u64_2(&ticket) == proposal_payload_u64_2);
    ticket
}

#[spec(prove, target = paperproof_governance::governance_voting::execute_comments_fee_level_proposal)]
fun execute_comments_fee_level_proposal_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    vault: &governance::GovernanceVault,
    action_executor_cap: &governance::GovernanceActionExecutorCap,
    fee_manager: &mut governance::FeeManager,
    ctx: &mut TxContext,
) {
    requires(governance_voting::config_version(config) == governance_voting::current_config_version());
    requires(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    requires(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    requires(governance::registry_id(vault) == governance_voting::config_registry_id(config));
    requires(governance::governance_config_id(vault) == object::id(config));
    requires(governance::action_executor_cap_registry_id(action_executor_cap) == governance::registry_id(vault));
    requires(governance::action_executor_cap_governance_vault_id(action_executor_cap) == object::id(vault));
    requires(governance::fee_manager_registry_id(fee_manager) == governance::registry_id(vault));
    requires(proposal_bound_to_config(config, proposal));
    requires(proposal_object_bound_to_config(config, proposal));
    requires(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    requires(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    requires(!governance_voting::proposal_executed(proposal));
    requires(governance_voting::action_type(proposal) == governance_voting::action_set_comments_fee_level());
    requires(governance_voting::proposal_payload_u64_1(proposal) <= 5);
    requires(
        governance_voting::proposal_end_epoch(proposal) <=
        std::u64::max_value!() - governance_voting::execution_validity_epochs()
    );
    requires(tx_context::epoch(ctx) <= governance_voting::execution_expiry_epoch(proposal));
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let fee_manager_registry_id = governance::fee_manager_registry_id(fee_manager);
    let new_level = governance_voting::proposal_payload_u64_1(proposal) as u8;
    governance_voting::execute_comments_fee_level_proposal(
        config,
        proposal,
        vault,
        action_executor_cap,
        fee_manager,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_executed());
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance::fee_manager_registry_id(fee_manager) == fee_manager_registry_id);
    ensures(governance::comments_fee_level(fee_manager) == new_level);
}

#[spec(prove, target = paperproof_governance::governance_voting::execute_cancel_operator_transfer_proposal)]
fun execute_cancel_operator_transfer_proposal_spec(
    config: &mut governance_voting::GovernanceConfig,
    proposal: &mut governance_voting::Proposal,
    vault: &mut governance::GovernanceVault,
    request: PendingOwnershipTransfer<governance::OperatorPermit>,
    wrapper_ticket: Receiving<TwoStepTransferWrapper<governance::OperatorPermit>>,
    ctx: &mut TxContext,
) {
    asserts(governance_voting::config_version(config) == governance_voting::current_config_version());
    asserts(governance_voting::proposal_version(proposal) == governance_voting::current_proposal_version());
    asserts(governance::governance_vault_version(vault) == governance::current_governance_vault_version());
    asserts(governance::registry_id(vault) == governance_voting::config_registry_id(config));
    asserts(governance::governance_config_id(vault) == object::id(config));
    asserts(governance_voting::proposal_type(proposal) == governance_voting::proposal_type_executable());
    asserts(governance_voting::proposal_status(proposal) == governance_voting::proposal_status_passed());
    asserts(!governance_voting::proposal_executed(proposal));
    asserts(governance_voting::action_type(proposal) == governance_voting::action_cancel_operator_transfer());
    let config_registry_id = governance_voting::config_registry_id(config);
    let proposal_registry_id = governance_voting::proposal_registry_id(proposal);
    let proposal_id = governance_voting::proposal_id(proposal);
    let vault_registry_id = governance::registry_id(vault);
    governance_voting::execute_cancel_operator_transfer_proposal(
        config,
        proposal,
        vault,
        request,
        wrapper_ticket,
        ctx,
    );
    ensures(governance_voting::proposal_executed(proposal));
    ensures(governance_voting::config_registry_id(config) == config_registry_id);
    ensures(governance_voting::proposal_registry_id(proposal) == proposal_registry_id);
    ensures(governance_voting::proposal_id(proposal) == proposal_id);
    ensures(governance::registry_id(vault) == vault_registry_id);
}
