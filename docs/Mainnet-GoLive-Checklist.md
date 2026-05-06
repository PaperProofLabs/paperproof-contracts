# PaperProof Mainnet Go-Live Checklist

This checklist is intended to be used immediately before the PaperProof mainnet
launch or before opening the official frontend to the public.

It is intentionally shorter and more operational than
`Deployment-Manifest-Template.md`.

Use this document as the final readiness gate after package publication,
initialization, smoke testing, and frontend wiring have already been completed.

## 1. Release Identity

- [ ] Mainnet release tag is finalized
- [ ] Mainnet git commit is finalized
- [ ] The deployed package IDs match the intended release
- [ ] The deployment manifest has been completed

Record here:

- Release tag:
- Git commit:
- Deployment manifest path:

## 2. Canonical Package IDs

- [ ] Official `PPRF` package ID is recorded
- [ ] Official `governance` package ID is recorded
- [ ] Official `comments` package ID is recorded
- [ ] Official `publishing` package ID is recorded

Record here:

- `PPRF` package ID:
- `governance` package ID:
- `comments` package ID:
- `publishing` package ID:

## 3. Canonical Root Object IDs

- [ ] Official `PaperRegistry` object ID is recorded
- [ ] Official `GovernanceVault` object ID is recorded
- [ ] Official `GovernanceConfig` object ID is recorded

Record here:

- `PaperRegistry`:
- `GovernanceVault`:
- `GovernanceConfig`:

## 4. Governance and Authority Checks

- [ ] Governance authority is correct
- [ ] Initial operator is correct
- [ ] Upgrade authority is correct
- [ ] Fee recipient is correct
- [ ] Proposal creation paused flag is in the intended state
- [ ] Proposer threshold is in the intended state

Record here:

- Governance authority:
- Current operator:
- Upgrade authority:
- Fee recipient:
- Proposal creation paused:
- Proposer threshold:

## 5. Fee Configuration Checks

- [ ] Publishing fee level is correct
- [ ] Comments fee level is correct
- [ ] Fee amounts derived from fee levels are correct
- [ ] Frontend displays the same fee policy the contracts enforce

Record here:

- Publishing fee level:
- Publishing fee amount:
- Comments fee level:
- Comments fee amount:

## 6. UpgradeCap and Managed Upgrade Checks

- [ ] Real `UpgradeCap` custody for all official packages is documented
- [ ] If using governed custody, `ManagedUpgradeCap` objects are registered
- [ ] Managed upgrade package bindings are correct
- [ ] The team understands which packages are already under governed upgrade
      control and which are not

Record here:

- `PPRF` `UpgradeCap` custody:
- `governance` `UpgradeCap` custody:
- `comments` `UpgradeCap` custody:
- `publishing` `UpgradeCap` custody:
- Managed upgrade object IDs:

## 7. Cross-Package Binding Checks

- [ ] `GovernanceVault.registry_id` equals the official `PaperRegistry`
- [ ] `GovernanceConfig.registry_id` equals the official `PaperRegistry`
- [ ] `publishing` frontend config points to the official `publishing` package
- [ ] `comments` frontend config points to the official `comments` package
- [ ] `governance` frontend config points to the official `governance` package
- [ ] Official `PPRF` package/type is the one used by governance voting

## 8. Smoke Test Confirmation

- [ ] Reserve paper code test passed
- [ ] Finalize paper test passed
- [ ] CommentsTree binding test passed
- [ ] Add comment test passed
- [ ] Like/unlike test passed
- [ ] Add version test passed
- [ ] Governance proposal creation test passed
- [ ] Vote cast test passed
- [ ] Vote finalization test passed
- [ ] Vote claim test passed
- [ ] Operator handoff test passed or consciously deferred
- [ ] Managed upgrade rehearsal test passed or consciously deferred

Record key test tx digests here:

- Reserve:
- Finalize:
- Comment:
- Like:
- Add version:
- Create proposal:
- Vote:
- Finalize proposal:
- Claim locked vote:

## 9. Frontend Readiness

- [ ] Official frontend is wired to canonical package IDs and root object IDs
- [ ] Official frontend handles governance fee/payment prompts correctly
- [ ] Official frontend handles comment fee/payment prompts correctly
- [ ] Official frontend handles lock-based governance voting correctly
- [ ] Official frontend displays canonical governance state
- [ ] Official frontend displays canonical paper/comment state
- [ ] Official frontend uses the intended mainnet hostname / Walrus site

Record here:

- Frontend release tag:
- Frontend commit:
- Official URL:

## 10. Indexer / Analytics Readiness

- [ ] Indexer is pointed at the correct package IDs
- [ ] Indexer is pointed at the correct root object IDs
- [ ] Governance events are being ingested
- [ ] Publishing events are being ingested
- [ ] Comments events are being ingested
- [ ] Upgrade / migration observability is being ingested

Record here:

- Indexer start checkpoint:
- Indexer status:

## 11. Docs and Public Communication

- [ ] Main protocol docs reflect the deployed package IDs and object IDs
- [ ] Governance docs reflect the deployed voting model
- [ ] Fee docs reflect the deployed fee model
- [ ] Upgrade authority / treasury / governance wording is current
- [ ] Whitepaper / website references are not stale

## 12. Operational Readiness

- [ ] Team members know who can:
  - rotate operator
  - execute passed proposals
  - update fee policy through governance
  - manage `UpgradeCap` custody
  - run migrations in a future upgrade
- [ ] Incident response path is documented
- [ ] Upgrade freeze / rollback expectations are documented
- [ ] A mainnet announcement plan exists

## 13. Final Go / No-Go

- [ ] All blocking issues are closed
- [ ] No unresolved package-ID mismatch exists
- [ ] No unresolved root-object mismatch exists
- [ ] No unresolved authority mismatch exists
- [ ] No unresolved frontend-config mismatch exists
- [ ] No unresolved fee-policy mismatch exists
- [ ] Team sign-off complete

Final decision:

- Go / No-Go:
- Approved by:
- Date:
- Notes:
