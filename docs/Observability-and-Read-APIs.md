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

- canonical root, registry, comments tree factory cap, and type-index object IDs
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

- root IDs: governance vault, fee manager, type registry, comments tree factory
  cap
- artifact type getters and `artifact_type_name`
- type registry state: enabled flag, schema version, index object ID
- `get_series_id_by_code`
- series owner, type, code, current version, current version ID
- series version IDs and comments tree ID
- series metadata count, key, and value getters
- typed record header getters
- typed record header metadata count, key, and value getters
- typed record field getters

`TypeRegistry` is the source of truth for `artifact_type -> TypeIndex`.
`TypeIndex` is the source of truth for `artifact_code -> ArtifactSeries ID`.
Version metadata is immutable after the version record is created. Series
metadata can be replaced by the series owner, and successful updates emit
`ArtifactSeriesMetadataUpdatedEvent`.

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

The publishing root creates and records one official `TreeFactoryCap` during
initialization. First-publication flows use that cap to create the official
per-series `CommentsTree`.

The like event names still include `Paper` for compatibility with the current
comments module naming, but the tree target is now generalized:

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
- like count and per-address like state
- tree factory cap ID
- tree factory cap registry ID

Official comments binding is determined by
`ArtifactSeries.comments_tree_id`. Official comments tree creation is bounded by
the shared `TreeFactoryCap` recorded on `PaperProofRoot`.

Replies can only be added under active comments. Hidden or deleted comments
remain readable through getters, but they cannot continue receiving child
comments.

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

Publishing-specific governance actions use a one-time
`GovernanceActionTicket`.

The ticket is not created during voting. It is created only when a passed
executable proposal is consumed by
`governance_voting::consume_executable_proposal_action`.

The resulting transaction also emits `ProposalExecutedEvent`. Off-chain systems
should treat that event plus the corresponding publishing/governance state
event as the complete execution trace.

## Practical Indexing Guidance

Indexers should persist:

- package IDs by release
- root object IDs
- `TypeRegistry` object ID
- `FeeManager` object ID
- `TreeFactoryCap` object ID
- every `TypeIndex` object ID
- artifact code to series mapping
- series current version and comments tree ID
- series and version metadata extension key/value pairs
- proposal lifecycle events
- artifact type activation and fee events

Frontends should use getters for current canonical state and events for
activity timelines.
