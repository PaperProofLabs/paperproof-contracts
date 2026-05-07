# Treasury and Fee Management

This document describes the current protocol fee model.

## Fee Surfaces

PaperProof uses `governance::FeeManager` as the canonical fee configuration
object.

It currently stores:

```text
fee_key -> fee_level
```

Publishing fees use artifact type IDs as fee keys:

```text
artifact_type -> fee_level -> SUI amount
```

Comments use the reserved comments fee key inside the same `FeeManager`.

If a fee key has no explicit fee level, it is treated as free.

## Fee Manager

`FeeManager` is a shared object bound to the official `PaperProofRoot` by
`registry_id`.

Both publishing and comments verify that the supplied `FeeManager` belongs to
the same registry as the official protocol root. A foreign fee manager cannot be
used to bypass fees.

## Fee Recipient

`GovernanceVault` stores:

```text
fee_recipient: address
```

When a fee is collected, the required `SUI` amount is transferred immediately to
that address. The contracts do not yet hold accumulated protocol revenue in a
treasury object.

Every successful nonzero fee collection emits `FeeCollectedEvent` with the
registry ID, fee key, artifact type when applicable, payer, recipient, and
amount. This gives treasury dashboards a direct event stream even though the
current contracts route revenue immediately instead of holding an on-chain
treasury balance.

## Governance Control

Fee configuration is protocol configuration.

Publishing artifact fees are changed by executable governance through proposal
tickets:

- `ACTION_SET_ARTIFACT_FEE_LEVEL`
- `ACTION_ACTIVATE_ARTIFACT_TYPE`

Comments fees are also stored in `FeeManager` and can be changed through the
comments fee governance action. After a proposal passes, a permissionless
execution transaction consumes the proposal into a `GovernanceActionTicket`,
then applies the approved comments fee level to `FeeManager`.

The direct authority path can still set the comments fee while direct authority
is in full mode. That path is intentionally sunsettable by governance and should
be treated as bootstrap or recovery surface rather than the normal operating
path.

## Fee Amounts

Fee levels are interpreted by the governance package:

- `FREE`
- `MICRO`
- `LOW`
- `STANDARD`
- `HIGH`
- `PREMIUM`

The concrete amounts are currently defined in `governance.move`.

## Current Capabilities

The current model supports:

- type-specific publishing fees
- comments fees in the shared `FeeManager`
- governance-controlled fee recipient changes
- proposal-gated artifact fee changes
- proposal-gated comments fee changes
- immediate routing of fee revenue
- foreign vault/fee manager rejection

It does not yet support:

- on-chain treasury balance accounting
- proposal-based treasury disbursement
- revenue splits
- grant budgeting

## Treasury Evolution

A dedicated treasury should remain a separate module or package.

Near-term path:

1. deploy or designate a treasury-controlled address
2. use governance to set `fee_recipient`
3. keep `FeeManager` as the canonical fee configuration object

Longer-term path:

1. introduce a treasury object
2. route fees into treasury custody
3. add governance-approved disbursement flows
4. optionally add budget, grant, or revenue-sharing policies

This keeps `publishing`, `comments`, `governance`, and future `treasury`
responsibilities separate.
