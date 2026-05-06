# PaperProof Deployment Manifest Template

This template is intended to be copied and filled in for each deployment
environment, release candidate, testnet deployment, and production deployment.

It is designed to help the PaperProof team keep a durable record of:

- package IDs
- root shared object IDs
- governance-critical addresses
- `UpgradeCap` custody
- deployment transactions
- frontend/runtime configuration

Use one filled manifest per environment and per release.

## 1. Deployment Identity

- Environment:
- Network:
- Deployment date:
- Deployment operator:
- Release tag:
- Git commit:
- Notes:

## 2. Canonical Repositories

- `PPRF-token-contracts` commit/tag:
- `paperproof-contracts` commit/tag:
- Frontend repository commit/tag:
- Docs repository commit/tag:

## 3. Deployer and Governance Addresses

- Deployer address:
- Governance authority address:
- Initial operator address:
- Current operator address:
- Upgrade authority address:
- Fee recipient address:

## 4. Official Package IDs

### `PPRF`

- Package ID:
- Published tx digest:
- Token type:
- Treasury cap / mint authority custody notes:
- Real `UpgradeCap` custody:
- Managed upgrade object ID, if applicable:

### `governance`

- Package ID:
- Published tx digest:
- Real `UpgradeCap` custody:
- Managed upgrade object ID, if applicable:

### `comments`

- Package ID:
- Published tx digest:
- Real `UpgradeCap` custody:
- Managed upgrade object ID, if applicable:

### `publishing`

- Package ID:
- Published tx digest:
- Real `UpgradeCap` custody:
- Managed upgrade object ID, if applicable:

## 5. Canonical Root Shared Objects

### Publishing / Governance Root

- `PaperRegistry` object ID:
- `PaperRegistry` creation tx digest:
- `GovernanceVault` object ID:
- `GovernanceVault` creation tx digest:
- Initial `OperatorPermit` recipient:

### Governance Voting Root

- `GovernanceConfig` object ID:
- `GovernanceConfig` creation tx digest:

## 6. Governance Runtime Configuration

- Governance vault version:
- Governance config version:
- Current active operator:
- Current active operator epoch:
- Pending operator transfer exists:
- Pending operator address:
- Pending operator epoch:

### Fee Configuration

- Publishing fee level:
- Publishing fee amount:
- Comments fee level:
- Comments fee amount:
- Fee recipient:

### Proposal Configuration

- Proposal creation paused:
- Proposer threshold:
- Governance total `PPRF` supply recorded:
- Proposal duration (epochs):
- Active proposal ID:

## 7. Upgrade Configuration

### Protocol-Level Upgrade Authority

- Recorded `upgrade_authority`:
- Last change tx digest:

### Managed UpgradeCap Custody

For each managed upgrade object:

- Managed object ID:
- Registry ID bound to it:
- Package ID controlled:
- Registration tx digest:
- Current custody status:
- Notes:

## 8. Package Dependency Resolution Notes

Record the exact package dependency assumptions used at deployment time.

### Governance

- OpenZeppelin dependency revision:
- Local `PPRF` path/reference used:

### Comments

- Governance package linked:
- `PPRF` package linked:

### Publishing

- Governance package linked:
- Comments package linked:

## 9. Frontend / Client Configuration

The frontend and external clients should use only the canonical IDs below.

- Official `PPRF` package ID:
- Official governance package ID:
- Official comments package ID:
- Official publishing package ID:
- `PaperRegistry` object ID:
- `GovernanceVault` object ID:
- `GovernanceConfig` object ID:
- Fee recipient:
- Upgrade authority:

### Frontend Config Commit / Release

- Frontend config commit:
- Frontend release tag:
- Deployment target URL:
- Walrus site / official hostname:

## 10. Deployment Verification Checklist

Mark each item after verification.

- [ ] `GovernanceVault.registry_id` equals the official `PaperRegistry` ID
- [ ] `GovernanceConfig.registry_id` equals the official `PaperRegistry` ID
- [ ] `publishing` frontend config points to the official package ID
- [ ] `comments` frontend config points to the official package ID
- [ ] `governance` frontend config points to the official package ID
- [ ] `publishing_fee_level` is correct
- [ ] `comments_fee_level` is correct
- [ ] `fee_recipient` is correct
- [ ] `upgrade_authority` is correct
- [ ] `PPRF total_supply` in governance config is correct
- [ ] `ManagedUpgradeCap` objects, if used, are registered for the expected package IDs

## 11. Smoke Test Results

### Publishing

- Reserve code test tx:
- Finalize paper test tx:
- Add version test tx:
- Transfer owner test tx:

### Comments

- Add on-chain comment tx:
- Add blob-backed comment tx:
- Like paper tx:
- Unlike paper tx:

### Governance

- Create proposal tx:
- Vote yes tx:
- Vote no tx:
- Finalize proposal tx:
- Execute proposal tx:
- Claim locked vote tx:

### Operator / Upgrade

- Nominate operator tx:
- Accept operator tx:
- Managed upgrade registration tx:
- Managed upgrade authorize tx:
- Managed upgrade commit tx:
- `migrate_*` test tx:

## 12. Event / Indexer Validation

- Indexer deployment status:
- Event ingestion start checkpoint:
- Governance events verified:
- Publishing events verified:
- Comments events verified:
- Migration events verified:
- Managed upgrade events verified:

## 13. Known Deviations or Temporary Exceptions

Use this section to record anything that differs from the intended canonical
architecture.

Examples:

- a package `UpgradeCap` is not yet under managed custody
- a temporary fee recipient is being used
- a frontend is temporarily pinned to an older package revision
- governance is intentionally paused during rollout

Notes:

-

## 14. Post-Deployment Upgrade Notes

If this deployment is the result of an upgrade, record:

- previous package IDs:
- previous root object versions:
- migration tx digests:
- any package IDs replaced in frontend config:
- any rollback considerations:

## 15. Sign-Off

- Deployment prepared by:
- Deployment reviewed by:
- Governance / operator reviewed by:
- Frontend config reviewed by:
- Final sign-off date:
