# PaperProof Contracts Observability and Read APIs

This document summarizes the current event and getter surface.

## Publishing Events

The publishing package now emits artifact-level events:

- `PaperProofRootCreatedEvent`
- `TypeRegistryCreatedEvent`
- `TypeIndexCreatedEvent`
- `ArtifactPublishedEvent`
- `ArtifactVersionAddedEvent`
- `ArtifactStatusChangedEvent`
- `ArtifactSeriesMetadataUpdatedEvent`
- `ArtifactTypeStatusChangedEvent`
- `ProtocolPausedChangedEvent`

These events let indexers observe:

- canonical root, registry, and type-index object IDs
- first publication of an `ArtifactSeries`
- typed version additions
- current series status changes
- series metadata updates
- artifact type enable/disable changes
- pause/unpause changes

The canonical publishing event surface is artifact-oriented.
Version-added events include the new version's content hash, Walrus blob ID,
and content type so event-only indexers can build version timelines without
loading every version object immediately.

## Publishing Getters

Important current publishing getters include:

- root IDs: governance vault, fee manager, and type registry
- artifact type getters and `artifact_type_name`
- type registry state: enabled flag, schema version, index object ID
- series owner, type, code, current version, current version ID
- series version IDs and comments tree ID
- series metadata count, key, and value getters
- typed record header getters
- typed record header metadata count, key, and value getters
- typed record field getters

`TypeRegistry` is the source of truth for artifact type activation and the
type-index marker object. `TypeIndex` is no longer written during
first-publication and is not the source of truth for
`artifact_code -> ArtifactSeries ID`. Indexers should rebuild that mapping from
`ArtifactPublishedEvent`, whose `series_id` and `artifact_code` fields are the
canonical event pair.
Version metadata is immutable after the version record is created. Series
metadata can be replaced only by the series owner while the series is `ACTIVE`,
and successful updates emit `ArtifactSeriesMetadataUpdatedEvent`.

## Comments Events

The comments package emits:

- `TreeCreatedEvent`
- `CommentAddedEvent`
- `TreeStatusChangedEvent`
- `CommentStatusChangedEvent`
- `TreeOwnerTransferredEvent`
- `PaperLikedEvent`
- `PaperUnlikedEvent`
- `CommentsTreeMigratedEvent`

The publishing root creates and embeds one official `TreeFactoryCap` during
initialization. First-publication flows borrow that internal capability to
create the official per-series `CommentsTree` and its paired `LikesBook`.

The like event names still include `Paper` for compatibility with the current
comments module naming, but likes are stored in the independent `LikesBook`.
Like events include both the comments tree ID and the likes book ID, and the
target is generalized:

- `target_series_id`
- `target_artifact_type`
- `target_key`

## Comments Getters

Important comments getters include:

- tree version
- registry ID
- owner
- target series ID
- target artifact type
- target key
- root comment ID
- total comments
- next comment ID
- tree status
- max on-chain comment bytes
- max comment depth
- comment fields
- likes book ID
- likes book registry, comments tree, target series, and target type
- like count and per-address like state on the likes book
- tree factory cap registry ID

Official comments binding is determined by
`ArtifactSeries.comments_tree_id`. Official like binding is determined by
`ArtifactSeries.likes_book_id`. Official comments tree and likes book creation
is bounded by the root-embedded `TreeFactoryCap`.

Replies can only be added under active comments. Hidden or deleted comments
remain readable through getters, but they cannot continue receiving child
comments.

Comment status uses the following policy:

- the root comment is structural and its status is immutable
- `DELETED` is final and cannot be restored by the author or tree owner
- a comment author can delete their own non-deleted comment
- the tree owner can switch non-deleted comments between `ACTIVE` and `HIDDEN`
- the tree owner can delete non-deleted comments
- a comment author cannot reactivate a comment hidden by the tree owner

Indexers should still use `ArtifactSeries.comments_tree_id` and
`ArtifactSeries.likes_book_id` as the canonical bindings. With the factory cap
embedded in `PaperProofRoot`, ordinary callers cannot create official-looking
trees through a shared factory object, but the series object remains the
clearest source of truth for consumers.

## Governance Events

Governance core emits:

- `GovernanceVaultCreatedEvent`
- `FeeManagerCreatedEvent`
- `GovernanceConfigBoundEvent`
- `OperatorNominatedEvent`
- `OperatorTransferAcceptedEvent`
- `OperatorTransferCancelledEvent`
- `FeeRecipientChangedEvent`
- `FeeCollectedEvent`
- `CommentsFeeLevelChangedEvent`
- `ArtifactFeeLevelChangedEvent`
- `UpgradeAuthorityChangedEvent`
- `DirectAuthorityModeChangedEvent`
- `ManagedUpgradeCapRegisteredEvent`
- `ManagedUpgradeAuthorizedEvent`
- `ManagedUpgradeCommittedEvent`
- `GovernanceVaultMigratedEvent`

Permission and parameter-change events include old and new values where the
previous value is protocol-relevant. Fee collection emits `FeeCollectedEvent`
with registry, fee key, payer, recipient, and amount.
`GovernanceConfigBoundEvent` records the one canonical voting config bound to
the vault; consumers should treat proposal execution from any unbound config as
non-canonical.

Governance voting emits:

- `GovernanceConfigCreatedEvent`
- `ProposalCreatedEvent`
- `VoteCastEvent`
- `ProposalFinalizedEvent`
- `ProposalExecutedEvent`
- `ProposalExpiredEvent`
- `VoteClaimedEvent`
- `GovernanceConfigMigratedEvent`
- `ProposalMigratedEvent`
- `ProposalCreationPausedChangedEvent`
- `ProposerThresholdChangedEvent`
- `ProposalDurationChangedEvent`
- `GovernanceActionStatusChangedEvent`

Proposal lifecycle events include `registry_id` so indexers can safely handle
multiple deployments or test environments. Execution events also include the
account that submitted the execution transaction.
`GovernanceConfigCreatedEvent` includes `governance_config_id`, matching the
config id bound on the vault.

## Governance Read Surface

The governance package exposes getters for:

- vault version
- governance authority
- upgrade authority
- active operator and epoch
- pending operator transfer state
- fee recipient
- fee collection events
- comments fee level in `FeeManager`
- artifact fee level and amount by `artifact_type`
- artifact fee level and amount by `artifact_type`
- fee manager registry binding

The voting layer exposes getters for:

- governance config version
- total supply
- proposer threshold
- proposal duration
- proposal creation paused flag
- next proposal ID
- active proposal ID
- proposal object ID lookup
- proposal type and action type
- yes/no votes
- locked vote values
- proposal status and executed flag
- proposal epoch window and execution expiry
- per-address vote and claim state
- governance action constants
- whether a known governance action is enabled

Governance config initialization is restricted to the vault's governance
authority or recorded upgrade authority. Proposal creation also validates known
executable action payloads before voting begins, including fee levels, boolean
fields, nonzero addresses, direct-authority modes, proposal duration bounds,
and action-enable targets.

## Proposal Ticket Observability

Publishing-specific and fee-manager governance actions use official executor
entrypoints backed by the `GovernanceActionExecutorCap` embedded in
`PaperProofRoot`.

A one-time `GovernanceActionTicket` is not created during voting. It is created
only inside the execution transaction after the official executor cap has been
checked against the official `GovernanceVault`.

The resulting transaction also emits `ProposalExecutedEvent`. Off-chain systems
should treat that event plus the corresponding publishing/governance state
event as the complete execution trace.

## Practical Indexing Guidance

Indexers should persist:

- package IDs by release
- root object IDs
- `TypeRegistry` object ID
- `FeeManager` object ID
- every `TypeIndex` object ID
- artifact code to series mapping
- series current version, comments tree ID, and likes book ID
- series and version metadata extension key/value pairs
- proposal lifecycle events
- artifact type activation and fee events
- proposal object IDs from `GovernanceConfig.proposal_id_to_object`

Frontends should use getters for current canonical state and events for
activity timelines.
