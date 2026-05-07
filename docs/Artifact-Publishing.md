# PaperProof Artifact Publishing

This document describes the current `publishing` architecture.

`publishing` is the canonical PaperProof artifact publication package for
verifiable digital content.

## Core Model

The main model is:

- `PaperProofRoot`: canonical protocol root for publishing.
- `TypeRegistry`: artifact-type registry and activation state.
- `TypeIndex`: per-type deployment marker kept for registry discovery.
- `ArtifactSeries`: stable identity for one work.
- `MetadataAttribute`: optional key/value extension metadata.
- strong typed `VersionRecord` objects: immutable snapshots for each published
  version.

The core protocol names are `ArtifactSeries` and typed `VersionRecord` objects.

## Built-In Artifact Types

The first built-in artifact types are:

- `preprint`
- `blog_post`
- `technical_report`
- `dataset`
- `software_release`
- `generic_file`

Artifact type IDs are `u8` values owned by
`paperproof_publishing::artifact_types`. `publishing` consumes the module
getters and does not define duplicate type constants.

## Public Codes

Public artifact codes use:

```text
PaperProof-{type}-{epoch6}-{series_id_hex_12}
```

`epoch6` is `tx_context::epoch(ctx) % 1000000`, left-padded to six decimal
digits. `series_id_hex_12` is the first 12 lowercase hexadecimal characters of
the newly created `ArtifactSeries` object ID.

Examples:

- `PaperProof-preprint-000742-a3f91c8b2d4e`
- `PaperProof-dataset-000742-7b20aa91f044`
- `PaperProof-generic_file-000743-d4c3b2a19088`

Artifact codes are not globally sequential and are not allocated through a
shared per-type counter. This is intentional: first-publication transactions do
not write `TypeIndex`, so different users can publish the same artifact type
without contending on a per-type shared object. Chain consumers should treat the
`ArtifactSeries` object ID as the canonical on-chain identity and rebuild
`artifact_code -> ArtifactSeries ID` from `ArtifactPublishedEvent`.

The first version intentionally does not add on-chain author, tag, keyword, or
license indexes. Those belong in events and off-chain indexers for now.

## Root And Registry Boundaries

`PaperProofRoot` stores only protocol-level dependencies:

- `governance_vault_id`
- `fee_manager_id`
- `type_registry_id`
- embedded comments tree factory capability
- protocol version and pause flag

It does not store one hardcoded field per artifact type.

`TypeRegistry` owns artifact type activation state and records the type-index
marker object:

- `artifact_type`
- `index_object_id`
- `enabled`
- `schema_version`
- `min_protocol_version`
- timestamps

This keeps future type expansion from changing the root object layout. Publish
entrypoints read the official `TypeRegistry` object recorded in
`PaperProofRoot.type_registry_id` to validate type enablement, but they do not
write the per-type `TypeIndex`. A registry with the same `registry_id` is not
trusted unless its object ID also matches the root binding.

## Version Records

Every typed record contains a shared header:

- `series_id`
- `artifact_type`
- `version`
- `previous_version_id`
- `author`
- `content_hash`
- `walrus_blob_id`
- `walrus_blob_object_id`
- `content_type`
- `metadata_extensions`
- `status`
- `created_at_ms`

The concrete record types add only necessary type-specific fields:

- `PreprintVersionRecord`
- `BlogPostVersionRecord`
- `TechnicalReportVersionRecord`
- `DatasetVersionRecord`
- `SoftwareReleaseVersionRecord`
- `GenericFileVersionRecord`

## Input Bounds

Publishing entrypoints validate user-supplied text and vector fields before
creating objects:

- title, short text, content hash, Walrus blob ID, and Walrus blob object ID:
  `128` to `256` bytes depending on the field
- content type: `64` bytes
- medium text: `1024` bytes
- long text: `4096` bytes
- authors: at least one author, at most `20`
- keywords: at most `10`
- tags: at most `20`
- each vector item: non-empty and at most `128` bytes
- metadata extensions: fewer than `5` attributes, no duplicate keys
- metadata key: non-empty and at most `64` bytes
- metadata value: fewer than `512` bytes

## Metadata Extensions

`MetadataAttribute` is a small optional extension record:

```move
public struct MetadataAttribute has copy, drop, store {
    key: String,
    value: String,
}
```

`ArtifactSeries.metadata_extensions` stores series-level metadata. It is
optional and may remain empty for most artifacts. First-publication entrypoints
accept `series_metadata_extensions`, and the series owner can later replace the
series metadata while the series status is `ACTIVE` through:

```move
publishing::update_series_metadata_extensions
```

Every successful series metadata update emits
`ArtifactSeriesMetadataUpdatedEvent`.

Locked or hidden series reject metadata-extension updates. This keeps metadata
changes aligned with the visible publication state instead of allowing owners to
continue changing indexer-facing fields after a series has been restricted.

`CommonArtifactHeader.metadata_extensions` stores version-level metadata.
First-publication entrypoints and add-version entrypoints accept
`version_metadata_extensions`. After a version record is created, its metadata
is immutable because version records are immutable shared snapshots and no
version metadata update function is exposed.

## Comments Binding

Publishing automatically creates one official `CommentsTree` and one official
`LikesBook` when an artifact series is first published.

The tree must be created through the official `comments::TreeFactoryCap`
embedded inside `PaperProofRoot`. First-publication entrypoints therefore
require the caller to supply:

- the official `GovernanceVault`
- the official `FeeManager`

The publishing package verifies that these objects match the IDs recorded on
`PaperProofRoot` before collecting fees or creating the tree. The tree factory
capability itself is not a shared object and is not supplied by users. This
prevents a frontend or external caller from creating official-looking comments
trees through a shared factory object, forged fee manager, or foreign vault.

The comments tree is bound to the series, not to a single version:

- `target_series_id`
- `target_artifact_type`
- `target_key`
- `owner`

The likes book is a separate shared object bound to the same series and comments
tree:

- `comments_tree_id`
- `target_series_id`
- `target_artifact_type`

This lets comment writes and like/unlike writes use different shared objects.
It removes the avoidable contention between discussion activity and lightweight
PPRF-holding proof activity on a popular series.

## Pause Boundary

Protocol pause is intentionally scoped to publishing entrypoints that create a
new series or append a new version. Comment and like flows do not read
`PaperProofRoot` or `TypeRegistry` on every call, so normal discussion and
PPRF-holding proof activity can keep their shared-object concurrency. If a
deployment needs to stop comments for a specific series, use the comments-tree
status controls for that tree.

`ArtifactSeries.comments_tree_id` and `ArtifactSeries.likes_book_id` are the
official per-series bindings. The official publishing path creates those
objects from the root-embedded factory capability, and the publishing protocol
recognizes only the tree and likes book recorded on the series.

Owner transfer must be called with the official comments tree. The publishing
entrypoint verifies that the supplied tree ID equals
`ArtifactSeries.comments_tree_id` before synchronizing tree ownership.

## Series Status

An artifact series has a protocol status. Version additions are allowed only
while the series is `ACTIVE`.

Locked or hidden series remain readable, but they cannot receive new
`VersionRecord` objects until governance/operator-controlled status management
returns them to `ACTIVE`.

Version additions are also capped at `168` versions per series. This bounds the
on-chain `version_ids` vector while preserving a long publishing history for a
single work.

Disabled artifact types block both first publication and later version
additions. Re-enabling the type through governance restores the normal
publishing path for active series.

## Fees

Artifact publishing fees are managed by `governance::FeeManager`.

The fee table is:

```text
artifact_type -> fee_level
```

The same type fee applies to both first publication and later version additions.

Type-specific artifact fees are protocol configuration. They are applied
through passed executable governance proposals.

## Governance Activation

Artifact type configuration is governance-gated.

The current executable governance actions for artifact publishing are:

- `ACTION_SET_ARTIFACT_TYPE_ENABLED`
- `ACTION_SET_ARTIFACT_FEE_LEVEL`
- `ACTION_ACTIVATE_ARTIFACT_TYPE`

`ACTION_ACTIVATE_ARTIFACT_TYPE` is the combined path for major type activation:

1. enable the artifact type in `TypeRegistry`
2. set the artifact type fee level in `FeeManager`

`governance_voting` does not import `publishing`. Instead, publishing
entrypoints borrow the official `GovernanceActionExecutorCap` embedded in
`PaperProofRoot`, consume the passed proposal into a one-time
`GovernanceActionTicket`, and apply the publishing-specific state change in the
same transaction. This keeps the dependency direction as:

```text
publishing -> governance
```

and avoids a package dependency cycle.

Executable proposal payloads are validated when proposals are created. The
validation lives in `governance_voting` and uses pure validation helpers from
`governance`, so publishing-specific proposal execution remains cycle-free.

## Adding A New Built-In Type

Adding a new type is a protocol upgrade, not a pure runtime configuration.

Expected development steps:

1. Add the type constant/getter/name in `artifact_types`.
2. Add the strong typed `VersionRecord`.
3. Add `publish_xxx` and `add_xxx_version` entrypoints.
4. Add getters and tests.
5. Add or migrate the `TypeRegistry`/`TypeIndex` registration path.
6. Ship the package upgrade.
7. Activate the type through executable governance.

Because a new type changes entrypoints and typed record objects, it should be
reviewed and activated through governance, not silently enabled by an operator.
