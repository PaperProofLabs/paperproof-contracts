# Governance Modes in PaperProof

## Overview

The current `PaperProof` governance system supports two distinct governance
modes:

1. **Directly executable governance**
2. **Signal / directional governance**

These two modes share the same proposal-and-voting infrastructure, but they
serve different purposes and produce different kinds of outcomes.

The distinction is intentional:

- some governance decisions should directly change protocol state
- some governance decisions should primarily express community will and guide
  off-chain execution, research, development, or ecosystem activity

This document explains both modes in detail.

## Shared Governance Foundations

Before the two modes diverge, they share the same underlying governance
mechanics:

- proposals are created on-chain
- proposal creation requires a locked `PPRF` proposer stake
- the proposer automatically records a `YES` vote with that locked stake
- additional voters lock `PPRF` into the proposal to vote
- each address may successfully vote only once per proposal
- a proposal remains active for `14` Sui epochs
- after the voting window ends, the proposal must be finalized on-chain
- locked voting funds are reclaimed later by the voter address itself

The current proposal passage rule requires both:

- `yes_votes * 3 >= no_votes * 4`
- `yes_votes * 10 > PPRF total_supply`

So a proposal passes only if:

- support clearly exceeds opposition, and
- support also exceeds ten percent of the total `PPRF` supply

## Mode 1: Directly Executable Governance

## Definition

Directly executable governance is used for decisions that should produce a
concrete change to on-chain protocol state after a successful vote.

In this mode:

1. a proposal is created
2. the proposal is voted on
3. the proposal is finalized
4. a follow-up on-chain transaction calls `execute_proposal`
5. the proposal outcome is applied to protocol state

So, passage alone does **not** immediately mutate state. A passed executable
proposal still requires an execution transaction.

This is a normal and deliberate separation between:

- governance legitimacy (`vote` + `finalize`)
- protocol execution (`execute_proposal`)

## What It Is Used For

This mode is appropriate when the governance result should directly alter
protocol configuration, authority, or routing.

In the current implementation, executable governance supports the following
actions:

- `SET_PUBLISHING_FEE_LEVEL`
- `SET_COMMENTS_FEE_LEVEL`
- `SET_FEE_RECIPIENT`
- `NOMINATE_OPERATOR`
- `SET_PROPOSAL_CREATION_PAUSED`
- `SET_PROPOSER_THRESHOLD`
- `SET_UPGRADE_AUTHORITY`

These actions affect one or more of:

- `GovernanceVault`
- `GovernanceConfig`
- operator nomination flow
- fee configuration
- governance access conditions

## Current Executable Governance Content

### 1. Publishing Fee Level

Governance can change the protocol-level fee charged in:

- `publishing::finalize_paper`
- `publishing::add_version`

This directly affects protocol pricing for paper publication and version
updates.

### 2. Comments Fee Level

Governance can change the protocol-level fee charged in:

- `comments::add_onchain_comment`
- `comments::add_blob_comment`

This directly affects protocol pricing for discussion activity.

### 3. Fee Recipient

Governance can change the `fee_recipient` address.

This allows the protocol to redirect fee income to:

- a team-controlled address
- a treasury-controlled address
- a later treasury contract or treasury custody path

### 4. Operator Nomination

Governance can nominate a new operator.

This does not directly replace the current operator in one step. Instead, it
initiates the operator handoff path handled in the `governance` package. This
preserves the protocol's separation between:

- legitimacy layer
- execution layer

### 5. Proposal Creation Pause

Governance can pause or unpause proposal creation.

This is a protocol-level governance management control that can be useful for:

- emergency situations
- governance maintenance windows
- temporarily freezing new proposal creation

### 6. Proposer Threshold

Governance can change the proposer threshold itself through the same governance
system.

This means the community can tighten or loosen the minimum proposal stake
requirement without introducing a separate governance channel.

The current allowed range is:

- minimum: `100,000 PPRF`
- maximum: `1,000,000,000 PPRF`

### 7. Upgrade Authority

Governance can also change the protocol's official `upgrade_authority`
address.

This address is intended to identify the account or custody path that should
control future package upgrades for the PaperProof contracts.

This is useful for:

- rotating upgrade control to a new operational address
- moving upgrade control into multisig or treasury custody later
- making upgrade-control changes subject to the same public governance process
  as other protocol authority changes

Important boundary:

- governance can record and update the official `upgrade_authority`
- actual Sui package upgrades still depend on the real `UpgradeCap` being held
  by that address or custody path

So this action governs the protocol-recognized upgrader identity, while the
real package-upgrade path must still be operationally aligned with Sui's
native upgrade model.

## Why Executable Governance Requires a Separate Execution Transaction

A passed executable proposal does not mutate state by itself.

Instead, the protocol deliberately requires:

- a successful vote
- proposal finalization
- a separate `execute_proposal` transaction

This pattern has several advantages:

- clearer execution trace
- explicit transition from governance result to protocol change
- reduced ambiguity about whether a proposal has merely passed or has actually
  been applied
- more controllable governance operations

So in PaperProof, executable governance is best understood as:

- **vote to authorize**
- **execute to apply**

## Typical Use Cases for Executable Governance

Examples of decisions that fit this mode:

- raising or lowering publishing fees
- adjusting comments fees
- redirecting fee revenue to a treasury
- rotating the official upgrade authority
- replacing the active operator
- changing proposal-spam resistance parameters

These are all protocol-state decisions and are therefore good candidates for
direct execution.

## Mode 2: Signal / Directional Governance

## Definition

Signal governance is used for decisions that should create a formal on-chain
governance outcome without directly modifying protocol state.

In this mode:

1. a proposal is created
2. the proposal is voted on
3. the proposal is finalized
4. the result becomes an on-chain record of community will
5. no direct protocol-state execution occurs

These proposals are intentionally **not** executable through
`execute_proposal`.

So signal governance is not about automatically changing the contract state.
Instead, it is about:

- recording a formal governance position
- expressing community intent
- authorizing or legitimizing off-chain action

## What It Is Used For

This mode is appropriate for matters that are too broad, too operational, or
too off-chain in nature to be represented as a simple contract state update.

In the current implementation, signal governance supports:

- `SIGNAL_REPLACE_OPERATOR`
- `SIGNAL_FEATURE_DIRECTION`
- `SIGNAL_POLICY_POSITION`

These are intentionally broad enough to support community decision-making that
does not map cleanly to a single on-chain state mutation.

## Current Signal Governance Content

### 1. Signal Replacement of Operator

This lets the community formally express that it believes the current operator
should be replaced, even if the protocol does not immediately perform that
replacement by execution.

This is useful when:

- the community wants to register dissatisfaction
- the matter requires additional coordination before an executable operator
  replacement proposal is submitted
- the signal itself is politically or operationally valuable

### 2. Signal Feature Direction

This lets the community indicate support or opposition for a future protocol or
product direction.

Typical examples:

- whether a new frontend should be developed
- whether a new product capability should be prioritized
- whether a certain interaction mode should be added
- whether a future storage or verification feature should be pursued

This is especially useful for research and development planning.

### 3. Signal Policy Position

This lets the community register support for a policy direction without
immediately translating that position into a parameter change.

Typical examples:

- content incentive programs
- off-chain points systems
- airdrop eligibility ideas
- moderation philosophy
- ecosystem participation rules
- research or partnership directions

## Why Signal Governance Matters

Not all legitimate governance questions are contract-parameter questions.

In many real protocol environments, some important decisions concern:

- development priorities
- operator legitimacy
- ecosystem incentives
- marketing or community campaigns
- off-chain treasury spending ideas
- roadmap sequencing

These matters may be too complex or too operationally broad to express as a
single state mutation inside a smart contract.

Signal governance gives the community a way to:

- express a formal position
- create a durable on-chain governance record
- provide legitimacy for downstream off-chain execution

## Typical Use Cases for Signal Governance

Examples of decisions that fit this mode:

- whether the project should launch a new official frontend
- whether a future protocol feature should be developed
- whether the community supports replacing an operator in principle
- whether an off-chain points campaign should be launched
- whether publishing and commenting activity should count toward a later
  airdrop policy

These do not necessarily require direct state change at vote time, but they
still benefit from formal governance backing.

## How Signal Governance Supports Off-Chain Execution

When a signal proposal passes, it does not change protocol parameters directly.

Instead, it provides:

- formal governance authorization
- recorded community legitimacy
- a public decision artifact that teams, operators, committees, and community
  actors can rely on

Examples:

- a passed feature-direction proposal can justify new development work
- a passed policy-position proposal can justify a new incentive program
- a passed operator-replacement signal can justify preparing a later executable
  replacement proposal

So signal governance should be understood as:

- **vote to express and authorize**
- **execute through social, operational, or later protocol processes**

## Relationship Between the Two Governance Modes

These two modes are not competitors. They are complementary.

### Executable Governance

Best for:

- contract-state changes
- authority changes
- fee changes
- governance parameter changes

### Signal Governance

Best for:

- roadmap direction
- community sentiment
- off-chain development
- incentive and policy direction
- matters that need legitimacy before implementation

Together they form a governance model in which:

- the protocol can directly change what should be contract-enforced
- the community can still govern broader project direction even when the matter
  is not reducible to a contract write

## Current Governance Boundary

At the current stage of `PaperProof`, governance already supports:

- **protocol parameter governance**
- **operator-related governance**
- **community will expression for non-parameter matters**

What it does not yet provide is:

- automatic execution of broad off-chain programs
- automatic execution of frontend development work
- automatic execution of points campaigns or airdrops

Those still require off-chain implementation, even when they have on-chain
governance legitimacy.

This is intentional and appropriate for the current protocol stage.

## Summary

The current `PaperProof` governance system supports two different but related
modes:

- **Directly executable governance**, for decisions that should directly change
  protocol state through an execution transaction
- **Signal governance**, for decisions that should register community will and
  support off-chain action without directly mutating contract state

This two-mode design allows `PaperProof` to govern both:

- what the protocol does on-chain
- and what the community wants the broader project to do beyond on-chain
  parameter updates
