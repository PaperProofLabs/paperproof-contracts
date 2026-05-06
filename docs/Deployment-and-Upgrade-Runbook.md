# PaperProof Contracts Deployment and Upgrade Runbook

This document describes how to deploy, initialize, operate, and later upgrade
the `paperproof-contracts` protocol packages in a safe and repeatable way.

It is written for maintainers, deployment operators, governance operators, and
future community contributors who need to understand the dependency order across
the three contract packages:

- `publishing`
- `comments`
- `governance`

It also covers how the current versioned-upgrade preparation is intended to be
used in practice.

## 0. Scope and Assumptions

This runbook assumes:

- the repository root is `paperproof-contracts`
- the official token package is the separately maintained
  `PPRF-token-contracts` repository
- deployment is performed by a trusted operator team before the community
  frontend is opened
- package upgrade operations are high-trust and should be rehearsed on testnet
  before any mainnet production use

This document does not assume that package addresses are hardcoded in-source.
The current Move packages use placeholder addresses in `Move.toml`, so actual
published package IDs must always be recorded after deployment and then fed
into frontend, docs, and operational tooling.

## 1. Current Package Roles

### `publishing`
Owns the publication lifecycle:

- reserve a paper code
- finalize a paper
- add a version
- transfer paper ownership
- bind a single `CommentsTree` to each published paper

### `comments`
Owns the discussion layer:

- create and manage one `CommentsTree` per paper
- add on-chain or blob-backed comments
- like/unlike a paper
- manage comment/tree status markers

### `governance`
Owns protocol control and voting:

- root governance custody (`GovernanceVault`)
- operator delegation and handoff
- fee recipient and fee levels
- `PPRF` lock-based proposal voting
- proposer threshold and proposal gating
- protocol-recognized `upgrade_authority`
- managed `UpgradeCap` custody path for future governed upgrades

## 2. Dependency Model

The packages are intentionally separated, but they are not fully independent.

### Publishing depends on governance

`publishing` requires governance-controlled state for:

- official fee routing
- official publishing fee level
- operator-gated administrative actions
- upgrade/migration authority checks

### Publishing depends on comments

`publishing::finalize_paper` creates and binds a `CommentsTree` when a paper is
first published.

### Comments depends on governance

`comments` uses governance for:

- official comments fee routing
- official comments fee level
- upgrade/migration authority checks

### Governance depends on PPRF

`governance_voting` depends on the official `PPRF` token contract for:

- proposer threshold funding
- lock-based voting
- governance total supply initialization

## 2.1 Package Dependency Chain

At build and deployment time, the package dependency chain is:

- `paperproof_governance`
  - depends on:
    - OpenZeppelin Sui access package
    - local `PPRF-token-contracts`
- `paperproof_comments`
  - depends on:
    - local `paperproof_governance`
    - local `PPRF-token-contracts`
- `paperproof_publishing`
  - depends on:
    - local `paperproof_governance`
    - local `paperproof_comments`

This means:

- `governance` must be buildable against the official `PPRF` contract first
- `comments` must be built against the same `governance` package intended for
  production use
- `publishing` must be built against the same `comments` and `governance`
  packages intended for production use

If any of these package links drift, deployment may still technically publish,
but the resulting protocol instance will not be canonical and may fail runtime
binding checks.

## 3. High-Level Deployment Order

The safest deployment sequence is:

1. Deploy the official `PPRF` token package and confirm the canonical token
   type and total supply.
2. Deploy the `governance` package with the correct `PPRF` dependency.
3. Deploy the `comments` package with the same official `PPRF` and governance
   references expected by the main protocol instance.
4. Deploy the `publishing` package with the official `comments` and
   `governance` dependencies.
5. Initialize the publishing/governance root state.
6. Initialize governance voting state.
7. Optionally move the real package `UpgradeCap` objects into governed custody
   via `ManagedUpgradeCap`.
8. Verify all root object IDs and package IDs before opening the frontend.

## 3.1 Deployment Prerequisites

Before publishing any package, prepare:

- the target network and RPC endpoint
- the deployer address
- the initial governance authority address
- the initial operator address
- the intended upgrade authority address
- the intended fee recipient address
- the official `PPRF` package/type reference
- the exact git commit / release tag being deployed

Also decide, before production deployment:

- whether `UpgradeCap` objects will remain externally held for the first
  deployment step
- or whether they will be immediately moved into governed
  `ManagedUpgradeCap` custody

## 3.2 Deployment Output Checklist

Each successful deployment should produce and preserve:

- published package IDs
- transaction digests for package publication
- transaction digests for shared-object initialization
- object IDs for:
  - `PaperRegistry`
  - `GovernanceVault`
  - `GovernanceConfig`
  - any `ManagedUpgradeCap` objects
- the first `OperatorPermit` ownership target

## 4. Root State Objects to Record

After deployment, maintainers should record and publish the canonical IDs of:

- `PaperRegistry`
- `GovernanceVault`
- `GovernanceConfig`
- official package IDs for:
  - `publishing`
  - `comments`
  - `governance`
- official `PPRF` token package/type

It is also strongly recommended to record:

- the publication transaction digest of each package
- the publication timestamp / checkpoint
- each package upgrade-cap custody path
- whether a managed upgrade cap has already been registered for that package

These IDs should be treated as protocol entrypoints and should be referenced by:

- frontend configuration
- indexers
- docs
- community tooling
- governance operations

## 5. Initial Setup Checklist

### Step A: Initialize publishing/governance root state

The current architecture creates:

- one `PaperRegistry`
- one `GovernanceVault`
- one initial `OperatorPermit`

This setup establishes:

- the official publishing registry
- the official fee configuration path
- the initial operator execution path
- the protocol-recognized governance authority and upgrade authority

Required inputs:

- deployer transaction sender
- initial governance authority address
- initial operator address

Important note:

- `publishing::init` currently creates both the `PaperRegistry` and the initial
  `GovernanceVault`
- so the canonical governance root for the protocol instance is not initialized
  separately from publishing; it is born from the official publishing package
  init path

### Step B: Initialize governance voting

Create the single `GovernanceConfig` object for the protocol instance.

Important properties of current governance:

- one active proposal at a time
- lock-based `PPRF` voting
- proposer threshold auto-locks and auto-counts as `YES`
- proposal duration is `14` Sui epochs
- `PPRF total_supply` is read from the official token contract at
  initialization

Required input:

- the canonical `GovernanceVault`

Important note:

- only one official `GovernanceConfig` should exist for the canonical protocol
  instance
- if multiple configs are accidentally created for the same registry, tooling
  and community governance expectations will diverge

### Step C: Configure fee routing

Set and verify:

- `fee_recipient`
- `publishing_fee_level`
- `comments_fee_level`

Because fees are protocol-level and not frontend-only, a misconfigured
recipient or level will affect all official use paths.

Recommended initial production values:

- `publishing_fee_level = 0`
- `comments_fee_level = 0`
- `fee_recipient = treasury or operator-controlled destination selected by the
  team`

Even if initial fees are free, explicitly verify the vault values so that
future governance changes have a known baseline.

### Step D: Decide upgrade custody model

There are two distinct concepts:

- the protocol-level `upgrade_authority` address recorded in governance
- the real Sui `UpgradeCap` objects that actually authorize package upgrades

To make upgrade governance operational rather than advisory, the deployment
team should register each relevant `UpgradeCap` into a `ManagedUpgradeCap`
shared object controlled through governance.

Without this step, governance can change the recorded `upgrade_authority`, but
an externally held `UpgradeCap` could still upgrade a package outside the
governed path.

## 5.1 Recommended Initial Parameter Baseline

The deployment team should explicitly confirm the initial live values of:

- governance authority
- active operator
- upgrade authority
- publishing fee level
- comments fee level
- fee recipient
- proposer threshold
- proposal creation paused flag
- `PPRF total_supply` captured into `GovernanceConfig`

This should be written down even if the values are still the defaults.

## 6. Managed UpgradeCap Custody

The current governance package supports a governed custody path for package
upgrades:

- `register_managed_upgrade_cap`
- `share_managed_upgrade_cap`
- `authorize_managed_upgrade`
- `commit_managed_upgrade`

Recommended operational model:

1. Publish package and obtain the real `UpgradeCap`.
2. Register that `UpgradeCap` into `ManagedUpgradeCap`.
3. Share the resulting `ManagedUpgradeCap`.
4. From that point on, treat the managed object as the operational upgrade
   path.
5. Only let the recorded `upgrade_authority` drive authorization/commit steps.

This gives the protocol a governance-aligned path for real Sui package
upgrades.

## 6.1 Which Packages Should Use Managed Upgrade Custody

The safest long-term plan is to place the real `UpgradeCap` for all three
official contract packages into governed custody:

- `governance`
- `comments`
- `publishing`

This avoids a split situation where:

- governance records one `upgrade_authority`
- but one or more real package upgrade caps are still controlled elsewhere

If operationally necessary, this can be rolled out in stages, but the protocol
should clearly disclose which packages are already under governed `UpgradeCap`
custody and which are not.

## 7. Official Runtime Invariants

The current protocol should be operated with these assumptions:

- exactly one official `PaperRegistry`
- exactly one official `GovernanceVault`
- exactly one official `GovernanceConfig`
- every published paper binds exactly one `CommentsTree`
- later paper versions reuse the same `CommentsTree`
- official fees must be read from the official `GovernanceVault`
- `PaperRecord` lifecycle actions must be validated against the official
  registry mapping

## 8. Recommended Deployment Verification

Before announcing the system as live, verify:

- the official `GovernanceVault.registry_id` matches the official
  `PaperRegistry` ID
- the official `GovernanceConfig.registry_id` matches the same registry
- `fee_recipient` is correct
- `publishing_fee_level` and `comments_fee_level` are correct
- `upgrade_authority` is correct
- `ManagedUpgradeCap` objects, if used, are registered for the expected package
  IDs
- the frontend is configured with the correct root object IDs and package IDs

Also verify these runtime relations:

- `publishing` package ID used by the frontend is the same one that created the
  canonical `PaperRegistry`
- `comments` package ID used by the frontend is the same one expected by the
  official `publishing` deployment
- `governance` package ID used by the frontend is the same one expected by the
  official `publishing` and `comments` deployments
- the `PaperRecord.paper_code -> record_id` registry mapping resolves correctly
  for newly reserved records
- newly finalized papers bind `CommentsTree` objects owned by the same current
  paper owner

## 8.1 Post-Deployment Smoke Tests

Before public launch, run at least one manual end-to-end smoke test covering:

1. reserve a paper code
2. finalize a paper
3. verify that a `CommentsTree` was bound
4. add a comment
5. like and unlike the paper
6. add a new version
7. create a governance proposal
8. cast at least one yes vote
9. finalize the proposal after the voting window on the target environment
10. reclaim locked voting funds

On a non-production network, also test:

11. nominate and accept operator transfer
12. register a managed upgrade cap
13. authorize and commit a package upgrade rehearsal
14. call the relevant `migrate_*` hooks

## 9. How Protocol Use Works After Deployment

### Paper publishing

1. User reserves a paper code.
2. User finalizes the paper.
3. The paper receives its first `PaperVersion`.
4. A single `CommentsTree` is created and bound to the paper.

### Paper version upgrades

1. Current paper owner calls `add_version`.
2. The same `PaperRecord` remains active.
3. The same `CommentsTree` remains bound.

### Comments

1. Users comment through the official `CommentsTree`.
2. Governance-controlled comments fee enforcement applies.
3. Comment-tree governance follows current paper ownership rather than
   remaining permanently with the first publisher.

### Governance

1. A proposer meeting the current threshold creates a proposal.
2. Voters lock `PPRF` into the proposal.
3. Proposal is finalized after the voting period.
4. Executable proposals require a separate execution transaction.
5. Locked voting funds are reclaimed directly by voter address after proposal
   end; no receipt object is required.

## 9.1 Runtime Parameter Relationships

Several runtime actions depend on consistent cross-package configuration:

- publishing fees and comments fees depend on the official `GovernanceVault`
- governance voting depends on the official `PPRF` contract
- comments governance follows paper ownership as updated by publishing
- upgrades and migrations depend on the official `upgrade_authority`

If the wrong root object is passed at runtime, some operations will fail
explicitly due to binding checks. This is desirable, but it means frontend and
operator tooling must be careful to always load the canonical object IDs.

## 10. Upgrade Strategy

The current v1 architecture does not rely on arbitrary mutable code paths.
Instead, it prepares for controlled upgrades through:

- package upgrade via Sui `UpgradeCap`
- governed `ManagedUpgradeCap` custody
- version fields on core shared objects
- version guards on key entrypoints
- governed `migrate_*` hooks

## 11. Current Versioned Objects

The current design prepares these core shared objects for versioned upgrade:

- `PaperRegistry`
- `PaperRecord`
- `CommentsTree`
- `GovernanceVault`
- `GovernanceConfig`
- `Proposal`

These are the most important objects to migrate carefully in future upgrades.

## 12. Recommended Upgrade Workflow

When upgrading to a future package version:

1. Freeze operations at the governance/process level as appropriate.
   In practice, avoid running an upgrade while a live governance proposal is in
   flight unless the upgrade plan explicitly accounts for it.
2. Build and verify the new package version.
3. Use the real Sui `UpgradeCap` path, preferably through `ManagedUpgradeCap`,
   to publish the upgraded package.
4. Call the relevant `migrate_*` entrypoints with the governed
   `upgrade_authority`.
5. Verify all root objects now satisfy the new version guards.
6. Update frontend and tooling to point to the new package version if needed.
7. Resume normal operations.

## 12.1 Upgrade Preparation Checklist

Before beginning any production upgrade:

- identify which packages are being upgraded
- confirm the real `UpgradeCap` custody path for each package
- confirm the current `upgrade_authority`
- confirm whether any active proposal is live
- confirm whether new paper publication/comment activity should be temporarily
  paused operationally
- prepare exact object IDs for all migration targets
- define rollback expectations in case publication succeeds but migration is
  interrupted

## 12.2 Recommended Upgrade Execution Order

If multiple packages are being upgraded in a coordinated release, the safest
logical order is usually:

1. `governance`
2. `comments`
3. `publishing`

Reason:

- governance owns upgrade/migration authority semantics
- comments is depended on by publishing
- publishing is the top lifecycle package and should be upgraded after its
  dependencies are already on the intended version

This is not an absolute rule for every future release, but it is the safest
default assumption for protocol-wide changes.

## 13. Package-Specific Migration Hooks

The current protocol exposes these migration entrypoints:

### Publishing

- `migrate_registry`
- `migrate_record`

### Comments

- `migrate_tree`

### Governance

- `migrate_vault`
- `migrate_config`
- `migrate_proposal`

These hooks are currently lightweight, but they are the intended place to carry
future migration logic.

## 14. Upgrade Safety Notes

### Real `UpgradeCap` custody matters

If the real `UpgradeCap` remains outside governed custody, governance can only
record who should upgrade, not enforce who can upgrade.

### Registry binding matters

`PaperRecord` now relies on the registry's `paper_code -> record_id` mapping as
its binding proof. This means:

- finalize/version/migrate flows are constrained to the correct official
  registry
- future upgrades should preserve the integrity of this mapping

### Governance execution remains two-step

Executable proposals still require:

1. proposal passes
2. execution transaction is submitted

That is intentional and should be reflected in operator and community
expectations.

### Init functions do not re-run on package upgrade

Package upgrade does not recreate protocol root state automatically.
Future upgrades must assume:

- existing shared objects remain the canonical state
- migrations are explicit
- `init` is not a substitute for migration

### Event and getter changes should be coordinated with clients

Even if a package upgrade is structurally compatible, frontend and indexer code
may still need updating if:

- new events are added
- event interpretation changes
- new getters become the preferred read path
- operational tooling begins to rely on new migration or upgrade telemetry

## 15. Recommended Operational Docs Outside the Chain

For smooth deployment and maintenance, the team should also keep an external
operator runbook that records:

- package IDs
- root shared object IDs
- current `fee_recipient`
- current `upgrade_authority`
- current managed upgrade package IDs
- current frontend config values
- current release/tag corresponding to deployed packages

It is also helpful to maintain a deployment manifest with:

- package name -> package ID
- package name -> publication tx digest
- package name -> `UpgradeCap` custody location
- package name -> managed upgrade object ID if applicable
- root object name -> object ID
- root object name -> creation tx digest

## 16. Summary

The current `paperproof-contracts` system is already modular and deployable, but
it should be treated as an integrated protocol rather than three unrelated
packages.

Safe operation depends on:

- deploying in the right order
- recording canonical root IDs
- routing all official behavior through the official governance state
- aligning real `UpgradeCap` custody with governed upgrade authority
- using the existing version guards and `migrate_*` hooks in future upgrades
