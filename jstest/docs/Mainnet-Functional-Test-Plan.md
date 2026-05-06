# PaperProof Mainnet Functional Test Plan

Date:

- 2026-05-06

Scope:

- `paperproof-contracts` mainnet canonical deployment
- publishing
- comments tree
- paper likes
- governance proposal / vote / finalize / claim
- no successful executable governance action

Related canonical on-chain references:

- `PPRF` package:
  - `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da`
- `PPRF` type:
  - `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF`
- `paperproof_governance` package:
  - `0x5e9624d571464b0edd55bbef88f7d603079f1b5e336873ec853eeaafc76b0ba6`
- `paperproof_comments` package:
  - `0x4957dc41c3f5ada9fec450681d6447334d59d21983183cbe1b876287be722097`
- `paperproof_publishing` package:
  - `0x58f1038ed42a7585a55b860174ec70a96f80625cf2102ff167797454f3ddbd63`
- canonical `PaperRegistry`:
  - `0x7f18b6355da8684918d0d2669261cd04b4796e365c10221151d25318db0a7815`
- canonical `GovernanceVault`:
  - `0x6073595f4e1bdaa6732fc25818e793bed341c4fb888b562eadaeff8db222f43c`
- canonical `GovernanceConfig`:
  - `0xb34b875ddf89abdf7253efaa68644e8abd17790ddf097915a72912d12fc89dd9`

Local test materials:

- accounts are stored in:
  - [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\jstest\.env](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/.env)
- sample PDFs:
  - [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\jstest\paperSamples\Versioned Upgrade Design.pdf](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/paperSamples/Versioned%20Upgrade%20Design.pdf)
  - [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\jstest\paperSamples\PaperProof Contracts Observability and Read APIs.pdf](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/paperSamples/PaperProof%20Contracts%20Observability%20and%20Read%20APIs.pdf)
- existing frontend reference for Sui and Walrus usage:
  - [D:\Works\VscodeProject\OriginPapers\sites\src\services\contract.js](D:/Works/VscodeProject/OriginPapers/sites/src/services/contract.js)
  - [D:\Works\VscodeProject\OriginPapers\sites\src\services\walrus.js](D:/Works/VscodeProject/OriginPapers/sites/src/services/walrus.js)
  - [D:\Works\VscodeProject\OriginPapers\sites\src\config\deployments.js](D:/Works/VscodeProject/OriginPapers/sites/src/config/deployments.js)

## Goal

This plan is intended to verify that the canonical PaperProof mainnet deployment
works end-to-end under real wallets, real SUI gas, real Walrus blob writes, and
real `PPRF`-gated interactions, while avoiding any successful governance action
that would permanently change protocol parameters.

## Feasibility Assessment

This test plan is feasible on mainnet.

Reasons:

- `publishing`, `comments`, and `governance` are already deployed and initialized.
- the three wallets in `.env` are sufficient to simulate:
  - founder / whale governance account
  - small `PPRF` holder
  - non-holder becoming a holder
- the two sample PDFs are enough to test:
  - reserve + finalize
  - multi-user publishing
  - optional add-version flow
- current protocol fee defaults are free, so only SUI gas and Walrus writes are
  expected to cost real funds
- governance proposal duration is currently `1` mainnet epoch, which is slow for
  rapid iteration but still short enough for a real-world validation cycle

Main constraints:

- all successful mainnet writes are permanent
- paper publishing will create real canonical `PaperRecord`, `PaperVersion`, and
  `CommentsTree` objects
- proposal creation and voting will lock real `PPRF` until the proposal can be
  finalized and the participants later reclaim tokens
- a complete governance cycle still requires waiting until the active proposal
  epoch ends

## Safety Principles

- do not expose private keys in logs, screenshots, or committed files
- do not transfer more than `10 PPRF` total out of the main wallet
- do not execute any governance proposal that could change fee levels, operator,
  proposer threshold, upgrade authority, or proposal duration
- use real executable-governance proposals only in a configuration that is
  expected to be rejected
- keep the test footprint small and intentional

## Account Model

Use the three accounts from `.env` as follows:

- `ADDR_1`
  - founder / deployer / whale account
  - controls almost all `PPRF`
  - creates governance proposal
  - publishes at least one paper
- `ADDR_2`
  - already holds SUI and `1 PPRF`
  - publishes one paper
  - comments, likes, and votes
- `ADDR_3`
  - starts with SUI only
  - receives a small `PPRF` transfer from `ADDR_1`
  - tests the transition from non-holder to holder
  - comments, likes, and votes

Recommended minimal `PPRF` transfers:

- transfer `1 PPRF` from `ADDR_1` to `ADDR_3`
- do not transfer additional `PPRF` unless a later step needs it

Why this is enough:

- likes require the caller to prove possession of a `Coin<PPRF>` with value
  `>= 1 PPRF`
- voting only needs small balances for `ADDR_2` and `ADDR_3` because the
  governance proposal is intentionally designed not to pass
- keeping the transfer tiny minimizes unnecessary change to token distribution

## Test Coverage Objectives

The plan should cover the following mainnet behaviors:

- reserve a paper code
- stamp the final PDF with the reserved `paperCode` before Walrus upload
- finalize a paper with a real Walrus-backed artifact
- update an existing paper with a new version
- extend storage end epoch for an existing paper version
- create and bind a `CommentsTree`
- read back the created paper and version state
- like a paper
- unlike a paper
- prove that a no-`PPRF` account cannot like before receiving `PPRF`
- build a comments tree with up to `3` first-level branches and depth `3`
- optionally add one blob-backed comment
- confirm comment tree ownership follows paper owner
- create one executable governance proposal
- prove that a low-balance address cannot create a proposal because it does not
  meet proposer threshold
- cast votes from multiple addresses
- prove that one address cannot vote twice on the same proposal
- prove that a second proposal cannot be created while one proposal is active
- wait one epoch
- finalize the proposal
- verify the proposal is rejected
- reclaim locked `PPRF`
- prove that a second claim attempt fails after tokens are reclaimed

## Explicitly Out of Scope

- any successful executable governance action
- any permanent change to:
  - fee recipient
  - publishing fee level
  - comments fee level
  - operator
  - proposer threshold
  - upgrade authority
  - proposal duration
- any managed upgrade flow
- any `migrate_*` flow

## Recommended Test Phases

### Phase 0: Environment Validation

Verify before any write transaction:

- `ADDR_1`, `ADDR_2`, and `ADDR_3` can all sign and submit mainnet transactions
- all three accounts have enough SUI for gas
- `ADDR_2` really has `>= 1 PPRF`
- `ADDR_3` really has `0 PPRF` before transfer
- frontend/runtime config points at the canonical mainnet objects and packages

Suggested checks:

- read SUI balances
- read `PPRF` coin objects
- read `GovernanceVault`
- read `GovernanceConfig`
- read `PaperRegistry`

### Phase 1: Minimal `PPRF` Distribution

Perform one small real transfer:

- `ADDR_1 -> ADDR_3`: `1 PPRF`

Post-conditions:

- `ADDR_3` now has at least one `Coin<PPRF>`
- `ADDR_1` still holds effectively all voting power
- total transferred amount stays far below the `10 PPRF` ceiling

Negative coverage in this phase:

- have `ADDR_2` or `ADDR_3` attempt to create a governance proposal before any
  real proposer action
- expect failure because proposer threshold is not met
- this verifies the proposer threshold path without risking a real successful
  proposal

### Phase 2: Publishing Flow

#### Scenario A: `ADDR_1` publishes Paper A

Use:

- `Versioned Upgrade Design.pdf`

Steps:

1. reserve a code using `reserve_code`
2. stamp the final PDF locally with the reserved `paperCode`
3. verify the stamped file follows the frontend reference behavior from
   [D:\Works\VscodeProject\OriginPapers\sites\src\services\pdf.js](D:/Works/VscodeProject/OriginPapers/sites/src/services/pdf.js):
   - first page stamp text includes:
     - ``${paperCode} | Verify on PaperProof``
   - later pages include:
     - `paperCode`
   - embedded verification link points to:
     - `https://paperproof.wal.app/#/p/<paperCode>`
4. validate final PDF metadata and hash after stamping
3. upload PDF to Walrus
4. finalize with:
   - title
   - abstract
   - keywords
   - authors
   - field
   - license
   - `walrus_blob_id`
   - `walrus_blob_object_id`
   - file hash
   - file size
   - page count
   - `storage_end_epoch`
   - `is_shared_blob`
5. capture:
   - `paper_code`
   - `PaperRecord` ID
   - `PaperVersion` ID
   - `CommentsTree` ID

Checks:

- `PaperFinalized` event emitted
- `CommentsTreeBound` event emitted
- `PaperRecord.comments_tree_id` exists
- the paper owner is `ADDR_1`
- the bound comments tree owner resolves to `ADDR_1`
- the on-chain `file_hash` matches the stamped PDF hash, not the original source
- the finalized file name convention is consistent with the reference behavior:
  - `.originpaper.pdf`

#### Scenario B: `ADDR_2` publishes Paper B

Use:

- `PaperProof Contracts Observability and Read APIs.pdf`

Repeat the same flow with `ADDR_2`.

Checks:

- a second independent `PaperRecord` is created
- a second independent `CommentsTree` is created
- ownership is correctly bound to `ADDR_2`
- reserved code sequence and record numbers continue to advance correctly across
  multiple papers

#### Scenario C: `ADDR_1` updates Paper A with a second version

This is mandatory coverage, not optional.

Recommended source:

- reuse the second sample PDF, or regenerate a slightly changed stamped PDF so
  the version is visibly distinct

Steps:

1. prepare a second finalized PDF for Paper A
2. upload the new finalized PDF to Walrus
3. call `add_version`
4. capture the new `PaperVersion` ID

Checks:

- `PaperVersionAdded` event emitted
- `current_version` increments from `1` to `2`
- `version_ids` grows by one
- latest version metadata reflects the new file
- `comments_tree_id` on the `PaperRecord` remains exactly unchanged
- the same `CommentsTree` continues to be used before and after the version
  update

#### Scenario D: storage extension on the latest version of Paper A

Steps:

1. read the latest `storage_end_epoch` for Paper A version 2
2. call `record_storage_extension` with a strictly larger epoch value
3. read the version again

Checks:

- `StorageExtended` event emitted
- the latest version `storage_end_epoch` increases
- the extension is recorded on the correct `PaperVersion`
- the operation does not alter `current_version` or `comments_tree_id`

### Phase 3: Like / Unlike Flow

Primary target:

- Paper A

#### Negative precondition check

Before the `PPRF` transfer in Phase 1, or by replaying that logic first in a
fresh sequence:

- have `ADDR_3` attempt `like_paper`
- expect failure because the account cannot provide a qualifying `Coin<PPRF>`

#### Positive like tests

After Phase 1:

- `ADDR_2` likes Paper A using its existing `PPRF` coin
- `ADDR_3` likes Paper A using the transferred `PPRF` coin

Checks:

- `PaperLikedEvent` emitted twice
- `like_count` becomes `2`
- `has_liked(ADDR_2)` and `has_liked(ADDR_3)` return `true`
- repeated like from the same address should fail or be rejected

Additional negative case:

- have `ADDR_2` attempt to like Paper A twice
- expect the second like transaction to fail or be rejected

#### Unlike tests

- `ADDR_3` unlikes Paper A

Checks:

- `PaperUnlikedEvent` emitted
- `like_count` decreases back to `1`
- `has_liked(ADDR_3)` becomes `false`

Additional negative case:

- optionally attempt a second unlike from `ADDR_3`
- expect failure or rejection because the address no longer has an active like

### Phase 4: Comments Tree Flow

Primary target:

- Paper A comments tree

#### On-chain comment tree topology

Build an explicit tree on Paper A with:

- at most `3` top-level branches
- maximum depth `3`

Recommended shape:

- root comment `A` by `ADDR_2`
  - reply `A1` by `ADDR_1`
    - reply `A1a` by `ADDR_3`
- root comment `B` by `ADDR_3`
  - reply `B1` by `ADDR_2`
    - reply `B1a` by `ADDR_1`
- root comment `C` by `ADDR_1`
  - reply `C1` by `ADDR_3`
    - reply `C1a` by `ADDR_2`

This gives:

- `3` first-level branches
- depth `3`
- all three accounts participating in different positions

Steps:

1. `ADDR_2` creates top-level comment `A`
2. `ADDR_1` replies with `A1`
3. `ADDR_3` replies with `A1a`
4. `ADDR_3` creates top-level comment `B`
5. `ADDR_2` replies with `B1`
6. `ADDR_1` replies with `B1a`
7. `ADDR_1` creates top-level comment `C`
8. `ADDR_3` replies with `C1`
9. `ADDR_2` replies with `C1a`

Checks:

- all comments are anchored under the same `CommentsTree`
- parent/child relationships are correct
- `total_comments` increments exactly as expected
- top-level root-anchored comment count is `3`
- maximum tested depth reached is `3`
- `CommentAddedEvent` sequence is emitted
- the tree remains readable and reconstructible from on-chain fields plus event
  history

Additional semantic coverage:

- mark one intermediate comment as `HIDDEN`
- verify that the node status changes on-chain
- add one reply under that hidden comment
- verify the reply is still accepted

This confirms the intended business rule that hidden/deleted comment states are
only node-state markers and do not enforce subtree pruning at the contract
layer.

#### Optional blob-backed comment path

If Walrus text blob scripting is added in `jstest`:

1. encode a short UTF-8 text payload
2. write the payload to Walrus using the same general flow pattern as the PDF
   upload code in the frontend reference
3. call `add_blob_comment`

Checks:

- comment node is created with blob-backed mode
- blob id / digest / preview fields are populated as expected

Note:

- this is optional because mainnet functional confidence can already be high
  from on-chain comments alone
- but it is still a valuable extra if the JS test harness adds generic Walrus
  text blob support

### Phase 5: Comments Tree Ownership and Governance Semantics

Goal:

- verify that comments tree governance follows paper ownership

Recommended sequence:

1. on Paper B, have `ADDR_2` transfer paper ownership to `ADDR_3`
2. read the associated `CommentsTree`
3. verify comments tree owner changes accordingly
4. have `ADDR_3` perform a tree-governance action that requires ownership
   authority, such as `set_tree_status`
5. restore the tree to open status if needed for further testing

Checks:

- `PaperOwnerTransferred` event emitted
- `TreeOwnerTransferredEvent` emitted
- old owner can no longer use owner-only tree controls
- new owner can
- if comments already exist on Paper B, those comments remain attached to the
  same tree after ownership transfer

Additional lock semantics coverage:

6. while Paper B tree is locked, attempt to add a new comment
7. expect the comment write to fail
8. reopen the tree
9. add a new comment successfully after reopening

This verifies the contract-layer distinction between:

- tree lock, which blocks new comments
- comment hidden/deleted state, which is only a marker

This is a high-value behavior because it validates the special rule that the
discussion space follows the current paper owner rather than the original
publisher forever.

### Phase 6: Governance Flow Without Parameter Change

This phase is the most important governance safety scenario.

Use one executable proposal that would be meaningful if it passed, but ensure it
does not pass.

Recommended proposal:

- change `comments_fee_level` from `0` to `1`

Why this proposal:

- it exercises a real executable-governance path
- if it were passed, the chain state would visibly change
- but we will intentionally configure the vote so it fails

#### Why rejection is expected

Current governance rules require both:

- `yes_votes * 3 >= no_votes * 4`
- `yes_votes * 10 > total_supply`

The proposer automatically locks the proposer threshold and receives a default
`YES` vote.

But current proposer threshold is far below the `> 10% of total supply` passage
condition, so a proposal created by `ADDR_1` can be safely tested without
casting any further large `YES` votes.

#### Recommended governance sequence

1. before creating the real proposal, have `ADDR_2` or `ADDR_3` attempt to
   create the same proposal
2. expect failure because proposer threshold is not met
3. `ADDR_1` creates an executable proposal to set `comments_fee_level = 1`
4. while that proposal is still active, have one address attempt to create a
   second proposal
5. expect second proposal creation to fail because only one active proposal is
   allowed
6. `ADDR_2` casts `NO` with its `1 PPRF`
7. `ADDR_3` casts `NO` with its `1 PPRF`
8. have one address attempt to vote a second time on the same proposal
9. expect the second vote attempt to fail
10. optionally verify `can_claim_locked_tokens` is still false before finalize
11. wait until the proposal epoch window ends
12. finalize the proposal
13. verify the proposal is rejected
14. do not execute the proposal
15. reclaim locked `PPRF` from:
   - `ADDR_1`
   - `ADDR_2`
   - `ADDR_3`

Checks:

- `ProposalCreatedEvent`
- proposer-threshold failure is observed for a small holder
- the second proposal attempt fails while `active_proposal_id` is occupied
- `VoteCastEvent` from all participating addresses
- duplicate vote attempt fails
- `ProposalFinalizedEvent`
- final proposal status is `REJECTED`
- `is_proposal_executable` may still be true by type, but execution must not be
  attempted after rejection
- all participants can reclaim locked tokens successfully
- a second claim attempt after reclaim fails

This gives full governance coverage without changing any protocol parameter.

### Phase 7: Readback and Observability Audit

After the write tests, perform a read-focused audit from chain state and events.

Read back and verify:

- all created paper records
- all created paper versions
- both Paper A versions in the correct order
- latest Paper A version has the extended `storage_end_epoch`
- all created comments trees
- final like counts
- final comment counts
- exact reconstructed Paper A comment tree shape
- hidden comment node plus accepted child reply under it
- locked-tree rejection followed by reopened-tree success on Paper B
- governance proposal object
- vote lock reclaim state
- current fee levels still remain `0`
- `proposal_duration_epochs` still remains `1`
- `upgrade_authority` remains unchanged
- `fee_recipient` remains unchanged

This phase should rely heavily on public getters and event queries to confirm
that off-chain monitoring and frontend rendering can reconstruct the state.

## Suggested Execution Style

Use simple, explicit transactions by default.

Why:

- clearer transaction history on mainnet
- easier debugging
- easier event correlation
- easier to explain to community members later

Use PTB only where it genuinely reduces friction, for example:

- create governance config and immediately share it
- register managed upgrade caps and immediately share them
- later, if desired, wrap small utility transfers or helper setup

For the functional tests in this plan, PTB is not required for most user flows.

## Recommended Artifacts to Save During Testing

For every meaningful transaction, record:

- tx digest
- signer address
- affected object IDs
- relevant event types
- gas cost
- a short note about expected vs actual result

Recommended files under `jstest`:

- one markdown run log per session
- one JSON artifact capture file for:
  - paper IDs
  - version IDs
  - comments tree IDs
  - proposal IDs
  - vote participation

## Pass Criteria

The mainnet functional test is considered successful if all of the following are
true:

- at least two papers are successfully finalized on mainnet
- each finalized paper uses a stamped PDF whose hash matches the finalized
  artifact
- Paper A is successfully updated with a second version
- the latest Paper A version successfully records a storage extension
- each finalized paper has a bound `CommentsTree`
- at least one like and one unlike are successful
- a non-holder like attempt fails before `PPRF` is received
- duplicate like attempt is rejected
- the Paper A comments tree reaches:
  - `3` top-level branches
  - depth `3`
- a hidden comment still accepts a child reply, confirming marker-only comment
  status semantics
- comment ownership/governance follows paper ownership after transfer
- a locked comments tree rejects new comments until reopened
- at least one executable governance proposal is created, voted on, finalized,
  and rejected
- a low-balance address cannot create a proposal
- a voter cannot vote twice on the same proposal
- while a proposal is active, a second proposal attempt is rejected
- locked governance tokens are successfully reclaimed
- a second claim attempt after reclaim is rejected
- no protocol parameter is actually changed

## Practical Recommendation

The safest and most informative first live run is:

1. validate balances and objects
2. transfer `1 PPRF` to `ADDR_3`
3. publish Paper A with `ADDR_1`
4. publish Paper B with `ADDR_2`
5. update Paper A with a second version
6. extend storage for the latest version of Paper A
7. test like / unlike on Paper A
8. build the full Paper A comment tree
9. test hidden-comment marker semantics on Paper A
10. test paper-owner-to-comments-tree-owner synchronization on Paper B
11. test lock / reopen behavior on Paper B
12. create one rejected executable governance proposal
13. verify that a second proposal cannot be created while the first is active
14. verify duplicate voting is rejected
15. wait one epoch
16. finalize, reclaim, and confirm double-claim rejection

This sequence gives broad coverage with minimal irreversible governance risk.

## Estimated Transaction Count For One Full Scripted Round

The following estimate assumes the script sends real mainnet transactions for
both positive and selected negative cases.

### Core positive flow

1. `ADDR_1 -> ADDR_3` transfer `1 PPRF`
2. reserve Paper A
3. Walrus register/upload for Paper A
4. Walrus certify for Paper A
5. finalize Paper A
6. reserve Paper B
7. Walrus register/upload for Paper B
8. Walrus certify for Paper B
9. finalize Paper B
10. Walrus register/upload for Paper A version 2
11. Walrus certify for Paper A version 2
12. add version to Paper A
13. extend storage for Paper A version 2
14. like Paper A by `ADDR_2`
15. like Paper A by `ADDR_3`
16. unlike Paper A by `ADDR_3`
17. comment `A`
18. reply `A1`
19. reply `A1a`
20. comment `B`
21. reply `B1`
22. reply `B1a`
23. comment `C`
24. reply `C1`
25. reply `C1a`
26. set one comment status to `HIDDEN`
27. add reply under hidden comment
28. transfer Paper B owner to `ADDR_3`
29. lock Paper B tree
30. reopen Paper B tree
31. add reopened-tree success comment
32. create governance proposal
33. `ADDR_2` vote `NO`
34. `ADDR_3` vote `NO`
35. finalize proposal after one epoch
36. claim locked tokens by `ADDR_1`
37. claim locked tokens by `ADDR_2`
38. claim locked tokens by `ADDR_3`

Core positive subtotal:

- `38` transactions

### Negative-case transactions that still hit chain

1. proposal creation attempt by low-balance address
2. duplicate like attempt by `ADDR_2`
3. unlike-again attempt by `ADDR_3` after already unliked
4. add comment while Paper B tree is locked
5. second proposal creation attempt while first proposal is active
6. duplicate vote attempt on active proposal
7. second claim attempt after reclaim
8. optional direct low-balance like attempt before `PPRF` transfer, if executed
   as a real failed write instead of being observed only in setup

Negative-case subtotal:

- about `7` to `8` transactions

### Full round estimate

- conservative full scripted round:
  - about `45` to `46` transactions

### Possible range

- if optional blob-backed comment coverage is skipped and certain negative cases
  are checked only via reads instead of real failed writes:
  - about `41` to `43` transactions
- if optional blob-backed comment coverage is added:
  - about `46` to `48` transactions before any extra retries

### Interpretation

This is well within the operational budget suggested by the current Sui gas
environment.

The heavier cost driver is not Sui gas itself, but:

- Walrus register/certify activity
- waiting one epoch to close the proposal
- the fact that failed negative tests still consume small real gas amounts
