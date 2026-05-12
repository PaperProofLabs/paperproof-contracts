# PPRF Governance Voting

## Purpose

This document describes the implemented `PPRF` governance voting layer for the
PaperProof protocol.

`PPRF` is treated as part of the PaperProof protocol stack: the protocol's
governance, coordination, and participation asset, not an external token bolted
onto the system.

The voting layer extends the existing `governance` package, which already
provides:

- `GovernanceVault` as the root protocol authority holder;
- `OperatorPermit` as the revocable execution role;
- OpenZeppelin `two_step_transfer` for operator nomination and acceptance; and
- governance-controlled protocol fee settings, operator selection, direct
  authority sunset, and the official upgrade authority address.

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

- `ACTION_SET_COMMENTS_FEE_LEVEL`
- `ACTION_SET_FEE_RECIPIENT`
- `ACTION_NOMINATE_OPERATOR`
- `ACTION_SET_PROPOSAL_CREATION_PAUSED`
- `ACTION_SET_PROPOSER_THRESHOLD`
- `ACTION_SET_UPGRADE_AUTHORITY`
- `ACTION_SET_PROPOSAL_DURATION_EPOCHS`
- `ACTION_SET_ARTIFACT_TYPE_ENABLED`
- `ACTION_SET_ARTIFACT_FEE_LEVEL`
- `ACTION_ACTIVATE_ARTIFACT_TYPE`
- `ACTION_SET_GOVERNANCE_ACTION_ENABLED`
- `ACTION_SET_DIRECT_AUTHORITY_MODE`
- `ACTION_CANCEL_OPERATOR_TRANSFER`

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

## Proposal Text Bounds

Proposal creation rejects an empty title, titles longer than `256` bytes, and
descriptions longer than `4096` bytes. These limits are byte limits on the Move
`String` value and are enforced before the proposal object is created.

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

## Proposal Duration

The current governance system distinguishes between:

- the initial default proposal duration
- the governance-configured live proposal duration

### Initial Default

At initialization, governance starts with:

```text
proposal_duration_epochs = 1
```

This is intentionally short so the protocol can validate governance mechanics
and correct parameters during the earliest operating phase.

### Governance-Configurable Range

After initialization, proposal duration can be changed through governance
itself, but only within the following range:

- minimum governance-set duration: `7` epochs
- maximum governance-set duration: `14` epochs

So the rule is:

- the bootstrap default may be `1` epoch
- later governed runtime values must remain between `7` and `14` epochs

## Lock-Based Voting Model

The implemented governance system uses **token locking**, not free-floating
balance declarations.

### Core Rule

When voting on a proposal, the voter must submit a real `Coin<PPRF>` object to
the voting contract.

The contract:

- consumes that `Coin<PPRF>`;
- converts it into an internal locked balance stored inside the proposal; and
- records the locked voting position under the voter address inside the
  proposal state.

The locked `PPRF` remains inside the proposal until the proposal is finalized.

### Claiming Locked Tokens

After proposal finalization, the voter can reclaim their locked `PPRF` by
calling:

- `claim_locked_tokens`

from the same address that originally cast the vote.

The contract looks up the stored vote record for that address and releases the
corresponding locked `PPRF` back to the caller as a `Coin<PPRF>`.

### Why This Model Is Used

This model is used because it gives a strong protocol-level guarantee that:

- the same locked `PPRF` cannot be reused elsewhere while the proposal is
  active;
- double voting is prevented on-chain; and
- voting power remains under the governance contract’s direct control during
  the vote.

It avoids relying on:

- prior balance snapshots;
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
    proposer_threshold: u64,
    proposal_duration_epochs: u64,
    next_proposal_id: u64,
    proposal_creation_paused: bool,
    active_proposal_id: Option<u64>,
    proposal_id_to_object: Table<u64, ID>,
}
```

### Notes

- `pprf_total_supply` is the governance denominator.
- `proposer_threshold` is the minimum locked `PPRF` stake required to open a
  proposal.
- `proposal_duration_epochs` is the live governance voting duration used for
  newly created proposals.
- `proposal_creation_paused` allows governance to halt new proposal creation.
- `active_proposal_id` enforces the single-active-proposal rule.
- `proposal_id_to_object` binds each proposal number to the exact `Proposal`
  object ID. Finalization, early resolution, execution, and executor-cap
  proposal consumption must verify this binding before mutating proposal state.

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
    start_epoch: u64,
    end_epoch: u64,
    status: u8,
    executed: bool,
    votes: Table<address, VoteRecord>,
}
```

### Notes

- `yes_locked_balance` and `no_locked_balance` are the actual locked `PPRF`
  escrow pools for the proposal.
- `votes` stores exactly one vote record per address.
- the payload remains generic, but action dispatch is explicit.
## 3. `VoteRecord`

Per-address vote record stored inside the proposal.

```move
public struct VoteRecord has store, drop {
    side: u8,
    voting_power: u64,
}
```

### Notes

- one address can successfully vote only once per proposal;
- the stored record is later used by `claim_locked_tokens`; and
- no transferable receipt object is created, which avoids accidental loss or
  transfer of claim rights.

## Proposal Types

```move
const PROPOSAL_TYPE_EXECUTABLE: u8 = 1;
const PROPOSAL_TYPE_SIGNAL: u8 = 2;
```

## Action Types

### Directly Executable Actions

```move
const ACTION_SET_COMMENTS_FEE_LEVEL: u8 = 2;
const ACTION_SET_FEE_RECIPIENT: u8 = 3;
const ACTION_NOMINATE_OPERATOR: u8 = 4;
const ACTION_SET_PROPOSAL_CREATION_PAUSED: u8 = 5;
const ACTION_SET_PROPOSER_THRESHOLD: u8 = 6;
const ACTION_SET_UPGRADE_AUTHORITY: u8 = 7;
const ACTION_SET_PROPOSAL_DURATION_EPOCHS: u8 = 8;
const ACTION_SET_ARTIFACT_TYPE_ENABLED: u8 = 9;
const ACTION_SET_ARTIFACT_FEE_LEVEL: u8 = 10;
const ACTION_ACTIVATE_ARTIFACT_TYPE: u8 = 11;
const ACTION_SET_GOVERNANCE_ACTION_ENABLED: u8 = 12;
const ACTION_SET_DIRECT_AUTHORITY_MODE: u8 = 13;
const ACTION_CANCEL_OPERATOR_TRANSFER: u8 = 14;
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
const PROPOSAL_STATUS_EXPIRED: u8 = 5;
```

## Core Functions

### Initialize Governance Voting Config

```move
public fun new_governance_config(
    vault: &mut GovernanceVault,
    ctx: &mut TxContext,
): GovernanceConfig
```

Creating the governance config binds its object id into the corresponding
`GovernanceVault`. A vault can bind only one canonical config, and proposal
execution checks that the supplied config id matches the vault binding. This
prevents duplicate governance configs from creating parallel active-proposal
state or bypassing disabled-action settings.

Only the vault's `governance_authority` or recorded `upgrade_authority` can
create the governance config.

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
    proposer_stake: Coin<PPRF>,
    ctx: &mut TxContext,
): u64
```

This function aborts if:

- proposal creation is paused; or
- another proposal is already active.
- the proposer stake is below the current proposer threshold.
- the action type is disabled or the known executable action payload is invalid.

The proposal end epoch is computed from the current
`GovernanceConfig.proposal_duration_epochs` value.

### Vote Yes

```move
public fun vote_yes(
    proposal: &mut Proposal,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
)
```

### Vote No

```move
public fun vote_no(
    proposal: &mut Proposal,
    locked_tokens: Coin<PPRF>,
    ctx: &TxContext,
)
```

These functions:

- require the proposal to still be active;
- reject duplicate votes by the same address;
- require the locked amount to exceed `100 PPRF`; and
- lock the provided `Coin<PPRF>` into the proposal.

### Finalize Proposal

```move
public fun finalize_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    ctx: &TxContext,
)
```

Finalization:

- requires the voting period to have ended;
- determines `PASSED` or `REJECTED`;
- and clears `active_proposal_id`.

### Resolve Proposal Early

```move
public fun resolve_proposal_early(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
)
```

This function allows any caller to close an still-active proposal before
`end_epoch`, but only when the outcome is already mathematically fixed under
the current governance rule.

That means:

- a proposal may resolve early as `PASSED` when even allocating all remaining
  uncast voting supply to `NO` still cannot overturn it; or
- a proposal may resolve early as `REJECTED` when even allocating all
  remaining uncast voting supply to `YES` still cannot rescue it.

If the outcome is not yet determinable, the call aborts.

### Execute Proposal

```move
public fun execute_proposal(
    config: &mut GovernanceConfig,
    proposal: &mut Proposal,
    vault: &mut GovernanceVault,
    ctx: &mut TxContext,
)
```

Execution is restricted to:

- executable proposals only;
- proposals already finalized as `PASSED`;
- proposals not yet executed; and
- proposals whose execution window has not expired.

### Expire Passed Proposal

```move
public fun expire_passed_proposal(
    proposal: &mut Proposal,
    ctx: &TxContext,
)
```

This function:

- applies only to executable proposals;
- requires the proposal to still be in `PASSED` state;
- requires the execution window to have already expired; and
- marks the proposal as `EXPIRED`.

### Claim Locked Tokens

```move
public fun claim_locked_tokens(
    proposal: &mut Proposal,
    ctx: &mut TxContext,
): Coin<PPRF>
```

This function:

- requires the proposal to no longer be active;
- requires the caller address to already have a stored vote record for the
  proposal; and
- releases the corresponding locked `PPRF`.

## Execution Model

When a directly executable proposal passes:

1. the proposal remains a governance object with on-chain legitimacy;
2. the protocol can verify that its passage conditions were satisfied;
3. `execute_proposal` applies governance-internal results to `GovernanceVault`
   only if it is called within the execution-validity window; and
4. package-specific execution can use the official executor cap, consume the
   proposal into a `GovernanceActionTicket`, and apply the approved change in
   the target package.

Comments fee changes and publishing artifact actions use official executor
entrypoints backed by the `GovernanceActionExecutorCap` embedded in
`PaperProofRoot`. The vote remains in `governance_voting`; the approved action
is consumed into a linear `GovernanceActionTicket`, and the target module
applies the verified payload. The ticket has no `drop` ability, so a
transaction that creates one must consume it in the same transaction.

Comments fee changes update the official `FeeManager` through the publishing
executor entrypoint. Publishing artifact actions update `TypeRegistry` and
artifact fee entries through publishing execution entrypoints.

### Governance Action Availability

`GovernanceConfig` stores an action availability table.

Proposal creation requires the action to be enabled.

Execution intentionally does not re-check action availability. Once a proposal
has been created, voted, finalized, and passed, later disabling that action must
not become a retroactive veto over the already-approved proposal.

This lets maintainers ship code for a new governance action while keeping that
action unavailable until governance enables it, without weakening already-passed
governance decisions.

Known executable action payloads are also validated at proposal creation time.
Invalid fee levels, boolean fields, direct-authority modes, action-enable
targets, proposal-duration values, and required nonzero addresses are rejected
before voting begins. Artifact-action payload validation stays inside
`governance_voting` and uses pure helpers from `governance`; it does not import
`publishing`, preserving the package dependency direction.

The enabling path is itself a governance action:

```move
ACTION_SET_GOVERNANCE_ACTION_ENABLED
```

It can enable or disable other known actions, but it cannot disable itself.

`ACTION_CANCEL_OPERATOR_TRANSFER` has a dedicated execution entrypoint:

```move
governance_voting::execute_cancel_operator_transfer_proposal
```

It requires the pending transfer objects at execution time and is intentionally
not routed through the generic `execute_proposal` path.

### Execution Validity Window

Passed executable proposals do not remain executable forever.

The current implementation gives every passed executable proposal a fixed
execution-validity window of:

- `3` epochs after `end_epoch`

That means:

- if execution happens on time, the proposal becomes `EXECUTED`;
- if execution is attempted after the window, the proposal is marked
  `EXPIRED`; and
- any account may also explicitly call `expire_passed_proposal` after the
  window to clear a stale passed proposal into `EXPIRED`.

This prevents stale passed proposals from remaining executable indefinitely.

This means:

- `PPRF` voting defines what should happen;
- `GovernanceVault` is the canonical executor for governance-approved changes;
- the current operator remains an execution-layer role rather than the source
  of legitimacy.

### Early Resolution Model

PaperProof governance now supports two distinct ways to close an active
proposal:

1. normal finalization after `end_epoch` through `finalize_proposal`
2. early resolution before `end_epoch` through `resolve_proposal_early`, when
   the outcome is already fixed by arithmetic

This lets governance converge sooner when additional votes can no longer change
the result, while keeping closure permission open to any caller.

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

## 3. Direct Authority Sunset

`GovernanceVault` keeps a direct authority mode so the protocol can move toward
DAO-first operation without losing upgrade or recovery continuity.

The modes are:

- full
- emergency
- read-only
- disabled

`ACTION_SET_DIRECT_AUTHORITY_MODE` is controlled by PPRF voting. It can reduce
the direct authority surface, and disabled mode is irreversible.

This only gates direct `governance_authority` mutations. It does not disable
PPRF proposal execution, executor-cap proposal execution, `upgrade_authority`
upgrade/migration functions, or separately permit-gated operator actions.

## 4. Operator Role

The operator is not the source of governance legitimacy. The operator is a
revocable executor of day-to-day governance and protocol administration.

Artifact type activation and artifact-specific fee configuration are not
operator actions. They are protocol configuration changes and use executable
governance proposals.

The governance system should therefore be understood as:

- token governance decides;
- the vault applies;
- the operator executes routine work.

## 5. Use of `two_step_transfer`

OpenZeppelin `two_step_transfer` continues to be used for operator handoff, not
for root authority handoff.

In other words:

- root governance authority stays in `GovernanceVault`;
- operator nomination and acceptance continue to use
  `two_step_transfer`; and
- the operator role remains replaceable without risking loss of root governance
  continuity.

## 6. Directly Executable vs Signaling Governance

Directly executable proposals are used for:

- fee level changes;
- artifact type activation;
- artifact-specific fee changes;
- fee recipient changes;
- upgrade authority changes;
- proposal duration changes;
- operator nomination; and
- clearly bounded protocol configuration changes.

Signaling proposals are used for:

- feature direction;
- operator replacement sentiment;
- major policy positions; and
- broader community legitimacy questions that are not yet represented as
  immediate contract actions.

## 7. Enforcement Boundary

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

## 8. Governance-Managed Voting Window

PaperProof governance can now change the live voting window through the same
governance process, using:

- `ACTION_SET_PROPOSAL_DURATION_EPOCHS`

This means proposal duration is no longer treated as a permanently hardcoded
runtime value.

However, the live duration remains bounded:

- not below `7`
- not above `14`

This preserves a flexible production voting policy without allowing arbitrary
extreme durations through governance.

## 9. Bounded Execution Window for Passed Proposals

PaperProof also now distinguishes between:

- the voting window of a proposal; and
- the execution window of a passed executable proposal.

The voting window is governance-configurable within the allowed runtime range.

The execution window is currently fixed at:

- `3` epochs after `end_epoch`

This value is not currently governance-configurable. It exists to ensure that
stale passed proposals cannot remain executable forever.

## 10. Permissionless Proposal Closure

Proposal closure is intentionally permissionless.

Any account may:

- finalize a proposal after its voting window ends;
- resolve a proposal early if the result is already determinable; and
- mark a stale passed executable proposal as expired after its execution window
  has elapsed.

This prevents proposal lifecycle progress from depending on a single operator
or proposer address.

## Implemented Test Coverage

Current governance voting tests cover:

- creating and executing fee proposals;
- creating and executing upgrade-authority proposals;
- signal proposals that pass but are not executable;
- duplicate vote rejection;
- low-quorum rejection;
- early pass resolution while voting is still active;
- early rejection resolution while voting is still active;
- rejection of premature early-resolution attempts;
- single-active-proposal enforcement;
- operator nomination and handoff execution;
- proposer-threshold updates through governance itself;
- proposal-duration updates through governance itself; and
- late execution expiry and explicit expiry of stale passed proposals; and
- address-based token claims after proposal finalization.

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
- starts with a `1`-epoch default voting window and allows governance to move
  the live duration into the `7`-to-`14` epoch runtime range;
- gives passed executable proposals a fixed `3`-epoch execution-validity
  window after `end_epoch`;
- uses address-based post-finalization claims instead of transferable vote
  receipts;
- enforces that only one proposal may be active at a time; and
- preserves the separation between governance legitimacy, root authority, and
  operator execution.
