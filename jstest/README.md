# PaperProof JS Mainnet Harness

This directory contains live Sui mainnet scripts for the current PaperProof
deployment. The scripts are intended to be both an operational smoke test and a
frontend reference for building transaction blocks against the deployed
contracts.

## Current Scope

The main script covers the latest `artifact series / artifact version` model:

- preprint publish, metadata extensions, and second version
- software release publish using `node_modules/pdf-lib/package.json`
- comments tree creation through publishing
- on-chain comment, blob-backed comment, hidden-state negative case
- likes through the separate `LikesBook`, including duplicate like/unlike checks
- tree lock/reopen behavior
- artifact owner transfer and comments tree owner synchronization
- series metadata update by old/new owner
- signal governance proposal, counter-vote, early settlement, balance reclaim
- final PPRF conservation check across the four configured accounts

Only two artifact types are used:

- `preprint`
- `software_release`

The preprint path is the primary example.

## Files

- [mainnet-functional-test.mjs](./mainnet-functional-test.mjs)
  - validates the deployment and runs the full mainnet smoke flow
  - writes JSON artifacts and markdown logs
  - includes a PPRF protection path that attempts to settle an active proposal
    and return temporary balances if the script fails
- [paperproof-mainnet-common.mjs](./paperproof-mainnet-common.mjs)
  - current deployment constants
  - account loading
  - read helpers
  - transaction helpers for publishing, comments, likes, metadata, ownership,
    governance, and coin transfers
- [mainnet-governance-finalize.mjs](./mainnet-governance-finalize.mjs)
  - older standalone finalize utility kept for reference
  - the main flow now uses early settlement and normally does not need a next
    epoch finalize step
- [mainnet-native-prompts.mjs](./mainnet-native-prompts.mjs)
  - publishes the official app Copilot prompt as a PaperProof `generic_file`
    prompt package
  - registers `paperproof-app/copilot/global` in the deployed prompt registry
  - writes a summary under `artifacts/native-prompts`

Runtime outputs are written to:

- [artifacts](./artifacts)
- [logs](./logs)

These runtime files are ignored by Git.

## Install

From this directory:

```powershell
npm install
```

## Validate

Read-only validation:

```powershell
node .\mainnet-functional-test.mjs --validate
```

or:

```powershell
npm run validate
```

Validation checks:

- `.env` address/key consistency
- canonical root, registry, fee manager, vault, and governance config
- current role bindings to `ADDR_4`
- sample preprint PDF and software sample file presence
- SUI, WAL, and PPRF balances
- current `active_proposal_id`

## Run

This sends real Sui mainnet transactions:

```powershell
node .\mainnet-functional-test.mjs --run
```

or:

```powershell
npm run run
```

The script intentionally spends small SUI gas and may use small WAL/SUI funding
for participant accounts. PPRF is handled as a protected balance:

- temporary PPRF is sent only when a feature requires proof or staking
- the governance phase is settled in the same run when possible
- participant PPRF is returned to `ADDR_4`
- the script asserts the final PPRF total across `.env` accounts is unchanged

The latest successful run was:

- run id: `mainnet-current-smoke-2026-05-07T17-29-30-998Z`
- artifact:
  [artifacts/mainnet-current-smoke-2026-05-07T17-29-30-998Z.json](./artifacts/mainnet-current-smoke-2026-05-07T17-29-30-998Z.json)
- log:
  [logs/mainnet-current-smoke-2026-05-07T17-29-30-998Z.md](./logs/mainnet-current-smoke-2026-05-07T17-29-30-998Z.md)
- PPRF guard delta: `0`

Created example objects from that run:

- preprint series:
  `0xe89ef69f7f74db99ee8ff76c2151ea6be961b2005b333defbecb48d724df237b`
- preprint artifact code:
  `PaperProof-preprint-001120-e89ef69f7f74`
- preprint comments tree:
  `0xc27bb4ddbf6afca87af6422f4d78d139805308fe2f6b15cd2c0ea4b7f4b4d018`
- preprint likes book:
  `0xa4f06bfb6b2909b8e958e2977378a3600dbc3ed8dc64b92fa491a10dae427891`
- software release series:
  `0x9e7bdd016ebc68b1edc552a08715bee8c6e48b3afdeea8690cb4959a1942a2ed`
- software release artifact code:
  `PaperProof-software_release-001120-9e7bdd016ebc`
- governance proposal:
  `0x722f3a05da653ec107b739b39264c082187bbabe5b324952edc07e29e1dab65e`

## Frontend Reference Notes

Use [paperproof-mainnet-common.mjs](./paperproof-mainnet-common.mjs)
as the reference for:

- building `MetadataAttribute` values with `publishing::metadata_attribute`
- passing `vector<MetadataAttribute>` into publish/update calls
- using `noneSuiPayment(tx)` for optional free-fee payment paths
- reading series, versions, comments tree, likes book, and proposal objects
- treating `comments_tree_id` and `likes_book_id` as separate objects
- handling expected Move aborts as negative tests
- rebuilding transactions when Sui reports stale object versions

For production frontend code, keep private-key loading out of the browser. The
transaction-building shapes in this harness are the useful part; signing should
come from wallet adapters.

## Native Prompt Operations

The native prompt script is a mainnet write path for official operators. It
extracts the current `copilotGlobalPrompt` from the app source, encodes it as
`application/vnd.paperproof.prompt+json`, uploads the prompt package to Walrus,
publishes the package as a PaperProof `generic_file`, and registers the
resulting series/version with the prompt registry.

Current mainnet prompt deployment:

- prompt registry package:
  `0x10b9c6e90a896dc3244d047e32724d80de0dc697b5ea12c5fdd8925131ed4c59`
- prompt registry object:
  `0x14ec45eb83bb1b0eb22c7e885c7c71ea05b1e22dd05e3e1107dcef528600b0da`
- `copilot/global` prompt series:
  `0x13c99b4811d9b89fd0decd8e9c713bafd639e6af3401a18043aed7e0270044fb`
- first prompt version:
  `0x8963dd3178bfe759c2301c921beca0aac88a8e1eb286685ff70e98c862b01e5e`

Prompt registry writes are accepted only from the active operator recorded in
the official `GovernanceVault`. They do not require a governance vote or an
upgrade to the existing publishing/governance packages.
