# PPRF Utility Paths

This document describes the utility paths of the native PaperProof token,
`PPRF`, from two perspectives:

- protocol-native utility paths that are already implemented or directly
  supported by the current contracts; and
- non-protocol or protocol-adjacent utility paths that can be supported by the
  frontend, community processes, ecosystem tooling, and future extensions.

The goal of this document is not to present `PPRF` as a generic all-purpose
token, but to describe how `PPRF` is meaningfully empowered within the current
PaperProof system and how it can be extended without distorting the protocol's
architecture.

## 1. Core Positioning

At the current stage of the protocol, `PPRF` should be understood primarily as:

- the native governance-control token of the PaperProof ecosystem;
- the legitimacy anchor for protocol-level decisions; and
- a token with clear extension paths toward treasury, ecosystem coordination,
  and incentive design.

It is not currently:

- the mandatory payment token for protocol usage fees;
- a revenue-sharing token;
- a staking-yield token; or
- a buyback/burn token with already implemented economic reflex loops.

The current system collects protocol usage fees in `SUI`, not in `PPRF`.

## 2. Protocol-Native Utility Paths

The strongest current utility of `PPRF` is inside the governance layer.

## 2.1 Voting Power

The governance contracts require real `Coin<PPRF>` objects for voting.

This means:

- a vote is not just a declared number;
- a voter must lock actual `PPRF` into the proposal; and
- the proposal directly records the locked token value.

This gives `PPRF` the most important protocol-native utility already in
production:

- **`PPRF` is the on-chain voting-power asset of PaperProof governance.**

This is implemented through:

- `vote_yes`
- `vote_no`
- `claim_locked_tokens`

in:

- [D:\Works\VscodeProject\PaperProofLabs\paperproof-contracts\governance\sources\governance_voting.move](D:/Works/VscodeProject/PaperProofLabs/paperproof-contracts/governance/sources/governance_voting.move)

## 2.2 Proposal Creation Power

`PPRF` also gates proposal creation.

To create a proposal, the proposer must lock at least the current
`proposer_threshold` amount of `PPRF`. That stake is:

- locked just like normal voting stake;
- counted as a default `YES` vote; and
- reclaimed later through the same address-based claim path after proposal end.

This means `PPRF` is not only used to vote on proposals, but also to decide who
can responsibly open one.

As a result, `PPRF` already has a second strong native utility:

- **proposal-entry power and anti-spam governance gating**

## 2.3 Protocol Parameter Control

The current governance layer allows `PPRF` voting to directly affect important
protocol parameters.

Currently implemented executable governance actions include:

- `ACTION_SET_PUBLISHING_FEE_LEVEL`
- `ACTION_SET_COMMENTS_FEE_LEVEL`
- `ACTION_SET_FEE_RECIPIENT`
- `ACTION_NOMINATE_OPERATOR`
- `ACTION_SET_PROPOSAL_CREATION_PAUSED`
- `ACTION_SET_PROPOSER_THRESHOLD`
- `ACTION_SET_UPGRADE_AUTHORITY`

This means `PPRF` already empowers holders to change:

- protocol fee policy
- protocol income destination
- operator legitimacy
- governance entry conditions
- official upgrade authority

This is more meaningful than symbolic voting alone, because governance outcomes
can already change real protocol behavior.

## 2.4 Protocol Legitimacy for Signal Governance

Not every governance matter should directly change on-chain state.

The current contracts also support signaling proposals such as:

- `ACTION_SIGNAL_REPLACE_OPERATOR`
- `ACTION_SIGNAL_FEATURE_DIRECTION`
- `ACTION_SIGNAL_POLICY_POSITION`

This gives `PPRF` another native utility:

- **community legitimacy and formal policy signaling**

Even when a proposal does not execute a contract-state change, the result still
becomes a formal on-chain expression of ecosystem intent.

This is especially relevant for:

- feature direction
- operator replacement sentiment
- ecosystem policy positions
- community consensus-building

## 2.5 Governance Scarcity Through Single Active Proposal

The current governance model intentionally permits only one active proposal at a
time.

In that context, `PPRF` becomes a scarce governance-coordination resource:

- the token decides who can open the governance lane;
- the token decides who can dominate the current active proposal outcome; and
- the token determines who can credibly mobilize support in the only available
  active governance window.

This gives `PPRF` practical agenda-setting power inside the protocol.

## 2.6 Upgrade-Control Legitimacy

The protocol now includes:

- `upgrade_authority`
- managed `UpgradeCap` custody support
- versioned upgrade hooks

As a result, `PPRF` governance can influence:

- who is recognized as the official upgrade authority; and
- in practice, once `UpgradeCap` custody is correctly routed, who can control
  the package-upgrade path of the protocol.

This gives `PPRF` an especially important native role:

- **governing the continuity and evolution path of the protocol itself**

## 2.7 Access-Gated Social Utility Through Balance Proof

The comments layer currently requires a minimal `PPRF` balance proof for paper
likes and unlikes:

- a user must provide a `Coin<PPRF>` object with at least `1 PPRF`

This means `PPRF` already has a lightweight social-access role:

- **minimal participation credential for paper-like interactions**

This is not a heavy economic use, but it is still a native utility path inside
the protocol.

## 3. What Is Not Yet Native Utility

To keep the design honest, it is important to distinguish current utility from
future possibilities.

The following are **not yet implemented** as protocol-native `PPRF` utility:

- paying publication/comment fees in `PPRF`
- treasury disbursement controlled by `PPRF`
- staking for yield
- fee rebating to token holders
- burn mechanics
- buyback mechanics
- protocol revenue distribution

Those may become future paths, but they are not current contract behavior.

## 4. Near-Term Protocol-Adjacent Utility Paths

These are not all fully implemented on-chain today, but they are strongly
compatible with the current architecture.

## 4.1 Treasury Governance

Once a Treasury module is introduced, `PPRF` can naturally expand from:

- controlling fee policy

to:

- controlling protocol spending policy
- approving grants
- approving research/development budgets
- approving ecosystem incentives
- directing operational treasury flows

This would extend `PPRF` from a governance-control token into a governance-plus
treasury token.

## 4.2 Incentive-System Governance

PaperProof can eventually support token-governed incentive systems around:

- publishing activity
- commenting activity
- verification activity
- quality participation metrics
- ecosystem contribution scoring

Even before those systems become fully on-chain, `PPRF` already provides the
governance infrastructure that can approve or reject them.

## 4.3 Governance of Future Protocol Modules

Because the current contracts already support executable and signaling
governance, `PPRF` is well positioned to expand into future modules such as:

- Treasury
- incentives
- grants
- curation policies
- emergency governance
- long-term upgrade paths

So even where utility is not yet fully implemented, the direction is structurally
prepared.

## 5. Non-Protocol Utility Paths: Frontend and Product Layer

Some of the most meaningful future utility of `PPRF` may come from the frontend
and product layer rather than direct contract enforcement.

These paths should still be considered real utility, as long as they remain
consistent with the protocol architecture.

## 5.1 Governance UX and Participation Layer

The frontend can make `PPRF` more useful by turning governance from a raw
contract function into a visible social process:

- proposal dashboards
- voting participation screens
- quorum and passage visualizations
- operator-change transparency
- proposal history
- upgrade transparency

This does not create new token rights by itself, but it greatly increases the
practical usability of the token's existing governance power.

## 5.2 Reputation and Participation Display

The frontend can also give `PPRF` social meaning through product design.

Examples:

- showing whether a user is governance-eligible
- showing whether a user meets minimum governance thresholds
- highlighting proposal sponsors
- highlighting active voters
- showing governance history tied to addresses

This creates a visible governance identity layer around `PPRF`.

## 5.3 Community Access Patterns

The product layer could choose to grant soft privileges to `PPRF` holders, such
as:

- access to certain discussion spaces
- access to special front-end surfaces
- access to governance dashboards
- access to experimental tooling or features

These do not have to be permanent or absolute rights, but they are plausible
non-protocol utility paths.

## 5.4 Paper and Research Community Signaling

PaperProof is not only a token-governed protocol, but also a publishing and
research ecosystem.

The frontend and surrounding community can make `PPRF` relevant in ways such
as:

- indicating ecosystem support for a line of research
- highlighting community-backed initiatives
- indicating governance-backed feature priorities
- signaling long-term alignment with PaperProof as a public research protocol

## 6. Non-Protocol Utility Paths: Community and Ecosystem Layer

Some of the most important future utility of `PPRF` may emerge from community
practice rather than direct contract code.

## 6.1 Community Legitimacy

If the community comes to treat `PPRF` voting outcomes as the canonical voice
of protocol legitimacy, then `PPRF` gains strong social utility as:

- the token of official community mandate
- the token that validates major strategic shifts
- the token that anchors upgrade legitimacy

This is especially powerful for:

- replacing operators
- endorsing new directions
- approving ecosystem changes that may not be purely on-chain

## 6.2 Ecosystem Coordination

`PPRF` can also become useful as a coordination token across:

- community research contributors
- frontend contributors
- indexer/tooling maintainers
- moderators
- ecosystem builders

Even before all such coordination is hard-coded on-chain, the token can support
community practice by:

- indicating stakeholder alignment
- identifying serious participants
- expressing support in a scarce governance system

## 6.3 Incentive Campaigns and Airdrop Policy

Future community or operator-driven programs may use activity signals such as:

- paper publication
- versioning activity
- comment participation
- governance voting
- community contribution

to calculate points or eligibility for future `PPRF` distribution.

Even if such policies are initially coordinated off-chain, the current
governance system can already support them through signaling proposals and later
through more direct execution paths.

## 7. Design Constraints and Honesty Boundaries

Any token utility analysis should also state what should not be overstated.

## 7.1 `PPRF` is not currently the protocol fee token

The current contracts charge fees in `SUI`, not `PPRF`.

So any statement implying that `PPRF` is already the required medium of payment
for publishing/comments would be inaccurate.

## 7.2 `PPRF` does not yet carry treasury cashflow rights

The current system routes fees to `fee_recipient`, but there is no protocol
Treasury contract yet.

So any statement implying that `PPRF` already controls or receives treasury
flows directly would also be premature.

## 7.3 `PPRF` utility is strongest today in governance

The most defensible current statement is:

- `PPRF` is already a serious governance-control asset

and not:

- `PPRF` already has a fully built financial utility stack

## 8. Strategic Summary

The current protocol gives `PPRF` a real and non-trivial native role through:

- voting power
- proposal-entry power
- executable governance power
- signaling legitimacy
- upgrade-control legitimacy
- lightweight social access for paper-like actions

Beyond that, the architecture cleanly supports future expansion into:

- treasury governance
- incentive governance
- ecosystem coordination
- community participation and reputation layers
- product-level utility in frontend and social surfaces

## 9. One-Sentence Conclusion

`PPRF` is already meaningfully empowered as the native governance and protocol
legitimacy asset of PaperProof, and the current architecture leaves clear,
coherent paths for additional frontend-, community-, treasury-, and
incentive-layer utility without requiring the protocol to pretend that all of
those paths are already implemented today.
