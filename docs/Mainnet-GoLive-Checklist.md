# PaperProof Mainnet Go-Live Checklist

Use this checklist before opening a deployment of the current artifact
publishing protocol to users.

## Package IDs

- [ ] `governance` package ID recorded
- [ ] `comments` package ID recorded
- [ ] `publishing` package ID recorded
- [ ] `PPRF` package/type recorded

## Canonical Objects

- [ ] `PaperProofRoot` object ID recorded
- [ ] `TypeRegistry` object ID recorded
- [ ] `FeeManager` object ID recorded
- [ ] `GovernanceVault` object ID recorded
- [ ] `GovernanceConfig` object ID recorded
- [ ] all six initial `TypeIndex` object IDs recorded

## Binding Checks

- [ ] `GovernanceVault.registry_id == PaperProofRoot ID`
- [ ] `GovernanceConfig.registry_id == PaperProofRoot ID`
- [ ] `FeeManager.registry_id == PaperProofRoot ID`
- [ ] `TypeRegistry.registry_id == PaperProofRoot ID`
- [ ] every `TypeInfo.index_object_id` points to the expected `TypeIndex`

## Artifact Types

- [ ] `preprint` enabled state correct
- [ ] `blog_post` enabled state correct
- [ ] `technical_report` enabled state correct
- [ ] `dataset` enabled state correct
- [ ] `software_release` enabled state correct
- [ ] `generic_file` enabled state correct
- [ ] artifact type fee levels correct in `FeeManager`

## Publishing Smoke Tests

- [ ] publish one artifact
- [ ] verify `ArtifactSeries` created
- [ ] verify typed `VersionRecord` created
- [ ] verify `TypeIndex` code lookup returns the series ID
- [ ] verify official `CommentsTree` created and bound to the series
- [ ] add a second version
- [ ] verify comments tree ID remains unchanged

## Comments Smoke Tests

- [ ] add on-chain comment
- [ ] add blob-backed comment
- [ ] lock/unlock tree behavior verified if needed
- [ ] like/unlike path verified if frontend uses it

## Governance Smoke Tests

- [ ] create executable proposal
- [ ] vote yes
- [ ] finalize proposal
- [ ] execute proposal
- [ ] claim locked vote tokens
- [ ] governance action availability baseline reviewed
- [ ] artifact type activation proposal path tested if deployment includes a
      type launch

## Frontend / Indexer

- [ ] frontend points to current package IDs
- [ ] frontend uses `PaperProofRoot`, `TypeRegistry`, `FeeManager`, and
      `TypeIndex` object IDs
- [ ] frontend reads artifact type names through current constants/getters
- [ ] indexer listens for `ArtifactPublishedEvent`
- [ ] indexer listens for `ArtifactVersionAddedEvent`
- [ ] indexer listens for artifact type and artifact fee events
- [ ] frontend and indexer use `PaperProofRoot`, `TypeRegistry`, and
      `ArtifactSeries`

## Documentation

- [ ] deployment manifest completed
- [ ] artifact publishing documentation reviewed
- [ ] governance modes documentation reviewed
- [ ] public website/whitepaper copy describes the current artifact publishing
      model
