#[test_only]
module paperproof_governance::governance_tests;

use paperproof_governance::governance::{Self as governance, GovernanceVault, OperatorPermit};

use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario as ts;

const ADMIN: address = @0xA;
const OPERATOR: address = @0xB;
const NEW_OPERATOR: address = @0xC;
const FEE_RECIPIENT: address = @0xD;
const PAYER: address = @0xE;
const UPGRADE_AUTHORITY: address = @0xF;

#[test]
fun test_vault_defaults_and_fee_setters() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x301),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::share_vault(vault);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        assert!(governance::fee_recipient(&vault) == ADMIN, 0);
        assert!(governance::publishing_fee_level(&vault) == 0, 1);
        assert!(governance::comments_fee_level(&vault) == 0, 2);
        assert!(governance::upgrade_authority(&vault) == ADMIN, 3);

        governance::set_fee_recipient(&mut vault, FEE_RECIPIENT, ts::ctx(&mut scenario));
        governance::set_upgrade_authority(&mut vault, UPGRADE_AUTHORITY, ts::ctx(&mut scenario));
        governance::set_publishing_fee_level(&mut vault, 3, ts::ctx(&mut scenario));
        governance::set_comments_fee_level(&mut vault, 5, ts::ctx(&mut scenario));

        assert!(governance::fee_recipient(&vault) == FEE_RECIPIENT, 4);
        assert!(governance::upgrade_authority(&vault) == UPGRADE_AUTHORITY, 5);
        assert!(governance::publishing_fee_amount(&vault) == 1_000_000, 6);
        assert!(governance::comments_fee_amount(&vault) == 100_000_000, 7);

        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
fun test_collect_publishing_fee_transfers_and_refunds() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x302),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::share_vault(vault);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::set_fee_recipient(&mut vault, FEE_RECIPIENT, ts::ctx(&mut scenario));
        governance::set_publishing_fee_level(&mut vault, 1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, PAYER);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let payment = coin::mint_for_testing<SUI>(20_000, ts::ctx(&mut scenario));
        governance::collect_publishing_fee(
            &vault,
            option::some(payment),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, FEE_RECIPIENT);
    {
        let fee_coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
        assert!(coin::value(&fee_coin) == 10_000, 10);
        transfer::public_transfer(fee_coin, FEE_RECIPIENT);
    };

    ts::next_tx(&mut scenario, PAYER);
    {
        let refund_coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
        assert!(coin::value(&refund_coin) == 10_000, 11);
        transfer::public_transfer(refund_coin, PAYER);
    };

    ts::end(scenario);
}

#[test]
fun test_nominate_and_accept_operator_transfer() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x303),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::share_vault(vault);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::nominate_operator(&mut vault, NEW_OPERATOR, ts::ctx(&mut scenario));
        assert!(governance::has_pending_operator_transfer(&vault), 20);
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

        assert!(governance::active_operator(&vault) == NEW_OPERATOR, 21);
        assert!(governance::active_operator_epoch(&vault) == 2, 22);

        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, NEW_OPERATOR);
    {
        let wrapper = ts::take_from_sender<TwoStepTransferWrapper<OperatorPermit>>(&scenario);
        let permit = governance::unwrap_operator_permit(wrapper, ts::ctx(&mut scenario));
        assert!(governance::operator_epoch(&permit) == 2, 23);
        transfer::public_transfer(permit, NEW_OPERATOR);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 3, location = paperproof_governance::governance)]
fun test_non_governance_authority_cannot_set_fee_level() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x304),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::share_vault(vault);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, OPERATOR);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::set_publishing_fee_level(&mut vault, 1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 11, location = paperproof_governance::governance)]
fun test_collect_comments_fee_rejects_insufficient_payment() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x305),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::share_vault(vault);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        governance::set_comments_fee_level(&mut vault, 2, ts::ctx(&mut scenario));
        ts::return_shared(vault);
    };

    ts::next_tx(&mut scenario, PAYER);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let payment = coin::mint_for_testing<SUI>(99_999, ts::ctx(&mut scenario));
        governance::collect_comments_fee(
            &vault,
            option::some(payment),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(vault);
    };

    ts::end(scenario);
}
