# Governance Modes in PaperProof

PaperProof governance supports two modes:

1. executable governance
2. signal governance

Both modes use the same proposal and voting objects. They differ in whether a
passed proposal can mutate protocol state.

## Shared Rules

All proposals use lock-based `PPRF` voting:

- proposal creation requires a proposer stake
- the proposer stake is recorded as a `YES` vote
- voters lock `PPRF` into the proposal
- each address can vote once
- one proposal can be active at a time
- proposal finalization is required before execution or claim
- locked voting funds are reclaimed by address after the proposal is closed

The passage rule is:

```text
yes_votes * 3 >= no_votes * 4
yes_votes * 10 > PPRF total_supply
```

This requires both relative support and absolute support.

## Executable Governance

Executable proposals authorize on-chain state changes.

The lifecycle is:

1. create proposal
2. vote
3. finalize as `PASSED`
4. execute before `end_epoch + 3`
5. mark the proposal `EXECUTED`

Execution is intentionally separate from passage. Any account may submit the
execution transaction if the proposal is valid and still inside its execution
window.

## Direct Governance Actions

Some executable actions are handled entirely inside the governance package by
`governance_voting::execute_proposal`:

- `ACTION_SET_FEE_RECIPIENT`
- `ACTION_NOMINATE_OPERATOR`
- `ACTION_SET_PROPOSAL_CREATION_PAUSED`
- `ACTION_SET_PROPOSER_THRESHOLD`
- `ACTION_SET_UPGRADE_AUTHORITY`
- `ACTION_SET_PROPOSAL_DURATION_EPOCHS`
- `ACTION_SET_GOVERNANCE_ACTION_ENABLED`
- `ACTION_SET_DIRECT_AUTHORITY_MODE`

These affect `GovernanceVault`, `GovernanceConfig`, or the operator handoff
flow. They do not require a cross-package execution adapter.

## Governance Action Availability

`GovernanceConfig` maintains an action availability table.

Creating or executing a proposal requires the target action to be enabled. This
lets the package contain code for a protocol capability before that capability
is available as a live governance action.

`ACTION_SET_GOVERNANCE_ACTION_ENABLED` is the governance-controlled action used
to enable or disable other known actions. It cannot disable itself.

This supports the protocol rule:

```text
UpgradeCap makes code available.
Governance enables protocol capabilities.
```

## Proposal-Ticket Governance Actions

Fee-manager and publishing-specific artifact actions are executable governance
actions, but they are not executed directly by `governance_voting`.

Current proposal-ticket actions are:

- `ACTION_SET_COMMENTS_FEE_LEVEL`
- `ACTION_SET_ARTIFACT_TYPE_ENABLED`
- `ACTION_SET_ARTIFACT_FEE_LEVEL`
- `ACTION_ACTIVATE_ARTIFACT_TYPE`

Comments fee changes consume the proposal into a `GovernanceActionTicket` and
apply the approved fee level to `FeeManager`.

Publishing artifact actions are executed through publishing package entrypoints:

- `publishing::execute_artifact_type_enabled_proposal`
- `publishing::execute_artifact_fee_level_proposal`
- `publishing::execute_artifact_type_activation_proposal`

This is required because `publishing` depends on `governance`. If
`governance_voting` imported `publishing`, the packages would form a dependency
cycle.

## Governance Action Tickets

For proposal-ticket execution, `governance_voting` consumes a passed proposal
and returns a one-time `GovernanceActionTicket`.

The ticket is created only by:

```move
governance_voting::consume_executable_proposal_action
```

That function verifies:

- config and proposal versions
- registry ID
- proposal type is executable
- proposal status is `PASSED`
- proposal is not already executed
- action type matches the expected action
- execution window has not expired

It then marks the proposal executed and returns the ticket to the caller.

The ticket lets another package apply the already-approved action without
letting that package forge governance legitimacy.

`GovernanceActionTicket` is linear and has no `drop` ability. A transaction that
creates a ticket must pass it to the appropriate application function in the
same transaction.

## Operator Transfer Cancellation

Operator handoff cancellation can be triggered in two ways:

- direct authority, if the current direct-authority mode still permits that
  emergency operation
- executable PPRF governance through `ACTION_CANCEL_OPERATOR_TRANSFER`

The proposal execution path for cancellation takes the pending transfer objects
directly and clears the pending operator state after the governance proposal has
passed and while its execution window is still valid.

## Permissionless Execution

Proposal execution and proposal-ticket consumption are permissionless.

Any account may trigger execution if it supplies the correct objects and the
proposal satisfies the rules. This prevents a passed proposal from being held
hostage by an operator, proposer, or admin address.

The caller does not gain discretionary authority. The proposal payload and
action type determine what can happen.

## Operator Boundary

The operator remains useful for bounded operational work, such as emergency or
maintenance actions that the protocol deliberately keeps operator-gated.

Artifact type activation and artifact type fee changes are not operator
configuration. They are protocol configuration and should go through executable
governance.

## Direct Authority Sunset

`GovernanceVault` records a direct authority mode:

- full
- emergency
- read-only
- disabled

`ACTION_SET_DIRECT_AUTHORITY_MODE` lets token governance reduce or permanently
disable the direct authority surface.

The sunset mechanism only gates direct `governance_authority` mutations. It does
not block:

- PPRF proposal execution
- proposal-ticket execution
- `upgrade_authority` package upgrade and migration functions
- operator actions that are separately permit-gated

Emergency mode keeps narrow recovery operations available, such as
upgrade-authority recovery and operator nomination. Read-only and disabled modes
reject direct authority mutations. Disabled mode is irreversible.

## Signal Governance

Signal proposals create a formal on-chain governance outcome without direct
state mutation.

Current signal actions are:

- `ACTION_SIGNAL_REPLACE_OPERATOR`
- `ACTION_SIGNAL_FEATURE_DIRECTION`
- `ACTION_SIGNAL_POLICY_POSITION`

Signal proposals are useful for:

- roadmap direction
- operator sentiment
- ecosystem policy
- off-chain programs
- future feature prioritization

They are not executable through `execute_proposal`.

## Summary

PaperProof separates:

- governance legitimacy: voting and finalization
- protocol execution: applying passed executable proposals
- business-module execution: package-specific execution through proposal tickets
- operational response: limited operator-gated actions
- community intent: signal proposals

This keeps governance explicit without forcing every package to depend on every
other package.
