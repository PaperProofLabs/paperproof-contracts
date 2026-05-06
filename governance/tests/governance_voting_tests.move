#[test_only]
module paperproof_governance::governance_voting_tests;

use std::string;

use paperproof_governance::governance::{Self as governance, GovernanceVault, OperatorPermit};
use paperproof_governance::governance_voting::{Self as voting, GovernanceConfig, Proposal};
use pprf::pprf::{Self as pprf, PPRF};

use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use sui::coin::{Self as coin, Coin};
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
const MIN_VOTE_PLUS_ONE: u64 = 100_000_000_001;
const UPDATED_PROPOSER_THRESHOLD: u64 = 20_000_000_000_000_000;
const UPDATED_PROPOSAL_DURATION: u64 = 7;

fun mint_votes(amount: u64, scenario: &mut ts::Scenario): Coin<PPRF> {
    coin::mint_for_testing<PPRF>(amount, ts::ctx(scenario))
}

fun init_vault_and_config(
    scenario: &mut ts::Scenario,
    registry_id: ID,
) {
    let (vault, permit) = governance::new_vault(
        registry_id,
        ADMIN,
        OPERATOR,
        ts::ctx(scenario),
    );
    let config = voting::new_governance_config(
        &vault,
        ts::ctx(scenario),
    );
    governance::share_vault(vault);
    voting::share_governance_config(config);
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
            voting::action_set_publishing_fee_level(),
            string::utf8(b"Set publishing fee"),
            string::utf8(b"Raise publishing fee to level 2"),
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
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);

        voting::finalize_proposal(&mut config, &mut proposal, ts::ctx(&mut scenario));
        assert!(voting::proposal_status(&proposal) == voting::proposal_status_passed(), 7);
        assert!(option::is_none(&voting::active_proposal_id(&config)), 8);

        voting::execute_proposal(
            &mut config,
            &mut proposal,
            &mut vault,
            ts::ctx(&mut scenario),
        );

        assert!(voting::proposal_executed(&proposal), 9);
        assert!(governance::publishing_fee_level(&vault) == 2, 10);

        ts::return_shared(config);
        ts::return_shared(proposal);
        ts::return_shared(vault);
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
