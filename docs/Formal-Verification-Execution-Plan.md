<!--
Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available
-->

# PaperProof Formal Verification Execution Record

This document records the execution model that guided the completed
formal-verification work corresponding to `docs/Formal-Specification-Checklist.md`.
It is retained as a historical planning and review record. For the final
verification outcome, use `docs/Formal-Verification-Final-Report.md`.

The checklist answered:

- what should be specified and proved;
- which properties matter most;
- which modules carry the highest protocol risk.

This record explains:

- in what order the work should be done;
- what the deliverables are for each phase;
- how to decide when a property is complete, blocked, or requires code changes;
- how to keep prover work isolated from the main production branch.

This record was written for the dedicated formal-verification branch rather
than for routine product development on `main`.

## 1. Scope and Working Assumptions

### 1.1 Branch and change policy

Formal verification work was performed on a dedicated branch:

- `formal-verification`

The branch allowed the following without destabilizing `main`:

- adding Move `spec` blocks;
- introducing prover-only helper structure;
- reorganizing functions for prover tractability;
- discovering code/spec mismatches;
- making narrowly scoped semantic fixes when prover work reveals a real issue.

### 1.2 What counts as "formal verification" here

For PaperProof, formal verification means a staged combination of:

1. writing explicit specifications;
2. mechanically checking them with Move Prover where feasible;
3. recording which properties are:
   - proved;
   - specified but currently unproved;
   - blocked by prover limitations;
   - blocked by code structure;
   - violated by current code.

### 1.3 What this plan does not assume

This plan does not assume that:

- all 200 checklist items can be proved in one pass;
- current contract structure is already prover-friendly;
- prover failures automatically imply protocol bugs;
- existing test coverage can be replaced by prover results.

The expected reality is mixed:

- some properties will prove directly;
- some will require refinement of specs;
- some will require small structural code adjustments;
- a few may expose real design or implementation risk.

## 2. Success Criteria

The formal-verification program was considered successful because it produced:

1. a reproducible prover workflow in this repository;
2. a documented mapping from checklist IDs to concrete spec locations;
3. a proved first wave of high-value P0 properties;
4. explicit findings for any blocked or failing properties;
5. a clear record of any code changes made for soundness or provability;
6. an updated residual-risk picture after each wave.

## 3. Deliverables

The work produced the following classes of artifacts inside this repository.

### 3.1 Required artifacts

- this execution plan;
- the checklist:
  `docs/Formal-Specification-Checklist.md`;
- prover setup instructions and commands;
- module-by-module spec coverage notes;
- verification result summaries after each wave;
- issue notes for any properties that fail or remain blocked.

### 3.2 Recommended artifact layout

Recommended additions during execution:

- `docs/formal-verification/README.md`
- `docs/formal-verification/status.md`
- `docs/formal-verification/wave-1-publishing.md`
- `docs/formal-verification/wave-2-governance.md`
- `docs/formal-verification/wave-3-comments.md`
- `docs/formal-verification/findings/`

The exact filenames may vary, but status tracking should be kept in-repo.

## 4. Property Status Model

Each checklist item should be tracked using one of the following statuses:

- `unstarted`
- `specified`
- `proved`
- `blocked-prover`
- `blocked-structure`
- `failed-real-risk`
- `covered-by-test-only`
- `deferred`

### 4.1 Status definitions

- `unstarted`:
  no spec text or proof attempt exists yet.

- `specified`:
  a concrete spec exists, but proof has not yet passed.

- `proved`:
  the intended property is mechanically established with the current code and
  prover configuration.

- `blocked-prover`:
  the property looks semantically sound, but current prover capability or proof
  ergonomics prevent completion.

- `blocked-structure`:
  the property is reasonable, but current code organization makes proof
  impractical without refactoring.

- `failed-real-risk`:
  proof work exposed a real defect, inconsistent assumption, or insufficient
  guard in the protocol logic.

- `covered-by-test-only`:
  defended by runtime tests when a property sits outside the completed formal
  baseline.

- `deferred`:
  intentionally pushed to a later wave.

## 5. Proof Rollout Strategy Used

The checklist is intentionally broader than a sensible first proof pass.
Execution followed a wave model.

### 5.1 Wave ordering

Recommended wave order:

1. prover bootstrap and spec conventions;
2. `publishing::publishing` P0;
3. `governance::governance_voting` P0;
4. `comments::comments` P0;
5. `governance::governance` P0;
6. cross-module P0 bindings;
7. targeted P1 properties;
8. selected P2 hardening properties.

### 5.2 Why this order

This order prioritizes:

- value at risk;
- user-visible correctness;
- irreversible state transitions;
- locked funds and governance state;
- artifact identity continuity;
- registry, tree, and likes bindings that indexers and SDKs rely on.

## 6. Phase-by-Phase Plan

## Phase 0. Bootstrap and Inventory

### Goal

Make the repository prover-ready and produce an initial proof map.

### Tasks

1. Confirm local Sui/Move prover toolchain is available.
2. Document exact commands to run prover in this repository.
3. Record current package/module boundaries:
   - `publishing::artifact_types`
   - `publishing::validation`
   - `publishing::publishing`
   - `governance::governance`
   - `governance::governance_voting`
   - `comments::comments`
4. Map checklist ranges to code modules.
5. Decide spec placement style:
   - inline `spec` blocks in source files;
   - or auxiliary spec organization if needed.
6. Define naming conventions for checklist references inside specs.

### Deliverables

- prover commands documented;
- module map confirmed;
- checklist-to-module mapping confirmed;
- status tracker initialized.

### Exit criteria

This phase is complete when a contributor can clone the repo, run the prover
command, and understand where new specs should go.

## Phase 1. Publishing P0 First Wave

### Goal

Prove the highest-value artifact identity and preprint publishing properties.

### Priority source

From the checklist:

- `P0-147` through `P0-164`
- plus supporting properties from:
  - `P0-01` through `P0-16`
  - `P0-189` through `P0-194`

### Focus topics

1. Direct preprint publish is disabled.
2. Reserved preprint flow is mandatory for preprints.
3. Reserved preprint code equals finalized artifact code.
4. Finalization cannot succeed with mismatched reservation identity.
5. Add-version preserves series identity and type continuity.
6. Publishing creates the official comments tree and likes book bindings.
7. Fee-manager, governance-vault, and root bindings are canonical.

### Detailed tasks

1. Specify supported type assumptions used by publishing entry functions.
2. Specify non-empty content references and title preconditions where relevant.
3. Specify preprint reservation ownership and finalization authorization.
4. Specify reservation-to-series identity continuity.
5. Specify that preprint finalization cannot mint a different code.
6. Specify series identity stability across add-version flows.
7. Specify comments-tree and likes-book creation/binding correctness.
8. Specify binding of publishing-created objects to the official root.

### Deliverables

- first prover-backed publishing spec set;
- first list of publishing properties marked:
  `proved`, `blocked-prover`, `blocked-structure`, or `failed-real-risk`;
- regression notes for any code changes required.

### Exit criteria

This phase is complete when the core preprint reserve/finalize chain and core
artifact identity path have explicit specs and at least the intended first-wave
subset has been attempted in prover.

## Phase 2. Governance Voting P0

### Goal

Establish the most important locked-funds and proposal-state correctness
properties.

### Priority source

From the checklist:

- `P0-65` through `P0-86`

### Focus topics

1. Proposal creation constraints.
2. Single-active or otherwise intended active-state rules.
3. Vote locking correctness.
4. Claim cannot over-withdraw.
5. Finalization cannot move value inconsistently.
6. Proposal state transitions are well formed.
7. Governance records remain bound to the official registry.

### Detailed tasks

1. Specify allowed proposal lifecycle transitions.
2. Specify vote lock accounting invariants.
3. Specify that claimed value never exceeds locked or owed value.
4. Specify per-proposal registry binding and governance object consistency.
5. Specify uniqueness/consistency of voting records where applicable.
6. Check liveness assumptions around ending proposals and claiming.

### Deliverables

- governance-voting spec set;
- proof results for locked-token conservation properties;
- documented list of any liveness or stuck-state concerns.

### Exit criteria

This phase is complete when the highest-risk vote-lock and claim paths are
specified and mechanically attempted.

## Phase 3. Comments and Likes P0

### Goal

Prove that comment trees, comments, and likes cannot drift away from the target
artifact identity.

### Priority source

From the checklist:

- `P0-105` through `P0-130`
- and cross-module:
  - `P0-189` through `P0-194`

### Focus topics

1. `CommentsTree.target_series_id` is authoritative and stable.
2. `LikesBook.target_series_id` stays bound to the same series.
3. Comments cannot be added under the wrong tree or wrong registry.
4. Likes/unlikes cannot affect the wrong series.
5. Comment-fee payment flows cannot target the wrong fee manager or root.

### Detailed tasks

1. Specify tree creation and target-series binding.
2. Specify comment insertion authorization and target consistency.
3. Specify likes-book ownership/binding constraints.
4. Specify comment and like counters or records cannot cross series.
5. Specify registry equality between comments module state and publishing root.

### Deliverables

- comments/likes spec set;
- proof results for official binding invariants;
- any discovered mismatch between comments and publishing assumptions.

### Exit criteria

This phase is complete when comments-tree and likes-book correctness are no
longer implicit assumptions but explicit proved or tracked properties.

## Phase 4. Governance Core P0

### Goal

Cover governance configuration, fee-manager, and vault integrity at the core
object level.

### Priority source

From the checklist:

- `P0-29` through `P0-40`

### Focus topics

1. Root/governance-vault/fee-manager/config bindings.
2. Only authorized paths mutate governance-critical state.
3. Fee-level state is well formed.
4. Vault and config references remain canonical for the official deployment.

### Detailed tasks

1. Specify initialization bindings.
2. Specify mutation authority for governance core objects.
3. Specify fee-level state invariants.
4. Specify root-registry equality across governance core objects.

### Deliverables

- governance core spec set;
- proof results for authority and binding correctness.

### Exit criteria

This phase is complete when official governance infrastructure objects are
explicitly constrained by specs rather than by code inspection alone.

## Phase 5. Cross-Module P0 Closure

### Goal

Connect the publishing, comments, and governance modules into one official
deployment integrity story.

### Priority source

From the checklist:

- `P0-189` through `P0-194`

### Focus topics

1. Published series, comments tree, and likes book all agree on identity.
2. Publishing, comments, and governance all agree on registry identity.
3. Fee flows cannot succeed against the wrong official deployment objects.

### Detailed tasks

1. Prove comments-tree and likes-book back-references for every official
   series.
2. Prove registry equality across cross-module object references.
3. Prove publishing cannot produce official state under mixed registries.
4. Prove comment fee payment cannot succeed against a mismatched registry.

### Deliverables

- cross-module P0 proof set;
- deployment integrity summary.

### Exit criteria

This phase is complete when the official deployment can be described as one
coherent object graph with explicit formal constraints.

## Phase 6. Targeted P1 Expansion

### Goal

Expand beyond minimum safety into important integrity, lifecycle, and mutation
controls.

### Recommended P1 starting areas

1. `publishing::publishing`
   - `P1-165` through `P1-182`
2. `governance::governance_voting`
   - `P1-87` through `P1-100`
3. `comments::comments`
   - `P1-131` through `P1-140`
4. selected `validation` and `artifact_types` properties

### Focus topics

- owner-controlled transitions;
- metadata bounds;
- governance action targeting correctness;
- type-registry mutation correctness;
- preservation of historical identity under future changes.

### Exit criteria

This phase is complete when the protocol has a meaningful layer of integrity
proofs beyond the minimal P0 safety envelope.

## Phase 7. Selective P2 Hardening

### Goal

Prove a curated subset of lower-payoff but high-assurance hardening properties.

### Recommended P2 candidates

- repeated preprint reservations do not cross-talk;
- reservation IDs remain distinct;
- event/state consistency properties;
- migration helpers preserve identity/binding assumptions.

### Exit criteria

This phase is complete when the remaining P2 set is either:

- proved;
- intentionally deferred;
- or documented as not worth current prover budget.

## 7. Rules for Code Changes During Formal Verification

Formal verification is allowed to modify contract code on this branch, but only
under controlled rules.

### 7.1 Allowed code-change categories

1. `spec-only`
   - add or refine `spec` without changing runtime behavior.

2. `proof-structure`
   - refactor code to make reasoning explicit without changing semantics.

3. `soundness-fix`
   - change behavior because proof work exposed a real issue.

### 7.2 Required discipline for any runtime code change

If a `.move` implementation changes:

1. document which checklist IDs motivated the change;
2. explain whether the change is:
   - prover ergonomics only;
   - or a real semantic fix;
3. rerun relevant tests;
4. update deployment assumptions if behavior changed;
5. record the change in formal-verification status notes.

## 8. Completion Criteria Per Property

A checklist item should only be marked `proved` when all of the following are
true:

1. the intended meaning is written down concretely in spec form;
2. the proof is run against the current checked-in code;
3. the proof result is reproducible by command;
4. any hidden assumptions are documented;
5. the proved statement really matches the intended protocol property.

A property should not be marked complete merely because:

- a unit test exists;
- the prover did not complain about a weaker statement;
- the code "looks obviously correct";
- or the property was discussed informally in docs.

## 9. Risk Handling and Escalation

### 9.1 When to escalate immediately

Escalate a finding immediately if proof work suggests:

- locked funds may be stranded or over-claimed;
- proposal state can become permanently stuck;
- preprint reservation can be bypassed or mismatched;
- comments/likes can bind to the wrong series;
- registry identity can silently diverge across modules;
- historical artifact identity can mutate unexpectedly.

### 9.2 Required output for each serious finding

Each serious finding should include:

1. affected checklist IDs;
2. affected module/function;
3. whether the issue is exploitable, theoretical, or operational;
4. whether current tests catch it;
5. recommended next action.

## 10. Suggested Tracking Table

Maintain a table like the following during execution:

| Checklist ID | Module | Priority | Status | Spec Location | Proof Command | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| P0-147 | publishing::publishing | P0 | specified | `publishing.move` | `...` | direct preprint publish disabled |
| P0-154 | publishing::publishing | P0 | proved | `publishing.move` | `...` | reserved code equals final code |
| P0-189 | cross-module | P0 | blocked-structure | `comments.move` + `publishing.move` | `...` | needs helper invariant |

## 11. Immediate Next Actions

The recommended immediate next actions on the formal-verification branch are:

1. document exact prover command(s) for this repository;
2. create the formal-verification status tracker;
3. start Phase 1 with `publishing::publishing` P0 properties;
4. implement the first 5 to 10 publishing specs;
5. run the first prover pass and classify all outcomes;
6. only then decide whether code restructuring is necessary.

## 12. First Concrete Property Batch

If work begins immediately, the best first batch is:

- `P0-147`
- `P0-148`
- `P0-149`
- `P0-150`
- `P0-151`
- `P0-152`
- `P0-153`
- `P0-154`
- `P0-155`
- `P0-156`

These properties give the highest near-term value because they directly cover:

- preprint reserve/finalize integrity;
- prohibition of the old direct-preprint path;
- artifact identity continuity;
- canonical official object binding;
- the protocol behavior most likely to matter for both product trust and audit
  review.
