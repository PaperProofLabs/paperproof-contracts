Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available

# Artifact Control NFT Local Upgrade Prep

This note records the current local-only status of the controller-NFT contract
refactor in `paperproof-contracts-NFT`.

It is intended as the handoff point before any future unified on-chain upgrade
deployment of the PaperProof protocol package family.

## 1. Scope Completed Locally

The current local work covers:

- additive shared controller package creation:
  - `shared/controller`
- marketplace-facing controller NFT support:
  - `shared/controller::controller_marketplace`
- publish-time controller enablement for new artifact series
- dual-mode and controller-primary authority paths in `publishing`
- controller-aware moderation and tree-control paths in `comments`
- per-series promotion helpers:
  - `promote_existing_series_to_dual_mode`
  - `promote_existing_series_to_controller_primary`
  - `promote_existing_series_to_controller_only`
  - `sync_existing_series_control_mirrors`
  - `repair_existing_series_control_mirrors`
- series-description and version-change-note protocol split
- marketplace-oriented controller NFT metadata fields:
  - `artifact_code`
  - `artifact_type_name`
  - `control_right`
  - `authority_mode_name`
  - `image_url`
- shared `Display<ControllerNFT>`
- shared `TransferPolicy<ControllerNFT>`
- local unit-test coverage for:
  - legacy paths
  - dual-mode new-series behavior
  - controller-primary write blocking of legacy paths
  - controller-aware write and moderation paths
  - real legacy-series promotion rehearsal

## 2. Packages Changed

Changed packages:

- `shared/controller`
- `publishing`
- `comments`

Not changed in this phase:

- `governance`
- `governance_voting`
- `memory_registry`
- `prompt_registry`

Reason governance was left untouched:

- the current governance package family already provides the needed upgrade
  authority and migrate-style operational model for the later unified upgrade;
- no governance-side logic change was strictly required to make controller-NFT
  authority work locally.

## 3. Local Validation Completed

The following local checks passed:

- `sui move build --path shared/controller`
- `sui move test --path shared/controller`
- `sui move test --path comments`
- `sui move test --path publishing`

Current result:

- `comments`: all tests passing
- `publishing`: all tests passing

Current passing totals:

- `shared/controller`: `0 / 0`
- `comments`: `21 / 21`
- `publishing`: `55 / 55`

## 4. Main Contract Behaviors Now Covered

### New series

- new series create controller state at publish time
- new series start in `dual_mode`
- controller NFT is transferred to the publisher
- control record is shared and queryable
- controller NFT now also carries marketplace-facing identity fields
- controller marketplace display and transfer-policy objects are created in
  package init

### Existing series

- existing series can be promoted into `dual_mode`
- promoted series can be moved into `controller_primary`
- promoted series can be moved into `controller_only`
- series identity, comments tree, likes book, and version history remain in
  place
- stale legacy owner mirrors can be repaired after controller NFT transfer
- owner mirrors can be explicitly synced when controller and legacy mirrors are
  already aligned

### Authority routing

- legacy owner paths remain usable in legacy and dual mode
- legacy owner paths are blocked in controller-primary mode
- controller-aware paths can continue operating in controller-primary mode

### Metadata semantics

- stable series description is readable from series metadata using the reserved
  `series_description` key
- per-version change note is readable from version metadata using the reserved
  `version_change_note` key
- controller-aware add-version flows require a version change note

### Comments semantics

- controller-aware tree moderation works
- controller-aware comment moderation works
- comment-author self-delete semantics remain intact
- controller authority is not downgraded merely because the controller is also
  the comment author

## 5. Legacy Promotion Rehearsal Coverage

The local test suite now includes a realistic rehearsal path for an already
published legacy artifact series.

Covered rehearsal flow:

1. publish a true legacy generic-file series through the legacy-only test hook
2. add a real comment to the linked comments tree before migration
3. promote the legacy series into `dual_mode`
4. promote the same series into `controller_primary`
5. transfer the controller NFT to a new wallet
6. detect stale legacy owner mirrors
7. repair legacy owner mirrors from controller authority
8. moderate the existing legacy-era comment through controller authority
9. publish a new version through the controller-aware add-version path
10. verify that:
   - `series_id` is unchanged
   - `comments_tree_id` is unchanged
   - `likes_book_id` is unchanged
   - `current_version_id` advances only when the new version is added
   - authority mode remains `controller_primary`

Why this matters:

- it validates the intended operational upgrade story for already-live series
  instead of only validating fresh controller-enabled series;
- it exercises the exact mirror-repair path that a real operator may need after
  a controller NFT transfer;
- it confirms that historical comments remain manageable after promotion;
- it reduces the risk that package upgrade succeeds but per-series migration
  operations fail in practice.

## 6. Governance-Orchestration Assessment

Current judgment:

- do **not** add a first-wave governance migration-orchestration helper
  entrypoint yet.

Reason:

- the current `governance` and `governance_voting` packages already provide the
  required `upgrade_authority` model and migration-hook pattern for package
  upgrade operations;
- the controller-NFT migration itself is currently a **per-series operational
  action**, not a parameter flip that should be mass-executed by a generic
  governance action;
- a premature orchestration entrypoint would increase package surface area and
  upgrade complexity before the real operational batch requirements are known.

Recommended first deployment posture:

- use the existing unified package-upgrade path to ship the upgraded packages;
- perform series promotion through explicit operational scripts or SDK-assisted
  operator flows;
- keep governance focused on package-upgrade legitimacy and protocol-wide
  parameter control;
- revisit orchestration only after real migration batching requirements are
  observed in staging or mainnet rehearsal.

Conditions that would justify a later governance-side orchestration helper:

- the protocol needs a governance-approved batch promotion or batch repair path
  over many official series;
- the operator workflow needs pause/resume/checkpoint semantics for a large
  migration wave;
- downstream tooling requires a canonical on-chain record of migration phase
  execution beyond the existing per-series promotion events.

Current conclusion:

- governance continuity is required for deployment;
- governance code changes are not yet required for safe controller-NFT rollout.

## 7. Downstream Handshake Requirements

Before unified deployment, downstream modules should be updated to understand:

- controller-NFT existence and discovery
- `series_control_enabled`
- `series_authority_mode`
- `series_control_record_id`
- `series_controller_nft_id`
- `tree_control_enabled`
- `tree_authority_mode`
- `tree_control_record_id`
- `tree_controller_nft_id`
- `series_description`
- `header_version_change_note`
- controller NFT marketplace metadata:
  - `artifact_code`
  - `artifact_type_name`
  - `control_right`
  - `authority_mode_name`
  - `image_url`
- shared `Display<ControllerNFT>` and `TransferPolicy<ControllerNFT>` existence
- the distinction between:
  - canonical controller NFT ownership
  - control-record mirrors
  - legacy owner mirrors

### SDK expectations

- resolve whether a target series is legacy, dual, or controller-primary
- select legacy or controller-aware transaction builders accordingly
- surface controller-NFT requirements only when needed
- add controller-aware read models and write builders before app rollout
- expose reserved metadata keys `series_description` and
  `version_change_note` as first-class SDK fields
- keep owner compatibility fields visible during migration, but do not treat
  them as canonical authority for promoted series

### Indexer expectations

- index controller record and controller NFT linkage
- expose current authority mode per series
- preserve compatibility owner fields during the migration window
- index series description and version change note separately
- index controller marketplace metadata for reverse lookup and wallet / market
  discovery
- preserve owner-based search APIs during migration while adding controller-aware
  inventory and reverse-lookup APIs

### App expectations

- artifact pages should distinguish current controller from historical author
- controller-primary artifacts should use controller-aware write flows
- comments moderation UI should call controller-aware paths when appropriate
- app wallet UX should hide controller-NFT complexity by default when the
  target series is already known
- app should show controller holder, authority mode, and mirror drift only when
  relevant

## 8. Unified Upgrade Deployment Prep Checklist

Before future deployment, prepare:

1. final package list for unified upgrade
2. final package build outputs and package dependency order
3. explicit upgrade order across package family
4. post-upgrade migration sequence for existing series
5. explicit rehearsal checklist for at least one official legacy series:
   - pre-upgrade snapshot of `series_id`, `comments_tree_id`, `likes_book_id`,
     `current_version_id`, owner mirror fields, and current authority mode
   - promotion to `dual_mode`
   - promotion to `controller_primary`
   - controller transfer rehearsal
   - mirror repair rehearsal
   - controller-aware add-version rehearsal
   - controller-aware comment moderation rehearsal
6. smoke checks for:
   - legacy reads
   - new publish
   - existing-series promotion
   - controller-aware add version
   - controller-aware comments moderation
7. verify package-upgrade custody and authority assumptions:
   - real `UpgradeCap` holder(s)
   - recorded `upgrade_authority`
   - package publish order
   - rollback / stop conditions
8. downstream release order:
   - SDK
   - indexer
   - app

## 9. Remaining Recommended Work Before Deployment

The contract-local phase is in good shape, but these items are still
recommended before any real upgrade:

- add jstest or transaction-builder rehearsal coverage for controller-aware
  entrypoints
- write the exact package upgrade runbook and post-upgrade operator checklist
- update formal/spec notes to reflect controller-primary and metadata-split
  semantics
- decide whether any official legacy series should intentionally stop in
  `dual_mode` before later cutover to `controller_primary`
- write the off-chain migration operator workflow for:
  - selecting target series
  - locating the correct controller NFT after promotion
  - detecting stale mirrors
  - applying mirror repair only when needed

## 10. Current Local Commits

Important local checkpoints created during this work:

- `9fae672` `Add controller NFT contract foundation and dual-mode paths`
- `753ef63` `Add controller mode tests and tighten legacy path gating`
- `8713276` `Harden controller upgrade paths and expand migration tests`

These commits are local only and have not been pushed.
