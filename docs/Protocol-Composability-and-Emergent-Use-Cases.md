Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

# Protocol Composability and Emergent Use Cases

This document describes how PaperProof Protocol primitives may support a wide
range of ecosystem use cases beyond the protocol's original research-publishing
motivation. It is a product and ecosystem analysis document, not a promise that
PaperProof Labs will build, endorse, support, finance, list, or moderate every
use case described here.

Protocol events and objects record that actions occurred. They do not
automatically establish truth, legality, quality, peer review, safety,
investment value, or PaperProof Labs endorsement.

## 1. The Core Primitive

PaperProof can be understood as a durable identity and discussion layer for
public digital artifacts.

The protocol combines:

- typed artifact publication;
- stable public artifact codes;
- versioned records;
- content hashes;
- Walrus blob references;
- per-series comments trees;
- per-series likes books;
- PPRF-gated lightweight social signaling;
- governance events and proposals;
- replayable events for indexers and analytics.

This makes PaperProof broader than a single publication website. The protocol
can serve as an identity, versioning, discussion, and evidence layer for many
classes of public digital objects.

## 2. Built-In Artifact Types as Open Design Space

PaperProof currently supports six built-in artifact types:

- `preprint`
- `blog_post`
- `technical_report`
- `dataset`
- `software_release`
- `generic_file`

The original academic and research direction remains important, especially for
preprints, technical reports, datasets, and durable citations. However, the
same primitives can also support software releases, public statements, DAO
records, DeFi risk reports, agent-generated research, model cards, benchmark
snapshots, and other public artifacts.

This flexibility is intentional. PaperProof records durable artifact identity
and versioned references, while applications, indexers, communities, and
third-party frontends can decide how to interpret and present those records.

## 3. Emergent Content and Social Use Cases

## 3.1 Permanent Blog and Public Statement Layer

`blog_post` artifacts can store Markdown content packages on Walrus, including
text, images, and structured package manifests. This allows blog posts,
research notes, DAO updates, announcements, public statements, and long-form
commentary to have durable artifact codes and version history.

Possible products include:

- permanent blogs backed by artifact records;
- public statement archives;
- project update timelines;
- DAO weekly reports;
- research notebooks;
- announcement records with version history.

The value is not merely storage. The value is durable identity, verifiable
content references, and visible historical evolution.

## 3.2 Public Evidence and Commitment Records

PaperProof can be used to publish records that users want to make difficult to
erase or silently rewrite:

- project commitments;
- rule announcements;
- audit responses;
- incident explanations;
- grant policies;
- hackathon submissions;
- governance rationales;
- dispute timelines.

This may create a "public evidence repository" pattern where communities use
PaperProof artifact codes as stable references during disputes, reviews, or
coordination processes.

## 3.3 Object-Centered Forums

Every official artifact series is paired with an official comments tree and
likes book. This enables discussion to be organized around artifacts rather
than only around user profiles, feeds, or channels.

Third-party products may build:

- artifact-centered forums;
- version-specific discussion views;
- public review threads;
- issue discussions for software releases;
- dataset quality discussions;
- governance debate archives.

Because comments are bound to the artifact series, discussion can remain
connected to the underlying public object even if different frontends present
the discussion differently.

## 3.4 Lightweight Reputation and Curation

PaperProof likes require a minimal PPRF balance proof. This gives likes a
different meaning from ordinary free social clicks. A like can become a
lightweight signal from a protocol participant.

Potential product layers include:

- PPRF-holder curated lists;
- community-backed artifact rankings;
- active-voter or active-curator profiles;
- artifact discovery by participant signals;
- incentive eligibility based on transparent activity history.

Such systems should be designed carefully. A like is a protocol action and a
social signal, not proof of truth, quality, legality, or endorsement by
PaperProof Labs.

## 4. Lightweight Social and Meme-Native Use Cases

PaperProof's most formal use cases are research, datasets, reports, and
software releases. However, public networks often develop high-energy social
behaviors around simpler patterns: being early, making public predictions,
claiming origin, preserving community moments, and proving that a statement
existed before it became important.

These use cases are not the same as academic credibility or protocol
endorsement. They are examples of how third-party frontends and communities
may use the same durable artifact primitives for lighter social products.

## 4.1 Proof-of-First

Users may use PaperProof to claim that they were early to a phrase, idea,
prediction, meme, bug report, market thesis, or public observation.

Possible patterns include:

- first public prediction records;
- first public bug-discovery notes;
- first public meme or phrase records;
- first public project thesis;
- first public critique or risk warning.

The protocol cannot prove that an idea never existed elsewhere before. It can
prove that a specific artifact was recorded through PaperProof at a specific
time with a specific content reference.

## 4.2 Public Flags, Challenges, and Accountability

PaperProof can be used for public commitments and challenges:

- personal build commitments;
- public predictions;
- community challenges;
- bounty submissions;
- "I said this before" records;
- later versions, updates, or postmortems.

This may create social products where users voluntarily make statements that
are easy to revisit later. Some records may become reputation signals; others
may become community jokes or cautionary examples.

## 4.3 Meme Birth Certificates

Meme communities often care about origin stories, first versions, canonical
images, community slogans, and legendary moments. PaperProof can provide a
durable record for:

- original meme images or packages;
- community slogans;
- canonical meme variants;
- source posts or source files;
- later remixes and version history;
- comments and PPRF-holder signals around the artifact.

This does not turn a meme into official intellectual property, nor does it
guarantee ownership, licensing rights, or endorsement. It can still serve as a
public source-of-origin record for communities that value provenance.

## 4.4 Proof-of-Alpha and Market Commentary Records

DeFi and crypto communities often reward being early, being right, or publicly
warning others before events unfold. Third-party products may use PaperProof to
record:

- market theses;
- risk warnings;
- trading rationales;
- public alpha notes;
- later reviews of whether the thesis was right or wrong.

These artifacts should not be treated as investment advice. They are public
records of claims, reasoning, and commentary. Frontends should be careful to
avoid presenting them as guaranteed, endorsed, or reliable financial guidance.

## 4.5 Community Canon and Time Capsules

Communities may also use PaperProof to preserve:

- founding statements;
- public letters;
- community constitutions;
- major milestones;
- historical screenshots or files;
- time capsules;
- cultural archives;
- "hall of fame" or "hall of lessons" records.

This can give communities a durable memory layer without requiring every record
to be part of a formal governance process.

## 4.6 Separate Social Frontends

The official PaperProof interface can remain focused on serious artifact
publishing, protocol transparency, and durable records. More playful or
high-energy social behavior can be explored by separate third-party or
experimental frontends.

Possible product concepts include:

- Proof-of-First;
- AlphaProof;
- MemeProof;
- Onchain Receipts;
- public challenge boards;
- community canon explorers.

Keeping these surfaces distinct can help preserve the credibility of the
official protocol interface while still allowing the protocol ecosystem to
experiment with lighter social formats.

## 5. AI and Agentic Web Use Cases

## 5.1 Agent Memory and Artifact Identity

AI agents generate reports, summaries, plans, datasets, prompts, code,
evaluations, and decisions. These outputs often need stable references and
version history. PaperProof can serve as an artifact identity layer for agent
outputs.

Possible patterns include:

- agents publishing research logs;
- agents publishing task-completion records;
- agents referencing PaperProof artifact codes in generated reports;
- agent-generated datasets and benchmark snapshots;
- versioned model cards and evaluation notes;
- autonomous workflows that update artifact series over time.

In this model, PaperProof is not the agent itself. It is the durable memory,
evidence, and reference layer that agents can read from and write to.

## 5.2 Verifiable Citation Layer for Agents

Agent systems need reliable references to avoid losing context, fabricating
sources, or mixing stale and current information. PaperProof artifact codes,
content hashes, Walrus blob IDs, and version records can give agents stable
targets for citations and retrieval.

This can support:

- source-grounded agent reports;
- agent-to-agent artifact references;
- reproducible research workflows;
- verifiable AI-generated summaries;
- agent-curated knowledge collections.

## 6. Developer, Dataset, and Research Infrastructure

## 6.1 Software Release Registry

`software_release` artifacts can serve as durable release records for code,
plugins, packages, scripts, models, and deployment artifacts.

Possible fields and references include:

- version number;
- repository URL;
- commit hash;
- source archive hash;
- binary or package hash;
- license;
- changelog;
- audit references.

This does not replace GitHub, npm, crates.io, or PyPI. Instead, it can become
an independent evidence layer for what was released, by whom, at what time, and
with which content hash.

## 6.2 Dataset and Model Evidence Layer

`dataset` artifacts can support:

- dataset version records;
- schema snapshots;
- benchmark input sets;
- model evaluation datasets;
- training-data notes;
- data license declarations;
- reproducibility packages.

AI and data communities may use these records to establish durable references
for datasets and evaluations, especially when off-chain websites change or
disappear.

## 6.3 Open RFC and Technical Governance Hub

`technical_report`, `blog_post`, and `generic_file` artifacts can combine with
comments and governance to form an RFC-style workflow:

- publish a draft;
- collect comments;
- add updated versions;
- publish rationale documents;
- run governance proposals;
- preserve the full history.

This can be useful not only for PaperProof itself, but also for other Web3
projects that need durable proposal materials and transparent discussion
records.

## 7. DeFi-Adjacent Use Cases

PaperProof is not a DeFi protocol in the sense of being an AMM, lending market,
perpetuals venue, stablecoin, or vault. Its strongest DeFi potential is as a
trusted information, versioning, and evidence layer around DeFi products.

## 7.1 DeFi Strategy Registry

DeFi strategies often depend on written assumptions, parameters, backtests,
risk notes, data snapshots, and updates over time. PaperProof can record these
strategy artifacts without taking custody of funds.

Possible strategy records include:

- strategy description;
- parameter set;
- market assumptions;
- backtest data;
- risk disclosure;
- version changes;
- observed performance notes;
- linked code or bot configuration.

Vaults, agents, dashboards, or research communities could reference PaperProof
strategy artifacts as external evidence and documentation.

## 7.2 Risk Disclosure Layer

DeFi users often need to know what risks were disclosed before they interacted
with a protocol, pool, vault, or campaign. PaperProof can provide durable,
versioned risk artifacts.

Examples include:

- smart contract risk reports;
- oracle risk notes;
- liquidity risk disclosures;
- liquidation-risk explanations;
- admin-key and upgradeability disclosures;
- incident reports;
- post-mortems;
- risk-rating methodology.

This can make DeFi risk communication more auditable without requiring
PaperProof itself to custody user assets.

## 7.3 Incentive, Points, and Airdrop Evidence

DeFi ecosystems frequently run points programs, liquidity incentives, grants,
airdrops, and snapshot campaigns. Disputes often arise when rules change,
snapshots are unclear, or final datasets are not reproducible.

PaperProof can be used to record:

- campaign rules;
- eligibility criteria;
- snapshot methodology;
- input datasets;
- final output hashes;
- scripts or notebooks;
- appeals rules;
- updates and corrections.

This creates a transparent evidence trail for incentive programs. It does not
guarantee that any campaign will be fair, valuable, or legally compliant, but
it can make the record easier to inspect.

## 7.4 Agentic DeFi Memory Layer

DeFi agents may produce trading rationales, risk checks, vault-selection
recommendations, parameter updates, or governance voting explanations.
PaperProof can give those outputs durable references.

Possible patterns include:

- agents publishing strategy-intent artifacts;
- agents publishing risk observations before actions;
- agents attaching PaperProof references to automated workflows;
- vault frontends showing the latest PaperProof-backed strategy note;
- communities reviewing agent behavior through version history.

One possible phrase for this design space is:

```text
Proof-of-Strategy: a verifiable strategy and risk memory layer for DeFi agents,
vaults, and communities.
```

## 7.5 Governance Evidence for DeFi Protocols

DeFi governance often requires long-form reasoning, parameter analysis, risk
discussion, and historical accountability. PaperProof can support external
governance evidence records:

- proposal drafts;
- economic analysis;
- risk analysis;
- dissenting reports;
- implementation notes;
- execution postmortems;
- vote rationale archives.

These records may be referenced by other governance systems even when the vote
itself happens outside PaperProof.

## 8. Why Emergent Uses Matter

Many important protocols and platforms become valuable because users discover
uses that the original builders did not fully predict. PaperProof's
composability comes from small, durable primitives rather than from a single
closed application flow.

The most important reusable primitives are:

- stable artifact identity;
- content-addressed references;
- version history;
- per-artifact discussion;
- lightweight participant signaling;
- social provenance;
- governance and proposal records;
- indexer-friendly event history.

These primitives can be recombined by official applications, third-party
applications, agents, indexers, dashboards, research communities, and DeFi
frontends.

## 9. Boundaries

The existence of a possible use case does not mean that PaperProof Labs
endorses it or that official interfaces must display it.

PaperProof Labs and official interfaces may hide, label, delist, de-rank, stop
previewing, or stop caching artifacts, comments, links, or content for safety,
abuse, copyright, trademark, privacy, fraud, malware, spam, legal, or policy
reasons.

PaperProof Protocol should be treated as infrastructure. Users, third-party
interfaces, indexers, agents, dashboards, and communities remain responsible
for their own content, interpretation, moderation, compliance, and downstream
uses.

## 10. Summary

PaperProof may begin with research publishing, but the protocol primitive is
broader:

```text
durable identity and discussion for public digital artifacts
```

That primitive can support academic publishing, permanent blogs, public
statements, software releases, dataset records, AI-agent memory, DeFi strategy
evidence, incentive snapshots, governance materials, social provenance,
public challenges, meme-origin records, and many third-party products that may
not be designed or operated by PaperProof Labs.

This diversity is part of the protocol's long-term development potential.
