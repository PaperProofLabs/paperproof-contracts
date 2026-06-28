Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available

# Artifact Control NFT Contract Roadmap

This roadmap describes a practical contract-first implementation path for the
PaperProof controller-NFT redesign.

It is intended for the `paperproof-contracts-NFT` worktree and assumes the
current deployed package family must be preserved.

This roadmap is implementation-oriented. It complements the higher-level design
document in:

- `paperproof-docs/design/system/artifact-control-nft-rearchitecture.md`

Current status note:

- this roadmap began as a forward-looking implementation plan;
- parts of the work described here are now already implemented locally on the
  `nft` branch;
- the document therefore now distinguishes between:
  - contract work already completed locally
  - downstream work still pending before unified deployment.

## 1. Contract-Side Objective

The contract work should achieve all of the following without breaking current
artifact identity and version history:

- make artifact control transferable through a controller NFT;
- keep current package lineage rather than creating a parallel deployment family;
- preserve `artifact_code`, `series_id`, `current_version_id`,
  `comments_tree_id`, `likes_book_id`, `status`, and `ui_status`;
- preserve historical publish provenance and per-version author fields;
- preserve comments-tree and likes-book continuity;
- preserve preprint reservation flow;
- preserve event compatibility for the current SDK, app, and indexer;
- introduce a clean split between artifact-series description and per-version
  change note.

## 2. Non-Regression Requirements

Before any implementation begins, the contract work should treat the following
as hard invariants:

- old series must remain readable;
- legacy publish/add-version flows must continue to work until a series is
  explicitly migrated;
- migrating or promoting a series must not create a new comments tree;
- migrating or promoting a series must not create a new likes book;
- migrating or promoting a series must not rewrite historical version records;
- controller transfer must not rewrite `header.author` or historical publish
  events;
- comments author self-service semantics must remain intact;
- hidden / active / paused state must remain unaffected unless explicitly
  changed by separate status operations.

Current-contract implementation note:

- `publishing::add_version_common(...)` currently gates version append by
  `series.owner`;
- `publishing::transfer_artifact_owner(...)` currently assumes the linked
  comments tree owner mirrors `series.owner`;
- `publishing::update_series_metadata_extensions(...)` currently gates
  series-level metadata writes by `series.owner`;
- `comments::set_tree_status(...)` currently gates by tree owner;
- `comments::set_comment_status(...)` currently allows tree-owner moderation and
  separate author-scoped self-service delete behavior;
- `comments::transfer_tree_owner(...)` currently gates by tree owner.

The controller-NFT rollout must explicitly replace or wrap each of those
authority checks. None of them should be left implicitly depending on legacy
`owner` fields once a series enters controller-primary mode.

## 3. Pre-Implementation Checklist

Before changing contract code, capture the current baseline explicitly:

- identify all `series.owner` checks in `publishing`;
- identify all `tree.owner` checks in `comments`;
- list every current event consumed by SDK, app, indexer, and official-content
  workflows;
- list every current field consumed by normalized artifact rows:
  - `owner`
  - `latest_version_id`
  - `comments_tree_id`
  - `likes_book_id`
  - `status`
  - `artifact_code`
  - `series_id`
- identify all publish flows that already have special behavior, especially
  preprint reservation / finalize-reserved-preprint.

This checklist should be completed before the first functional refactor commit.

## 4. Recommended Workstreams

The contract refactor should be split into six workstreams.

Implementation-status shorthand used below:

- `completed locally`: implemented and validated in
  `paperproof-contracts-NFT`
- `pending downstream`: contract work is in place, but SDK / indexer / app have
  not fully adapted yet

### Workstream A: Authority Model Foundation

Goal:

- add controller-NFT and controller-binding objects without breaking existing
  object layouts.

Primary tasks:

- define `ControllerNFT`;
- define `ArtifactControlRecord`;
- define authority mode constants:
  - `legacy_owner_only`
  - `dual_mode`
  - `controller_primary`
  - `controller_only`
- define controller-specific abort codes;
- define controller-specific events.

Output:

- no legacy write path changed yet;
- new controller objects exist and are readable;
- no current `ArtifactSeries` or `CommentsTree` layout is removed or repurposed.
- event compatibility strategy is defined before any legacy event surface is
  touched.

Current local status:

- completed locally

Already implemented locally:

- `ControllerNFT`
- `ArtifactControlRecord`
- authority mode constants
- controller abort codes
- controller lifecycle events
- dynamic-field state on series and comments tree
- controller-specific read helpers

### Workstream B: Publishing Module Integration

Goal:

- make `publishing` controller-aware while keeping legacy-compatible entrypoints.

Primary tasks:

- add controller-aware helper functions:
  - `mint_controller_nft_for_series`
  - `get_series_controller`
  - `assert_series_controller`
  - `sync_legacy_owner_mirror`
  - `transfer_controller_compat`
  - `update_series_description`
- add or route series-level description storage;
- add required version change note support for publish and add-version flows;
- preserve current event fields for publish and add-version;
- add additive controller-specific events.
- refactor the current owner-gated call sites explicitly:
  - `add_version_common(...)`
  - `transfer_artifact_owner(...)`
  - `update_series_metadata_extensions(...)`
- define how new-series publish mints controller NFT without breaking special
  flows such as reserved preprint finalization.

Output:

- `publishing` can operate in legacy mode and controller-aware mode;
- current `ArtifactPublishedEvent` and `ArtifactVersionAddedEvent` remain usable;
- `header.author` continues to represent the signer that published that version.
- preprint reservation flow still lands in the same artifact-series identity and
  publish-event structure as before.

Current local status:

- completed locally for contract scope
- pending downstream adaptation

Already implemented locally:

- new-series publish path mints controller NFT in `dual_mode`
- reserved-preprint finalize path also mints controller NFT
- existing-series promotion helpers
- controller-aware add-version paths
- controller-aware owner transfer compatibility path
- series description / version change note split via reserved metadata keys

### Workstream C: Comments Module Integration

Goal:

- move tree-owner-level control to controller-aware checks without breaking
  comment-author rights.

Primary tasks:

- add controller-aware tree authority helper(s);
- refactor `set_tree_status` to support controller-aware authority for migrated
  series;
- refactor the tree-owner branch in `set_comment_status` to support
  controller-aware authority for migrated series;
- preserve comment-author self-service actions;
- keep `CommentsTree.owner` as a compatibility mirror during migration;
- keep `transfer_tree_owner` available as a legacy / mirror-sync helper.
- explicitly preserve the current split in `set_comment_status(...)` where the
  tree owner can moderate while ordinary authors can still delete their own
  comments under the current state machine.

Output:

- controller of a migrated series can manage the official comments tree;
- comment authors still retain their current protocol-level self-service rights.
- no migrated series ends up with split authority where publish control moved
  but comments moderation did not.

Current local status:

- completed locally for contract scope
- pending downstream adaptation

### Workstream D: Migration Hooks And Promotion Path

Goal:

- create explicit and reversible migration mechanics.

Primary tasks:

- add publishing-side migration entrypoints;
- add per-series promotion path into dual/controller mode;
- define rules for minting controller NFTs to current owners of existing series;
- define mirror sync behavior for `ArtifactSeries.owner` and `CommentsTree.owner`;
- define rollback / stay-in-dual-mode behavior.
- define how migration records or events make it observable whether a series is
  still legacy, dual, or controller-primary.

Output:

- migration is explicit, per-series, and operationally controllable;
- old series do not need republishing.

Current local status:

- completed locally for contract scope

Already implemented locally:

- `promote_existing_series_to_dual_mode(...)`
- `promote_existing_series_to_controller_primary(...)`
- `promote_existing_series_to_controller_only(...)`
- `sync_existing_series_control_mirrors(...)`
- `repair_existing_series_control_mirrors(...)`

### Workstream E: Metadata Clarity Upgrade

Goal:

- introduce a clean split between artifact-series description and version change
  note.

Primary tasks:

- add a series-level description field or equivalent controller-aware storage;
- add a required version change note field or equivalent common-header-level
  extension;
- keep existing type-specific text fields unchanged in meaning;
- define events for description updates and version change notes if needed;
- define how legacy versions without explicit change notes are represented.
- define where the series-level description lives in the contract state so it
  does not get conflated with type-specific version fields.

Output:

- future versions always have a change note;
- series description can remain stable across many versions;
- old versions remain readable without being retroactively rewritten.

Current local status:

- completed locally using reserved metadata keys rather than a new top-level
  `ArtifactSeries` field

### Workstream F: Compatibility And Verification Surface

Goal:

- make sure the current SDK, app, and indexer can continue to trust the
  contract surface during the rollout window.

Primary tasks:

- preserve current event shapes where downstream tooling depends on them;
- preserve owner-mirror compatibility for normalized search surfaces;
- preserve comments-tree and likes-book binding fields;
- preserve preprint reservation semantics;
- add tests for controller-aware event and object trust checks;
- document any new read helpers needed by SDK / indexer.
- preserve official Docs / Blog / Forum artifact assumptions that depend on
  `current_version_id`, `comments_tree_id`, and `likes_book_id`.

Output:

- downstream migration can proceed incrementally instead of requiring a full
  lockstep rewrite.

Current local status:

- partially completed locally

Completed locally:

- event compatibility preserved for current publish/version surfaces
- legacy owner mirrors preserved
- comments-tree and likes-book continuity preserved
- preprint reservation flow preserved

Still pending before full-stack rollout:

- downstream SDK type expansion
- indexer normalization expansion
- app authority-mode-aware UX

### Workstream G: Marketplace Surface For ControllerNFT

Goal:

- make controller NFTs legible and tradable in standard Sui wallet /
  marketplace infrastructure without making marketplace infrastructure the
  authority source.

Primary tasks:

- add marketplace-facing metadata fields to `ControllerNFT`
- expose readable helper functions for those fields
- create and share `Display<ControllerNFT>`
- create and share `TransferPolicy<ControllerNFT>`
- transfer `TransferPolicyCap<ControllerNFT>` to the deployer / sender in
  package init

Output:

- controller NFTs can be displayed and transferred through mainstream Sui NFT
  infrastructure;
- reverse lookup remains anchored on `series_id` and `artifact_code`, not on
  website-only links;
- marketplace support remains additive to protocol authority, not a replacement
  for it.

Current local status:

- completed locally

Implemented module:

- `shared/controller/sources/controller_marketplace.move`

## 5. Recommended Implementation Phases

### Phase 0: Branch Setup And Baseline Capture

Tasks:

- create `nft` branch from `main`;
- record current package IDs, object assumptions, and key invariants;
- list current event consumers in SDK, app, and indexer;
- identify every place where `series.owner` and `tree.owner` are checked.
- record current special-case flows that are not NFT-specific but can be broken:
  - preprint reservation
  - hidden / active filtering
  - official-content manifests
  - owner-based search
  - Walrus retention tooling

Exit criteria:

- branch created;
- implementation checklist prepared;
- no code changes yet.

### Phase 1: Additive Controller Primitives

Tasks:

- implement controller object structs;
- implement read helpers for controller lookup;
- implement events for controller mint / binding / mode changes;
- do not route existing publish/comments authority through them yet.

Exit criteria:

- code compiles;
- tests can instantiate controller objects;
- no legacy publish/comments regression introduced.

### Phase 2: Dual-Mode Publishing Authority

Tasks:

- add controller-aware authority checks in `publishing`;
- keep legacy owner path active;
- support minting controller NFT on new series creation;
- support explicit series promotion / migration for old series;
- implement series description and version change note support.
- keep `transfer_artifact_owner(...)` available as a compatibility helper while
  clearly splitting canonical authority from legacy mirror maintenance.

Exit criteria:

- new series can be controller-enabled;
- old series still operate through legacy path;
- add-version preserves current version history and comments-tree / likes-book
  anchors.

### Phase 3: Dual-Mode Comments Authority

Tasks:

- add controller-aware comments moderation path;
- preserve author-scoped delete / self-service semantics;
- keep tree-owner mirror sync behavior;
- verify no mismatch between publishing authority and comments authority.
- explicitly test `set_tree_status(...)`, `set_comment_status(...)`, and
  `transfer_tree_owner(...)` under both legacy and migrated series conditions.

Exit criteria:

- migrated series controller can manage comments tree;
- legacy series still use current owner model;
- comment-author rights unchanged.

### Phase 4: Migration Hooks And Existing-Series Promotion

Tasks:

- implement publishing migration hooks;
- implement existing-series controller mint and promotion path;
- implement mirror repair / sync helpers;
- define recovery behavior for stale mirror state.
- define whether promotion is gated only by current series owner, by governance,
  or by another controlled migration path.

Exit criteria:

- an existing series can be promoted without republish;
- promotion preserves all identity and provenance anchors.

### Phase 5: Contract Test Expansion

Tasks:

- add unit tests and integration tests for:
  - legacy publish
  - legacy add-version
  - new-series controller mint
  - migrated-series add-version under controller authority
  - comments moderation under controller authority
  - author self-delete after controller promotion
  - mirror sync
  - controller transfer
  - preprint reservation compatibility
  - series description update
  - per-version change note recording
  - hidden / active state continuity
  - owner-based compatibility reads
  - official event trust compatibility

Exit criteria:

- all old critical paths still pass;
- new controller paths have explicit test coverage.

### Phase 6: Downstream Handshake Preparation

Tasks:

- document new events, fields, and entrypoints;
- prepare SDK-facing field mapping;
- prepare indexer-facing normalization mapping;
- prepare rollout notes for app compatibility.
- prepare a migration note for official-content manifests and cached rendered
  content consumers.

Exit criteria:

- contract layer is ready for SDK / indexer / app adaptation.

## 6. First-Wave File Targets

Most likely first-wave contract files:

- `publishing/sources/publishing.move`
- `comments/sources/comments.move`
- `shared/controller/sources/controller.move`
- `shared/controller/sources/controller_marketplace.move`
- related tests in:
  - `publishing/tests/publishing_tests.move`
  - `comments/tests/comments_tests.move`
  - `shared/controller/tests` or module-local controller tests where needed

Possible later-wave governance touch points:

- `governance/sources/governance.move`
- `governance/sources/governance_voting.move`

These should be touched only when needed for migration orchestration, recovery,
or explicit governance integration.

Likely supporting documents to keep updated during implementation:

- `docs/Versioned-Upgrade-Design.md`
- `docs/Artifact-Publishing.md`
- `docs/Observability-and-Read-APIs.md`
- any new mainnet upgrade record produced by this work

## 7. First-Wave Contract Priorities

The recommended first-wave contract priorities are:

1. Preserve legacy functionality.
2. Add controller primitives without layout breakage.
3. Add dual-mode authority in `publishing`.
4. Add dual-mode authority in `comments`.
5. Add explicit migration hooks.
6. Add series-description / version-change-note split.
7. Expand tests before touching SDK / app assumptions.

This order is important. Do not start by rewriting every downstream surface.
The contract layer should first become safely dual-mode and migration-capable.

## 8. Function-Level First-Wave TODOs

The roadmap should be translated into an explicit first-wave function plan
before contract coding starts.

### 8.1 `publishing.move`

Recommended first-wave helpers or entrypoints:

- `mint_controller_nft_for_series(...)`
- `create_artifact_control_record(...)`
- `get_series_control_record_id(...)`
- `get_series_controller_nft_id(...)`
- `get_series_authority_mode(...)`
- `assert_series_controller_or_legacy_owner(...)`
- `assert_series_controller_only(...)`
- `sync_series_owner_mirror_from_controller(...)`
- `sync_comments_tree_owner_mirror_from_controller(...)`
- `promote_series_to_dual_mode(...)`
- `promote_series_to_controller_primary(...)`
- `repair_control_mirrors(...)`
- `update_series_description(...)`

Current call sites that must be explicitly refactored rather than relying on
indirect behavior:

- `reserve_preprint_code(...)`
- `finalize_reserved_preprint(...)`
- `transfer_artifact_owner(...)`
- `update_series_metadata_extensions(...)`
- `add_version_common(...)`
- each typed `add_*_version(...)` wrapper that currently relies on
  `add_version_common(...)`

Function-level implementation rule:

- do not allow controller authority to be inferred only from a mirrored
  `series.owner`;
- controller-aware write paths must verify controller binding from the actual
  controller object path introduced by the upgrade;
- legacy paths must remain explicit and readable while dual mode exists.

### 8.2 `comments.move`

Recommended first-wave helpers or entrypoints:

- `assert_tree_controller_or_legacy_owner(...)`
- `assert_tree_controller_only(...)`
- `sync_tree_owner_mirror_from_controller(...)`
- `repair_tree_owner_mirror(...)`
- `get_tree_control_series_id(...)`

Current call sites that must be explicitly refactored:

- `set_tree_status(...)`
- `set_comment_status(...)`
- `transfer_tree_owner(...)`

Comments-specific implementation rule:

- tree-owner moderation rights should become controller-aware for migrated
  series;
- comment-author self-service logic must remain author-scoped and must not be
  rewritten into controller-only permissions.

### 8.3 Shared Read And Compatibility Surface

Recommended first-wave read helpers:

- `is_series_controller_enabled(...)`
- `is_series_in_dual_mode(...)`
- `is_series_in_controller_primary_mode(...)`
- `get_series_legacy_owner_mirror(...)`
- `get_series_current_controller(...)`
- `is_control_mirror_stale(...)`

Read-surface rule:

- the first upgrade should give SDK and indexer enough chain-readable helpers
  to distinguish legacy series from migrated series without needing heuristics.

## 9. Proposed Additive Events

The first controller-enabled upgrade should preserve current lifecycle events
and add controller-specific observability events alongside them.

Recommended additive events:

- `ControllerNftMintedForSeriesEvent`
- `ArtifactControlRecordCreatedEvent`
- `ArtifactControllerModeChangedEvent`
- `ArtifactControllerMirrorSyncedEvent`
- `ArtifactControllerMirrorRepairEvent`
- `ArtifactSeriesDescriptionUpdatedEvent`
- `ArtifactVersionChangeNoteRecordedEvent`

Minimum payload expectations:

- every controller-related event should include `series_id`;
- controller mint / binding events should include `controller_nft_id`;
- mode-change events should include previous and new authority modes;
- mirror sync or repair events should include the synchronized mirror targets;
- description and version-note events should be additive and must not replace
  current publish or add-version events.

Event design rule:

- current `ArtifactPublishedEvent`, `ArtifactVersionAddedEvent`,
  `ArtifactTransferredEvent`, and current comments events must remain usable for
  downstream compatibility during the rollout window;
- new events should explain controller mechanics, not silently mutate the
  meaning of old ones.

## 10. Migration And Promotion Entry Points

The roadmap should assume explicit migration entrypoints rather than informal
one-off operator procedures.

Recommended first-wave migration entrypoints:

- `mint_controller_for_existing_series(...)`
- `promote_existing_series_to_dual_mode(...)`
- `promote_existing_series_to_controller_primary(...)`
- `sync_existing_series_control_mirrors(...)`
- `repair_existing_series_control_mirrors(...)`
- `read_series_migration_state(...)`

Recommended migration sequence per existing series:

1. verify current `ArtifactSeries`, `CommentsTree`, and latest version anchors;
2. mint controller NFT to the current legacy owner;
3. create or initialize the control record;
4. sync `series.owner` and `CommentsTree.owner` as compatibility mirrors;
5. move the series into `dual_mode`;
6. after verification, promote the series into `controller_primary`.

Migration-entrypoint rule:

- promotion must be per-series, not all-or-nothing for the whole protocol;
- migration helpers must never create a replacement series, replacement
  comments tree, replacement likes book, or replacement artifact code;
- migration state must be chain-readable so SDK, indexer, and app can react
  deterministically.

## 11. Test Matrix And Release Gates

The contract work should not be considered ready until a mode-aware test matrix
exists and passes.

### 11.1 Minimum Test Matrix

Required mode coverage:

- legacy-only series
- dual-mode migrated series
- controller-primary series

Required flow coverage:

- create new series
- reserve preprint code
- finalize reserved preprint
- add version
- transfer artifact owner compatibility path
- update series metadata extensions
- update stable series description
- record per-version change note
- set comments-tree status
- moderate comment status as tree authority
- self-delete or equivalent author-scoped comment action
- transfer comments-tree owner compatibility path
- controller transfer followed by privileged write
- mirror repair after controller transfer
- hidden / active / paused continuity

### 11.2 Required Assertions

Every mode-aware test set should assert at least:

- `artifact_code` stays unchanged;
- `series_id` stays unchanged;
- `current_version_id` advances only when expected;
- `version_ids` remains ordered and append-only;
- `comments_tree_id` stays unchanged;
- `likes_book_id` stays unchanged;
- historical version author fields stay unchanged;
- legacy owner mirrors can drift temporarily without breaking canonical
  controller authorization;
- comment-author self-service behavior still matches current semantics.

### 11.3 Release Gates

Before any contract release candidate is accepted:

- all legacy tests must still pass;
- all dual-mode tests must pass;
- all controller-primary tests must pass;
- at least one existing-series migration rehearsal must succeed in a
  production-like environment;
- downstream teams must receive the final event and read-helper list produced
  by the contract implementation.

## 12. Specific Implementation Hazards

The current protocol surface suggests a few concrete hazards:

- if `transfer_artifact_owner(...)` is changed before comments authority is
  updated, migrated series can end up with split authority between series and
  tree;
- if `add_version_common(...)` is refactored without preserving current event
  fields, downstream event verification can fail even if transactions succeed;
- if series description is bolted into `metadata_extensions` without a clear
  stable key or first-class field rule, clients can continue to confuse it with
  version-level text;
- if controller promotion updates `owner` mirrors too aggressively, owner-based
  compatibility reads can drift before indexer / app changes are ready;
- if controller transfer is implemented without a mirror-repair path, display
  surfaces can show stale tree-owner or series-owner data for longer than
  intended;
- if preprint reservation is not explicitly tested, reserved finalize flow can
  silently diverge from the new-series mint path.

Mitigation rule:

- treat each of these as a required test scenario, not a documentation-only
  warning.

## 13. Things To Avoid

Avoid these implementation traps:

- do not remove `owner` fields in the first upgrade;
- do not repurpose old fields to mean controller ownership silently;
- do not replace old events with controller-only events;
- do not create a parallel package family just to move faster;
- do not change comments semantics in a way that removes comment-author
  self-service actions;
- do not couple controller rollout to official website-only assumptions;
- do not blur series description and version change note into one field again;
- do not allow controller transfer to rewrite provenance.

## 14. Definition Of Contract Success

The contract refactor is successful when all of the following are true:

- a series can be controlled through a controller NFT;
- controller transfer can change future operational control;
- old series can continue to function until explicitly promoted;
- migrated series preserve current version history and bindings;
- comments-tree authority follows controller authority for migrated series;
- historical version authorship remains intact;
- series description and version change note are distinct concepts;
- existing downstream consumers still have a compatibility surface to build on;
- existing series can be promoted incrementally with explicit migration state;
- the first-wave implementation can be rolled out without forcing immediate
  downstream lockstep rewrites.
