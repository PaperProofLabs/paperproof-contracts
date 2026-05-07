# Mainnet Governance v2 Upgrade

This document records the 2026-05-08 mainnet governance package upgrade that
adds explicit `GovernanceVault.governance_authority` migration support.

## Purpose

The initial mainnet deployment allowed direct and governance-controlled updates
for fee recipient, upgrade authority, operator nomination, proposal settings,
and direct-authority mode. It did not include a direct or proposal-based path to
change `GovernanceVault.governance_authority` itself.

Governance v2 fixes that operational gap without changing existing object
layouts.

## Code Changes

Package changed:

- `paperproof_governance`

Files changed:

- `governance/sources/governance.move`
- `governance/sources/governance_voting.move`
- `governance/tests/governance_tests.move`
- `governance/tests/governance_voting_tests.move`

Added in `governance.move`:

- `GovernanceAuthorityChangedEvent`
- `set_governance_authority(vault, new_governance_authority, ctx)`
- `apply_governance_authority(vault, new_governance_authority, changed_by)`

Added in `governance_voting.move`:

- `ACTION_SET_GOVERNANCE_AUTHORITY = 15`
- `action_set_governance_authority()`
- proposal creation payload validation for nonzero `payload_address`
- executable proposal handling that calls `governance::apply_governance_authority`
- `migrate_config` logic to add action `15` to already deployed
  `GovernanceConfig.enabled_actions`

No existing struct layout was changed.

## Security Semantics

Direct migration path:

- caller must be current `governance_authority`
- `direct_authority_mode` must allow emergency-capable direct authority
- `new_governance_authority` must not be `0x0`
- emits `GovernanceAuthorityChangedEvent`

Proposal migration path:

- executable proposal action type must be `15`
- `payload_address` is the new governance authority
- `payload_address` must not be `0x0`
- after the proposal passes and is executed, `governance_authority` is updated
- emits `GovernanceAuthorityChangedEvent` and `ProposalExecutedEvent`

Existing deployed `GovernanceConfig` objects need `migrate_config` once after
the package upgrade so action `15` is added to `enabled_actions`.

## Test Results

Commands run:

```powershell
sui move test
```

Results:

- `governance`: 52/52 passed
- `comments`: 16/16 passed
- `publishing`: 26/26 passed

New/expanded tests covered:

- current governance authority can directly transfer governance authority
- old governance authority loses direct access after transfer
- non-governance authority cannot transfer governance authority
- governance authority cannot be set to `0x0`
- governance authority can be changed by executable proposal
- governance authority proposal rejects `0x0` payload
- existing config migration enables action `15`

## Mainnet Upgrade Parameters

Network:

- Sui mainnet

Deployer / current custodian:

- `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`

Governance package:

- Original package ID: `0x75923624e354789e995537e88afaab698bd405a61f91926e3f8837fb7cc6b5cf`
- v2 package ID: `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- UpgradeCap: `0x2bd93f4408133a7f739d6b73f5bc7d03d9e221aa22a9e4c576b1b6ec916ea658`
- UpgradeCap owner after upgrade:
  `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- UpgradeCap version after upgrade: `2`

Canonical root/config objects:

- `PaperProofRoot`: `0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78`
- `GovernanceVault`: `0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875`
- `GovernanceConfig`: `0x7ed018db6b2cd7c32692a1c33543fb90d9c36add1226f93cbeb2a8fb10955dfa`

## Mainnet Transactions

Upgrade dry-run:

- status: success
- estimated balance change: `-194935540 MIST`
- dry-run package ID: `0x6961ec26ed7de58ff1bf682af4f757f4acf0211148d8291ba0594ade08f28442`

Executed upgrade:

- tx digest: `8TpVmJuCMYwpesBdQmazK4fgfcweihL6vcRZumcjX8Cv`
- created v2 package:
  `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- gas balance change: `-193957420 MIST`
- raw output: `governance/upgrade-mainnet-v2-2026-05-08.json`

GovernanceConfig migration dry-run:

- status: success
- estimated gas cost: `2574544 MIST`
- effect: add dynamic field for action `15` under
  `GovernanceConfig.enabled_actions`

Executed GovernanceConfig migration:

- tx digest: `9PxfYxXzNkwHqpAgPAkDrhr8pr6DweZZUSpnLRSNiBU6`
- gas balance change: `-1496424 MIST`
- created dynamic field:
  `0xc58c7ca32ab5ed962e1afbfb4b57f72862d817ff0a5a114db13b28c321324809`
- `GovernanceConfig.enabled_actions.size`: `17`
- raw output: `governance/migrate-config-mainnet-v2-2026-05-08.json`

## Post-Upgrade Verification

Verified:

- `UpgradeCap.package` now points to
  `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- `UpgradeCap.version == 2`
- new getter `action_set_governance_authority` resolves through the v2 package
- `GovernanceConfig.enabled_actions.size == 17`
- `GovernanceConfig.registry_id` remains
  `0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78`
- no authority migration was executed during the upgrade

Important call note:

- Newly added public functions must be called through the v2 package ID:
  `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- Existing types and objects still use the original package ID in their type
  tags:
  `0x75923624e354789e995537e88afaab698bd405a61f91926e3f8837fb7cc6b5cf`

## Direct Governance Authority Migration Command

Use the v2 package ID for the function call.

```powershell
sui client ptb `
  --move-call 0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e::governance::set_governance_authority `
    '@0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875' `
    @NEW_GOVERNANCE_AUTHORITY
```

After execution, verify:

```powershell
sui client object 0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875 --json
```

Expected field:

- `content.governance_authority == NEW_GOVERNANCE_AUTHORITY`

## Proposal-Based Migration Parameters

For an executable proposal:

- proposal type: `1`
- action type: `15`
- `payload_address`: new governance authority
- `payload_u64_1`: `0`
- `payload_u64_2`: `0`
- `payload_object_id`: none
- `payload_bytes`: empty

The proposal path is available because the deployed `GovernanceConfig` was
migrated and now has 17 enabled actions.

## Operational Notes

- This upgrade verified that the real governance `UpgradeCap` can upgrade the
  package on mainnet.
- The real governance `UpgradeCap` remains owned by the current custodian.
- Governance authority has not yet been moved.
- Direct-authority mode has not been changed.
- Smoke tests remain separate from this upgrade record.
