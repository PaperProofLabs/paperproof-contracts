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
- [ ] comments tree factory capability confirmed as embedded in `PaperProofRoot`
- [ ] `GovernanceVault` object ID recorded
- [ ] `GovernanceConfig` object ID recorded
- [ ] all six initial `TypeIndex` object IDs recorded

## Binding Checks

- [ ] `GovernanceVault.registry_id == PaperProofRoot ID`
- [ ] `GovernanceConfig.registry_id == PaperProofRoot ID`
- [ ] `FeeManager.registry_id == PaperProofRoot ID`
- [ ] root comments tree factory registry getter returns `PaperProofRoot ID`
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
- [ ] verify artifact code matches
      `PaperProof-{type}-{epoch6}-{series_id_hex_12}`
- [ ] verify indexer records `artifact_code -> series_id` from
      `ArtifactPublishedEvent`
- [ ] verify publish path uses the root-embedded comments tree factory
      capability
- [ ] verify official `CommentsTree` created and bound to the series
- [ ] verify official `LikesBook` created and bound to the series
- [ ] add a second version
- [ ] verify comments tree ID and likes book ID remain unchanged
- [ ] verify protocol pause blocks publish and add-version paths
- [ ] verify locked or hidden series reject metadata-extension updates

## Comments Smoke Tests

- [ ] add on-chain comment
- [ ] add blob-backed comment
- [ ] lock/unlock tree behavior verified if needed
- [ ] like/unlike path verified through the official `LikesBook` if frontend
      uses it
- [ ] verify root comment status cannot be changed
- [ ] verify deleted comments cannot be restored by author or tree owner
- [ ] verify author cannot reactivate a tree-owner-hidden comment

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
- [ ] indexer treats `ArtifactSeries.comments_tree_id` as the trusted comments
      tree binding, not a standalone `TreeCreatedEvent`
- [ ] indexer treats `ArtifactSeries.likes_book_id` as the trusted likes
      binding, not a standalone like event
- [ ] indexer discovers official governance objects from `PaperProofRoot` and
      `GovernanceConfigBoundEvent`, not public constructor-style events

## Documentation

- [ ] deployment manifest completed
- [ ] artifact publishing documentation reviewed
- [ ] governance modes documentation reviewed
- [ ] public website/whitepaper copy describes the current artifact publishing
      model
