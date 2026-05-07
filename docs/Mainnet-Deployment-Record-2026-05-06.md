# PaperProof Contracts Mainnet Deployment Record

Use this file to record the canonical mainnet deployment for the current
PaperProof contract system.

## Release

- Deployment date:
- Release tag:
- Source commit:
- Deployer address:
- Network:
- RPC endpoint:

## Package IDs

- `PPRF` package:
- `PPRF` type:
- `paperproof_governance` package:
- `paperproof_comments` package:
- `paperproof_publishing` package:

## Canonical Publishing Objects

- `PaperProofRoot`:
- `TypeRegistry`:
- `FeeManager`:
- Comments tree factory capability: embedded in `PaperProofRoot`
- `TypeIndex` for `preprint`:
- `TypeIndex` for `blog_post`:
- `TypeIndex` for `technical_report`:
- `TypeIndex` for `dataset`:
- `TypeIndex` for `software_release`:
- `TypeIndex` for `generic_file`:

## Governance Objects

- `GovernanceVault`:
- `GovernanceConfig`:
- Initial `OperatorPermit` recipient:
- Governance authority:
- Upgrade authority:
- Fee recipient:

## Governance Configuration

- Proposal creation paused:
- Proposer threshold:
- Proposal duration epochs:
- Active proposal ID:
- Captured `PPRF` total supply:

## Fee Configuration

- Comments fee level:
- Artifact fee level for `preprint`:
- Artifact fee level for `blog_post`:
- Artifact fee level for `technical_report`:
- Artifact fee level for `dataset`:
- Artifact fee level for `software_release`:
- Artifact fee level for `generic_file`:

## Binding Verification

- [ ] `GovernanceVault.registry_id` equals `PaperProofRoot`
- [ ] `GovernanceConfig.registry_id` equals `PaperProofRoot`
- [ ] `FeeManager.registry_id` equals `PaperProofRoot`
- [ ] root comments tree factory registry getter equals `PaperProofRoot`
- [ ] `TypeRegistry.registry_id` equals `PaperProofRoot`
- [ ] every `TypeInfo.index_object_id` matches the expected `TypeIndex`
- [ ] governance executor cap is embedded in `PaperProofRoot`
- [ ] proposal execution paths verify `GovernanceConfig.proposal_id_to_object`
- [ ] published series records both official `comments_tree_id` and `likes_book_id`

## Smoke Test Transactions

- Publish artifact:
- Verify root-embedded comments tree factory capability used:
- Verify official `CommentsTree` and `LikesBook` bound:
- Add artifact version:
- Add on-chain comment:
- Add blob-backed comment:
- Like and unlike through official `LikesBook`:
- Create proposal:
- Vote yes:
- Finalize proposal:
- Execute proposal:
- Claim locked voting funds:

## Frontend And Indexer Configuration

- Frontend config commit:
- Indexer config commit:
- Official hostname:
- Walrus site:
- Package/object configuration reviewed by:
