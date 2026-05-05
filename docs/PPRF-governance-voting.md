# PPRF Governance Voting

## Purpose

This document describes the implemented `PPRF` governance voting layer for the
PaperProof protocol.

The voting layer extends the existing `governance` package, which already
provides:

- `GovernanceVault` as the root protocol authority holder;
- `OperatorPermit` as the revocable execution role;
- OpenZeppelin `two_step_transfer` for operator nomination and acceptance; and
- direct governance control over protocol fee settings and operator selection.

The `PPRF` voting layer adds a formal token-governance mechanism for:

- directly executable governance actions;
- signaling and opinion-recording proposals; and
- token-based legitimacy for protocol-wide decisions.

This package is now implemented in:

- [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\governance\sources\governance_voting.move](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/governance/sources/governance_voting.move)

## Relationship to Existing Governance

The current governance structure remains layered:

1. `PPRF` token voting produces governance legitimacy and proposal outcomes.
2. `GovernanceVault` receives and applies directly executable governance
   decisions.
3. The current operator continues to perform routine execution work under
   governance-defined legitimacy.

This preserves the separation between legitimacy and execution:

- token governance decides what should happen;
- `GovernanceVault` is the canonical root authority and application point; and
- the operator remains a revocable execution-layer role.

## Governance Categories

PaperProof governance distinguishes between two proposal categories.

### 1. Directly Executable Proposals

These proposals can be executed on-chain after passing.

Currently implemented executable actions are:

- `ACTION_SET_PUBLISHING_FEE_LEVEL`
- `ACTION_SET_COMMENTS_FEE_LEVEL`
- `ACTION_SET_FEE_RECIPIENT`
- `ACTION_NOMINATE_OPERATOR`
- `ACTION_SET_PROPOSAL_CREATION_PAUSED`

These proposals are intended to produce enforceable protocol changes.

### 2. Signaling Proposals

These proposals do not automatically modify protocol state, but record the
formal position of token governance.

Currently implemented signaling actions are:

- `ACTION_SIGNAL_REPLACE_OPERATOR`
- `ACTION_SIGNAL_FEATURE_DIRECTION`
- `ACTION_SIGNAL_POLICY_POSITION`

These proposals are intended to reflect community will and provide formal
governance evidence for subsequent off-chain or operational action.

## Total Voting Token Supply

For PaperProof governance, the total voting token supply is defined directly as
the `total_supply` recorded by the official `PPRF` token contract.

This means:

- the governance denominator is the full `PPRF total_supply`;
- no distinction is made at this stage between circulating, locked, treasury,
  or reserved supply; and
- governance quorum calculations use the full official supply as the fixed
  reference amount.

This definition is intentionally simple and explicit.

## Passage Rule

A proposal passes only if both of the following conditions are satisfied:

1. affirmative votes are at least four-thirds of negative votes:

```text
yes_votes * 3 >= no_votes * 4
```

2. affirmative votes exceed ten percent of `PPRF total_supply`:

```text
yes_votes * 10 > total_supply
```

These checks are implemented using integer arithmetic only.

## Lock-Based Voting Model

The implemented governance system uses **token locking**, not free-floating
balance declarations.

### Core Rule

When voting on a proposal, the voter must submit a real `Coin<PPRF>` object to
the voting contract.

The contract:

- consumes that `Coin<PPRF>`;
- converts it into an internal locked balance stored inside the proposal; and
- returns a `VoteReceipt` that proves the locked vote position.

The locked `PPRF` remains inside the proposal until the proposal is finalized.

### Claiming Locked Tokens

After proposal finalization, the voter can reclaim their locked `PPRF` by
calling:

- `claim_locked_tokens`

and presenting the corresponding `VoteReceipt`.

The receipt must match:

- the proposal;
- the original voter address; and
- the recorded vote side and voting power.

If these checks pass, the contract releases the locked `PPRF` back to the
caller as a `Coin<PPRF>`.

### Why This Model Is Used

This model is used because it gives a strong protocol-level guarantee that:

- the same locked `PPRF` cannot be reused elsewhere while the proposal is
  active;
- double voting is prevented on-chain; and
- voting power remains under the governance contract’s direct control during
  the vote.

It avoids relying on:

- historical balance snapshots;
- chain-external balance proofs; or
- post-hoc object-state validation of moving token objects.

## Single Active Proposal Rule

PaperProof governance adopts the rule that:

**at any given time, there may be at most one active proposal.**

This is enforced on-chain through `GovernanceConfig.active_proposal_id`.

Proposal creation will abort if another proposal is still active.

This rule is intentional. It simplifies:

- governance attention;
- quorum coordination;
- lock-based voting UX; and
- protocol-level enforcement of token locking.

Under this rule, the token-locking model does not prevent valid participation
in multiple simultaneous proposals, because simultaneous active proposals are
not allowed.

## Package Scope

The implemented governance voting package is responsible for:

- proposal creation;
- vote recording;
- vote-token locking;
- proposal finalization;
- execution of directly executable proposals;
- post-finalization claim of locked voting tokens; and
- emission of proposal and voting events.

It does not replace:

- `publishing`;
- `comments`; or
- the existing `governance` operator model.

Instead, it acts as the formal decision layer above them.

## Implemented Contract Structure

## 1. `GovernanceConfig`

Global governance configuration object.

```move
public struct GovernanceConfig has key {
    id: UID,
    registry_id: ID,
    pprf_total_supply: u64,
    voting_period_ms: u64,
    execution_delay_ms: u64,
    next_proposal_id: u64,
    proposal_creation_paused: bool,
    active_proposal_id: Option<u64>,
    proposal_id_to_object: Table<u64, ID>,
}
```

### Notes

- `pprf_total_supply` is the governance denominator.
- `voting_period_ms` defines how long proposals remain open.
- `execution_delay_ms` may be `0` or positive.
- `proposal_creation_paused` allows governance to halt new proposal creation.
- `active_proposal_id` enforces the single-active-proposal rule.

## 2. `Proposal`

Proposal object representing one governance item.

```move
public struct Proposal has key {
    id: UID,
    registry_id: ID,
    proposal_id: u64,
    proposer: address,
    proposal_type: u8,
    action_type: u8,
    title: String,
    description: String,
    payload_u64_1: u64,
    payload_u64_2: u64,
    payload_address: address,
    payload_object_id: Option<ID>,
    payload_bytes: vector<u8>,
    yes_votes: u64,
    no_votes: u64,
    yes_locked_balance: Balance<PPRF>,
    no_locked_balance: Balance<PPRF>,
    start_time_ms: u64,
    end_time_ms: u64,
    execution_earliest_ms: u64,
    status: u8,
    executed: bool,
    voters: Table<address, bool>,
}
```

### Notes

- `yes_locked_balance` and `no_locked_balance` are the actual locked `PPRF`
  escrow pools for the proposal.
- `voters` prevents one-address double voting.
- the payload remains generic, but action dispatch is explicit.

## 3. `VoteReceipt`

Vote record returned to the voter at voting time.

```move
public struct VoteReceipt has key, store {
    id: UID,
    proposal_id: u64,
    voter: address,
    side: u8,
    voting_power: u64,
    voted_at_ms: u64,
}
```

### Notes

- the receipt is required later to reclaim locked voting tokens;
- the voter must still be the caller of the claim transaction; and
- the receipt is consumed during `claim_locked_tokens`.

## Proposal Types

```move
const PROPOSAL_TYPE_EXECUTABLE: u8 = 1;
const PROPOSAL_TYPE_SIGNAL: u8 = 2;
```

## Action Types

### Directly Executable Actions

```move
const ACTION_SET_PUBLISHING_FEE_LEVEL: u8 = 1;
const ACTION_SET_COMMENTS_FEE_LEVEL: u8 = 2;
const ACTION_SET_FEE_RECIPIENT: u8 = 3;
const ACTION_NOMINATE_OPERATOR: u8 = 4;
const ACTION_SET_PROPOSAL_CREATION_PAUSED: u8 = 5;
```

### Signaling Actions

```move
const ACTION_SIGNAL_REPLACE_OPERATOR: u8 = 101;
const ACTION_SIGNAL_FEATURE_DIRECTION: u8 = 102;
const ACTION_SIGNAL_POLICY_POSITION: u8 = 103;
```

## Proposal Status Values

```move
const PROPOSAL_STATUS_ACTIVE: u8 = 1;
const PROPOSAL_STATUS_PASSED: u8 = 2;
const PROPOSAL_STATUS_REJECTED: u8 = 3;
const PROPOSAL_STATUS_EXECUTED: u8 = 4;
```

## Core Functions

### Initialize Governance Voting Config

```move
public fun new_governance_config(
    vault: &GovernanceVault,
    pprf_total_supply: u64,
    voting_period_ms: u64,
    execution_delay_ms: u64,
    ctx: &mut TxContext,
): GovernanceConfig
```

### Share Governance Config

```move
public fun share_governance_config(config: GovernanceConfig)
```

### Create Proposal

```move
public fun create_proposal(
    config: &mut GovernanceConfig,
    proposal_type: u8,
    action_type: u8,
    title: String,
    description: String,
    payload_u64_1: u64,
    payload_u64_2: u64,
    payload_address: address,
    payload_object_id: Option<ID>,
    payload_bytes: vector<u8>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): u64
```

This function aborts if:

- proposal creation is paused; or
- another proposal is already active.

### Vote Yes

```move
public fun vote_yes(
    proposal: &mut Proposal,
    locked_tokens: Coin<PPRF>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): VoteReceipt
```

### Vote No

```move
public fun vote_no(
    proposal: &mut Proposal,
    locked_tokens: Coin<PPRF>,
    clock_ref: &Clock,
    ctx: &mut TxContext,
): VoteReceipt
```

These functions:

- require the proposal to still be active;
- reject duplicate votes by the same address;
- lock the provided `Coin<PPRF>` into the proposal; and
- return a `VoteReceipt`.

### Finalize Proposal

```move
public fun finalize_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    clock_ref: &Clock,
)
```

Finalization:

- requires the voting period to have ended;
- determines `PASSED` or `REJECTED`;
- and clears `active_proposal_id`.

### Execute Proposal

```move
public fun execute_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    vault: &mut GovernanceVault,
    clock_ref: &Clock,
    ctx: &mut TxContext,
)
```

Execution is restricted to:

- executable proposals only;
- proposals already finalized as `PASSED`;
- proposals not yet executed; and
- proposals whose execution delay has elapsed.

### Claim Locked Tokens

```move
public fun claim_locked_tokens(
    proposal: &mut Proposal,
    receipt: VoteReceipt,
    ctx: &mut TxContext,
): Coin<PPRF>
```

This function:

- requires the proposal to no longer be active;
- requires the receipt to match the proposal;
- requires the caller to be the original voter; and
- releases the corresponding locked `PPRF`.

## Execution Model

When a directly executable proposal passes:

1. the proposal remains a governance object with on-chain legitimacy;
2. the protocol can verify that its passage conditions were satisfied;
3. `execute_proposal` applies the result to `GovernanceVault`; and
4. `GovernanceVault` acts as the bridge from token governance to protocol
   state.

This means:

- `PPRF` voting defines what should happen;
- `GovernanceVault` is the canonical executor for governance-approved changes;
- the current operator remains an execution-layer role rather than the source
  of legitimacy.

## Governance Rules

## 1. Legitimacy vs Execution

PaperProof governance distinguishes between:

- legitimacy: what the protocol community authorizes; and
- execution: what the current operator carries out in routine operation.

This distinction is already reflected in the base `governance` package and is
preserved by the voting layer.

## 2. Root Authority

The root authority of the protocol remains inside `GovernanceVault`.

This avoids the owner-custody trap that would arise if root governance power
were permanently held by an individual operator address.

## 3. Operator Role

The operator is not the source of governance legitimacy. The operator is a
revocable executor of day-to-day governance and protocol administration.

The governance system should therefore be understood as:

- token governance decides;
- the vault applies;
- the operator executes routine work.

## 4. Use of `two_step_transfer`

OpenZeppelin `two_step_transfer` continues to be used for operator handoff, not
for root authority handoff.

In other words:

- root governance authority stays in `GovernanceVault`;
- operator nomination and acceptance continue to use
  `two_step_transfer`; and
- the operator role remains replaceable without risking loss of root governance
  continuity.

## 5. Directly Executable vs Signaling Governance

Directly executable proposals are used for:

- fee level changes;
- fee recipient changes;
- operator nomination; and
- clearly bounded protocol configuration changes.

Signaling proposals are used for:

- feature direction;
- operator replacement sentiment;
- major policy positions; and
- broader community legitimacy questions that are not yet represented as
  immediate contract actions.

## 6. Enforcement Boundary

Any user who continues interacting with the official PaperProof protocol
contracts remains subject to:

- the official protocol fee logic;
- the official governance configuration; and
- the official execution authority derived from governance.

These are protocol-level rules, not merely frontend-level policies.

Users can only avoid them by leaving the official ecosystem and interacting
with a separate protocol deployment or fork.

## 7. Active Proposal Policy

PaperProof governance intentionally limits the system to one active proposal at
a time.

This policy is not merely social; it is also enforced on-chain. This ensures
that:

- lock-based voting remains simple;
- the same locked voting tokens are not expected to service multiple active
  proposals; and
- governance attention remains concentrated on one decision at a time.

## Implemented Test Coverage

Current governance voting tests cover:

- creating and executing fee proposals;
- signal proposals that pass but are not executable;
- duplicate vote rejection;
- low-quorum rejection;
- single-active-proposal enforcement;
- operator nomination and handoff execution;
- signal proposal execution rejection; and
- `VoteReceipt` ownership checks during token claims.

Related test files:

- [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\governance\tests\governance_voting_tests.move](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/governance/tests/governance_voting_tests.move)
- [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\governance\tests\governance_tests.move](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/governance/tests/governance_tests.move)

## Summary

The implemented `PPRF` governance voting layer is a decision-making system
above the existing PaperProof governance package. It:

- uses `PPRF total_supply` directly as the governance denominator;
- requires both a relative support threshold and an absolute support threshold;
- supports both executable and signaling proposals;
- uses lock-based voting with on-chain `Coin<PPRF>` custody;
- returns `VoteReceipt` objects for post-finalization claims;
- enforces that only one proposal may be active at a time; and
- preserves the separation between governance legitimacy, root authority, and
  operator execution.
