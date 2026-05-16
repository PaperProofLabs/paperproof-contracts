Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

# PaperProof Engagement Layer Design

This document defines a lightweight interaction layer for the PaperProof protocol. The goal is to increase sustained onchain activity and user adoption without weakening PaperProof's artifact-first positioning or degrading the usability of core protocol flows.

The Engagement Layer is designed as a protocol-adjacent module, not as a replacement for the core publishing, comments, and governance packages.

## 1. Design goals

The Engagement Layer should:

- increase low-friction onchain activity around artifacts and governance;
- improve user retention and repeat interaction;
- provide richer engagement signals than simple like and unlike toggles;
- avoid competing with core protocol state hot paths;
- preserve the serious, artifact-centric positioning of PaperProof;
- remain compatible with static frontends, SDKs, indexers, and future dynamic applications.

The Engagement Layer should not:

- turn PaperProof into a feed-first or profile-first social protocol;
- overload `ArtifactSeries`, `CommentsTree`, or `Proposal` with frequent state writes;
- allow incentives to be trivially farmed through high-frequency low-information actions;
- make publishing, versioning, comments, or governance noticeably slower or more expensive.

## 2. Core design principle

The most important principle is:

> Lightweight engagement must live beside the core protocol, not inside its hottest shared state.

In practice, this means:

- no frequent engagement writes to `ArtifactSeries`;
- no frequent engagement writes to `CommentsTree`;
- no frequent engagement writes to `Proposal`;
- engagement should prefer standalone events and lightweight receipts;
- aggregations should primarily be reconstructed offchain by indexers.

This keeps the core artifact lifecycle clean and prevents lightweight interaction traffic from competing with high-value protocol actions.

## 3. Positioning relative to the core protocol

PaperProof already has heavyweight or semantically rich core actions:

- publish artifact;
- add version;
- add comment;
- blob comment;
- governance proposal;
- vote;
- proposal execution.

These should remain the canonical protocol actions.

The Engagement Layer should add low-friction companion actions such as:

- react;
- bookmark;
- mark as read;
- follow artifact series;
- watch governance proposal;
- optionally express lightweight share or recommendation intent.

These actions are not meant to replace comments or governance participation. They are meant to lower the threshold for recurring interaction and create a broader usage funnel that can later lead into higher-value actions.

## 4. Why a separate Engagement Layer is needed

The current protocol has relatively high damping for frequent interaction:

- publish and add-version flows are intentionally heavy and meaningful;
- comment flows write persistent state and may require fees;
- governance requires stake, proposal lifecycle handling, and explicit transitions;
- like and unlike are currently lightweight, but too low-information to serve as the primary activity flywheel.

This means PaperProof is strong as an artifact protocol, but it does not yet have a well-shaped lightweight interaction layer that can safely increase everyday activity.

The Engagement Layer fills that gap without diluting the artifact model.

## 5. Recommended lightweight actions

The first recommended version should support the following actions.

### 5.1 Reaction

Users should be able to set a lightweight reaction on an artifact.

Recommended reaction types:

- useful
- insightful
- novel
- reproducible
- want_more

Important design constraints:

- this should be a set or overwrite action, not a score-farming toggle loop;
- each address should hold at most one current reaction per target;
- changing the reaction should overwrite the prior state rather than accumulate repeated event value.

This gives more semantic value than a binary like while remaining lightweight.

### 5.2 Bookmark

Users should be able to bookmark an artifact or proposal for later reference.

Bookmark is primarily a personal utility action, but it also provides a meaningful engagement signal for applications and indexers.

Recommended constraints:

- per-address current state only;
- no need for heavy onchain aggregation;
- can be free or micro-fee.

### 5.3 Read mark

Users should be able to mark an artifact as read, viewed, or acknowledged.

This is one of the best candidates for increasing activity, but it must be designed with anti-spam constraints.

Recommended constraints:

- same address, same target: at most one effective read signal within a cooldown window;
- no manual un-read needed at protocol level;
- intended mainly for event generation and offchain aggregation.

Suggested default cooldown:

- 24 hours per address per target.

### 5.4 Follow series

Users should be able to follow an `ArtifactSeries` to express ongoing interest in future versions.

This aligns well with PaperProof's versioned artifact model and is better than user-follow graphs for the protocol's intended domain.

Recommended constraints:

- current state only;
- low-frequency action;
- useful for notification systems, update feeds, and interest inference.

### 5.5 Watch proposal

Users should be able to watch a governance proposal without yet voting.

This creates a meaningful low-friction governance entry point and can increase governance page activity without interfering with the actual voting mechanism.

Recommended constraints:

- current state only;
- useful for frontend reminders and proposal popularity metrics;
- should not affect proposal outcome.

## 6. Actions not recommended for v1

The following are intentionally excluded from the first version:

- full social follow graph;
- repost or quote mechanics;
- user-to-user feed relationships;
- chain-level browsing history for every page view;
- automatic onchain logging of every Copilot interaction;
- general-purpose profile social layer.

These would push PaperProof toward a social protocol identity and create unnecessary state and spam pressure.

## 7. Protocol architecture

The recommended architecture is a separate Move package:

- `paperproof_engagement`

This package should be protocol-recognized, but not protocol-central.

### 7.1 Weak coupling to core packages

The Engagement Layer should establish formal association with the PaperProof protocol, but remain weakly coupled.

Recommended properties:

- separate package;
- separate objects and events;
- no mandatory writes into publishing, comments, or governance core objects;
- can be independently upgraded;
- can be independently indexed.

### 7.2 Protocol-recognized extension

The Engagement Layer should not be a random external add-on. It should be formally recognized as an official protocol extension.

Recommended mechanism:

- a lightweight extension registry or module registry entry;
- registered as an official module kind such as `engagement`;
- package ID and schema version discoverable onchain;
- enabled status governed by the protocol.

This allows frontends, SDKs, indexers, and third-party applications to discover and trust the engagement module as part of the PaperProof ecosystem.

## 8. Governance relationship

The Engagement Layer should be governed, but not deeply entangled with the hottest governance state paths.

### 8.1 Recommended governance relationship

The governance layer should be able to:

- enable or disable engagement action types;
- set fee levels for engagement actions;
- set cooldown windows for engagement actions such as read marks;
- determine which actions count toward official engagement metrics.

### 8.2 What governance should not do

Governance should not:

- require proposal approval for routine engagement use;
- make every engagement action depend on heavyweight governance reads or transitions;
- tie normal engagement execution to proposal objects.

The Engagement Layer should be policy-controlled, not proposal-path-dependent.

## 9. Storage model

The storage model must avoid hot shared-object contention.

### 9.1 Strong recommendation: receipt plus event model

The preferred design is:

- emit engagement events;
- optionally store a minimal per-user receipt for current state;
- perform most aggregation offchain.

Examples:

- reaction receipt for `(user, target)` current reaction;
- bookmark receipt for `(user, target)` bookmarked state;
- follow receipt for `(user, target)` followed state;
- watch receipt for `(user, proposal)` watched state.

### 9.2 Avoid embedding engagement counters in core objects

Do not continuously mutate:

- `ArtifactSeries`
- `CommentsTree`
- `Proposal`

to store frequent engagement counts.

Even if such fields appear convenient for UI reads, they will pull lightweight activity into the most valuable protocol state and create avoidable write contention.

### 9.3 Aggregation strategy

The recommended aggregation model is:

- events onchain;
- indexer reconstructs totals, unique users, cooldown-aware engagement, and trending scores;
- official frontend reads aggregated engagement data from indexed views.

This is the best tradeoff between activity, usability, and protocol cleanliness.

## 10. Anti-spam and anti-farming rules

The Engagement Layer should increase activity, but not turn into a farmable noise engine.

### 10.1 State-over-count for repeatable actions

For actions like:

- reaction
- bookmark
- follow
- watch

the protocol should track current state, not reward event count.

Users may change state, but repeated flipping should not directly create higher official engagement weight.

### 10.2 Cooldowns

Actions that are naturally repeatable should have cooldowns.

Recommended examples:

- read mark: 24h cooldown per address per target;
- share intent: 24h cooldown per address per target, if implemented later.

### 10.3 Event count must not equal official heat

Official heat and ranking systems should not use raw event count directly.

Instead they should weight:

- unique addresses;
- action type;
- time decay;
- relation to high-value actions;
- sustained behavior rather than toggling.

This prevents simple loops from dominating perceived protocol activity.

### 10.4 Incentives must not pay per raw action

If PPRF incentives later touch engagement data, rewards should not be:

- per reaction;
- per bookmark;
- per like-like toggle;
- per repeated read mark event.

Instead, incentives should depend on de-noised, aggregated behavior patterns.

## 11. Interaction with PPRF incentives

The Engagement Layer can support future PPRF-based ecosystem growth, but only carefully.

Recommended role:

- provide behavioral inputs;
- expand the top of the funnel;
- increase the number of meaningful recurring users;
- help identify transition from light engagement to heavy engagement.

Not recommended:

- direct faucet-like rewards for every lightweight action.

Better reward candidates:

- bookmark then later comment;
- watch proposal then later vote;
- follow series then later engage with new versions;
- repeated reading across a thematic cluster followed by substantive participation.

This preserves signal quality.

## 12. Suggested first-version scope

The recommended P0 scope is:

1. reaction set
2. bookmark
3. read mark with cooldown
4. follow series

Optional P1:

5. watch proposal

This scope is enough to:

- raise repeat activity;
- create richer product interactions;
- avoid social-protocol drift;
- keep implementation manageable.

## 13. Frontend integration guidance

The Engagement Layer should be present, but should not visually overpower the core artifact actions.

### 13.1 Artifact detail page

Recommended placement:

- below primary artifact metadata and core actions;
- near comments and version history, but visually secondary.

Recommended actions:

- react
- bookmark
- mark as read
- follow updates

### 13.2 Governance page

Recommended actions:

- watch proposal
- bookmark proposal

Voting remains the primary governance action. Watching is a low-friction companion action.

### 13.3 Explore and list pages

Frontend should display:

- aggregated engagement summaries;
- trend indicators;
- follow and bookmark hints where relevant.

List pages should not perform heavy direct onchain engagement reads. They should rely on indexed or cached aggregation data.

## 14. Indexer guidance

The Engagement Layer should be designed to be indexer-friendly from the start.

Recommended indexer outputs:

- current reaction summary by artifact;
- unique bookmark count;
- unique follower count;
- unique recent read marks;
- proposal watch count;
- time-windowed trending scores.

Recommended official heat score inputs:

- unique address participation;
- time decay;
- action weights;
- conversion into comments, versions, or governance.

The official frontend should use these indexed summaries rather than directly inferring heat from raw chain activity.

## 15. SDK guidance

SDKs should expose:

- builders for engagement actions;
- typed event decoders;
- current receipt state queries where applicable;
- optional helper utilities for cooldown-aware UX.

SDKs should not assume that raw event count equals meaningful popularity.

## 16. Package association with the main protocol

The Engagement Layer should be formally associated with PaperProof by protocol-level registration.

Recommended mechanism:

- a lightweight extension registry or module registry;
- module kind `engagement`;
- package ID recorded onchain;
- enabled flag recorded onchain;
- schema version recorded onchain.

Recommended governance control:

- engagement action enablement;
- engagement fee level;
- cooldown configuration;
- official scoring eligibility.

This gives the engagement package a formal place in the ecosystem while keeping it outside the core artifact state path.

## 17. Summary

The Engagement Layer should be understood as:

> a lightweight, protocol-recognized, event-first interaction layer that increases activity around artifacts and governance without competing with PaperProof's core publishing, comments, and voting state.

Its purpose is not to make PaperProof a social protocol.

Its purpose is to:

- widen the participation funnel;
- increase recurring chain activity;
- strengthen adoption across Sui and Walrus;
- create richer signals for applications and future incentives;
- preserve the seriousness of the artifact-first core.

The correct design choice is weak coupling, lightweight receipts, event-first architecture, governance-managed policy, and offchain aggregation for heat and ranking.
