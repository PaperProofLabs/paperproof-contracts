#[test_only]
module paperproof_governance::governance_tests;

use paperproof_governance::governance::{
    Self as governance,
    FeeManager,
    FeeManagerCreatedEvent,
    GovernanceVault,
    GovernanceVaultCreatedEvent,
    OperatorPermit,
};

use openzeppelin_access::two_step_transfer::{
    PendingOwnershipTransfer,
    TwoStepTransferWrapper,
};
use sui::package;
use sui::coin;
use sui::event;
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
        let fee_manager = governance::new_fee_manager(object::id_from_address(@0x301), ts::ctx(&mut scenario));
        governance::share_fee_manager(fee_manager);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        assert!(governance::governance_vault_version(&vault) == governance::current_governance_vault_version(), 0);
        assert!(governance::fee_recipient(&vault) == ADMIN, 0);
        assert!(governance::comments_fee_level(&fee_manager) == 0, 2);
        assert!(governance::upgrade_authority(&vault) == ADMIN, 3);
        assert!(governance::direct_authority_mode(&vault) == governance::direct_authority_mode_full(), 30);
        governance::migrate_vault(&mut vault, ts::ctx(&mut scenario));

        governance::set_fee_recipient(&mut vault, FEE_RECIPIENT, ts::ctx(&mut scenario));
        governance::set_upgrade_authority(&mut vault, UPGRADE_AUTHORITY, ts::ctx(&mut scenario));
        governance::set_comments_fee_level(&vault, &mut fee_manager, 5, ts::ctx(&mut scenario));

        assert!(governance::fee_recipient(&vault) == FEE_RECIPIENT, 4);
        assert!(governance::upgrade_authority(&vault) == UPGRADE_AUTHORITY, 5);
        assert!(governance::comments_fee_amount(&fee_manager) == 100_000_000, 7);

        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}

#[test]
fun test_public_governance_object_constructors_do_not_emit_discovery_events() {
    let mut scenario = ts::begin(ADMIN);
    let registry_id = object::id_from_address(@0x310);

    {
        let (vault, permit) = governance::new_vault(
            registry_id,
            ADMIN,
            ADMIN,
            ts::ctx(&mut scenario),
        );
        let fee_manager = governance::new_fee_manager(registry_id, ts::ctx(&mut scenario));
        assert!(event::events_by_type<GovernanceVaultCreatedEvent>().length() == 0, 0);
        assert!(event::events_by_type<FeeManagerCreatedEvent>().length() == 0, 1);
        governance::share_vault(vault);
        governance::share_fee_manager(fee_manager);
        transfer::public_transfer(permit, ADMIN);
    };

    ts::end(scenario);
}

#[test]
fun test_collect_comments_fee_transfers_and_refunds() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x302),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::share_vault(vault);
        let fee_manager = governance::new_fee_manager(object::id_from_address(@0x302), ts::ctx(&mut scenario));
        governance::share_fee_manager(fee_manager);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        governance::set_fee_recipient(&mut vault, FEE_RECIPIENT, ts::ctx(&mut scenario));
        governance::set_comments_fee_level(&vault, &mut fee_manager, 1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, PAYER);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let payment = coin::mint_for_testing<SUI>(20_000, ts::ctx(&mut scenario));
        governance::collect_comments_fee(
            &vault,
            &fee_manager,
            option::some(payment),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
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
fun test_managed_upgrade_cap_custody_and_upgrade_flow() {
    let mut scenario = ts::begin(ADMIN);

    let managed_cap_id = {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x306),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        let fake_upgrade_cap = package::test_publish(object::id_from_address(@0x777), ts::ctx(&mut scenario));
        let managed = governance::register_managed_upgrade_cap(&vault, fake_upgrade_cap, ts::ctx(&mut scenario));
        let id = object::id(&managed);
        governance::share_vault(vault);
        governance::share_managed_upgrade_cap(managed);
        transfer::public_transfer(permit, OPERATOR);
        id
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut managed = ts::take_shared_by_id<governance::ManagedUpgradeCap>(&scenario, managed_cap_id);
        let old_package = governance::managed_upgrade_package(&managed);

        let ticket = governance::authorize_managed_upgrade(
            &vault,
            &mut managed,
            package::compatible_policy(),
            b"upgrade-digest",
            ts::ctx(&mut scenario),
        );
        let receipt = package::test_upgrade(ticket);
        governance::commit_managed_upgrade(&vault, &mut managed, receipt, ts::ctx(&mut scenario));
        let new_package = governance::managed_upgrade_package(&managed);

        assert!(new_package != old_package, 15);

        ts::return_shared(vault);
        ts::return_shared(managed);
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
#[expected_failure(abort_code = 17, location = paperproof_governance::governance)]
fun test_operator_accept_rejects_foreign_pending_transfer() {
    let mut scenario = ts::begin(ADMIN);

    let real_vault_id = {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x30D),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        let vault_id = object::id(&vault);
        governance::share_vault(vault);
        transfer::public_transfer(permit, OPERATOR);
        vault_id
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let (mut fake_vault, fake_permit) = governance::new_vault(
            object::id_from_address(@0x30E),
            ADMIN,
            OPERATOR,
            ts::ctx(&mut scenario),
        );
        governance::nominate_operator(&mut fake_vault, NEW_OPERATOR, ts::ctx(&mut scenario));
        governance::share_vault(fake_vault);
        transfer::public_transfer(fake_permit, OPERATOR);
    };

    let fake_request_id = {
        ts::next_tx(&mut scenario, ADMIN);
        let fake_request = ts::take_shared<PendingOwnershipTransfer<OperatorPermit>>(&scenario);
        let request_id = object::id(&fake_request);
        ts::return_shared(fake_request);
        request_id
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut real_vault = ts::take_shared_by_id<GovernanceVault>(&scenario, real_vault_id);
        governance::nominate_operator(&mut real_vault, NEW_OPERATOR, ts::ctx(&mut scenario));
        assert!(governance::has_pending_operator_transfer(&real_vault), 60);
        ts::return_shared(real_vault);
    };

    ts::next_tx(&mut scenario, NEW_OPERATOR);
    {
        let mut real_vault = ts::take_shared_by_id<GovernanceVault>(&scenario, real_vault_id);
        let fake_request = ts::take_shared_by_id<PendingOwnershipTransfer<OperatorPermit>>(&scenario, fake_request_id);
        let fake_ticket = ts::most_recent_receiving_ticket<TwoStepTransferWrapper<OperatorPermit>>(&fake_request_id);

        governance::accept_operator_transfer(
            &mut real_vault,
            fake_request,
            fake_ticket,
            ts::ctx(&mut scenario),
        );

        ts::return_shared(real_vault);
    };

    ts::end(scenario);
}

#[test]
fun test_direct_authority_emergency_mode_keeps_upgrade_recovery() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x307),
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
        governance::apply_direct_authority_mode_from_vote(
            &mut vault,
            governance::direct_authority_mode_emergency(),
            ADMIN,
        );
        governance::set_upgrade_authority(&mut vault, UPGRADE_AUTHORITY, ts::ctx(&mut scenario));
        assert!(governance::upgrade_authority(&vault) == UPGRADE_AUTHORITY, 31);
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 16, location = paperproof_governance::governance)]
fun test_direct_authority_read_only_blocks_direct_mutation() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x308),
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
        governance::apply_direct_authority_mode_from_vote(
            &mut vault,
            governance::direct_authority_mode_read_only(),
            ADMIN,
        );
        governance::set_fee_recipient(&mut vault, FEE_RECIPIENT, ts::ctx(&mut scenario));
        ts::return_shared(vault);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = 16, location = paperproof_governance::governance)]
fun test_direct_authority_disabled_is_permanent() {
    let mut scenario = ts::begin(ADMIN);

    {
        let (vault, permit) = governance::new_vault(
            object::id_from_address(@0x309),
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
        governance::apply_direct_authority_mode_from_vote(
            &mut vault,
            governance::direct_authority_mode_disabled(),
            ADMIN,
        );
        assert!(governance::direct_authority_permanently_disabled(&vault), 32);
        governance::apply_direct_authority_mode_from_vote(
            &mut vault,
            governance::direct_authority_mode_full(),
            ADMIN,
        );
        ts::return_shared(vault);
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
        let fee_manager = governance::new_fee_manager(object::id_from_address(@0x304), ts::ctx(&mut scenario));
        governance::share_fee_manager(fee_manager);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, OPERATOR);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        governance::set_comments_fee_level(&vault, &mut fee_manager, 1, ts::ctx(&mut scenario));
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
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
        let fee_manager = governance::new_fee_manager(object::id_from_address(@0x305), ts::ctx(&mut scenario));
        governance::share_fee_manager(fee_manager);
        transfer::public_transfer(permit, OPERATOR);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let mut fee_manager = ts::take_shared<FeeManager>(&scenario);
        governance::set_comments_fee_level(&vault, &mut fee_manager, 2, ts::ctx(&mut scenario));
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::next_tx(&mut scenario, PAYER);
    {
        let vault = ts::take_shared<GovernanceVault>(&scenario);
        let fee_manager = ts::take_shared<FeeManager>(&scenario);
        let payment = coin::mint_for_testing<SUI>(99_999, ts::ctx(&mut scenario));
        governance::collect_comments_fee(
            &vault,
            &fee_manager,
            option::some(payment),
            ts::ctx(&mut scenario),
        );
        ts::return_shared(vault);
        ts::return_shared(fee_manager);
    };

    ts::end(scenario);
}
