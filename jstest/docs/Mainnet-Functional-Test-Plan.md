# PaperProof Current Mainnet Functional Test Plan

Date: 2026-05-08

This plan describes the current `jstest` mainnet harness for the latest
PaperProof contracts. It replaces the older paper reserve/finalize plan with the
current artifact series/version flow.

## Canonical Deployment Under Test

- PPRF type:
  `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF`
- publishing package:
  `0xe67a6956f37c3182354189d9b77ca14058694aad82522da0c6cb91cfddee4782`
- comments package:
  `0xaef346fc40bf20af62f4bbbc1608ba2272e80e4ba3d716634026baa589e9aeba`
- governance package, latest callable:
  `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- PaperProofRoot:
  `0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78`
- TypeRegistry:
  `0x966ffa24d0a96b34267b62c628f39c830afc9de25438b6502835fa8a3815d6b5`
- FeeManager:
  `0x7bb8360ea1fa50f923628c929b8726b00eb8968c6a678acde71f97ae146e9249`
- GovernanceVault:
  `0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875`
- GovernanceConfig:
  `0x7ed018db6b2cd7c32692a1c33543fb90d9c36add1226f93cbeb2a8fb10955dfa`

## Account Model

The script expects `ADDR_1` through `ADDR_4` in
[../.env](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/.env).

- `ADDR_1`: preprint publisher
- `ADDR_2`: commenter, liker, temporary proposal creator
- `ADDR_3`: commenter and later preprint owner
- `ADDR_4`: current role holder and PPRF custodian

PPRF should end concentrated back on `ADDR_4`.

## Artifact Types

The run intentionally uses only:

- `preprint`
- `software_release`

The preprint path is primary and should be the main frontend reference.

## Main Flow

1. Validate canonical objects, roles, and balances.
2. Temporarily provide small PPRF proof balances to `ADDR_2` and `ADDR_3`.
3. Publish a preprint from `ADDR_1`.
4. Update series-level metadata extensions.
5. Add a second preprint version with version metadata.
6. Add a top-level on-chain comment and a reply.
7. Hide the reply as tree owner.
8. Verify the author cannot restore a tree-owner-hidden comment to active.
9. Add a blob-backed comment with digest and preview bytes.
10. Like and unlike through the separate `LikesBook`.
11. Verify duplicate like and duplicate unlike fail.
12. Lock the comments tree and verify new comments fail.
13. Reopen the comments tree.
14. Transfer preprint ownership to `ADDR_3`.
15. Verify old owner cannot update metadata and new owner can.
16. Verify comments tree owner follows the artifact owner.
17. Publish a software release from `node_modules/pdf-lib/package.json`.
18. Temporarily provide proposal-creation PPRF to `ADDR_2`.
19. Create a signal proposal from `ADDR_2`.
20. Use `ADDR_4` to cast enough counter-vote balance to make the proposal
    outcome immediately settled as rejected.
21. Verify duplicate vote fails.
22. Resolve the proposal early.
23. Reclaim proposal balances.
24. Verify duplicate reclaim fails.
25. Return all participant PPRF to `ADDR_4`.
26. Assert final PPRF total across `.env` accounts equals the starting total.

## PPRF Protection Rules

The script treats PPRF as protected custody material:

- It records starting and ending PPRF totals.
- It returns participant PPRF at the end.
- It has an emergency path on script failure:
  - settle an active proposal when possible,
  - reclaim proposal balances,
  - return loose participant PPRF to `ADDR_4`,
  - print the final total across `.env` accounts.
- The successful run must have `pprfGuard.delta = 0`.

This makes the script suitable for repeated mainnet smoke tests without leaving
PPRF scattered across participant accounts in normal operation.

## Concurrency And Object Version Notes

Sui shared and owned object versions can advance between build and submit. The
helper wraps build/sign/execute in one retry boundary and treats stale-object
version responses as retryable.

The main script also adds short waits between consecutive writes to the same:

- `CommentsTree`
- `LikesBook`
- PPRF coin set

This is not a contract requirement. It is a script stability measure for live
mainnet RPC behavior.

## Latest Successful Run

- run id: `mainnet-current-smoke-2026-05-07T17-29-30-998Z`
- artifact:
  [../artifacts/mainnet-current-smoke-2026-05-07T17-29-30-998Z.json](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/artifacts/mainnet-current-smoke-2026-05-07T17-29-30-998Z.json)
- log:
  [../logs/mainnet-current-smoke-2026-05-07T17-29-30-998Z.md](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/logs/mainnet-current-smoke-2026-05-07T17-29-30-998Z.md)

Important outputs:

- preprint series:
  `0xe89ef69f7f74db99ee8ff76c2151ea6be961b2005b333defbecb48d724df237b`
- preprint version 1:
  `0xf1c12a55927d5333a082b5da99692c45487211ec1a1b1b5e9fb261060ea8a7a6`
- preprint version 2:
  `0x01f7b5784352a71f6834dfb6d7bba256671726c9af21c1eb9437d6f9a8d382cb`
- preprint code:
  `PaperProof-preprint-001120-e89ef69f7f74`
- preprint comments tree:
  `0xc27bb4ddbf6afca87af6422f4d78d139805308fe2f6b15cd2c0ea4b7f4b4d018`
- preprint likes book:
  `0xa4f06bfb6b2909b8e958e2977378a3600dbc3ed8dc64b92fa491a10dae427891`
- software release series:
  `0x9e7bdd016ebc68b1edc552a08715bee8c6e48b3afdeea8690cb4959a1942a2ed`
- software release code:
  `PaperProof-software_release-001120-9e7bdd016ebc`
- governance proposal:
  `0x722f3a05da653ec107b739b39264c082187bbabe5b324952edc07e29e1dab65e`

Final PPRF state after the successful run:

- `ADDR_1`: `0`
- `ADDR_2`: `0`
- `ADDR_3`: `0`
- `ADDR_4`: `9,990,000,000 PPRF`
- total delta: `0`

## Pass Criteria

A run passes when:

- `--validate` succeeds.
- `--run` exits successfully.
- preprint and software release are both published.
- preprint has two versions.
- metadata update permissions behave as expected.
- comments and likes positive and negative paths behave as expected.
- owner transfer synchronizes the comments tree owner.
- governance proposal is created, counter-voted, early-settled, and reclaimed.
- `active_proposal_id` is empty after the run.
- PPRF total across `.env` accounts is unchanged.
