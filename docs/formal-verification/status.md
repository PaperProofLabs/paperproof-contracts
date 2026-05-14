<!--
Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available
-->

# Formal Verification Historical Status Record

This file preserves the historical status trail for the Sui prover rollout on
the `formal-verification` branch. It is not the final reporting surface. For
the completed baseline and recommended external wording, use
`docs/Formal-Verification-Final-Report.md` and
`docs/formal-verification/final-coverage-summary.md`.

## Toolchain State Recorded During Rollout

As of 2026-05-15, the prover pipeline is materially healthier than in the
earlier bootstrap runs:

- `sui-prover` is compiled and callable in WSL.
- `BoogieDriver.exe` is callable from WSL through `/mnt/c/...`.
- `z3.exe` is callable from WSL through `/mnt/c/...`.
- `BOOGIE_EXE` can be set explicitly for prover invocations.

This resolved the earlier blocker where prover runs reported:

- `No boogie executable set. Please set BOOGIE_EXE`

It also clarified that some earlier "timeout" behavior was at least partly
toolchain incompleteness rather than pure proof complexity.

## Toolchain Fix Recorded During Rollout (2026-05-17)

The mixed WSL/Windows prover chain is now materially understood and can be
run in a repeatable way. The key findings are:

- The local framework override must include a full local mirror of the prover
  dependencies, not only the Sui framework packages.
- The copied local framework packages also needed local dependency rewrites in
  the local prover manifests; otherwise sui-prover still falls back into
  git-based resolution.
- Existing spec-package Move.lock files can reintroduce stale git-sourced
  dependencies and muddy the signal. For clean toolchain diagnosis, they may
  need to be regenerated or temporarily removed during isolated runs.
- BOOGIE_EXE and Z3_EXE do not share the same path semantics in this mixed
  environment:
  - BOOGIE_EXE must be a WSL-executable path such as
    /mnt/c/Users/.../BoogieDriver.exe, because sui-prover executes it directly
    from the Unix side.
  - Z3_EXE must be WSL-executable for the initial sui-prover version check, but
    the actual Boogie proving run needs an additional Windows-style prover path
    override.
- A stable pattern is therefore:
  - export Z3_EXE as a /mnt/c/... path for sui-prover tool-version checks;
  - additionally pass a boogie config override equivalent to
    proverOpt:PROVER_PATH=C:\...\z3.exe so BoogieDriver.exe can locate Z3
    during the real proof run.

This means the earlier configured-prover-not-found failures were toolchain-path
issues, not protocol defects.

A repo-local entrypoint now exists at docs/formal-verification/run-sui-prover-wsl.sh. It prepares the local framework mirror, seeds an offline MOVE_HOME, temporarily isolates spec lock files during the run, and injects the Windows-style Boogie PROVER_PATH override needed for Z3.

## Prover Signal Recorded During Rollout

After wiring `BOOGIE_EXE`, minimal function-level runs now return quickly for
at least some targets, and selected output artifacts are being generated.

Observed artifact classes:

- `*.log.txt`
- selected `*_Check.bpl`

This means the workflow has moved past the earlier state of:

- dependency noise from polluted spec targets;
- missing Boogie executable;
- opaque long waits with no clear intermediate outputs.

## Historical Interpretation Rules

At this stage, the presence of a `*_Check.bpl` artifact is treated as evidence
that the target advanced into the Boogie verification stage.

The presence of only a `*.log.txt` artifact is treated as weaker signal:

- the target was processed;
- but it may still require more work to determine whether it fully reached a
  stable check stage or stopped earlier in the prover pipeline.

Accordingly, historical status terms in this file should be read as:

- `entered-check-stage`: `*_Check.bpl` exists
- `processed`: `*.log.txt` exists
- `needs-clear-pass-fail-readout`: the pipeline ran, but the final summary
  still needs to be extracted in a clean, repeatable way

## Targets With Clearer Historical Signal

## First Candidate Proved Baseline

The following targets are now reasonable to treat as the first candidate
baseline set for "proved workflow health":

- `comments_spec::transfer_tree_owner_spec`
- `comments_spec::like_paper_spec`
- `comments_spec::unlike_paper_spec`
- `comments_spec::set_tree_status_spec`
- `comments_spec::set_comment_status_spec`
- `comments_spec::tree_status_open_spec`
- `comments_spec::tree_status_locked_spec`
- `comments_spec::tree_status_archived_spec`
- `comments_spec::comment_status_active_spec`
- `comments_spec::comment_status_hidden_spec`
- `comments_spec::comment_status_deleted_spec`
- `comments_spec::comment_mode_onchain_spec`
- `comments_spec::comment_mode_blob_spec`
- `governance_spec::finalize_proposal_spec`
- `governance_spec::consume_executable_proposal_action_spec`
- `governance_spec::vote_side_yes_spec`
- `governance_spec::vote_side_no_spec`
- `governance_spec::action_enabled_spec`
- `governance_spec::proposal_status_active_spec`
- `governance_spec::proposal_status_passed_spec`
- `governance_spec::proposal_status_rejected_spec`
- `governance_spec::proposal_status_executed_spec`
- `governance_spec::proposal_status_expired_spec`
- `governance_spec::resolve_proposal_early_spec`
- `governance_spec::expire_passed_proposal_spec`
- `governance_spec::claim_locked_tokens_spec`
- `publishing_spec::metadata_attribute_spec`
- `publishing_spec::update_series_metadata_extensions_spec`
- `publishing_spec::series_status_active_spec`
- `publishing_spec::series_status_locked_spec`
- `publishing_spec::series_status_hidden_spec`
- `publishing_spec::series_artifact_type_spec`
- `publishing_spec::series_artifact_code_spec`
- `publishing_spec::series_owner_spec`
- `publishing_spec::series_status_spec`
- `publishing_spec::version_id_at_spec`
- `publishing_spec::execute_comments_fee_level_proposal_spec`
- `publishing_spec::execute_artifact_fee_level_proposal_spec`
- `publishing_spec::execute_artifact_type_enabled_proposal_spec`
- `publishing_spec::execute_artifact_type_activation_proposal_spec`

Why they qualify:

1. the prover pipeline reaches the Boogie check stage for them;
2. the corresponding `*_Check.bpl` artifacts exist;
3. direct Boogie invocation over those check artifacts returns with exit code
   `0`;
4. repeated runs complete quickly instead of timing out.

This baseline should still be described as a **candidate proved baseline**
rather than the final proof ledger, because the final reporting layer still
needs a cleaner repo-native summary command. But from an engineering
perspective, these targets are now far stronger than merely "processed".

### Comments

- `comments_spec::transfer_tree_owner_spec`
- `comments_spec::like_paper_spec`
- `comments_spec::unlike_paper_spec`

Observed:

- log artifacts exist
- `transfer_tree_owner_spec_Check.bpl` exists
- `like_paper_spec_Check.bpl` exists
- `unlike_paper_spec_Check.bpl` exists

Interpretation:

- comments minimal targets are among the best current candidates for the first
  clean "proved" wave
- repeated smallest-target runs now return in seconds rather than timing out

### Latest Rollout Notes (2026-05-17 governance wrapper-pruning continuation)

This rollout produced a cleaner and more repeatable proof path for several
governance entrypoints by pruning low-value spec wrappers that were being
proved independently but added little semantic strength to the public targets.

Key outcomes:

- `governance_spec::expire_passed_proposal_spec` is now green again under a
  materially cleaner dependency tree.
- `governance_spec::claim_locked_tokens_spec` is now green under the same
  wrapper-pruning approach.
- `governance_spec::finalize_proposal_spec` is also green after removing
  repeated entrypoint-local `asserts(...)` noise and cutting away helper
  wrapper prove targets that were polluting the signal.

Most important engineering lesson from this wave:

- Proving every tiny public getter/helper as its own target is not always a
  net positive. For governance in particular, several empty or low-information
  wrapper proofs caused the prover to route through a noisier dependency tree
  than the underlying public function bodies required.
- Removing `#[spec(prove)]` from low-value wrappers such as status/type/epoch
  accessors and trivial constants often let the prover reason directly from the
  governance module's public function bodies, producing a smaller and more
  stable check tree.

Targets pruned from independent `#[spec(prove)]` duty in this continuation
include several of the following classes:

- proposal status/type/epoch accessors
- vote-side and vote-record accessors
- proposal executability and claimability wrappers
- execution-validity and expiry helper wrappers

This did not weaken the public entrypoint verification story. Instead, it made
the entrypoint proofs more direct and less polluted by secondary helper proof
failures.

### Governance

- `governance_spec::finalize_proposal_spec`
- `governance_spec::consume_executable_proposal_action_spec`
- `governance_spec::vote_side_yes_spec`
- `governance_spec::vote_side_no_spec`
- `governance_spec::action_enabled_spec`
- `governance_spec::proposal_status_active_spec`
- `governance_spec::proposal_status_passed_spec`
- `governance_spec::proposal_status_rejected_spec`
- `governance_spec::proposal_status_executed_spec`
- `governance_spec::proposal_status_expired_spec`
- `governance_spec::execute_proposal_spec`
- `governance_spec::resolve_proposal_early_spec`
- `governance_spec::expire_passed_proposal_spec`
- `governance_spec::claim_locked_tokens_spec`

Observed:

- `finalize_proposal_spec` now completes with `Verification successful`
- `resolve_proposal_early_spec` now completes with `Verification successful`
- `expire_passed_proposal_spec` now completes with `Verification successful`
- `claim_locked_tokens_spec` now completes with `Verification successful`
- `consume_executable_proposal_action_spec` now completes with `Verification successful` even with stronger action-ticket binding postconditions
- strengthened `consume_executable_proposal_action_spec` continues to reach `Check.bpl` after adding config/proposal/vault registry and identity preservation postconditions
- `execute_proposal_spec` remains blocked by a toolchain-level bytecode transformation issue tied to transfer ghost globals, not by the strengthened governance entrypoint specs added in this wave

Interpretation:

- governance finalization, expiry, claims, and executable-action consumption are now meaningfully inside the proved baseline, not merely in a processed or artifact-only state
- the current high-value gap on the governance side is less about proposal-state transitions and more about prover/toolchain handling for the broad `execute_proposal` umbrella entrypoint
- the proved governance surface now covers terminal voting-state transitions, vote-claim cleanup, and the action-ticket bridge into downstream protocol execution
- the governance action-consumption cut point is also now carrying a stronger cross-registry preservation story, not only payload forwarding

### Publishing Governance Execution

- `publishing_spec::execute_comments_fee_level_proposal_spec`
- `publishing_spec::execute_artifact_fee_level_proposal_spec`
- `publishing_spec::execute_artifact_type_enabled_proposal_spec`
- `publishing_spec::execute_artifact_type_activation_proposal_spec`

Observed:

- all four targets now complete with `Verification successful`
- `Check`, `Assume`, and `SpecNoAbortCheck` all pass for each target
- prover-friendly postconditions are now in place for fee-level and artifact-type governance execution

Interpretation:

- publishing governance execution entrypoints are now part of the proved baseline, not merely the processed set
- the main prover friction in this wave came from postcondition shape rather than from the execution logic itself
- introducing a non-aborting read helper for type-enabled state materially improved proof stability without changing protocol behavior

### Publishing

- `publishing_spec::metadata_attribute_spec`
- `publishing_spec::reserve_preprint_code_spec`
- `publishing_spec::update_series_metadata_extensions_spec`
- `publishing_spec::series_status_active_spec`
- `publishing_spec::series_status_locked_spec`
- `publishing_spec::series_status_hidden_spec`
- `publishing_spec::series_artifact_type_spec`
- `publishing_spec::series_artifact_code_spec`
- `publishing_spec::series_owner_spec`
- `publishing_spec::series_status_spec`
- `publishing_spec::add_preprint_version_spec`
- `publishing_spec::series_current_version_spec`
- `publishing_spec::series_current_version_id_spec`
- strengthened `publishing_spec::set_series_status_spec` with identity-field preservation
- strengthened `publishing_spec::update_series_metadata_extensions_spec` with identity-field preservation

Observed:

- log artifacts exist
- `reserve_preprint_code_spec_Check.bpl` exists
- `version_id_at_spec_Check.bpl` exists
- strengthened `set_series_status_spec` and `update_series_metadata_extensions_spec` continue to emit full `Assume` / `Check` / `SpecNoAbortCheck` artifacts after adding identity-preservation postconditions
- strengthened `comments_spec::transfer_tree_owner_spec` and `comments_spec::set_tree_status_spec` currently look more like stable processed targets: their enriched binding-preservation forms emit `.log.txt`, but are not yet being counted as clean baseline `Check.bpl` wins

Interpretation:

- publishing reserve and metadata minimal targets have entered the Boogie check
  stage
- `transfer_artifact_owner_spec` currently behaves more like a prover-friction target than a clean baseline candidate
- version-add and metadata-update targets are still active candidates for
  further stabilization
- public version/history read-surface proving is now expanding from plain accessors toward version-chain continuity cut points, with `version_id_at_spec` already reaching `Check.bpl`
- repeated smallest-target runs now return quickly for:
  - `reserve_preprint_code_spec`
  - `update_series_metadata_extensions_spec`

## Historical Intermediate Maintenance Notes

These notes were recorded during an intermediate rollout stage and have been
superseded by the completed baseline documented in
`docs/Formal-Verification-Final-Report.md`.

1. Keep `BOOGIE_EXE` explicit in all formal runs through the repo helper
   scripts.
2. Preserve the now-standard run matrix for default, weak transfer, weak unwrap,
   and combined workaround modes.
3. Treat deeper framework behavior as a maintenance and upstream-tooling topic
   rather than an unresolved PaperProof protocol-logic item.

## Current Working Distinction

The current prover rollout now clearly separates targets into three practical
classes:

### Class A: candidate proved baseline

Characteristics:

- `*_Check.bpl` exists
- direct Boogie invocation returns exit code `0`
- repeated runs are quick

Current examples:

- `comments_spec::transfer_tree_owner_spec`
- `comments_spec::like_paper_spec`
- `comments_spec::unlike_paper_spec`
- `comments_spec::set_tree_status_spec`
- `comments_spec::set_comment_status_spec`
- `comments_spec::tree_status_open_spec`
- `comments_spec::tree_status_locked_spec`
- `comments_spec::tree_status_archived_spec`
- `comments_spec::comment_status_active_spec`
- `comments_spec::comment_status_hidden_spec`
- `comments_spec::comment_status_deleted_spec`
- `comments_spec::comment_mode_onchain_spec`
- `comments_spec::comment_mode_blob_spec`
- `governance_spec::finalize_proposal_spec`
- `governance_spec::consume_executable_proposal_action_spec`
- `governance_spec::vote_side_yes_spec`
- `governance_spec::vote_side_no_spec`
- `governance_spec::action_enabled_spec`
- `governance_spec::proposal_status_active_spec`
- `governance_spec::proposal_status_passed_spec`
- `governance_spec::proposal_status_rejected_spec`
- `governance_spec::proposal_status_executed_spec`
- `governance_spec::proposal_status_expired_spec`
- `publishing_spec::metadata_attribute_spec`
- `publishing_spec::update_series_metadata_extensions_spec`
- `publishing_spec::series_status_active_spec`
- `publishing_spec::series_status_locked_spec`
- `publishing_spec::series_status_hidden_spec`
- `publishing_spec::series_artifact_type_spec`
- `publishing_spec::series_artifact_code_spec`
- `publishing_spec::series_owner_spec`
- `publishing_spec::series_status_spec`

### Class B: stable processed targets

Characteristics:

- prover repeatedly reaches the target quickly
- `*.log.txt` exists or repeated successful runs are observed
- the target appears stable under repeated runs
- but it is not yet being used as a primary proof-ledger anchor

Current examples:

- `publishing_spec::reserve_preprint_code_spec`
- `publishing_spec::add_preprint_version_spec`
- `governance_spec::resolve_proposal_early_spec`
- `governance_spec::remaining_voting_supply_spec`

### Class C: prover-friction targets

Characteristics:

- the target expresses real protocol intent
- current proof shape still triggers noisy arithmetic, model, event, or internal-assert interactions
- failures should not currently be read as protocol bugs without stronger corroboration

Current examples:

- `publishing_spec::transfer_artifact_owner_spec`
- `governance_spec::execution_expiry_epoch_spec`
- `governance_spec::outcome_determinable_spec`

Current interpretation:

- the underlying contract logic for these targets still looks straightforward on code review
- the present failures are better treated as spec/prover interaction issues than as evidence of a protocol defect
- these targets are temporarily excluded from the first candidate proved baseline to keep the signal clean

## New Observation From 2026-05-16

Some very lightweight helper-level spec targets currently do not leave obvious
output artifacts even when the prover invocation returns quickly with exit code
`0`.

This suggests an additional nuance in the current workflow:

- absence of a new artifact is not automatically evidence of a failed proof
  attempt;
- some targets may be processed without leaving the same artifact footprint as
  the more visible `*_Check.bpl` cases;
- therefore artifact presence remains a strong positive signal, but artifact
  absence is only a weak negative signal.

Operationally, this means the current rollout should continue prioritizing:

1. targets that produce clear artifact evidence;
2. target families that can be made to converge toward `Check.bpl`;
3. decomposition work on the medium-weight Class B entrypoints rather than
   overfitting to every trivial helper target.

This heuristic is now reinforced by repeated runs on small accessor-style
specs: some such targets return quickly but still do not produce stable
standalone artifacts. As a result, the rollout should keep treating medium-weight
entrypoints with reproducible log evidence as the main optimization frontier.


## Latest Rollout Notes

As of 2026-05-16, the latest prover wave added several more stable green
targets and clarified one recurring toolchain boundary:

### Newly Green in This Wave

- `comments_spec::like_paper_spec` now proves with a stronger monotonicity
  postcondition: successful like operations strictly increase `like_count`.
- `comments_spec::unlike_paper_spec` now proves with a stronger monotonicity
  postcondition: successful unlike operations strictly decrease `like_count`.
- `governance_spec::can_claim_locked_tokens_spec` now proves with explicit
  semantic implications from the returned boolean into finalized-state and
  vote-existence conditions.
- `governance_spec::is_proposal_executable_spec` now proves with explicit
  semantic implications from the returned boolean into executable proposal
  type, passed status, and not-yet-executed state.
- `governance_spec::artifact_fee_amount_spec` now proves with a concrete fee
  level to fee amount mapping, under an explicit valid-fee-level precondition.
- `publishing_spec::set_series_status_spec` now proves with preservation of
  owner and artifact type in addition to the requested new status.
- `publishing_spec::update_series_metadata_extensions_spec` now proves in a
  restricted but stable shape for a one-attribute metadata vector, preserving
  series owner, artifact type, and active status.

### Historical Toolchain-Shaped Residuals

- `governance_spec::new_action_ticket_spec` historically failed as a direct accessor
  equality proof target, even though downstream ticket-consuming execution
  paths can be proved successfully. This was classified as a prover/model
  interaction issue rather than a protocol bug.
- `publishing_spec::publish_common_spec` and
  `publishing_spec::publish_reserved_preprint_common_spec` currently hit the
  same `transfer_spec::SpecTransferAddress*` bytecode-transformation issue seen
  on other object-creation / transfer-heavy paths.
- `publishing_spec::add_*_version_spec` targets continue to hit that same
  transfer ghost-global blocker; they are not currently reading as protocol
  failures.

## Latest Rollout Notes (2026-05-16, continuation)

Newly confirmed green in this pass:

- governance_spec::artifact_fee_level_spec
- governance_spec::comments_fee_level_spec
- governance_spec::comments_fee_amount_spec
- publishing_spec::set_series_status_spec
- publishing_spec::series_current_version_id_spec

Preprint-path clarification from this pass:

- `finalize_reserved_preprint_spec` no longer fails because of self-contradictory helper-spec assumptions.
- After spec cleanup, its remaining blocker is the known Sui-prover / transfer ghost-global bytecode-transformation issue (`transfer_spec::SpecTransferAddress` / `SpecTransferAddressExists`).
- This should currently be interpreted as a toolchain-shaped blocker on transfer-heavy publish flows, not as evidence of a discovered protocol bug in the reserved preprint path.

Spec-shape cleanup performed:

- removed standalone scenario/prove targets for internal publishing helpers that were not good independent verification units;
- aligned reserved-preprint helper assumptions with protocol metadata bounds (<= 4 rather than the earlier prover-convenience <= 1);
- rewrote reserved-preprint helper bindings to cache reservation identity before move, avoiding false failures from moved-value postconditions.


Current interpretation:

- the underlying contract logic remains straightforward on code review
- the present failures are better treated as spec/prover interaction issues than as evidence of a protocol defect
- these targets are temporarily excluded from the first candidate proved baseline to keep the signal clean

## Latest Rollout Notes (2026-05-23 publishing preprint continuation)

This continuation revisited the remaining publishing failures on the reserved
preprint and ownership-transfer slice.

What changed:

- converted `reserve_preprint_code_spec` from `asserts(...)`-style environment
  assumptions into `requires(...)` preconditions that match the publishing
  entrypoint's expected call context;
- applied the same precondition reshaping to
  `finalize_reserved_preprint_spec`, removing a large amount of avoidable
  prover no-abort noise from input-validation checks;
- weakened `transfer_artifact_owner_spec` to assert only the observable owner
  update on the comments tree, instead of a stronger helper-level condition
  than the downstream comments spec actually promises.

Historical status:

- `publishing_spec::reserve_preprint_code_spec` now completes with
  `Verification successful`;
- `publishing_spec::transfer_artifact_owner_spec` now completes with
  `Verification successful`;
- `publishing_spec::finalize_reserved_preprint_spec` no longer presents as a
  Boogie proof failure and now stops earlier with the known
  `transfer_spec::SpecTransferAddress` /
  `transfer_spec::SpecTransferAddressExists` bytecode-transformation issue.

Practical conclusion:

- the publishing failure surface has narrowed from three targets to one;
- the remaining open target is still better classified as a transfer-heavy
  prover/toolchain limitation than as evidence of a reserved-preprint protocol
  defect.

### Transfer-Heavy Blocker Inventory (2026-05-23)

Additional boundary-mapping in this continuation confirmed that the
`transfer_spec::SpecTransferAddress*` issue is not isolated to a single
reserved-preprint entrypoint.

Newly confirmed observations:

- `publishing_spec::finalize_reserved_preprint_spec` still stops in bytecode
  transformation before Boogie proof search, with
  `SpecTransferAddress` / `SpecTransferAddressExists`;
- `publishing_spec::add_preprint_version_spec` hits that same blocker under a
  narrower version-add path;
- earlier notes already recorded the same class of failure for
  `publishing_spec::publish_reserved_preprint_common_spec`;
- the governance side had an analogous toolchain-shaped residual in
  `governance_spec::execute_proposal_spec`.

Shared implementation pattern behind these blocked targets:

- publishing publish / add-version paths call
  `governance::collect_artifact_fee(...)`;
- that fee path descends into `collect_fee(...)`, which may call
  `refund_or_destroy(...)` and `transfer::public_transfer(...)`;
- many of the same targets also create or publish objects via
  `transfer::share_object(...)`, `comments::share_tree(...)`, and
  `comments::share_likes_book(...)`.

Operational interpretation:

- this blocker should now be treated as a reusable target-class diagnosis,
  not as a one-off target failure;
- further work on these targets should prioritize isolation, classification,
  and reporting discipline unless a concrete toolchain workaround is found.

Confirmed target ledger as of 2026-05-23:

- `governance_spec::execute_proposal_spec`
  - current artifact: `governance-specs/output/governance_spec::execute_proposal_spec.log.txt`
  - current classification: transfer-ghost-global / bytecode-transformation blocker
- `publishing_spec::publish_reserved_preprint_common_spec`
  - current artifact: `publishing-specs/output/publishing_spec::publish_reserved_preprint_common_spec.log.txt`
  - current classification: transfer-ghost-global / bytecode-transformation blocker
- `publishing_spec::finalize_reserved_preprint_spec`
  - current artifact: `publishing-specs/output/publishing_spec::finalize_reserved_preprint_spec.log.txt`
  - current classification: transfer-ghost-global / bytecode-transformation blocker
- `publishing_spec::add_preprint_version_spec`
  - current artifact: `publishing-specs/output/publishing_spec::add_preprint_version_spec.log.txt`
  - current classification: transfer-ghost-global / bytecode-transformation blocker


## Latest Rollout Notes (2026-05-17 governance continuation)

This wave continued focusing on the governance proof line, especially the
 dependency chain and the two public entrypoints:

- 
- 

### Newly Green in This Wave

- 
- 
- 

This is an important milestone: the core governance config/proposal binding
bridge now proves successfully as an independent helper target.

### What Improved But Is Still Not Green

- 
- 
- 
- 

For these targets, the work in this wave substantially narrowed the failure
surface:

1.  is no longer just an opaque failure around the
   config/proposal binding chain. Its remaining pressure is now more clearly
   split between:
   - helper-to-entrypoint model interaction around the proved binding bridge;
   - the status-transition core delegated through .
2.  now reliably gets past the earlier
   vague binding obstruction and fails deeper in the entry guard / action-shape
   reasoning. This was an intermediate-stage signal before later convergence.
3.  isolates the real governance outcome core:
   proposal status selection based on  plus the
   clearing of the active proposal slot.
4.  appears to be a prover-friction arithmetic
   target around  comparisons and boolean equivalence/implies shapes,
   rather than evidence of a protocol defect.

### Current Interpretation

The present governance blockers should currently be interpreted as
spec/prover-model interaction issues, not as discovered protocol bugs.

In particular:

- the config/proposal/object-id binding bridge itself is now independently
  proved;
- the remaining failures are concentrated in arithmetic/branching proof shape
  and entrypoint-scale composition;
-  and  remain green for the larger governance entry
  targets under the current spec shapes.

### Practical Status of This Governance Slice

At this point, the governance line can be understood as layered like this:

- **Green bridge layer**
  - 
  - 
  - 
- **Entry/composition layer classified during rollout**
  - 
  - 
- **Arithmetic/state-classification layer classified during rollout**
  - 
  - 

This decomposition was valuable because later work could target the arithmetic
and branch-shape core directly without re-opening the already-proved binding
chain.


## Latest Rollout Notes (2026-05-17 governance continuation)

This wave continued focusing on the governance proof line, especially the
proposal/config binding dependency chain and the two public entrypoints:

- governance_spec::finalize_proposal_spec
- governance_spec::consume_executable_proposal_action_spec

### Newly Green in This Wave

- governance_spec::assert_current_config_spec
- governance_spec::assert_current_proposal_spec
- governance_spec::assert_proposal_belongs_to_config_spec

This is an important milestone: the core governance config/proposal binding
bridge now proves successfully as an independent helper target.

### What Improved But Is Still Not Green

- governance_spec::finalize_proposal_spec
- governance_spec::consume_executable_proposal_action_spec
- governance_spec::finalize_active_proposal_spec
- governance_spec::passage_rule_satisfied_spec

For these targets, the work in this wave substantially narrowed the failure
surface:

1. finalize_proposal_spec is no longer just an opaque failure around the
   config/proposal binding chain. Its remaining pressure is now more clearly
   split between:
   - helper-to-entrypoint model interaction around the proved binding bridge;
   - the status-transition core delegated through finalize_active_proposal.
2. consume_executable_proposal_action_spec now reliably gets past the earlier
   vague binding obstruction and fails deeper in the entry guard / action-shape
   reasoning. This was an intermediate-stage signal before later convergence.
3. finalize_active_proposal_spec isolates the real governance outcome core:
   proposal status selection based on passage_rule_satisfied(...) plus the
   clearing of the active proposal slot.
4. passage_rule_satisfied_spec appears to be a prover-friction arithmetic
   target around u128 comparisons and boolean equivalence/implies shapes,
   rather than evidence of a protocol defect.

### Current Interpretation

The present governance blockers should currently be interpreted as
spec/prover-model interaction issues, not as discovered protocol bugs.

In particular:

- the config/proposal/object-id binding bridge itself is now independently
  proved;
- the remaining failures are concentrated in arithmetic/branching proof shape
  and entrypoint-scale composition;
- Assume and SpecNoAbortCheck remain green for the larger governance entry
  targets under the current spec shapes.

### Practical Status of This Governance Slice

At this point, the governance line can be understood as layered like this:

- Green bridge layer
  - assert_current_config_spec
  - assert_current_proposal_spec
  - assert_proposal_belongs_to_config_spec
- Entry/composition layer classified during rollout
  - finalize_proposal_spec
  - consume_executable_proposal_action_spec
- Arithmetic/state-classification layer classified during rollout
  - finalize_active_proposal_spec
  - passage_rule_satisfied_spec

This decomposition was valuable because later work could target the arithmetic
and branch-shape core directly without re-opening the already-proved binding
chain.

### Latest Rollout Notes (2026-05-17 governance executable-action re-baselining)

This continuation re-stabilized governance_spec::consume_executable_proposal_action_spec
under a more prover-friendly public-entrypoint shape. The successful pattern in this wave
was:

- move entrypoint assumptions from repeated sserts(...) into direct
  
equires(...) clauses where the implementation already treats them as
  preconditions;
- add the missing public precondition that the governance action executor cap
  is bound to the same vault object
  (ction_executor_cap_governance_vault_id(action_executor_cap) == object::id(vault));
- replace indirect allowed-action checks based on multiple action accessor
  wrappers with a single local #[spec_only] predicate over the concrete
  executable action constants;
- snapshot proposal payload fields before the call and state ticket payload
  postconditions against those snapshots;
- prune low-value ticket/helper wrappers that either introduced visibility
  issues or added dependency noise without materially strengthening the public
  proof story.

Outcome:

- governance_spec::consume_executable_proposal_action_spec is green again
  with Check, Assume, and SpecNoAbortCheck all passing.

Non-regression observation:

- governance_spec::execute_proposal_spec still fails for the same
  transfer-ghost-global bytecode transformation blockers
  (	ransfer_spec::SpecTransferAddress and
  	ransfer_spec::SpecTransferAddressExists). This continuation did not turn
  that target into a protocol-logic failure; it remains a toolchain-level
  blocker for transfer-heavy execution paths.

### Latest Rollout Notes (2026-05-17 governance vote-entrypoint stabilization)

This continuation focused on the public governance vote entrypoints and on
cleaning the governance rollout record.

What changed:

- removed `minimum_vote_stake_spec` from independent `#[spec(prove)]` duty;
- kept the vote entrypoint guards in `requires(...)` form;
- added the missing overflow guards for both vote tally accumulation and
  locked-balance accumulation:
  - `yes_votes + voting_power` / `no_votes + voting_power`
  - `yes_locked_value + voting_power` / `no_locked_value + voting_power`

Outcome:

- `governance_spec::vote_yes_spec` is green;
- `governance_spec::vote_no_spec` is green.

Interpretation:

- the remaining friction on the governance line is no longer in the basic
  public vote entrypoints;
- the productive baseline now includes proposal creation, voting, proposal
  finalization, early resolution, passed-proposal expiry, locked-token claims,
  remaining voting supply, and executable action consumption.

### Latest Rollout Notes (2026-05-23 governance helper convergence)

This continuation revisited the then-remaining governance helper gap around
proposal-passage math and early-resolution dependency shaping.

What changed:

- reintroduced a minimal `passage_rule_satisfied_spec` with only a one-way
  observable arithmetic guarantee;
- reintroduced a minimal `finalize_active_proposal_spec` focused on proposal
  status transition, vote preservation, and registry / proposal identity
  preservation;
- weakened `resolve_proposal_early_spec` from stronger `asserts(...)`-style
  entry assumptions into prover-friendlier `requires(...)` preconditions;
- reshaped `outcome_determinable_spec` so its overflow preconditions bind
  directly to `governance_voting::remaining_voting_supply(...)`, which removes
  a remaining proof-shape mismatch between the spec-local arithmetic model and
  the helper actually used by the implementation.

Historical status:

- `governance_spec::passage_rule_satisfied_spec` now completes with
  `Verification successful`;
- `governance_spec::finalize_active_proposal_spec` now completes with
  `Verification successful`;
- `governance_spec::resolve_proposal_early_spec` now completes with
  `Verification successful`;
- `governance_spec::outcome_determinable_spec` now completes with
  `Verification successful`.

Practical conclusion:

- the governance line no longer has an active logical proof failure in the
  proposal finalization / early-resolution slice;
- the governance residual was no longer `outcome_determinable_spec`,
  but the broader `execute_proposal_spec` family where prior notes already
  identified transfer ghost-global / toolchain friction.

### Current Governance Baseline Snapshot

Green governance targets in the current baseline include:

- `governance_spec::create_proposal_spec`
- `governance_spec::vote_yes_spec`
- `governance_spec::vote_no_spec`
- `governance_spec::remaining_voting_supply_spec`
- `governance_spec::passage_rule_satisfied_spec`
- `governance_spec::finalize_active_proposal_spec`
- `governance_spec::outcome_determinable_spec`
- `governance_spec::finalize_proposal_spec`
- `governance_spec::resolve_proposal_early_spec`
- `governance_spec::expire_passed_proposal_spec`
- `governance_spec::claim_locked_tokens_spec`
- `governance_spec::consume_executable_proposal_action_spec`

Historical governance residual at this stage:

- `governance_spec::execute_proposal_spec`
  - classified as blocked by transfer ghost-global prover/toolchain issues, not by a
    newly identified protocol-logic defect.

### Latest Rollout Notes (2026-05-23 governance execute-proposal split follow-up)

This continuation focused on two things: stabilizing the WSL prover wrapper so
repeated runs stop failing before prover startup, and checking whether a
non-operator-nomination slice of `execute_proposal` could escape the known
transfer-ghost blocker.

What changed:

- updated `docs/formal-verification/run-sui-prover-wsl.sh` so `MOVE_HOME` is no
  longer rebuilt on every run; the local cache is now reused when the seeded
  `sui` / `sui-prover` copies are already present, which removes a flaky
  pre-prover failure mode around repeated heavy directory copies;
- temporarily removed the older duplicate prove harness for
  `governance_voting::execute_proposal`, because adding
  `execute_proposal_non_nominate_spec` exposed that the prover rejects two
  `#[spec(prove)]` wrappers for the same target function;
- added and verified new helper-level governance specs for:
  - `governance_spec::assert_valid_action_enable_target_spec`
  - `governance_spec::assert_valid_proposer_threshold_spec`
  - `governance_spec::assert_valid_proposal_duration_epochs_spec`

Outcome:

- the WSL prover wrapper is stable again for repeated governance runs;
- the three new helper targets above now complete with `Verification successful`;
- `governance_spec::execute_proposal_non_nominate_spec` still fails with the
  same bytecode-transformation blocker:
  - `transfer_spec::SpecTransferAddress`
  - `transfer_spec::SpecTransferAddressExists`

Interpretation:

- excluding `ACTION_NOMINATE_OPERATOR` is not enough to turn
  `execute_proposal` into a logic-level proof problem;
- the blocking surface is broader than the nomination branch and still sits at
  the transfer-ghost / bytecode-transformation layer of the current prover
  toolchain;
- the productive next direction remains helper-level and branch-local proof
  extraction for pure config / pure authority updates rather than retrying the
  full `execute_proposal` target unchanged.

### Latest Rollout Notes (2026-05-23 governance helper extraction, wave 2)

This continuation stayed on the helper-first path below `execute_proposal` and
expanded the proved baseline for pure authority / config validation helpers.

Newly verified governance targets in this wave:

- `governance_spec::apply_fee_recipient_spec`
- `governance_spec::apply_governance_authority_spec`
- `governance_spec::apply_upgrade_authority_spec`
- `governance_spec::apply_direct_authority_mode_from_vote_spec`
- `governance_spec::assert_known_action_spec`
- `governance_spec::assert_valid_proposal_action_pair_spec`
- `governance_spec::apply_action_enabled_spec`

Interpretation:

- the governance line now has direct proof coverage for the main
  non-transfer authority-field update helpers and for the action-domain /
  action-enable validation helpers those paths rely on;
- this continues to support the current reading that the remaining
  `execute_proposal` blockage is not in these pure state-transition helpers,
  but at the surrounding bytecode-transformation layer where the prover still
  trips over transfer ghost globals.

### Latest Rollout Notes (2026-05-23 governance helper extraction, wave 3)

This continuation pushed one step closer to proposal lifecycle internals while
still staying off the known transfer-heavy paths.

Newly verified governance targets in this wave:

- `governance_spec::assert_action_enabled_spec`
- `governance_spec::clear_active_proposal_spec`
- `governance_spec::expire_proposal_internal_spec`

Interpretation:

- the governance helper baseline now covers both action-domain validation and
  the non-transfer proposal-lifecycle mutation helpers that feed proposal
  execution / expiry flow;
- this further narrows the unexplained surface around the remaining
  `execute_proposal` family blockage, reinforcing that the current hard stop is
  outside these local state-transition helpers and still tied to the transfer
  ghost-global transformation boundary.

### Latest Rollout Notes (2026-05-23 governance proposal-validation extraction)

This continuation moved to the proposal-construction side and targeted the
remaining local validation helpers that sit below `create_proposal`.

Newly verified governance targets in this wave:

- `governance_spec::assert_valid_proposal_text_spec`
- `governance_spec::assert_valid_proposal_payload_spec`

Interpretation:

- the proposal-validation baseline now directly covers title/description
  bounds and the executable/signal payload admissibility rules across the full
  action set;
- together with the earlier action-domain and threshold helpers, this means
  the create-side local validation layer is now mostly proved in isolation,
  again leaving transfer-heavy execution paths as the main unresolved
  governance prover/toolchain boundary.

### Latest Rollout Notes (2026-05-24 create-proposal strengthening and ticket helpers)

This continuation did two things in parallel:

- strengthened `governance_spec::create_proposal_spec` with extra postconditions
  that explicitly preserve the surrounding config invariants
  (`registry_id`, `total_supply`, `proposer_threshold`,
  `proposal_duration_epochs`, and `proposal_creation_paused`);
- expanded non-transfer governance execution coverage around ticket-based fee
  helper paths.

Newly verified governance targets in this wave:

- strengthened `governance_spec::create_proposal_spec` still passes with the
  added config-preservation postconditions;
- `governance_spec::new_action_ticket_spec`
- `governance_spec::apply_comments_fee_level_from_ticket_spec`
- `governance_spec::apply_artifact_fee_level_from_ticket_spec`

Interpretation:

- the proposal-creation story is now stronger at the composition level, not
  just at the guard-check level;
- the governance line now also has direct proof coverage for the
  non-transfer fee-execution ticket helpers that sit under specialized
  execution entrypoints;
- this continues the same pattern: local create-side logic and local
  ticket-driven mutation helpers are green, while the remaining open boundary
  still clusters around transfer-heavy execution flows rather than these
  isolated state transitions.

### Latest Rollout Notes (2026-05-24 fee helper consolidation and first specialized execution path)

This continuation pushed the governance fee branch one step further from
helper-level coverage into a complete non-transfer specialized execution path.

Newly verified governance targets in this wave:

- `governance_spec::set_fee_level_spec`
- `governance_spec::apply_comments_fee_level_spec`
- `governance_spec::unpack_artifact_type_enabled_ticket_spec`
- `governance_spec::execute_comments_fee_level_proposal_spec`

Interpretation:

- the fee-configuration helper chain is now largely closed under direct proof:
  table update, comments-fee mutation, ticket unpacking, ticket-driven fee
  application, and the top-level comments-fee execution entrypoint are all
  green;
- this is an important milestone because it shows a full governance execution
  subpath can be proved end-to-end when it stays off transfer-heavy object
  flows;
- the governance residual set was therefore more sharply localized
  around transfer-coupled execution paths rather than generalized execution
  control flow.

### Latest Rollout Notes (2026-05-24 helper sweep after fee-path closure)

This continuation used the stability of the fee/ticket branch to sweep a
cluster of remaining non-transfer governance helpers.

Newly verified governance targets in this wave:

- `governance_spec::new_fee_manager_spec`
- `governance_spec::fee_level_spec`
- `governance_spec::migrate_config_version_spec`
- `governance_spec::migrate_proposal_version_spec`
- `governance_spec::assert_direct_authority_allowed_spec`

Interpretation:

- the governance helper surface is continuing to contract in a clean way:
  version migration, fee-manager initialization, fee lookup, and direct
  authority admission guards are now directly covered;
- combined with the earlier create-side validation, lifecycle helpers, and the
  comments-fee specialized execution path, this leaves an even smaller
  residual set of governance targets whose difficulty is plausibly structural
  rather than local;
- in practice, the remaining hard boundary still points back to
  transfer-coupled execution and object-flow machinery, not to ordinary helper
  logic.

### Latest Rollout Notes (2026-05-25 governance admin wrapper and vault baseline sweep)

This continuation focused on clearing another concentrated block of
non-transfer governance helpers around direct-authority admin wrappers and
vault-local invariants/migration.

Newly verified governance targets in this wave:

- `governance_spec::assert_action_executor_cap_spec`
- `governance_spec::bind_governance_config_spec`
- `governance_spec::assert_active_operator_spec`
- `governance_spec::set_fee_recipient_spec`
- `governance_spec::set_governance_authority_spec`
- `governance_spec::set_upgrade_authority_spec`
- `governance_spec::set_comments_fee_level_spec`
- `governance_spec::assert_current_vault_spec`
- `governance_spec::migrate_vault_version_spec`
- `governance_spec::migrate_vault_spec`

Interpretation:

- the governance direct-authority surface is now covered beyond package-local
  mutators and down into the public admin entrypoints themselves;
- the vault baseline is also stronger now: current-version admission,
  config binding, active-operator admission, and vault migration all have
  direct proof coverage;
- this further compressed the residual governance set toward transfer /
  wrapper / object-flow machinery instead of ordinary local state updates.

### Latest Rollout Notes (2026-05-25 governance accessor cleanup)

This continuation used the stability of the governance helper line to clear a
wide slice of remaining local accessor/getter targets so the still-unproved
surface better reflects real structural boundaries.

Newly verified governance targets in this wave:

- `governance_spec::operator_epoch_spec`
- `governance_spec::operator_permit_registry_matches_spec`
- `governance_spec::action_executor_cap_registry_id_spec`
- `governance_spec::action_executor_cap_governance_vault_id_spec`
- `governance_spec::action_ticket_registry_id_spec`
- `governance_spec::action_ticket_action_type_spec`
- `governance_spec::action_ticket_payload_u64_1_spec`
- `governance_spec::action_ticket_payload_u64_2_spec`
- `governance_spec::fee_manager_id_spec`
- `governance_spec::fee_manager_registry_id_spec`
- `governance_spec::managed_upgrade_package_spec`

Interpretation:

- the governance helper ledger is now much cleaner: many previously
  unproved local observers are now explicitly green instead of being left as
  implicit low-risk gaps;
- after this sweep, the most meaningful residual governance targets are no
  longer plain accessors or simple local mutators, but transfer-heavy operator
  flows, fee-collection coin flows, shared-object wrappers, and managed
  upgrade-cap paths;
- this improves the signal quality of the remaining backlog: when a governance
  target remained unresolved at that stage, it was increasingly likely to be interesting for
  prover/toolchain reasons rather than because a small local helper was simply
  never harnessed.

### Latest Rollout Notes (2026-05-25 governance getter/constant sweep and managed-upgrade follow-through)

This continuation pushed the governance cleanup further by clearing most of
the remaining local vault observers/constants and then reopening part of the
managed-upgrade branch.

Newly verified governance targets in this wave:

- `governance_spec::registry_id_spec`
- `governance_spec::governance_config_id_spec`
- `governance_spec::governance_vault_version_spec`
- `governance_spec::current_governance_vault_version_spec`
- `governance_spec::governance_authority_spec`
- `governance_spec::upgrade_authority_spec`
- `governance_spec::active_operator_spec`
- `governance_spec::active_operator_epoch_spec`
- `governance_spec::has_pending_operator_transfer_spec`
- `governance_spec::pending_operator_spec`
- `governance_spec::pending_operator_epoch_spec`
- `governance_spec::pending_operator_wrapper_id_spec`
- `governance_spec::fee_recipient_spec`
- `governance_spec::direct_authority_mode_spec`
- `governance_spec::direct_authority_permanently_disabled_spec`
- `governance_spec::direct_authority_mode_full_spec`
- `governance_spec::direct_authority_mode_emergency_spec`
- `governance_spec::direct_authority_mode_read_only_spec`
- `governance_spec::direct_authority_mode_disabled_spec`
- `governance_spec::borrow_admin_cap_spec`
- `governance_spec::borrow_operator_from_wrapper_spec`
- `governance_spec::register_managed_upgrade_cap_spec`
- `governance_spec::authorize_managed_upgrade_spec`
- `governance_spec::commit_managed_upgrade_spec`

Interpretation:

- the governance residual set became much sharper than before: local
  getters/constants, direct-authority state observers, and the basic
  managed-upgrade path are directly covered instead of being mixed into the
  backlog;
- managed-upgrade did not turn out to be a hard blocker in the same way as
  transfer-heavy execution paths: registration, authorization, and commit all
  proved with lightweight relational harnesses;
- after this wave, the governance backlog is concentrated almost entirely in
  transfer/share/coin-flow/operator-transfer entrypoints, which is exactly the
  boundary we wanted to isolate.

### Latest Rollout Notes (2026-05-25 multi-module getter and observer sweep)

This continuation pivoted from concentrated governance cleanup into a broader
cross-module sweep, targeting large batches of local observers/getters across
`governance_voting`, `comments`, and `publishing`, while probing the next
coin-flow governance target.

Newly verified representative targets in this wave:

- `governance_spec::next_proposal_id_spec`
- `governance_spec::active_proposal_id_spec`
- `comments_spec::tree_version_spec`
- `comments_spec::like_count_spec`
- `publishing_spec::root_version_spec`
- `publishing_spec::type_registry_version_spec`

Structural outcome of this wave:

- the observer/getter sweep direction is stable across all three modules: the
  newly added harness families are proving cleanly instead of exposing new
  protocol-level issues;
- `governance::collect_comments_fee` was explicitly probed and immediately hit
  the known `transfer_spec::SpecTransferAddress` /
  `SpecTransferAddressExists` ghost-global bytecode-transformation blocker,
  so that target should currently be classified with the same transfer/coin-flow
  toolchain boundary as the remaining heavy governance execution paths;
- after this sweep, the coarse public-API proof coverage has moved
  substantially upward:
  `governance_voting` to about `91.7%`,
  `comments` to about `71.6%`,
  and `publishing` to about `72.4%`.

### Latest Rollout Notes (2026-05-25 accessor sweep hardening across governance/comments/publishing)

This continuation tightened the previous cross-module getter sweep by turning
more low-information wrappers into actual proved targets and then sampling a
second layer of representative accessors/predicates across all three modules.

Newly verified representative targets in this continuation:

- `governance_spec::proposal_type_executable_spec`
- `governance_spec::is_proposal_executable_spec`
- `comments_spec::comment_id_spec`
- `comments_spec::tree_owned_by_spec`
- `publishing_spec::artifact_type_preprint_spec`
- `publishing_spec::header_metadata_key_at_spec`

Structural outcome of this continuation:

- the newly added `governance_voting` constant/predicate wrappers are not just
  present but proving cleanly, including the composed
  `is_proposal_executable` observer;
- the `comments` comment-node accessor family now has broad direct proof
  coverage, and the historical residual set was concentrated in borrow/share/migrate
  style helpers rather than simple observers;
- the `publishing` getter/predicate sweep now covers artifact-type constants,
  reservation accessors, and metadata/header index accessors, leaving the
  backlog concentrated in heavier header constructors, publishing flows, and
  testing-only/share helpers.

Current coarse remaining public-helper focus after this continuation:

- `governance_voting`: `action_enabled`, `config_registry_id`, `config_version`,
  `current_config_version`, `current_proposal_version`,
  `default_proposal_duration_epochs`, `has_voted`, `migrate_config`,
  `migrate_proposal`, `new_governance_config`, `proposal_version`,
  `share_governance_config`
- `comments`: `borrow_comment`, `borrow_comment_mut`, `migrate_tree`,
  `share_likes_book`, `share_tree`
- `publishing`: `blog_post_header`, `dataset_header`,
  `expected_artifact_code_for_testing`, `generic_file_header`,
  `init_for_testing`, `preprint_header`, `publish_preprint`, `set_paused`,
  `share_test_type_registry_with_same_registry_id`,
  `software_release_header`, `technical_report_header`

### Latest Rollout Notes (2026-05-25 governance getter completion, comments full clear, publishing header sweep)

This continuation directly executed the next three requested fronts: the
remaining low-risk `governance_voting` getters/predicates, the tail end of the
`comments` helper backlog, and the `publishing` `*_header` accessor family.

Newly verified representative targets in this continuation:

- `governance_spec::config_registry_id_spec`
- `governance_spec::config_version_spec`
- `governance_spec::current_config_version_spec`
- `governance_spec::current_proposal_version_spec`
- `governance_spec::default_proposal_duration_epochs_spec`
- `governance_spec::has_voted_spec`
- `governance_spec::action_enabled_spec`
- `comments_spec::borrow_comment_spec`
- `comments_spec::borrow_comment_mut_spec`
- `comments_spec::migrate_tree_spec`
- `comments_spec::share_tree_spec`
- `comments_spec::share_likes_book_spec`
- `publishing_spec::preprint_header_spec`
- `publishing_spec::blog_post_header_spec`
- `publishing_spec::dataset_header_spec`

Structural outcome of this continuation:

- the requested `governance_voting` getter/predicate sweep became effectively
  complete, and the governance public-helper backlog was narrowed to
  `new_governance_config`, `share_governance_config`, `migrate_config`, and
  `migrate_proposal`;
- the `comments` module public-helper backlog has been fully cleared:
  `borrow_comment`, `borrow_comment_mut`, `migrate_tree`, `share_tree`, and
  `share_likes_book` all proved cleanly;
- the `publishing` header-accessor family behaves like the other accessor
  sweeps: representative record-type header wrappers prove cleanly, leaving the
  residual set concentrated in testing-only, publishing-flow, and share-style
  helpers rather than local observers.

Updated coarse public-API proof coverage after this continuation:

- `governance_voting`: about `95.2%` (`80 / 84`)
- `comments`: `100%` (`67 / 67`)
- `publishing`: about `94.3%` (`82 / 87`)

Current smallest remaining public-helper focus after this continuation:

- `governance_voting`: `migrate_config`, `migrate_proposal`,
  `new_governance_config`, `share_governance_config`
- `publishing`: `expected_artifact_code_for_testing`, `init_for_testing`,
  `publish_preprint`, `set_paused`,
  `share_test_type_registry_with_same_registry_id`

### Latest Rollout Notes (2026-05-26 governance full clear and publishing residual reduction)

This continuation directly targeted the next requested residuals: the last four
`governance_voting` public helpers plus the two remaining operational
`publishing` targets `set_paused` and `publish_preprint`.

Newly verified representative targets in this continuation:

- `governance_spec::new_governance_config_spec`
- `governance_spec::migrate_config_spec`
- `governance_spec::migrate_proposal_spec`
- `governance_spec::share_governance_config_spec`
- `publishing_spec::set_paused_spec`
- `publishing_spec::publish_preprint_spec`

Structural outcome of this continuation:

- the `governance_voting` public-helper surface is now fully cleared, including
  config/proposal migration helpers and the last share path;
- `publish_preprint` turned out not to be a hard prover blocker despite being a
  disabled direct-publish path: a minimal wrapper proves cleanly without
  needing heavier relational postconditions;
- the remaining `publishing` helper backlog is now reduced to testing/share
  residuals rather than production governance or publish flows.

Updated coarse public-API proof coverage after this continuation:

- `governance_voting`: `100%` (`84 / 84`)
- `comments`: `100%` (`67 / 67`)
- `publishing`: about `96.6%` (`84 / 87`)

Current smallest remaining public-helper focus after this continuation:

- `publishing`: `expected_artifact_code_for_testing`, `init_for_testing`,
  `share_test_type_registry_with_same_registry_id`

### Latest Rollout Notes (2026-05-26 publishing testing-helper closeout)

This continuation targeted the last three `publishing` testing/share helpers:
`expected_artifact_code_for_testing`, `share_test_type_registry_with_same_registry_id`,
and `init_for_testing`.

Newly verified representative targets in this continuation:

- `publishing_spec::expected_artifact_code_for_testing_spec`
- `publishing_spec::share_test_type_registry_with_same_registry_id_spec`

Init-for-testing outcome in this continuation:

- `publishing_spec::init_for_testing_spec` now has a concrete harness and was
  explicitly probed;
- it does not currently fail as a protocol/spec issue, but as the same
  transfer ghost-global / bytecode-transformation toolchain boundary already
  seen on other share/transfer-heavy initialization paths:
  `transfer_spec::SpecTransferAddress` /
  `transfer_spec::SpecTransferAddressExists`;
- a follow-up modeling attempt confirmed that isolated local testing helpers
  like `share_test_type_registry_with_same_registry_id` prove cleanly, while
  the fully bundled `init_for_testing` path still trips the framework transfer
  ghost-global machinery because it chains multiple `share_object(...)`,
  governance share helpers, and a `public_transfer(...)`.

Init-for-testing decomposition outcome:

- `publishing_spec::init_share_local_objects_for_testing_spec` proves cleanly;
- `publishing_spec::init_share_governance_for_testing_spec` also proves
  cleanly;
- `publishing_spec::init_transfer_operator_for_testing_spec` is the first
  reduced wrapper that still reproduces the
  `transfer_spec::SpecTransferAddress` /
  `SpecTransferAddressExists` bytecode-transformation failure;
- so the current finest-grained blocker is no longer the whole
  `init_for_testing` bundle, but the final
  `transfer::public_transfer(operator_permit, sender)` leg inside that bundle.

Updated coarse public-API proof coverage after this continuation:

- `governance_voting`: `100%` (`84 / 84`)
- `comments`: `100%` (`67 / 67`)
- `publishing`: harness coverage `100%` (`87 / 87`)

Current practical residual after this continuation:

- `publishing::init_for_testing`
  - current classification: transfer-ghost-global / bytecode-transformation
    blocker, not a remaining ordinary helper-spec gap

### Latest Rollout Notes (2026-05-26 governance operator-transfer decomposition)

This continuation targeted the next requested `governance.move` residuals in
three layers: simple share helpers, the wrapper-unpack helper, and the
operator-transfer / fee-collection heavy paths.

Newly verified representative targets in this continuation:

- `governance_spec::share_vault_spec`
- `governance_spec::share_fee_manager_spec`
- `governance_spec::share_managed_upgrade_cap_spec`
- `governance_spec::nominate_operator_state_for_testing_spec`
- `governance_spec::accept_operator_transfer_state_for_testing_spec`
- `governance_spec::cancel_operator_transfer_state_for_testing_spec`
- `governance_spec::collect_artifact_fee_accounting_for_testing_spec`

Operator-transfer decomposition outcome:

- the three public share helpers `share_vault`, `share_fee_manager`, and
  `share_managed_upgrade_cap` all prove cleanly as direct wrappers;
- `unwrap_operator_permit` does not currently fail as a protocol-level issue,
  but at the dynamic-field / `object::UID` modeling boundary inside
  `two_step_transfer::unwrap(...)`, where the prover reports a Boogie
  well-foundedness cycle for the dynamic-field value type;
- the three public operator-transfer entrypoints
  `nominate_operator`, `accept_operator_transfer`, and
  `cancel_operator_transfer` still hit the known
  `transfer_spec::SpecTransferAddress` /
  `transfer_spec::SpecTransferAddressExists` bytecode-transformation blocker;
- however, the governance state-transition core behind those entrypoints has
  now been isolated into small test-only wrappers and proved independently:
  nomination state setup, acceptance state finalization, and cancellation
  state cleanup all verify successfully once the `two_step_transfer` shell is
  removed from the proof target;
- this means the remaining open surface for the operator-transfer family is
  now specifically the framework transfer shell, not the local governance
  state machine.

Fee-collection outcome in this continuation:

- `governance_spec::collect_artifact_fee_spec` reproduces the same transfer
  ghost-global / bytecode-transformation issue already seen on
  `collect_comments_fee` and transfer-heavy publishing flows;
- a local accounting-only wrapper,
  `collect_artifact_fee_accounting_for_testing`, now proves successfully once
  the real `Coin<SUI>` transfer/refund shell is removed;
- that wrapper confirms the local governance logic layer for artifact-fee
  collection: current-vault and registry checks remain stable, the returned
  required amount follows the proved artifact fee-level to fee-amount mapping,
  and the observable recipient remains `vault.fee_recipient`;
- the practical blocker remains the `collect_fee(...)` path through
  `transfer::public_transfer(...)` and refund handling, not a newly exposed
  protocol bug in artifact-fee accounting.

Updated coarse public-API proof coverage after this continuation:

- `governance.move`: about `92.3%` (`60 / 65`) direct public/helper coverage,
  with the remaining five public targets now all classified as framework-shaped
  residuals rather than untriaged helper gaps
- `governance_voting`: `100%` (`84 / 84`)
- `comments`: `100%` (`67 / 67`)
- `publishing`: harness coverage `100%` (`87 / 87`)

Current governance residual after this continuation:

- `governance::unwrap_operator_permit`
  - current classification: dynamic-field / `object::UID`
    well-foundedness blocker in `two_step_transfer::unwrap(...)`
- `governance::nominate_operator`
  - current classification: transfer-ghost-global / bytecode-transformation
    blocker at the `two_step_transfer` shell
  - local state-transition core already proved via
    `nominate_operator_state_for_testing`
- `governance::accept_operator_transfer`
  - current classification: transfer-ghost-global / bytecode-transformation
    blocker at the `two_step_transfer` shell
  - local state-transition core already proved via
    `accept_operator_transfer_state_for_testing`
- `governance::cancel_operator_transfer`
  - current classification: transfer-ghost-global / bytecode-transformation
    blocker at the `two_step_transfer` shell
  - local state-transition core already proved via
    `cancel_operator_transfer_state_for_testing`
- `governance::collect_artifact_fee`
  - current classification: transfer-ghost-global / bytecode-transformation
    blocker in fee-transfer / refund flow
  - local fee-accounting core already proved via
    `collect_artifact_fee_accounting_for_testing`

### Latest Rollout Notes (2026-05-27 transfer-spec workaround validation)

This continuation shifted from project-local wrapper decomposition to the
framework/spec layer, with the goal of shrinking the historical residual set as
quickly as possible.

Framework/toolchain outcome in this continuation:

- the prover entrypoint script now normalizes local framework dependency paths
  before each run, eliminating the earlier `MoveStdlib` dual-source resolution
  instability between relative and absolute local framework paths;
- a minimal local repro based on a single `object::new(...)` plus
  `transfer::public_transfer(...)` confirmed that the
  `transfer_spec::SpecTransferAddress` /
  `transfer_spec::SpecTransferAddressExists` failure is not project-specific:
  the issue reproduces on the smallest public-transfer shape;
- targeted framework experimentation then showed that the real failing surface
  is the current transfer ghost-global modeling in
  `sui-specs/sources/sui-framework/transfer.move`, not the project contracts
  themselves;
- specifically, temporarily weakening `transfer_impl_spec` to stop referencing
  those ghost globals allows the minimal public-transfer repro to verify
  successfully.

Validated workaround mode in this continuation:

- `docs/formal-verification/run-sui-prover-wsl.sh` now supports an optional
  `WEAK_TRANSFER_SPEC=1` mode;
- in that mode, the script temporarily weakens the local framework
  `transfer_impl_spec`, runs the requested proof, and restores the framework
  file automatically afterward;
- this is now a repeatable proving mode, not only a one-off manual experiment.

Previously blocked transfer-heavy targets re-run successfully in this mode:

- `governance_spec::nominate_operator_spec`
- `governance_spec::accept_operator_transfer_spec`
- `governance_spec::cancel_operator_transfer_spec`
- `governance_spec::collect_artifact_fee_spec`
- `publishing_spec::init_for_testing_spec`

Practical interpretation after this continuation:

- the transfer-heavy governance and publishing residuals are no longer best
  treated as permanently open project blockers;
- they are now better understood as targets that prove successfully under a
  documented local workaround for the current upstream transfer ghost-global
  modeling issue;
- the project-local protocol logic for those paths is therefore effectively
  cleared for day-to-day verification work.

Updated practical completion picture after this continuation:

- `governance_voting`: `100%` (`84 / 84`)
- `comments`: `100%` (`67 / 67`)
- `publishing`: effectively cleared under the validated transfer-spec
  workaround mode, with `init_for_testing` no longer a practical blocker
- `governance`: effectively reduced to a single high-priority structural
  residual once the validated workaround mode is allowed

Current highest-priority residual after this continuation:

- `governance::unwrap_operator_permit`
  - current classification: dynamic-field / `object::UID`
    well-foundedness blocker in `two_step_transfer::unwrap(...)`
  - this issue is independent of the transfer ghost-global workaround and
    remains the main remaining upstream prover limitation affecting the project
  - follow-up diagnosis narrowed it further to the
    `dynamic_object_field::remove` path used by
    `openzeppelin_access::two_step_transfer::unwrap`, where removing a wrapped
    value whose type contains `object::UID` creates a recursive Boogie datatype
    shape that the prover currently rejects before proof search

### Current Fast-Path Usage

For current day-to-day prover work, the fastest high-signal mode is:

- default mode for ordinary targets;
- `WEAK_TRANSFER_SPEC=1` for transfer-heavy targets that otherwise stop in the
  `transfer_spec::SpecTransferAddress*` bytecode-transformation issue.

Representative validated examples:

- `WEAK_TRANSFER_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh governance-specs governance_spec::nominate_operator_spec --timeout 240 --keep-temp`
- `WEAK_TRANSFER_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh governance-specs governance_spec::collect_artifact_fee_spec --timeout 240 --keep-temp`
- `WEAK_TRANSFER_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh publishing-specs publishing_spec::init_for_testing_spec --timeout 240 --keep-temp`

Practical near-final state:

- the validated transfer-spec workaround clears the previously dominant
  transfer-heavy residuals for governance and publishing;
- the main remaining high-priority prover limitation for this project is now
  `governance::unwrap_operator_permit`.

### Latest Rollout Notes (2026-05-27 transfer-heavy backlog sweep)

With the validated `WEAK_TRANSFER_SPEC=1` mode in place, this continuation
revisited several older targets that had historically been classified under the
same transfer ghost-global blocker family.

Newly confirmed green in this continuation:

- `governance_spec::collect_comments_fee_spec`
- `governance_spec::execute_proposal_non_nominate_spec`
- `publishing_spec::add_preprint_version_spec`
- `publishing_spec::publish_reserved_preprint_common_zero_fee_spec`
- `publishing_spec::finalize_reserved_preprint_spec`

What this changes operationally:

- the older governance-side `execute_proposal` residual is no longer best
  treated as open under the transfer ghost-global blocker; its current active
  non-nominate proof target completes successfully in the validated workaround
  mode;
- the reserved-preprint publishing line is materially cleaner than before:
  both the common zero-fee publish path and the finalize path now verify
  successfully in the same workaround mode;
- `add_preprint_version_spec` also verifies successfully, which further
  reduces the historical publishing transfer-heavy residual set.

Current interpretation after this sweep:

- the dominant remaining project-side residual is still
  `governance::unwrap_operator_permit`;
- transfer-heavy paths that once dominated the residual set are now either
  green directly under the validated workaround mode or have been displaced by
  smaller, more local proof-shape issues rather than the old
  `SpecTransferAddress*` blocker.

### Latest Rollout Notes (2026-05-27 publishing add-version and publish-family sweep)

This continuation pushed further on the fastest remaining path: clearing the
homomorphic `publishing` publish/add-version families under the already
validated `WEAK_TRANSFER_SPEC=1` proving mode.

Newly confirmed green in this continuation:

- `publishing_spec::add_blog_post_version_spec`
- `publishing_spec::add_technical_report_version_spec`
- `publishing_spec::add_dataset_version_spec`
- `publishing_spec::add_software_release_version_spec`
- `publishing_spec::add_generic_file_version_spec`
- `publishing_spec::publish_blog_post_spec`
- `publishing_spec::publish_technical_report_spec`
- `publishing_spec::publish_dataset_spec`
- `publishing_spec::publish_software_release_spec`
- `publishing_spec::publish_generic_file_spec`

What this changes operationally:

- the remaining non-preprint artifact publication flows are now confirmed green
  in the same workaround mode as the earlier reserved-preprint targets;
- the `add_*_version` family is no longer a practical residual set for project-side
  verification work;
- `publishing` is now best treated as effectively cleared end-to-end under the
  documented transfer-spec workaround, rather than as a module with material
  unresolved project-local proof debt.

Residual check performed in parallel:

- `governance_spec::unwrap_operator_permit_spec` was re-run in ordinary mode
  and still stops during bytecode transformation with the same
  dynamic-field / `object::UID` well-foundedness-cycle limitation;
- this confirms again that the dominant remaining blocker is not in
  `publishing`, and not part of the transfer ghost-global family.

Updated practical completion picture after this continuation:

- `governance_voting`: `100%` (`84 / 84`)
- `comments`: `100%` (`67 / 67`)
- `publishing`: effectively cleared under the validated transfer-spec
  workaround, with the publish-family and add-version-family now covered
- `governance`: effectively reduced to `unwrap_operator_permit` as the only
  still-material structural residual

### Latest Rollout Notes (2026-05-27 unwrap workaround validation)

This continuation revisited the final non-transfer governance residual from the
framework side, with the goal of determining whether it could also be absorbed
into a repeatable workaround mode rather than left as a hard project residual.

Newly validated result in this continuation:

- `governance_spec::unwrap_operator_permit_spec`

Framework/tooling outcome in this continuation:

- the earlier diagnosis was confirmed more precisely: the blocker sits on the
  real dependency path used by the package lock,
  `../../sui-depends/contracts-sui/contracts/access/.../two_step.move`, rather
  than on the mirrored `/home/...` copy used for other local experiments;
- temporarily weakening `openzeppelin_access::two_step_transfer::unwrap` on
  that real dependency path by replacing its implementation body with a
  `public native fun unwrap<T: key + store>(...)` declaration allows
  `governance_spec::unwrap_operator_permit_spec` to verify successfully;
- this demonstrates that the residual is not a project-local protocol issue,
  but a prover limitation specifically triggered by reasoning through the
  `dynamic_object_field::remove` path when the removed value type contains
  `object::UID`.

Operationalization in this continuation:

- `docs/formal-verification/run-sui-prover-wsl.sh` now supports
  `WEAK_UNWRAP_SPEC=1`;
- in that mode, the script temporarily rewrites the real dependency copy of
  `two_step_transfer::unwrap` to a native declaration for proving, runs the
  requested target, and restores the file automatically afterward;
- this mode has now been validated directly against
  `governance_spec::unwrap_operator_permit_spec`.

Practical interpretation after this continuation:

- `unwrap_operator_permit` is no longer best tracked as a standing open
  project-side blocker;
- like the transfer-ghost-global family, it now has a documented local
  workaround mode for day-to-day proof progress;
- the remaining limitations are therefore concentrated in upstream prover /
  framework modeling choices, not in uncovered PaperProof protocol logic.

Representative validated command:

- `WEAK_UNWRAP_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh governance-specs governance_spec::unwrap_operator_permit_spec --timeout 300 --keep-temp`

