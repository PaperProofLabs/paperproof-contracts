<!--
Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available
-->

# Formal Specification Checklist Review

This document reviews `Formal-Specification-Checklist.md` from a protocol and
application-semantics perspective, intentionally setting aside the exact shape
of the current Move implementation.

The goal is to identify:

1. checklist items that are too implementation-specific, too strong, too weak,
   or otherwise not ideal as protocol-level formal requirements;
2. important protocol properties that are currently missing;
3. priority shifts that would better reflect PaperProof's actual safety and
   product-critical semantics.

---

## Overall Assessment

The current checklist is already strong and directionally correct. It covers
most of the obvious safety and integrity surfaces across publishing,
governance, comments, and cross-module bindings.

However, viewed as a protocol-level specification rather than a spec for the
current code layout, it has three weaknesses:

1. some items are written too close to today's implementation details rather
   than durable protocol properties;
2. some items point in the right direction but are narrower than the actual
   protocol guarantee that matters;
3. several protocol-critical properties are not yet stated explicitly,
   especially around artifact identity, version-history continuity, immutable
   content binding, reservation consumption, and cross-registry isolation.

---

## Items That Should Be Revised

### 1. `P0-145` is too strong and too implementation-specific

Current text:

- `init(...)` always creates exactly one root, one type registry, and one type
  index for each built-in artifact type.

Issue:

- "exactly one" is too global and too deployment-script-specific.
- For protocol-level reasoning, the important property is that one invocation
  of canonical initialization creates one self-consistent deployment set.
- Upgrades, tests, future migrations, or helper environments can make absolute
  global uniqueness too rigid.

Suggested direction:

- A canonical `init(...)` creates one internally consistent root, registry, and
  one type index per built-in artifact type for that deployment.
- Canonical publishing/governance paths only operate against that deployment's
  bound objects.

### 2. `P1-58` is too policy-specific

Current text:

- `fee_level(...)` defaults to `FREE` when no explicit fee level is stored for
  a fee key.

Issue:

- This is a product/governance default, not necessarily a protocol invariant.
- The protocol-critical requirement is determinism and safety, not that the
  default must be `FREE` forever.

Suggested direction:

- When no explicit fee level is stored, fee resolution is deterministic and
  cannot bypass protocol accounting or authorization logic.

### 3. `P0-67` is more implementation detail than protocol guarantee

Current text:

- Creating a proposal always records the proposer stake as a first `YES` vote
  in both `votes` and `yes_locked_balance`.

Issue:

- The deeper protocol requirement is correct proposer stake locking and
  accounting.
- Requiring it to be represented specifically as the first `YES` vote may
  unnecessarily constrain future governance design.

Suggested direction:

- Proposal creation always locks proposer stake in a way that is consistently
  counted toward the proposal outcome and later claimable by the proposer.

### 4. `P0-86` is slightly too narrow

Current text:

- A passed executable proposal that is executed after the execution validity
  window becomes `EXPIRED` instead of mutating protocol state.

Issue:

- The important invariant is that expired executable proposals cannot produce
  governance effects after expiry.
- Whether the call aborts or transitions to an `EXPIRED` terminal state is a
  design choice.

Suggested direction:

- After execution expiry, no executable proposal may successfully cause any
  governance mutation; it must either abort or move to a non-executed terminal
  expired state.

### 5. `P0-127` is structurally useful but semantically incomplete

Current text:

- `like_count` equals the number of addresses currently stored in the likes
  table.

Issue:

- This captures data-structure consistency but not the full protocol meaning of
  likes.
- PaperProof likes are address-scoped preference records gated by minimum PPRF
  balance, not coin-object-specific likes.

Suggested direction:

- Keep the current item, but add explicit address-level uniqueness semantics:
  the like state is keyed only by address, and splitting/merging coin objects
  cannot create multiple simultaneous likes for one address.

### 6. `P1-139` and `P1-140` are weaker than they could be

Issue:

- They check event/post-state alignment for a couple of fields, which is good.
- But PaperProof relies heavily on event-driven indexing and reconstruction.
- More useful protocol-level event properties should focus on whether emitted
  identity fields are sufficient for deterministic off-chain reconstruction.

Suggested direction:

- Strengthen event specs toward indexability and ambiguity prevention, not only
  single-field equality.

### 7. `P2-186` has relatively low formal-value density

Current text:

- Typed version records preserve their type-specific user fields without field
  order ambiguity.

Issue:

- "field order ambiguity" is closer to schema/ABI/documentation quality than to
  high-value protocol correctness.
- It is not wrong, but it is low-priority compared with more important
  invariants still missing.

Suggested direction:

- Lower priority further, or replace with stronger schema-consistency and
  immutable-content semantics.

---

## Important Missing Properties

### 1. Missing artifact-code uniqueness requirement

The checklist has determinism and prefix separation, but it does not explicitly
state:

- within one deployment and one artifact-type namespace, distinct series must
  not share the same `artifact_code`.

Why it matters:

- PaperProof uses artifact codes as visible identity handles.
- This is especially critical for preprint reserve/finalize and stamped PDF
  workflows.

Suggested additions:

- artifact-code uniqueness within one deployment
- reservation-derived code uniqueness across distinct reserved series IDs

### 2. Missing strong version-chain continuity properties

There are good add-version items, but the version-history model is not fully
specified.

Missing aspects:

- `current_version == length(version_ids)`
- `version_ids` contains no duplicates
- `previous_version_id` links form a continuous append-only chain
- no cycles can arise in version ancestry
- the typed version header's `version` matches the series position

Why it matters:

- Verifiable version evolution is one of PaperProof's core protocol values.

### 3. Missing historical authorship integrity requirements

The checklist focuses mainly on current owner authority, but not enough on the
boundary between owner control and historical authorship.

Missing aspects:

- owner changes do not rewrite historical version authorship
- add-version authority is governed by current series ownership, not by
  retroactive rewrites of prior authors
- every created version header records the actual publishing sender for that
  version

### 4. Missing reservation single-consumption semantics

Current checklist covers reserve/finalize identity continuity, but not explicit
single-use consumption.

Missing aspects:

- one reservation cannot be finalized twice
- successful finalize consumes reservation authority irreversibly
- no stale valid reservation should remain after successful finalize

Why it matters:

- This is one of the most important preprint-specific correctness properties.

### 5. Missing statement that reserved finalize is the only legal preprint path

The current checklist says:

- direct preprint publish always aborts

But the stronger protocol-level statement should be:

- preprint series can only be created through the reserve/finalize path
- no alternate official entrypoint may create a canonical preprint series

This is more robust than focusing on one aborting function.

### 6. Missing immutable historical content-binding properties

The checklist validates content fields on creation, but does not say enough
about immutability afterward.

---

## Execution Notes From Current Sui-Prover Rollout

The current rollout is intentionally translating review-driven checklist items
into two prover-friendlier shapes:

1. local `spec_only` predicates that stay inside the spec package and avoid
   direct dependence on non-public internal helpers;
2. postconditions on public entrypoints and public helper surfaces that expose
   protocol-relevant observable effects.

For the current pass, the following review-driven items are being realized in
that style:

- `P0-201`: represented as deterministic reservation-code-to-series binding and
  public artifact-code shape cut points, rather than as an over-strong global
  uniqueness proof over all deployments.
- `P0-202`: represented through reserve/finalize public-path continuity and the
  fact that finalize consumes the only public reservation object accepted by the
  canonical path.
- `P0-203`: represented through the direct-preprint-publish abort path plus the
  reserved preprint finalize entrypoint as the only canonical public creation
  surface for preprint series.
- `P0-206`: represented through public entrypoint postconditions that owner,
  status, and metadata updates preserve version-head consistency and do not
  expose any public path that rewrites historical version-chain shape.
- `P1-209`: represented as metadata-shape and bounded-extension cut points on
  public update/publish paths; semantic non-override remains a protocol review
  requirement even where it is not yet a fully local prover fact.
- `P1-210`: represented through owner-transfer postconditions that update only
  current owner bindings while preserving series/version continuity and comment
  tree attachment.

Two operating rules have emerged and should remain in force:

1. Do not create spec targets for restricted-visibility internal helpers in
   other modules; this introduces noisy failures and does not scale.
2. Prefer public accessor-based protocol facts over implementation-structure
   facts whenever the two differ in prover cost.

Missing aspects:

- historical version content bindings are immutable
- later series metadata changes cannot rewrite historical content references
- governance actions cannot mutate historical version content fields

Why it matters:

- PaperProof's value depends on durable binding between chain identity and
  referenced content.

### 7. Missing explicit metadata non-override rule

The current checklist constrains metadata size, key uniqueness, and bounds, but
not its semantic boundary.

Missing aspect:

- metadata extensions are supplementary and cannot override canonical typed
  fields such as title, authors, abstract, version number, filename, etc.

Why it matters:

- Otherwise future indexers and UIs may face ambiguity about whether metadata
  should supersede typed fields.

### 8. Missing artifact lifecycle vs comments lifecycle relationship

The checklist defines comments-tree binding, but not the policy boundary
between artifact status and comment status.

Missing question:

- if an artifact series becomes hidden/locked, must its official comments tree
  remain independent, or must it be constrained?

This needs one of two protocol-level answers:

- explicit independence; or
- explicit coupling.

Right now that semantic space is largely uncovered.

### 9. Missing blob-comment content immutability semantics

There are structural validations for blob comments, but not enough semantic
constraints.

Missing aspects:

- blob comment references are immutable once created
- comment content mode does not change after creation
- blob-preview content cannot masquerade as later-editable canonical body state

### 10. Missing stronger cross-registry isolation requirements

The checklist does include some registry-binding rules, but there should be a
more systematic closure property:

- governance config, vault, fee manager, action executor cap, proposal, root,
  registry, comments tree, and likes book from different registries cannot be
  mixed into any successful official protocol path.

Why it matters:

- This is crucial for multiple deployments, future upgrades, and official vs
  non-official instances.

### 11. Missing systematic irreversible-terminal-state rules

Some terminality is covered in isolated places, but it should be generalized.

Missing aspects:

- executed proposals never become active/passed later
- expired proposals never later become executed/passed
- deleted comments never become active/hidden later
- finalized published history never shrinks or rewinds

### 12. Missing stronger historical non-retroactivity for type governance

The checklist says artifact-type governance affects future publishing
eligibility, which is good.

But it should also explicitly cover:

- disabling a type does not invalidate historical series
- re-enabling a type does not rewrite historical state
- governance type changes cannot alter existing series identity or prior typed
  records

### 13. Missing index-reconstructability requirements

Because PaperProof is designed for explorer, app, and indexer reconstruction,
the protocol should state stronger event sufficiency properties.

Missing aspects:

- canonical events plus canonical objects are sufficient to reconstruct series,
  version, comment, and likes relationships without ambiguity
- no official event path leaves canonical identity underdetermined

### 14. Missing owner-transfer boundary rules beyond control rights

The checklist does mention comments-tree owner alignment, but more is needed.

Missing aspects:

- owner transfer does not rewrite historical comment authorship
- owner transfer does not rewrite historical like authorship
- owner transfer only changes future control rights

### 15. Missing complete paused-scope semantics

The checklist covers paused publishing entrypoints, but not the entire protocol
surface.

Missing aspects:

- whether paused affects add-version
- whether paused affects comments creation
- whether paused affects governance execution
- whether paused affects vote claims

The protocol should explicitly define the pause boundary, not merely a subset
of publishing flows.

---

## Recommended Priority Changes

### Should move up in priority

The following are important enough to be considered P0 or high P1:

1. reservation single-consumption semantics
2. version-chain continuity and no-duplication
3. immutable historical content binding
4. stronger cross-registry isolation
5. metadata cannot override canonical typed fields

### Could move down

The following are lower-value than the missing invariants above:

1. `P2-186` typed field order ambiguity
2. narrow event-order details that do not affect canonical state
   reconstructability

---

## Ten High-Value Additions

If the checklist is revised, these ten additions would provide the biggest
improvement:

1. Artifact-code uniqueness within a deployment and artifact-type namespace.
2. A preprint reservation can be finalized at most once.
3. Preprint series can only be created through reserve/finalize.
4. `current_version == length(version_ids)` for every live series.
5. `version_ids` is append-only, duplicate-free, and ancestry-consistent.
6. Historical version content fields are immutable after creation.
7. Metadata extensions cannot override canonical typed fields.
8. Owner transfer does not rewrite historical author/comment/like identity.
9. Objects from different registries cannot be mixed into a successful official
   path.
10. Pause semantics are complete and explicit across publishing, versioning,
    comments, governance execution, and claims.

---

## Conclusion

The current checklist has no major conceptual failure. Its direction is good.

The main refinement needed is to move slightly away from current
implementation-shaped statements and toward stronger protocol-shaped
statements, especially around:

- artifact identity uniqueness
- reservation consumption
- version-history continuity
- immutable historical bindings
- metadata semantic boundaries
- cross-registry isolation
- paused-scope definition

In short:

- the checklist is solid;
- it is somewhat implementation-leaning;
- the most important missing themes are identity uniqueness, append-only
  history, immutable content binding, and stronger closure across the official
  deployment boundary.

---

## Execution Notes From Current Sui-Prover Rollout

The current formal-verification branch has now hit two practical boundaries
that should guide further work:

1. `sui move build` is not an appropriate validator for these spec packages.
   It treats `#[spec(...)]` and `#[spec_only]` as ordinary Move attributes and
   reports many false-positive "unknown attribute" warnings. It is still useful
   only as a coarse syntax sanity check when interpreted carefully.

2. Spec modules must not try to directly call internal helper functions from
   other modules. In practice, this means we should avoid new targets such as:
   - internal publishing helpers like `publish_common`,
     `publish_reserved_preprint_common`, `add_version_common`
   - internal comments helpers
   - internal governance-voting validation helpers

   Those attempts produce restricted-visibility errors and are not viable as a
   long-term prover pattern.

### Preferred rollout pattern

For the next wave, favor this shape:

1. express stronger protocol invariants as local spec-only predicates;
2. attach them to public entrypoints and public helper surfaces only;
3. use public accessors to describe post-state relationships;
4. avoid direct targetting of non-public implementation helpers unless the
   underlying contract surface is explicitly made prover-visible later.

### Implication for P0-201 through P1-210

The new review-driven properties are still valid, but many of them should be
implemented as:

- stronger postconditions on public publish / add-version / transfer /
  governance-execution functions; and
- cross-object binding predicates built only from public accessors,
  rather than direct specs on internal helper bodies.
