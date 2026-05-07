# PaperProof Contracts Deployment and Upgrade Runbook

This runbook reflects the current artifact publishing architecture.

## Packages

The active contract packages are:

- `governance`
- `comments`
- `publishing`

`publishing` depends on both `governance` and `comments`.

## Publishing Root Objects

Publishing initialization creates the canonical publishing root and related
objects:

- `PaperProofRoot`
- `TypeRegistry`
- six initial `TypeIndex` objects
- `FeeManager`
- `GovernanceVault`
- initial `OperatorPermit`

`PaperProofRoot` stores only root dependency IDs. `TypeRegistry` stores the
artifact-type-to-index mapping.

## Built-In Types

The initial built-in artifact types are:

- `preprint`
- `blog_post`
- `technical_report`
- `dataset`
- `software_release`
- `generic_file`

Each type has one `TypeIndex`.

## Deployment Recording

Record:

- package IDs
- `PaperProofRoot` object ID
- `TypeRegistry` object ID
- `FeeManager` object ID
- `GovernanceVault` object ID
- `GovernanceConfig` object ID, once created
- every initial `TypeIndex` object ID
- initial `OperatorPermit` recipient
- upgrade authority
- fee recipient

## Governance Setup

After publishing initialization:

1. create `GovernanceConfig` from the official `GovernanceVault`
2. verify `GovernanceConfig.registry_id == PaperProofRoot ID`
3. verify `GovernanceVault.registry_id == PaperProofRoot ID`
4. verify `FeeManager.registry_id == PaperProofRoot ID`
5. record proposer threshold, proposal duration, and active proposal state

## Artifact Type Governance

Artifact type activation and artifact-specific fees are governance actions.

Use executable proposals for:

- `ACTION_SET_ARTIFACT_TYPE_ENABLED`
- `ACTION_SET_ARTIFACT_FEE_LEVEL`
- `ACTION_ACTIVATE_ARTIFACT_TYPE`

`ACTION_ACTIVATE_ARTIFACT_TYPE` is the preferred path for a major type launch
because it enables the type and sets the fee level in the same approved action.

Any account may execute a passed proposal while it is inside the execution
window. The execution path consumes the proposal into a `GovernanceActionTicket`
and then applies the publishing-specific state change.

## Smoke Tests

Minimum deployment smoke test:

1. publish one artifact
2. verify an `ArtifactSeries` was created
3. verify the relevant `TypeIndex` maps code to series ID
4. verify a `CommentsTree` was created and bound to the series
5. add a version and verify the comments tree ID remains unchanged
6. add an on-chain comment
7. create a governance proposal
8. cast a yes vote
9. finalize the proposal
10. execute the proposal
11. claim locked voting funds

## Upgrade Flow

For ordinary package upgrades:

1. freeze risky frontend or operational paths if needed
2. check for active proposals
3. verify upgrade authority and `ManagedUpgradeCap` custody
4. publish the package upgrade
5. run any required migration hooks
6. re-run smoke tests
7. update deployment manifests and frontend configuration

Adding a new artifact type is a major publishing upgrade:

1. add type constants and name mapping in `artifact_types`
2. add the typed `VersionRecord`
3. add publish/add-version entrypoints
4. add tests
5. upgrade the package
6. register or migrate the new type/index state as needed
7. activate through executable governance

Adding a new governance action should follow the same code-before-activation
principle:

1. add the action constant and execution logic
2. include it as a known action
3. do not add it to default enabled actions unless it is part of the launch
   baseline
4. upgrade the package
5. enable the action through `ACTION_SET_GOVERNANCE_ACTION_ENABLED`
6. only then use the new action for live proposals

## Canonical Invariants

Maintain these invariants:

- one official `PaperProofRoot`
- one official `TypeRegistry`
- one official `FeeManager`
- one official `GovernanceVault`
- every built-in type maps to the expected `TypeIndex`
- `GovernanceVault.registry_id == PaperProofRoot ID`
- `GovernanceConfig.registry_id == PaperProofRoot ID`
- `FeeManager.registry_id == PaperProofRoot ID`
- each `ArtifactSeries` binds exactly one official `CommentsTree`
- later versions reuse the same comments tree
