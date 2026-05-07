# Mainnet Post-Deployment Funds And Authority Migration

This document records the recommended post-deployment custody steps for the
2026-05-07 mainnet deployment. It is intentionally operational rather than
architectural.

## Current Launch State

- Deployer/current custodian: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- `PaperProofRoot`: `0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78`
- `GovernanceVault`: `0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875`
- `GovernanceConfig`: `0x7ed018db6b2cd7c32692a1c33543fb90d9c36add1226f93cbeb2a8fb10955dfa`
- Initial `OperatorPermit`: `0xbfc867a7a95f6808a42c448fc80f31952752d7faf32bdcd9b7ee8ff86489c634`
- Governance, upgrade, operator, and fee-recipient roles currently all point to
  the deployer/current custodian.

## Migration Goals

Move routine operation, upgrade authority, fee receipt, and liquid funds away
from the launch custodian according to the team's preferred custody model.

Recommended targets:

- a hardware-backed operations address for the active operator
- a multisig or hardware-backed address for governance authority
- a multisig or hardware-backed address for upgrade authority
- a treasury-controlled address for fee receipt
- a separate low-balance hot address for routine smoke tests and frontend
  operational checks

## Step 1: Prepare Destination Addresses

Before moving any authority, create and verify every destination address.

Record:

- new governance authority:
- new upgrade authority:
- new active operator:
- new fee recipient:
- treasury address:
- emergency recovery signer set:

Fund each destination with enough SUI for at least several governance/operator
transactions.

## Step 2: Move Routine Funds

Transfer excess SUI and any nonessential assets out of the deployer/current
custodian. Leave only enough gas for the authority migration transactions.

Suggested local checks:

```powershell
sui client active-env
sui client active-address
sui client gas
```

Do not transfer the `UpgradeCap` or `OperatorPermit` objects until the intended
destination and control model are confirmed.

## Step 3: Move Or Rotate Operator Authority

The active operator is the address recorded in `GovernanceVault`, and the
matching `OperatorPermit` object is required for operator-only direct actions.

Preferred path:

1. From the current governance/upgrade authority, nominate the new operator
   through the governance vault operator-transfer function.
2. From the new operator address, accept the operator transfer and receive the
   fresh operator permit.
3. Verify `active_operator` and `active_operator_epoch` on
   `GovernanceVault`.
4. Retire or archive the old permit if it becomes stale.

Record the tx digests:

- nominate operator tx:
- accept operator tx:
- post-rotation verification tx/check:

## Step 4: Move Fee Recipient

Update `GovernanceVault.fee_recipient` to the treasury or fee-collection
address selected for production operations.

After the update, verify:

- `fee_recipient` on `GovernanceVault`
- frontend and indexer config that displays or relies on the fee recipient
- treasury monitoring for incoming fee events

Record:

- fee recipient change tx:
- new fee recipient:

## Step 5: Move Upgrade Authority

The deployment intentionally left the real package `UpgradeCap` objects at the
launch custodian. For production custody, choose one of these models:

- keep real `UpgradeCap` objects in a multisig/hardware address
- register them into `ManagedUpgradeCap` objects under the official
  `GovernanceVault`, then share those managed objects
- use a phased approach: first move caps to a hardened address, then register
  them as managed upgrade caps after smoke testing

Current package caps:

- `paperproof_governance`: `0x2bd93f4408133a7f739d6b73f5bc7d03d9e221aa22a9e4c576b1b6ec916ea658`
- `paperproof_comments`: `0x3e989e7954a01f93d16aa4d93d8283c4dcb4e7a4976d90c5833c7fcf16b753b3`
- `paperproof_publishing`: `0x8b3c6058f7d0e7641c958d02b3bb84b98a9c1b45304fc06f67c492b3f19ed143`

After moving or registering caps, update `GovernanceVault.upgrade_authority` to
the selected production upgrade authority.

Record:

- governance cap migration tx:
- comments cap migration tx:
- publishing cap migration tx:
- upgrade authority change tx:
- managed upgrade object IDs, if created:

## Step 6: Move Governance Authority

Move `GovernanceVault.governance_authority` to the intended governance address
only after the operator, fee recipient, and upgrade plan are clear.

After the change:

- verify the new authority can perform intended authority actions
- verify the old launch custodian can no longer perform those actions
- record the final authority state in the deployment record

Record:

- governance authority change tx:
- new governance authority:

## Step 7: Update Local And Client Configuration

Update:

- local deployment records
- frontend package/object IDs
- indexer trusted object IDs
- operations runbooks
- treasury monitoring

Trusted mainnet IDs are listed in `Mainnet-Deployment-Record-2026-05-06.md`.

## Step 8: Final Custody Review

Before opening production traffic, confirm:

- no production role still points to the launch custodian unless intentionally
  documented
- real `UpgradeCap` custody matches the intended control model
- active operator and operator permit are held by the intended operator
- fee recipient is monitored by treasury operations
- smoke tests have been run and recorded
- the frontend and indexer trust only the official package/root/config IDs
