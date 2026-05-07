# PaperProof Artifact Publishing

This document describes the current `publishing` architecture.

`publishing` is the canonical PaperProof artifact publication package for
verifiable digital content.

## Core Model

The main model is:

- `PaperProofRoot`: canonical protocol root for publishing.
- `TypeRegistry`: artifact-type registry and activation state.
- `TypeIndex`: per-type code index.
- `ArtifactSeries`: stable identity for one work.
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
PaperProof-{type}-{n}
```

Examples:

- `PaperProof-preprint-1`
- `PaperProof-dataset-1`
- `PaperProof-generic_file-1`

The code mapping is stored in the relevant `TypeIndex`:

```text
artifact_code -> ArtifactSeries ID
```

The first version intentionally does not add on-chain author, tag, keyword, or
license indexes. Those belong in events and off-chain indexers for now.

## Root And Registry Boundaries

`PaperProofRoot` stores only protocol-level dependencies:

- `governance_vault_id`
- `fee_manager_id`
- `type_registry_id`
- protocol version and pause flag

It does not store one hardcoded field per artifact type.

`TypeRegistry` owns the type-to-index mapping:

- `artifact_type`
- `index_object_id`
- `enabled`
- `schema_version`
- `min_protocol_version`
- timestamps

This keeps future type expansion from changing the root object layout.

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
- `status`
- `created_at_ms`

The concrete record types add only necessary type-specific fields:

- `PreprintVersionRecord`
- `BlogPostVersionRecord`
- `TechnicalReportVersionRecord`
- `DatasetVersionRecord`
- `SoftwareReleaseVersionRecord`
- `GenericFileVersionRecord`

## Comments Binding

Publishing automatically creates one official `CommentsTree` when an artifact
series is first published.

The tree is bound to the series, not to a single version:

- `target_series_id`
- `target_artifact_type`
- `target_key`
- `owner`

`ArtifactSeries.comments_tree_id` is the official binding. External packages
may create similar trees, but the publishing protocol recognizes only the tree
recorded on the series.

Owner transfer must be called with the official comments tree. The publishing
entrypoint verifies that the supplied tree ID equals
`ArtifactSeries.comments_tree_id` before synchronizing tree ownership.

## Series Status

An artifact series has a protocol status. Version additions are allowed only
while the series is `ACTIVE`.

Locked or hidden series remain readable, but they cannot receive new
`VersionRecord` objects until governance/operator-controlled status management
returns them to `ACTIVE`.

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

`governance_voting` does not import `publishing`. Instead, it consumes a passed
proposal and returns a one-time `GovernanceActionTicket`. The publishing package
then applies publishing-specific state changes using that ticket. This keeps the
dependency direction as:

```text
publishing -> governance
```

and avoids a package dependency cycle.

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
