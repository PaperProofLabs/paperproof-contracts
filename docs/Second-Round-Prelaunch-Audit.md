# PaperProof Second-Round Prelaunch Audit

This document records the second-round prelaunch security review of the current
PaperProof Sui Move contracts.

The review covered the current `publishing`, `comments`, and `governance`
packages after the first-round fixes and follow-up hardening work.

## Scope

The reviewed protocol surface includes:

- artifact series publication and version addition
- artifact type enablement, activation, and fee configuration
- governance vault, fee manager, and `PPRF` governance voting
- comments tree creation, comment publishing, comment hiding/deletion
- like/unlike as `PPRF` holding proof
- metadata extension fields on series and versions
- events used by frontends, indexers, scoring, and future airdrop systems

The review assumed that attackers can call all public functions and can pass
same-type but non-official objects wherever the function signature allows it.

## Executive Summary

No remaining P0 or P1 contract-level issue was found in the reviewed state.

The current contracts enforce official object bindings on the critical official
state-changing paths:

- publishing and add-version paths verify the official `TypeRegistry`
  object ID recorded in `PaperProofRoot`
- publishing fee paths verify the official `GovernanceVault` and `FeeManager`
  object IDs recorded in `PaperProofRoot`
- comments fee paths verify the `CommentsTree`-bound vault and fee manager IDs
- executable governance paths verify official proposal/config/vault/cap
  bindings before consuming a proposal
- comments tree discovery no longer depends on a standalone tree-created event
- public governance object constructors no longer emit constructor-style
  discovery events

The main remaining risk is not that fake objects can mutate official state.
The remaining risk is that fake objects can still produce non-official runtime
events, such as comments, likes, proposals, votes, and claims. Frontends,
indexers, scoring systems, and future airdrop systems must treat events as
candidate data only and must filter them through canonical official object
bindings.

## Severity Summary

- P0: none found
- P1: none found
- P2: chain-off/indexer filtering risk remains if clients trust bare events
- P3: documentation, UX, and testing improvements

## P2-1: Bare Runtime Events Must Be Filtered

Severity: P2

Affected areas:

- `comments::add_onchain_comment`
- `comments::add_blob_comment`
- `comments::like_paper`
- `comments::unlike_paper`
- `governance_voting::create_proposal`
- `governance_voting::vote_yes`
- `governance_voting::vote_no`
- `governance_voting::claim_locked_tokens`
- governance proposal finalization and execution events

Attack or failure scenario:

An attacker can create non-official objects and produce non-official runtime
events. For example:

- create a fake comments tree and emit comment-like activity against it
- create a fake governance config and emit proposal/vote-like activity
- create a fake likes book and emit like-like activity

Why the contracts do not fully block this:

This is an intentional composability boundary. The contracts prevent fake
objects from mutating official PaperProof state, but they do not make every
possible same-package object impossible to create or use. This preserves
package composition and parallelism while requiring official clients to filter.

Impact:

Official protocol state is not compromised. However, an indexer, frontend,
scoreboard, or future airdrop process that trusts bare event types can be
polluted by fake activity.

Required integration rule:

Events are candidate observations. Official object bindings are the source of
truth.

Recommended tests:

- fake comments tree events must not enter the official comments index
- fake likes book events must not enter the official likes index
- fake governance config events must not enter the official governance index
- airdrop/scoring jobs must reject events that fail official object binding
  checks

Design classification:

This is a chain-off integration risk, not a currently exploitable official
state mutation bug.

## P2-2: Public Fake Governance Objects Can Still Exist

Severity: P2

Affected areas:

- `governance::new_vault`
- `governance::new_fee_manager`
- `governance_voting::new_governance_config`

Attack or failure scenario:

An attacker can create same-type governance objects that are not the official
objects recorded in `PaperProofRoot` or in the official `GovernanceVault`.

Why the contracts allow this:

These constructors remain public so the package can be composed by the
publishing package during root initialization. The hardening work removed
constructor-style discovery events from these public constructors, and official
state-changing paths verify object ID bindings.

Impact:

Fake objects cannot change official PaperProof state when official entrypoints
are used correctly. The residual risk is chain-off confusion if an external
client discovers governance objects by type alone.

Required integration rule:

Governance discovery must start from official deployment data and canonical
bindings, not from arbitrary same-type shared objects.

Recommended tests:

- fake vault/config/fee manager cannot update official state
- fake governance config proposal events do not enter the official governance
  index

Design classification:

This is a composability and discovery tradeoff. It is acceptable only if
clients use official object ID bindings.

## P3-1: Deprecated Constructor-Style Event Types Remain in ABI

Severity: P3

Affected event types:

- `comments::TreeCreatedEvent`
- `governance::GovernanceVaultCreatedEvent`
- `governance::FeeManagerCreatedEvent`
- `governance_voting::GovernanceConfigCreatedEvent`

Issue:

The event structs remain in the ABI, but the current constructor paths no
longer emit them. This preserves source compatibility while preventing fake
object constructors from creating official-looking discovery events.

Impact:

Older indexer code may incorrectly expect these events.

Recommendation:

Treat these events as deprecated for discovery. Use canonical object bindings
instead.

## P3-2: Repeated Proposal Execution Error Is Safe But Not Semantically Ideal

Severity: P3

Issue:

An already executed proposal is blocked from being executed again. Depending on
the execution path, the observed abort can be the status guard
`E_PROPOSAL_NOT_PASSED` rather than the more precise
`E_PROPOSAL_ALREADY_EXECUTED`.

Impact:

No security issue was found. The behavior is safe, but the error code is less
clear for clients and tests.

Recommendation:

Optionally check `proposal.executed` before the status guard if clearer UX is
desired.

## Official Object Binding Rules

Official clients should build a canonical object map from:

- official package IDs
- official `PaperProofRoot` object ID
- official `TypeRegistry` object ID
- official `GovernanceVault` object ID
- official `FeeManager` object ID
- official `GovernanceConfig` object ID
- official `ArtifactSeries` object IDs
- each series' official `comments_tree_id`
- each series' official `likes_book_id`

The primary trust chain is:

```text
PaperProofRoot
  -> type_registry_id
  -> governance_vault_id
  -> fee_manager_id

GovernanceVault
  -> governance_config_id

GovernanceConfig
  -> proposal_id_to_object

ArtifactPublishedEvent
  -> ArtifactSeries
  -> comments_tree_id
  -> likes_book_id
```

## Event Filtering Rules

### Publishing Events

Accept `ArtifactPublishedEvent` only when it comes from the official publishing
package and can be resolved to an official `ArtifactSeries`.

Use the resulting `ArtifactSeries` as the canonical object for later comment
and like binding.

### Comment Events

For `CommentAddedEvent`, verify:

- `tree_id` equals an official `ArtifactSeries.comments_tree_id`
- the tree target series ID equals the official series ID
- the tree target artifact type equals the series artifact type

Reject comment events for unknown trees.

### Like Events

For `PaperLikedEvent` and `PaperUnlikedEvent`, verify:

- `likes_book_id` equals an official `ArtifactSeries.likes_book_id`
- `tree_id` equals the same series' `comments_tree_id`
- `target_series_id` equals the official series ID

Reject like events for unknown or mismatched likes books.

### Governance Events

For proposal, vote, finalize, execute, expire, and claim events, verify:

- `registry_id` equals the official `PaperProofRoot` ID
- the event belongs to the official `GovernanceConfig`
- `proposal_id` resolves through `GovernanceConfig.proposal_id_to_object`
- the resolved proposal object is the proposal being indexed

Reject governance events from unbound configs.

## Notes for Community Participants

### Publishers

- The `ArtifactSeries` object ID is the canonical on-chain identity of a work.
- Public artifact codes are human-readable identifiers, not the root of trust.
- Series metadata can be updated by the series owner only while the series is
  active.
- Version metadata is immutable after submission.

### Commenters

- Comments are official only when they are posted to the comments tree bound to
  an official `ArtifactSeries`.
- A hidden comment cannot receive replies.
- A deleted comment is final and cannot be restored.
- The root comment is structural and cannot be changed.

### Likers

- A like is a `PPRF` holding proof, not a stake, burn, payment, or lock.
- Like events should not be treated as strong incentive evidence by themselves.
- Official scoring must verify the official likes book binding.

### Voters

- Voting uses locked `PPRF` in the proposal object.
- A voter cannot vote twice on the same proposal.
- Locked tokens can be claimed after proposal closure and cannot be claimed
  twice.
- `PPRF` governance can still have borrowing or short-term concentration risk;
  that risk is intentionally handled outside the current contract layer.

### Indexers and Airdrop Designers

- Never score directly from event type alone.
- Never trust bare comment, like, or governance events.
- Always derive official status from object ID bindings.
- Treat fake-object events as spam unless they resolve through the official
  object graph.

## Test Coverage Reviewed

The current tests cover:

- fake `FeeManager`, fake `GovernanceVault`, and fake `TypeRegistry`
- foreign object and same-registry fake object rejection
- non-owner metadata update rejection
- version metadata immutability by absence of mutation entrypoints
- hidden comment author cannot restore active status
- deleted comment finality
- root comment immutability
- non-authority governance config initialization rejection
- repeated proposal execution rejection
- repeated claim rejection
- repeated vote rejection
- repeated like rejection
- disabled artifact type behavior for publish and add-version
- overlong publish fields
- overlong proposal title and description
- metadata duplicate key, count, key length, and value length
- `MAX_VERSIONS_PER_SERIES`
- pause blocks publish and add-version
- constructor-style fake discovery events are no longer emitted

## Launch Recommendation

Testnet:

Recommended. The current contract state is appropriate for testnet validation,
especially for official object binding and indexer filtering.

Mainnet:

Conditionally recommended after operational checks are complete.

Minimum pre-mainnet requirements:

- deployment manifest records all official package and object IDs
- frontend config uses only official object IDs
- indexer rejects bare fake events
- airdrop/scoring jobs use official object bindings
- full `sui move test` passes for comments, publishing, and governance
- deployment scripts are independently reviewed

## Manual Review Checklist

- Confirm official package IDs and object IDs after deployment.
- Confirm `PaperProofRoot.type_registry_id` matches the official registry.
- Confirm `PaperProofRoot.governance_vault_id` matches the official vault.
- Confirm `PaperProofRoot.fee_manager_id` matches the official fee manager.
- Confirm `GovernanceVault.governance_config_id` matches the official config.
- Confirm every indexed comment tree comes from an official `ArtifactSeries`.
- Confirm every indexed likes book comes from an official `ArtifactSeries`.
- Confirm governance events are tied to proposals in the official config
  mapping.
- Confirm community dashboards label likes as holding proof, not staking.
- Confirm pause semantics are understood: publishing and add-version pause,
  comments and likes remain available by design.
