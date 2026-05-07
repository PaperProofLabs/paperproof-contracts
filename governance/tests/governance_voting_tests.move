#[test_only]
module paperproof_governance::governance_voting_tests;

use std::string;

use paperproof_governance::governance::{Self as governance, FeeManager, GovernanceActionExecutorCap, GovernanceVault, OperatorPermit};
use paperproof_governance::governance_voting::{Self as voting, GovernanceConfig, Proposal};
use pprf::pprf::{Self as pprf, PPRF};

use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use sui::coin::{Self as coin, Coin};
use sui::event;
use sui::test_scenario as ts;

const ADMIN: address = @0xA;
const OPERATOR: address = @0xB;
const VOTER1: address = @0xC;
const NEW_OPERATOR: address = @0xE;
const FEE_RECIPIENT: address = @0xF;
const UPGRADE_AUTHORITY: address = @0x11;

const PROPOSER_THRESHOLD: u64 = 10_000_000_000_000_000;
const QUORUM_PASS_VOTES: u64 = 1_500_000_000_000_000_000;
const LOW_QUORUM_VOTES: u64 = 900_000_000_000_000_000;
const EARLY_PASS_VOTES: u64 = 6_000_000_000_000_000_000;
const EARLY_FAIL_NO_VOTES: u64 = 8_000_000_000_000_000_000;
const MIN_VOTE_PLUS_ONE: u64 = 100_000_000_001;
const UPDATED_PROPOSER_THRESHOLD: u64 = 20_000_000_000_000_000;
const UPDATED_PROPOSAL_DURATION: u64 = 7;

fun mint_votes(amount: u64, scenario: &mut ts::Scenario): Coin<PPRF> {
    coin::mint_for_testing<PPRF>(amount, ts::ctx(scenario))
}

fun repeated_string(byte: u8, len: u64): string::String {
    let mut bytes = vector[];
    let mut i = 0;
    while (i < len) {
        vector::push_back(&mut bytes, byte);
        i = i + 1;
    };
    string::utf8(bytes)
}

fun init_vault_and_config(
    scenario: &mut ts::Scenario,
    registry_id: ID,
) {
    let (mut vault, permit, executor_cap) = governance::new_vault_with_action_executor_cap(
        registry_id,
        ADMIN,
        OPERATOR,
        ts::ctx(scenario),
    );
    let config = voting::new_governance_config(
        &mut vault,
        ts::ctx(scenario),
    );
    let fee_manager = governance::new_fee_manager(registry_id, ts::ctx(scenario));
    governance::share_vault(vault);
    governance::share_fee_manager(fee_manager);
    voting::share_governance_config(config);
    transfer::public_transfer(executor_cap, ADMIN);
    transfer::public_transfer(permit, OPERATOR);
}

fun advance_beyond_voting_period(scenario: &mut ts::Scenario, sender: address) {
    let duration = voting::default_proposal_duration_epochs();
    let mut i = 0;
    while (i < duration) {
        ts::next_epoch(scenario, sender);
        i = i + 1;
    };
}

fun advance_epochs(scenario: &mut ts::Scenario, sender: address, count: u64) {
    let mut i = 0;
    while (i < count) {
        ts::next_epoch(scenario, sender);
        i = i + 1;
    };
}

#[test]
#[expected_failure(abort_code = 18, location = paperproof_governance::governance)]
fun test_duplicate_governance_config_is_rejected() {
    let mut scenario = ts::begin(ADMIN);
    let (mut vault, permit) = governance::new_vault(
        object::id_from_address(@0x499),
        ADMIN,
        OPERATOR,
        ts::ctx(&mut scenario),
    );
    let config = voting::new_governance_config(&mut vault, ts::ctx(&mut scenario));
    transfer::public_transfer(permit, OPERATOR);
    let duplicate = voting::new_governance_config(&mut vault, ts::ctx(&mut scenario));
    voting::share_governance_config(config);
    voting::share_governance_config(duplicate);
    governance::share_vault(vault);
    ts::end(scenario);
}

#[test]
fun test_public_governance_config_constructor_does_not_emit_discovery_event() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x423);

    {
        let (mut vault, permit) = governance::new_vault(
            registry_id,
            ADMIN,
            ADMIN,
            ts::ctx(&mut scenario),
        );
        let config = voting::new_governance_config(&mut vault, ts::ctx(&mut scenario));
        assert!(event::events_by_type<voting::GovernanceConfigCreatedEvent>().length() == 0, 0);
        governance::share_vault(vault);
        voting::share_governance_config(config);
        transfer::public_transfer(permit, ADMIN);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 30, location = paperproof_governance::governance_voting)]
fun test_non_authority_cannot_initialize_governance_config() {
    let mut scenario = ts::begin(VOTER1);
    let (mut vault, permit) = governance::new_vault(
        object::id_from_address(@0x49A),
        ADMIN,
        OPERATOR,
        ts::ctx(&mut scenario),
    );
    let config = voting::new_governance_config(&mut vault, ts::ctx(&mut scenario));
    voting::share_governance_config(config);
    transfer::public_transfer(permit, OPERATOR);
    governance::share_vault(vault);
    ts::end(scenario);
}

#[test]
fun test_create_execute_and_claim_fee_proposal() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x401));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);

        let proposal_id = voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            string::utf8(b"Raise comments fee to level 2"),
            2,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );

        assert!(proposal_id == 1, 0);
        assert!(voting::total_supply(&config) == pprf::total_supply_base_units(), 1);
        assert!(voting::proposer_threshold(&config) == PROPOSER_THRESHOLD, 2);
        assert!(voting::configured_proposal_duration_epochs(&config) == 1, 21);
        assert!(option::destroy_some(voting::active_proposal_id(&config)) == 1, 3);
        assert!(voting::default_proposal_duration_epochs() == 1, 4);
        assert!(voting::minimum_proposal_duration_epochs() == 7, 22);
        assert!(voting::maximum_proposal_duration_epochs() == 14, 23);
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        assert!(voting::yes_locked_value(&proposal) == PROPOSER_THRESHOLD + QUORUM_PASS_VOTES, 5);
        assert!(voting::vote_power_of(&proposal, VOTER1) == QUORUM_PASS_VOTES, 6);
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let action_executor_cap = ts::take_from_sender<GovernanceActionExecutorCap>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_passed(), 7);
        assert!(option::is_none(&voting::active_proposal_id(&config)), 8);

        voting::execute_comments_fee_level_proposal(
            &mut config,
            &mut proposal,
            &vault,
            &action_executor_cap,
            &mut fee_manager,
            ts::ctx(&mut scenario),
        );

        assert!(voting::proposal_executed(&proposal), 9);
        assert!(governance::comments_fee_level(&fee_manager) == 2, 10);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_to_sender(&scenario, action_executor_cap);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let refund = voting::claim_locked_tokens(&mut proposal, ts::ctx(&mut scenario));
        assert!(coin::value(&refund) == QUORUM_PASS_VOTES, 11);
        transfer::public_transfer(refund, VOTER1);
        assert!(voting::yes_locked_value(&proposal) == PROPOSER_THRESHOLD, 12);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let refund = voting::claim_locked_tokens(&mut proposal, ts::ctx(&mut scenario));
        assert!(coin::value(&refund) == PROPOSER_THRESHOLD, 13);
        transfer::public_transfer(refund, ADMIN);
        assert!(voting::yes_locked_value(&proposal) == 0, 14);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_governance::governance_voting)]
fun test_executed_proposal_cannot_execute_again() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x424));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            string::utf8(b"Execute once only"),
            2,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(&mut proposal, mint_votes(QUORUM_PASS_VOTES, &mut scenario), ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let action_executor_cap = ts::take_from_sender<GovernanceActionExecutorCap>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_comments_fee_level_proposal(
            &mut config,
            &mut proposal,
            &vault,
            &action_executor_cap,
            &mut fee_manager,
            ts::ctx(&mut scenario),
        );
        voting::execute_comments_fee_level_proposal(
            &mut config,
            &mut proposal,
            &vault,
            &action_executor_cap,
            &mut fee_manager,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
        ts::return_to_sender(&scenario, action_executor_cap);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 19, location = paperproof_governance::governance_voting)]
fun test_locked_tokens_cannot_be_claimed_twice() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x425));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_feature_direction(),
            string::utf8(b"Signal"),
            string::utf8(b"Low quorum should reject"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(&mut proposal, mint_votes(LOW_QUORUM_VOTES, &mut scenario), ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let refund = voting::claim_locked_tokens(&mut proposal, ts::ctx(&mut scenario));
        transfer::public_transfer(refund, VOTER1);
        let second_refund = voting::claim_locked_tokens(&mut proposal, ts::ctx(&mut scenario));
        transfer::public_transfer(second_refund, VOTER1);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_signal_proposal_passes_but_is_not_executable() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x402));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_feature_direction(),
            string::utf8(b"Signal feature direction"),
            string::utf8(b"Should this feature be developed?"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_passed(), 20);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_operator_nomination_proposal_executes_handoff() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x403));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_nominate_operator(),
            string::utf8(b"Nominate operator"),
            string::utf8(b"Replace operator"),
            0,
            0,
            NEW_OPERATOR,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            ts::ctx(&mut scenario),
        );

        assert!(governance::has_pending_operator_transfer(&vault), 30);
        assert!(governance::pending_operator(&vault) == NEW_OPERATOR, 31);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, NEW_OPERATOR);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        let request = ts::take_shared<PendingOwnershipTransfer<OperatorPermit>>(&scenario);
        let request_id = object::id(&request);
        let ticket = ts::most_recent_receiving_ticket<TwoStepTransferWrapper<OperatorPermit>>(&request_id);

        governance::accept_operator_transfer(
            &mut vault,
            request,
            ticket,
            ts::ctx(&mut scenario),
        );

        assert!(governance::active_operator(&vault) == NEW_OPERATOR, 32);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, NEW_OPERATOR);
    {
        let wrapper = ts::take_from_sender<TwoStepTransferWrapper<OperatorPermit>>(&scenario);
        let permit = governance::unwrap_operator_permit(wrapper, ts::ctx(&mut scenario));
        assert!(governance::operator_epoch(&permit) == 2, 33);
        transfer::public_transfer(permit, NEW_OPERATOR);
    };

    ts::end(scenario);
}

#[test]
fun test_cancel_operator_transfer_proposal_clears_pending_handoff() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x416));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_nominate_operator(),
            string::utf8(b"Nominate operator"),
            string::utf8(b"Create pending operator handoff"),
            0,
            0,
            NEW_OPERATOR,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(&mut proposal, mint_votes(QUORUM_PASS_VOTES, &mut scenario), ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(&mut config, &mut proposal, &mut vault, ts::ctx(&mut scenario));
        assert!(governance::has_pending_operator_transfer(&vault), 34);
        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    let cancel_proposal_id = {
        ts::next_tx(&mut scenario, ADMIN);
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let proposal_id = voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_cancel_operator_transfer(),
            string::utf8(b"Cancel operator transfer"),
            string::utf8(b"Clear stalled pending operator handoff"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        let proposal_object_id = voting::proposal_object_id(&config, proposal_id);
        ts::return_shared(config);
        proposal_object_id
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, cancel_proposal_id);
        voting::vote_yes(&mut proposal, mint_votes(QUORUM_PASS_VOTES, &mut scenario), ts::ctx(&mut scenario));
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared_by_id<Proposal>(&scenario, cancel_proposal_id);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        let request = ts::take_shared<PendingOwnershipTransfer<OperatorPermit>>(&scenario);
        let request_id = object::id(&request);
        let ticket = ts::most_recent_receiving_ticket<TwoStepTransferWrapper<OperatorPermit>>(&request_id);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_cancel_operator_transfer_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            request,
            ticket,
            ts::ctx(&mut scenario),
        );
        assert!(!governance::has_pending_operator_transfer(&vault), 35);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_proposer_threshold_update_uses_existing_governance_flow() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x404));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_proposer_threshold(),
            string::utf8(b"Raise proposer threshold"),
            string::utf8(b"Protect proposal lane"),
            UPDATED_PROPOSER_THRESHOLD,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            ts::ctx(&mut scenario),
        );

        assert!(voting::proposer_threshold(&config) == UPDATED_PROPOSER_THRESHOLD, 40);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_proposal_duration_update_uses_existing_governance_flow() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x40C));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_proposal_duration_epochs(),
            string::utf8(b"Raise proposal duration"),
            string::utf8(b"Move voting window to seven epochs"),
            UPDATED_PROPOSAL_DURATION,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            ts::ctx(&mut scenario),
        );

        assert!(voting::configured_proposal_duration_epochs(&config) == UPDATED_PROPOSAL_DURATION, 42);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_policy_position(),
            string::utf8(b"Duration follow-up"),
            string::utf8(b"Verify new proposal end epoch uses updated duration"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let proposal = ts::take_shared<Proposal>(&scenario);
        assert!(voting::proposal_end_epoch(&proposal) - voting::proposal_start_epoch(&proposal) == UPDATED_PROPOSAL_DURATION, 43);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_upgrade_authority_update_uses_existing_governance_flow() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x40A));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_upgrade_authority(),
            string::utf8(b"Set upgrade authority"),
            string::utf8(b"Move official upgrader control"),
            0,
            0,
            UPGRADE_AUTHORITY,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            ts::ctx(&mut scenario),
        );

        assert!(governance::upgrade_authority(&vault) == UPGRADE_AUTHORITY, 41);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_direct_authority_mode_update_uses_governance_flow() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x416));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_direct_authority_mode(),
            string::utf8(b"Set authority mode"),
            string::utf8(b"Move direct authority to read-only mode"),
            governance::direct_authority_mode_read_only() as u64,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(&mut config, &mut proposal, &mut vault, ts::ctx(&mut scenario));

        assert!(governance::direct_authority_mode(&vault) == governance::direct_authority_mode_read_only(), 82);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_passed_proposal_expires_when_executed_too_late() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x40D));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_fee_recipient(),
            string::utf8(b"Expire fee recipient vote"),
            string::utf8(b"Passed proposal should expire after three epochs"),
            0,
            0,
            FEE_RECIPIENT,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_passed(), 44);
        assert!(voting::execution_expiry_epoch(&proposal) == voting::proposal_end_epoch(&proposal) + voting::execution_validity_epochs(), 45);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    advance_epochs(&mut scenario, ADMIN, voting::execution_validity_epochs() + 1);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::execute_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            ts::ctx(&mut scenario),
        );

        assert!(voting::proposal_status(&proposal) == voting::proposal_status_expired(), 46);
        assert!(!voting::proposal_executed(&proposal), 47);
        assert!(governance::fee_recipient(&vault) == ADMIN, 48);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_passed_proposal_can_be_expired_explicitly() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x40E));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_fee_recipient(),
            string::utf8(b"Expire fee recipient vote"),
            string::utf8(b"Anyone should be able to mark stale passed proposal as expired"),
            0,
            0,
            FEE_RECIPIENT,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    advance_epochs(&mut scenario, VOTER1, voting::execution_validity_epochs() + 1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::expire_passed_proposal(&mut proposal, ts::ctx(&mut scenario));
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_expired(), 49);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_governance::governance)]
fun test_foreign_action_executor_cap_cannot_consume_proposal() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x427));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            string::utf8(b"Foreign executor cap must not consume official proposal"),
            2,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fake_fee_manager = governance::new_fee_manager(governance::registry_id(&vault), ts::ctx(&mut scenario));
        let (fake_vault, fake_permit, fake_executor_cap) =
            governance::new_vault_with_action_executor_cap(
                governance::registry_id(&vault),
                ADMIN,
                OPERATOR,
                ts::ctx(&mut scenario),
            );

        let ticket = voting::consume_executable_proposal_action(
            &mut config,
            &mut proposal,
            &vault,
            &fake_executor_cap,
            governance::registry_id(&vault),
            voting::action_set_comments_fee_level(),
            ts::ctx(&mut scenario),
        );
        governance::apply_comments_fee_level_from_ticket(&vault, &mut fake_fee_manager, ticket);

        governance::share_vault(fake_vault);
        transfer::public_transfer(fake_permit, OPERATOR);
        transfer::public_transfer(fake_executor_cap, ADMIN);
        governance::share_fee_manager(fake_fee_manager);
        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 31, location = paperproof_governance::governance_voting)]
fun test_fake_config_cannot_consume_real_proposal() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x428));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            string::utf8(b"Fake config must not consume this official proposal"),
            2,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let real_vault = ts::take_shared<GovernanceVault>(&scenario);
        let (mut fake_vault, fake_permit, fake_executor_cap) =
            governance::new_vault_with_action_executor_cap(
                governance::registry_id(&real_vault),
                ADMIN,
                OPERATOR,
                ts::ctx(&mut scenario),
            );
        let mut fake_config = voting::new_governance_config(&mut fake_vault, ts::ctx(&mut scenario));
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut fake_fee_manager = governance::new_fee_manager(governance::registry_id(&real_vault), ts::ctx(&mut scenario));

        let ticket = voting::consume_executable_proposal_action(
            &mut fake_config,
            &mut proposal,
            &fake_vault,
            &fake_executor_cap,
            governance::registry_id(&real_vault),
            voting::action_set_comments_fee_level(),
            ts::ctx(&mut scenario),
        );
        governance::apply_comments_fee_level_from_ticket(&fake_vault, &mut fake_fee_manager, ticket);

        ts::return_shared(real_vault);
        governance::share_vault(fake_vault);
        voting::share_governance_config(fake_config);
        governance::share_fee_manager(fake_fee_manager);
        transfer::public_transfer(fake_permit, OPERATOR);
        transfer::public_transfer(fake_executor_cap, ADMIN);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_early_resolution_passes_when_remaining_votes_cannot_flip_result() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x40F));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Early pass"),
            string::utf8(b"Should pass before end when all remaining NO votes cannot flip it"),
            4,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(EARLY_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        assert!(voting::outcome_determinable(&config, &proposal), 62);
        voting::resolve_proposal_early(&mut config, &mut proposal);
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_passed(), 63);
        assert!(option::is_none(&voting::active_proposal_id(&config)), 64);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_early_resolution_rejects_when_remaining_votes_cannot_save_result() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x410));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Early reject"),
            string::utf8(b"Should reject before end when remaining YES votes cannot save it"),
            1,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_no(
            &mut proposal,
            mint_votes(EARLY_FAIL_NO_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        assert!(voting::outcome_determinable(&config, &proposal), 65);
        voting::resolve_proposal_early(&mut config, &mut proposal);
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_rejected(), 66);
        assert!(option::is_none(&voting::active_proposal_id(&config)), 67);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = paperproof_governance::governance_voting)]
fun test_double_vote_is_rejected() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x405));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_fee_recipient(),
            string::utf8(b"Set fee recipient"),
            string::utf8(b"Move fees"),
            0,
            0,
            FEE_RECIPIENT,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        voting::vote_no(
            &mut proposal,
            mint_votes(MIN_VOTE_PLUS_ONE, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 17, location = paperproof_governance::governance_voting)]
fun test_second_active_proposal_is_rejected() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x406));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_policy_position(),
            string::utf8(b"Signal policy"),
            string::utf8(b"Policy statement"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_feature_direction(),
            string::utf8(b"Another proposal"),
            string::utf8(b"Should not be creatable while active"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 20, location = paperproof_governance::governance_voting)]
fun test_vote_stake_must_exceed_one_hundred_pprf() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x407));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_policy_position(),
            string::utf8(b"Signal policy"),
            string::utf8(b"Policy statement"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(100_000_000_000, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_rejected_proposal_on_low_quorum_and_claim_by_address() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x408));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            string::utf8(b"Raise comments fee to level 1"),
            1,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(LOW_QUORUM_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_rejected(), 50);
        ts::return_shared(config);
        ts::return_shared(proposal);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let refund = voting::claim_locked_tokens(&mut proposal, ts::ctx(&mut scenario));
        assert!(coin::value(&refund) == LOW_QUORUM_VOTES, 51);
        transfer::public_transfer(refund, VOTER1);
        ts::return_shared(proposal);
    };

    ts::end(scenario);
}

#[test]
fun test_migrate_config_and_proposal_hooks() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x40B));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        assert!(voting::config_version(&config) == voting::current_config_version(), 60);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_policy_position(),
            string::utf8(b"Migration hook"),
            string::utf8(b"Exercise config and proposal migration hooks"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        let vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::migrate_config(&mut config, &vault, ts::ctx(&mut scenario));
        ts::return_shared(config);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        assert!(voting::proposal_version(&proposal) == voting::current_proposal_version(), 61);
        voting::migrate_proposal(&mut proposal, &vault, ts::ctx(&mut scenario));

        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_governance_action_can_be_disabled_and_reenabled_by_vote() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x414));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_governance_action_enabled(),
            string::utf8(b"Disable comments fee action"),
            string::utf8(b"Temporarily disable comments fee proposals"),
            voting::action_set_comments_fee_level() as u64,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(&mut config, &mut proposal, &mut vault, ts::ctx(&mut scenario));
        assert!(!voting::action_enabled(&config, voting::action_set_comments_fee_level()), 80);
        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_governance_action_enabled(),
            string::utf8(b"Enable comments fee action"),
            string::utf8(b"Re-enable comments fee proposals"),
            voting::action_set_comments_fee_level() as u64,
            1,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(&mut config, &mut proposal, &mut vault, ts::ctx(&mut scenario));
        assert!(voting::action_enabled(&config, voting::action_set_comments_fee_level()), 81);
        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 28, location = paperproof_governance::governance_voting)]
fun test_disabled_governance_action_rejects_new_proposal() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x415));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_governance_action_enabled(),
            string::utf8(b"Disable comments fee action"),
            string::utf8(b"Temporarily disable comments fee proposals"),
            voting::action_set_comments_fee_level() as u64,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::vote_yes(
            &mut proposal,
            mint_votes(QUORUM_PASS_VOTES, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(proposal);
    };

    advance_beyond_voting_period(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        voting::execute_proposal(&mut config, &mut proposal, &mut vault, ts::ctx(&mut scenario));
        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            string::utf8(b"This action is disabled"),
            1,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 22, location = paperproof_governance::governance_voting)]
fun test_invalid_proposer_threshold_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x409));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_proposer_threshold(),
            string::utf8(b"Invalid threshold"),
            string::utf8(b"Too low"),
            99_999_000_000_000,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 32, location = paperproof_governance::governance_voting)]
fun test_empty_proposal_title_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x421));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b""),
            string::utf8(b"Set comments fee"),
            1,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 33, location = paperproof_governance::governance_voting)]
fun test_overlong_proposal_title_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x426));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            repeated_string(65, 257),
            string::utf8(b"Set comments fee"),
            1,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 33, location = paperproof_governance::governance_voting)]
fun test_overlong_proposal_description_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x422));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Set comments fee"),
            repeated_string(65, 4097),
            1,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = paperproof_governance::governance)]
fun test_invalid_fee_level_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x417));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_comments_fee_level(),
            string::utf8(b"Invalid fee"),
            string::utf8(b"Fee level is checked before the vote starts"),
            255,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 12, location = paperproof_governance::governance_voting)]
fun test_invalid_boolean_payload_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x418));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_proposal_creation_paused(),
            string::utf8(b"Invalid pause flag"),
            string::utf8(b"Boolean payloads must be 0 or 1"),
            2,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 29, location = paperproof_governance::governance_voting)]
fun test_invalid_action_enable_target_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x419));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_governance_action_enabled(),
            string::utf8(b"Invalid action target"),
            string::utf8(b"The action-enable action cannot target itself"),
            voting::action_set_governance_action_enabled() as u64,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 15, location = paperproof_governance::governance)]
fun test_invalid_direct_authority_mode_rejected_at_creation() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x420));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_executable(),
            voting::action_set_direct_authority_mode(),
            string::utf8(b"Invalid authority mode"),
            string::utf8(b"Authority mode is checked before the vote starts"),
            255,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 27, location = paperproof_governance::governance_voting)]
fun test_early_resolution_rejected_when_result_is_not_yet_determinable() {
    let mut scenario = ts::begin(ADMIN);
    init_vault_and_config(&mut scenario, object::id_from_address(@0x411));

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        voting::create_proposal(
            &mut config,
            voting::proposal_type_signal(),
            voting::action_signal_policy_position(),
            string::utf8(b"Too early"),
            string::utf8(b"Should not be resolvable yet"),
            0,
            0,
            @0x0,
            option::none(),
            vector[],
            mint_votes(PROPOSER_THRESHOLD, &mut scenario),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(config);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut config = ts::take_shared<GovernanceConfig>(&scenario);
        let mut proposal = ts::take_shared<Proposal>(&scenario);
        voting::resolve_proposal_early(&mut config, &mut proposal);
        ts::return_shared(proposal);
        ts::return_shared(config);
    };

    ts::end(scenario);
}
