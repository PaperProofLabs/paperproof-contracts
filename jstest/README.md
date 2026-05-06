# PaperProof JS Mainnet Test Harness

This directory contains a real mainnet functional test harness for the canonical
`paperproof-contracts` deployment.

It is designed to validate:

- `publishing`
- `comments`
- likes / unlikes
- paper owner to comments tree owner synchronization
- governance proposal creation and voting
- next-day governance finalization and token reclaim

It intentionally **does not execute any successful executable governance action**.

## Files

- [mainnet-functional-test.mjs](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/mainnet-functional-test.mjs)
  - main write-phase test script
  - runs all same-day publishing / comments / like / governance-create-and-vote actions
  - stops before governance finalize / claim
- [mainnet-governance-finalize.mjs](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/mainnet-governance-finalize.mjs)
  - next-day finalize script
  - currently hardcoded for the live mainnet governance test proposal
  - if the outcome is already mathematically fixed while voting is still open,
    it first tries `resolve_proposal_early`
  - otherwise it finalizes the active proposal after its end epoch
  - reclaims proposer-locked `PPRF`
- [paperproof-mainnet-common.mjs](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/paperproof-mainnet-common.mjs)
  - shared helpers for:
    - key loading
    - Sui / Walrus clients
    - PDF stamping
    - Walrus upload
    - contract transactions
    - object reads
- [docs/Mainnet-Functional-Test-Plan.md](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/docs/Mainnet-Functional-Test-Plan.md)
  - functional test plan and expected coverage

## Prerequisites

This harness expects:

- `.env` to exist in this directory
- 3 configured Sui mainnet accounts:
  - `ADDR_1` / `PRIVATE_KEY_1`
  - `ADDR_2` / `PRIVATE_KEY_2`
  - `ADDR_3` / `PRIVATE_KEY_3`
- the canonical mainnet contracts and objects already deployed
- the two sample PDFs to exist under:
  - [paperSamples](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/paperSamples)

The current scripts assume the canonical mainnet deployment described in:

- [../docs/Mainnet-Deployment-Record-2026-05-06.md](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/docs/Mainnet-Deployment-Record-2026-05-06.md)

## Install

From:

- `D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\jstest`

run:

```powershell
npm install
```

## Safe validation

This does **not** send any write transaction.

It validates:

- env account parsing
- key / address matching
- canonical object reachability
- current SUI / `PPRF` balances
- sample file presence
- current governance duration / threshold assumptions

Run:

```powershell
node .\mainnet-functional-test.mjs --validate
```

or:

```powershell
npm run validate
```

## Main write-phase test

This sends **real mainnet transactions**.

It covers:

- `ADDR_1 -> ADDR_3` transfer of `1 PPRF`
- optional small SUI / WAL prefunding for `ADDR_2` and `ADDR_3` when needed
- low-balance failed proposer attempts
- publish Paper A
- publish Paper B
- add version to Paper A
- extend storage for Paper A version 2
- like / unlike flow
- duplicate like / unlike-again failures
- Paper A comment tree with:
  - `3` top-level branches
  - depth `3`
  - one hidden node
  - one blob-backed reply under a hidden node
- Paper B owner transfer to `ADDR_3`
- comments tree governance sync after owner transfer
- locked-tree reject path and reopen-success path
- governance executable proposal creation by `ADDR_1`
- second proposal while active failure
- low-balance vote failure for `ADDR_2`
- low-balance vote failure for `ADDR_3`

It stops after proposal creation and voting, because the proposal must wait
until the next epoch before finalize.

Run:

```powershell
node .\mainnet-functional-test.mjs --run
```

or:

```powershell
npm run run
```

## Next-day governance finalize

The current repository already contains a hardcoded finalize script for the live
mainnet governance test proposal. In later rounds, the main script may rewrite
that helper with a new hardcoded proposal id and related invariants.

After the proposal epoch ends, run:

```powershell
node .\mainnet-governance-finalize.mjs
```

or:

```powershell
npm run finalize
```

That second script will:

- either resolve the proposal early when the result is already fixed, or
  finalize it after the end epoch
- verify it becomes `REJECTED`
- reclaim locked `PPRF` for `ADDR_1`
- verify `ADDR_2` / `ADDR_3` cannot claim because no successful vote was recorded
- verify a duplicate `ADDR_1` claim attempt fails
- verify `comments_fee_level` remains unchanged
- verify `active_proposal_id` is cleared

## Runtime outputs

The scripts write runtime artifacts to:

- [artifacts](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/artifacts)
- [logs](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/jstest/logs)

Typical outputs include:

- JSON run artifact
- markdown log
- markdown summary
- stamped output PDFs

These runtime files are ignored by Git.

## Important operating notes

- `ADDR_3` starts with `0 PPRF` in the expected test baseline
- repeated or partially completed runs may leave `ADDR_3` with `1 PPRF`; the
  current script tolerates either `0` or `1`
- because `like_paper` and governance proposal creation both require a `Coin<PPRF>`
  object input, the script proves the pre-transfer condition mainly by balance
  inspection and by low-balance proposer failures using `ADDR_2`
- governance voting has an on-chain minimum stake of `> 100 PPRF`, so `ADDR_2`
  and `ADDR_3` are expected to fail when attempting to cast `NO` votes
- current governance proposal duration is expected to be `1` epoch
- the main script refuses to proceed if an active proposal already exists
- the main script now blocks cleanly when a prior governance test proposal is
  still active
- the finalize script now has a dual settlement path:
  - `resolve_proposal_early` if the outcome is already mathematically fixed
  - `finalize_proposal` once the proposal end epoch has passed
- repeated mainnet runs are still not fully idempotent; they create fresh paper
  records and comments when allowed to proceed

## Recommended operator workflow

1. Run `--validate`
2. Inspect balances and current governance state
3. Run `--run`
4. Wait until the proposal epoch ends
5. Run `mainnet-governance-finalize.mjs`
6. Keep the generated artifacts for:
   - front-end configuration
   - manual verification
   - future regression comparison
