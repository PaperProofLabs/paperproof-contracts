# Treasury and Fee Management

## Overview

This document summarizes the current fee-handling model implemented in the
`paperproof-contracts` repository and outlines the intended evolution toward a
dedicated `Treasury` contract for the `PaperProof` protocol.

The current protocol already enforces fee collection at the contract layer for:

- `publishing::finalize_paper`
- `publishing::add_version`
- `comments::add_onchain_comment`
- `comments::add_blob_comment`

The current protocol does **not** yet implement an on-chain treasury object that
holds, budgets, or disburses accumulated fee revenue.

## Current Fee Logic

### Fee Types

The protocol currently maintains two fee schedules inside `GovernanceVault`:

- `publishing_fee_level`
- `comments_fee_level`

These levels are interpreted by the `governance` package and applied in:

- `governance::collect_publishing_fee`
- `governance::collect_comments_fee`

The fees are charged in `SUI`, not in `PPRF`.

### Fee Recipient

The current implementation stores a single fee recipient inside
`GovernanceVault`:

- `fee_recipient: address`

When a publishing or comments fee is collected, the protocol immediately
transfers the required `SUI` amount to `fee_recipient`.

This means that the current system uses a **direct recipient model**, not an
on-chain treasury custody model.

### Official Fee Binding

Fee collection is now bound to the official protocol instance:

- `publishing` checks that the provided `GovernanceVault` belongs to the current
  `PaperRegistry`
- `comments` checks that the provided `GovernanceVault` belongs to the current
  `CommentsTree.registry_id`

As a result, protocol users cannot bypass fees by routing calls through an
unrelated vault with different fee settings.

## What the Current Model Can Do

The current model already supports:

- protocol-level fee enforcement
- governance-controlled fee level updates
- governance-controlled fee recipient updates
- immediate fee routing to a designated address

This is sufficient for:

- direct fee collection into a team-controlled address
- direct fee collection into a treasury-controlled address
- future migration from one treasury endpoint to another

## What the Current Model Does Not Yet Do

The current model does **not** yet support:

- holding fee balances inside a protocol treasury object
- querying treasury-controlled protocol revenue on-chain
- proposal-based treasury disbursements
- on-chain budgeting
- grant allocation
- revenue splitting inside the protocol

In other words, the current system lets governance decide:

- **how much is charged**
- **where fees are sent**

but not yet:

- **how accumulated fee revenue is managed after receipt**

## Current Operational Interpretation

Under the present design, the most realistic interpretation is:

- `PaperProof` protocol fees are collected by the contracts
- the contracts immediately transfer fee revenue to `fee_recipient`
- `fee_recipient` is treated as the operational sink for protocol income

If the `fee_recipient` is controlled by the development team, then protocol fees
already function as direct protocol revenue.

If the `fee_recipient` is controlled by a treasury wallet or treasury contract,
then protocol fees already function as treasury income.

## Treasury as a Future Dedicated Module

### Why Treasury Should Be Separate

A dedicated `Treasury` module is best treated as a separate contract package,
rather than embedded into:

- `publishing`
- `comments`
- `governance`

This keeps responsibilities clean:

- `publishing`: publication lifecycle and artifact binding
- `comments`: discussion tree management
- `governance`: governance legitimacy, operator authority, protocol parameters
- `treasury`: custody, budgeting, disbursement, and protocol financial policy

### Minimal Treasury Integration Path

The simplest future treasury integration path is:

1. deploy a dedicated `Treasury` contract or treasury-controlled address
2. set that treasury-controlled address as `fee_recipient`
3. keep existing `publishing/comments` fee logic unchanged

This allows a treasury to begin receiving protocol income without requiring a
large rewrite of existing fee collection logic.

## Two-Stage Treasury Evolution Plan

### Stage 1: Address-Based Treasury

In the first stage, Treasury can be implemented as a relatively independent
module or operational custody layer.

Key properties:

- the treasury controls a receiving address
- governance can update `fee_recipient` to that address
- protocol fees flow directly into treasury custody
- treasury disbursement is managed externally or by a simple treasury module

Advantages:

- minimal contract changes
- fast integration
- preserves current fee enforcement model
- allows future evolution without changing `publishing/comments`

Risks to avoid in Stage 1:

- making the treasury recipient irreversible
- binding treasury control to a non-recoverable personal key
- having no migration path for already-collected funds

### Stage 2: Governance-Integrated Treasury

In the second stage, Treasury can become more deeply integrated with protocol
governance.

Possible capabilities:

- treasury balance tracked by a shared treasury object
- proposal-based disbursement
- budget approval through `PPRF` governance
- operator-executed treasury actions authorized by passed proposals
- grants, development funding, and community spending logic

At this stage, governance would no longer control only:

- fee levels
- fee recipient

but also:

- treasury spending decisions
- treasury policy
- structured protocol resource allocation

## Why Stage 1 Does Not Block Stage 2

Stage 1 and Stage 2 are not inherently in conflict, provided that the initial
treasury setup preserves migration flexibility.

The current architecture already helps here because:

- `fee_recipient` is governance-controlled and can be changed
- `publishing/comments` depend only on `fee_recipient`, not on treasury internals
- a later treasury implementation can replace an earlier treasury endpoint

To preserve upgradeability, Stage 1 treasury design should ensure:

- treasury-controlled assets can be migrated
- treasury control can be rotated
- fee recipient can be updated by governance
- protocol modules do not hard-code treasury internals

If those conditions hold, a simple initial treasury does not prevent later
upgrading to a stronger governance-integrated treasury.

## Recommended Near-Term Direction

For the current `PaperProof` contract system, the most practical near-term path
is:

1. keep protocol fee enforcement in `publishing/comments`
2. keep fee configuration in `governance`
3. introduce Treasury later as a separate package
4. route protocol fees into Treasury by changing `fee_recipient`
5. only after that, expand governance execution into treasury spending

This preserves the modularity already present in the repository and avoids
premature coupling between protocol operations and financial management.

## Summary

The current `PaperProof` contracts already implement strong protocol-level fee
collection, but they do so through a direct recipient model rather than through
an on-chain treasury balance.

This is already useful and operationally valid.

The natural next step is not to rewrite fee collection, but to introduce a
dedicated Treasury module that can first receive fees as `fee_recipient`, and
later evolve into a governance-integrated treasury layer for disbursement,
budgeting, and ecosystem funding.
