# PaperProof Core Contract Yellow Paper

## Abstract

PaperProof is a Sui-native protocol for publishing, verifying, interacting with, and rewarding digital artifacts. It does not attempt to place all content, business logic, or community behavior on-chain. Instead, it establishes a clear division of labor between Sui and Walrus: raw content is stored on Walrus; artifact identity, versions, types, ownership, governance state, constrained metadata, and verifiable events are anchored on Sui; off-chain indexers, frontends, scoring systems, and airdrop systems reconstruct richer application semantics around these trusted anchors.

The contract design of PaperProof favors a small core, strong constraints, and governance-driven extensibility. The protocol includes a limited set of high-value artifact types, such as preprints, technical reports, datasets, and software releases. New high-value types are not added through arbitrary self-service registration; they enter the core protocol gradually through governance and contract upgrades. This gives up some speed in permissionless type expansion in exchange for stronger type semantics, indexing consistency, long-term maintainability, and higher-quality community governance.

PPRF is the protocol asset that connects governance, fees, ecosystem participation, and future incentives. In the current contracts, it serves as the foundation for governance power, proof of holding, and participation weight. The protocol deliberately avoids binding all strong incentives immediately to a single behavioral event. PaperProof events provide raw evidence for future indexers, scoring, contribution accounting, and airdrops, but these events must be interpreted through official object binding, behavior quality, and anti-abuse rules rather than mechanically treated as final reward criteria.

## 1. Protocol Positioning

PaperProof addresses the lifecycle of verifiable digital artifacts, not merely file uploads or content display.

A digital artifact may be a preprint, a technical report, a dataset, a software release package, a long-form article, or a generic file. Its value comes not only from the content itself, but also from the verifiable relationships around it:

- who published it;
- which high-value type it belongs to;
- what the current version is;
- how historical versions evolved;
- how the raw content can be located and verified on Walrus;
- who owns the series;
- what comment space and like ledger are attached to it;
- whether it follows protocol-recognized type rules;
- what on-chain events it has produced;
- how future indexers and communities compute reputation, contribution, and incentives around it.

Therefore, the PaperProof core contracts are not a simple file registry. They form a base protocol for artifacts, types, governance, interaction, and ecosystem accounting.

## 2. Relationship With Existing Platforms

PaperProof is not a replacement for Twitter, Telegram, GitHub, arXiv, or other content and social platforms. It does not attempt to compete head-on with these platforms in real-time discussion, social distribution, code collaboration, academic review, content delivery, user relationships, or community operation experience.

These platforms already have powerful application-layer strengths:

- Twitter is strong at public distribution, narrative propagation, and short-form discussion;
- Telegram is strong at group organization, instant communication, and community operations;
- GitHub is strong at code hosting, collaborative development, issues, pull requests, and software engineering workflows;
- arXiv is strong at preprint distribution, academic archiving, and researcher habits;
- traditional content platforms are strong at recommendation, traffic distribution, creator relationships, and user experience.

PaperProof does not try to win by fighting these application-layer battles. It addresses a different layer: how digital artifacts obtain verifiable identity, traceable versions, governable types, composable interactions, verifiable events, and long-term interpretable ecosystem accounting.

Therefore, PaperProof is better understood as a protocol-layer complement rather than a platform-layer substitute. A preprint may still be distributed on arXiv, discussed on Twitter, debated in Telegram communities, and accompanied by code on GitHub. PaperProof provides the on-chain identity, version commitments, Walrus content anchors, comment and like objects, governance constraints, and future incentive evidence around that artifact.

This complementary relationship allows PaperProof to serve a larger world. It does not require users to abandon existing platforms, nor does it require content to live in a single frontend. Instead, it allows content, discussions, code, data, and community behavior across different platforms to be connected by the same verifiable protocol identity.

The core value of PaperProof is to separate where content is published from how content is recognized by the protocol. The former belongs to application platforms; the latter belongs to protocol infrastructure.

## 3. Design Principles

### 3.1 Raw Content Is Not Stored On-Chain

PaperProof does not write raw PDFs, datasets, software packages, or other large files into Sui objects. Raw content is large, read less frequently, and expensive to keep in on-chain state. It should be carried by decentralized storage networks such as Walrus.

Sui stores only the high-value state needed to verify and organize content, such as content hashes, Walrus identifiers, content type, artifact code, version IDs, ownership, and constrained metadata.

This division preserves public verifiability while preventing on-chain object growth from becoming a long-term burden.

### 3.2 Strongly Constrained State Lives On Sui

Any state that affects protocol identity, type semantics, version relationships, governance authority, fee paths, comment-space binding, or future trusted indexing should be constrained on-chain.

For example:

- artifact types must come from the official registry;
- series and versions must be created through official publishing paths;
- comments trees and likes books must be bound through the official publishing flow;
- series metadata may be updated, but only under owner authority and length constraints;
- version metadata is immutable after submission;
- governance objects must be bound to the official root, vault, and config;
- critical state changes must emit events.

These constraints allow PaperProof on-chain state to become a trusted entry point for indexers, frontends, and future ecosystem systems.

### 3.3 A Limited Set of Built-In High-Value Types

PaperProof does not treat artifact type as an arbitrary string marketplace. The protocol includes a small set of high-value types and governs their activation, deactivation, fee configuration, and future expansion.

The purpose of built-in types is stable semantics. `preprint` is not a casual tag; it is a protocol-recognized publication class. `software_release` is not merely user-entered classification; it is a type around which indexers can build rules for package hashes, source hashes, and version information.

This design allows frontends, search, academic indexing, content recommendation, community scoring, and airdrop statistics to rely on type semantics rather than guessing user intent from unlimited free-form tags.

### 3.4 Governance-Driven Extension

PaperProof's type space and protocol capabilities should expand gradually. New types, type activation or deactivation, fee changes, governance parameter adjustments, and critical authority migrations should be completed through governance or controlled upgrades.

This is not intended to make the protocol slow. It is intended to prevent the core protocol from being polluted by low-value types, spam types, or short-lived narratives. The core layer of PaperProof should remain scarce, clear, and verifiable. More flexible expression can live in metadata, frontend classifications, off-chain indexing, and community applications.

### 3.5 Events Are Evidence, Not Conclusions

PaperProof exposes artifact publication, version additions, comments, likes, governance, fees, and metadata updates to indexers and community systems through events.

But an event is only evidence. A comment event does not automatically mean high-quality contribution. A like event does not automatically mean claimable incentive. A publish event does not automatically mean the content is true, original, or academically valuable.

Off-chain systems should use official object IDs as trusted entry points, filter out non-official object noise, and interpret events through behavior quality, time windows, identity, content verification, anti-abuse rules, and community governance.

## 4. System Layers

PaperProof can be understood as four connected layers.

### 4.1 Content Layer

The content layer is carried by Walrus. It stores actual files, PDFs, data packages, software packages, or other blobs. PaperProof only requires on-chain records sufficient to locate and verify content, such as blob IDs, object IDs, digests, content hashes, and content types.

The content layer answers where the data is and whether it matches the commitment.

### 4.2 State Layer

The state layer is carried by Sui Move contracts. It records protocol objects such as artifact series, artifact versions, artifact types, the official root, registry, fee manager, governance vault, governance config, comments tree, and likes book.

The state layer answers what the protocol recognizes.

### 4.3 Event Layer

The event layer connects on-chain state to off-chain systems. Publishing, version additions, metadata updates, comments, likes, governance settlement, and authority changes emit events.

The event layer answers what happened.

### 4.4 Application Layer

The application layer includes frontends, indexers, search, recommendation, scoring, airdrops, analytics, community governance dashboards, and third-party tools.

The application layer answers how these facts should be interpreted and used.

The core contracts do not attempt to make every application-level judgment. They provide trusted facts, strongly constrained boundaries, and composable objects so that applications can develop on top of them.

## 5. Core Object Model

### 5.1 PaperProofRoot

PaperProofRoot is the root anchor of the protocol. It records key official object IDs such as TypeRegistry, FeeManager, and GovernanceVault, and it carries certain official creation capabilities.

For frontends and indexers, PaperProofRoot is the highest trusted entry point for determining whether a state belongs to official PaperProof. Any registry, vault, fee manager, comments tree, or publishing event that claims to belong to PaperProof should ultimately trace back to the official root binding.

### 5.2 TypeRegistry

TypeRegistry manages the protocol state of artifact types. It determines which types the protocol recognizes, which types are enabled or disabled, and which types may continue to publish or add versions.

The existence of TypeRegistry means that the PaperProof type system is not arbitrary text. It is a governable, auditable, and upgradeable protocol-layer resource.

### 5.3 ArtifactSeries

ArtifactSeries represents the long-term identity of an artifact. It is not a single file version, but a continuous publication unit around the same content object or project.

A series contains type, owner, artifact code, current version, version list, comments tree, likes book, metadata extensions, and related state. It is a central object for frontend display, indexer aggregation, community interaction, and future incentive accounting.

The series owner may update series metadata within protocol constraints and may transfer ownership. Ownership changes affect the management boundary of the corresponding comments tree.

### 5.4 ArtifactVersion

ArtifactVersion represents a specific publication under a series. It records version-level content commitments such as content hash, Walrus information, content type, and version metadata.

The core semantic of a version is immutability. Once a version is published, it should not be modified into another content object. Later revisions should be expressed by adding new versions, not overwriting old ones.

This model allows PaperProof to support content evolution while preserving historical verifiability.

### 5.5 CommentsTree

CommentsTree is the comment space of a series. It supports comment publication, reply relationships, and status markers.

Comment states include active, hidden, and deleted semantics. They are not judgments of content truth, but state-layer semantics for display, governance, and community management. The tree owner may hide or manage comments. The comment author's authority is constrained by the state machine and cannot override the tree owner's moderation decision.

CommentsTree and LikesBook are decoupled. Comment writes and like writes no longer compete over the same interaction object, which better fits the concurrency needs of popular content.

### 5.6 LikesBook

LikesBook records the like state of an artifact series. The current like semantic is proof of PPRF holding, not staking, consumption, or an irreversible commitment.

This means a like can be used as an ecosystem participation signal, but it should not be used alone as a strong incentive basis. Future scoring or airdrop systems should treat likes as low-cost, potentially gameable signals that require filtering.

### 5.7 GovernanceVault and FeeManager

GovernanceVault defines the boundaries of protocol authority, roles, and executable governance actions. FeeManager manages fee levels and fee paths.

Both must be bound to the official root. They cannot be trusted merely because they have the right registry id or Move type. PaperProof's security boundary depends on object ID binding, not only Move types.

### 5.8 GovernanceConfig and Proposal

GovernanceConfig defines proposal thresholds, voting duration, total supply record, the current active proposal, and executable governance actions.

A Proposal represents a governance process. It may be a signal proposal or an executable proposal. Governance execution does not simply read the proposal result; it revalidates the proposal, config, vault, and action state at execution time.

This repeated validation avoids empty or stale governance execution where a proposal was valid at creation time but invalid at execution time.

## 6. Artifact Type Model

Artifact type in PaperProof is a protocol-layer concept, not a user tag.

Built-in types represent content categories that the protocol considers worthy of strong semantic support. Examples include:

- `preprint`, for preprints, research drafts, and early papers;
- `blog_post`, for long-form writing and public statements;
- `technical_report`, for technical reports, audit reports, and engineering documents;
- `dataset`, for datasets;
- `software_release`, for software packages, releases, and source packages;
- `generic_file`, for general files that have not yet been further specialized.

These types are not permanently closed. PaperProof may add new types through governance and contract upgrades, but new types should meet standards of high value, indexability, enforceable constraints, and long-term maintainability.

The key question of type governance is not whether users can express themselves freely. It is whether the protocol core should recognize a form of expression as a composable base object.

## 7. Artifact Code

Artifact code is a human-readable artifact identifier for users, frontends, and off-chain references. The current design uses a format similar to:

`PaperProof-{type}-{epoch6}-{series_id_hex_12}`

It combines type, publication epoch, and a short series ID fragment, avoiding the concurrency bottleneck of a global incrementing counter.

The purpose of artifact code is not to replace object IDs, but to provide a protocol-level identifier more suitable for human sharing, document references, and frontend display. Strong identity still comes from Sui object IDs and official root binding.

## 8. Metadata Extensions

PaperProof introduces metadata extensions to give series and versions limited extensibility without frequent core-structure upgrades.

Metadata extensions use key/value pairs and are constrained by count, key length, value length, and duplicate-key rules. They are for display and indexing, and should not become the basis of core authority, fees, or governance security logic.

Series metadata may later be updated by the series owner and emits events. Version metadata is immutable after submission.

This reflects two different semantics:

- a series is a long-term identity whose display information can be maintained;
- a version is a historical commitment that should remain immutable.

## 9. Division of Labor Between Walrus and Sui

PaperProof's division of labor can be summarized as: Walrus stores content, Sui stores commitments.

Walrus is suited to raw files and large blobs. Sui is suited to strongly constrained small state, object relationships, and events.

Thus, a preprint PDF should not be written into Sui as a byte array. But its hash, Walrus ID, version ID, series ID, artifact code, owner, and publication event must be verifiable on Sui.

This division provides three advantages:

- cost control: large content is not stored on-chain, reducing object growth;
- clear verification: on-chain hashes form verifiable relationships with Walrus content;
- application flexibility: frontends and indexers can locate content from on-chain state and build rich experiences around it.

## 10. Comment and Interaction Model

The PaperProof comment model is a protocol-native interaction layer, not an external forum plugin.

Each series may have an official comments tree. The tree is bound to the series and managed by the tree owner. Comments may be short on-chain content or blob-backed content, with the latter suitable for longer text or external content summaries.

The comment state machine expresses community governance boundaries:

- active means normally displayed;
- hidden means hidden by management authority;
- deleted expresses deletion or withdrawal semantics;
- authors cannot override the tree owner's hidden-state decision;
- tree lock can block new comments without freezing all historical comment states.

This model recognizes that comments are both content interaction and governance objects. It must support expression while also supporting management.

The like model is separated from the comments tree. Likes use LikesBook, preventing like traffic and comment traffic on popular artifacts from competing over the same object. The current like semantic is proof of PPRF holding, expressing that an address held enough PPRF when the like occurred; it is not staking, burning, or a strong commitment.

## 11. The Protocol Role of PPRF

PPRF is the core connective asset of the PaperProof ecosystem.

### 11.1 Governance Power

PPRF is used for proposals, voting, and protocol parameter changes. Governance covers fees, roles, type state, upgrade-related authority, and other core actions.

Governance execution is constrained. Proposal creation, voting, settlement, and execution must satisfy state-machine rules. Executable governance actions must also revalidate business state at execution time.

### 11.2 Proof of Holding

PPRF can provide a lightweight participation threshold for some ecosystem behaviors. For example, likes require users to hold enough PPRF coin. This mechanism expresses participation eligibility or a weak signal, not a lockup or consumption of PPRF.

Therefore, proof of holding is suitable for expressing participation eligibility or weak signals. It is not suitable as a standalone basis for strong incentives.

### 11.3 Fees and Ecosystem Participation

PPRF may later connect fee discounts, protocol revenue distribution, contribution weights, ecosystem identity, airdrop rules, and community governance weights. The current contracts provide governance, event, and object foundations for these paths without freezing all economic mechanisms too early.

This is an important PaperProof design choice: the core protocol first provides trusted accounting and governance boundaries, while incentive systems evolve from real usage data and community consensus.

### 11.4 Risk Boundaries

If PPRF governance is based only on holding without lockups or snapshots, it naturally has risks such as borrowed voting power, short-term concentration, and sybil behavior.

PaperProof can mitigate these risks outside the core contracts through custody strategy, governance processes, time windows, snapshots, frontend warnings, and community rules. The core contracts do not need to solve every social-layer governance problem at once, but they must clearly expose their security boundaries.

## 12. Governance and Extension Path

The extension path of PaperProof is composed of governance and upgrades.

Governance is suited to parameter, state, and authority changes, such as:

- enabling or disabling artifact types;
- adjusting fee levels;
- modifying governance thresholds;
- changing role addresses;
- managing executable actions;
- expressing community signals.

Contract upgrades are suited to structural and capability changes, such as:

- adding structured publication functions for new artifact types;
- introducing new fields;
- changing object models;
- adding protocol modules;
- fixing security issues.

PaperProof does not pursue a completely immutable static protocol. It recognizes that an early protocol must evolve, while requiring upgrade paths to be constrained by authority, governance, and documentation.

This governance-plus-upgrade model fits a content protocol that must expand its types and ecosystem capabilities over time.

## 13. Fee Model

The PaperProof fee model is supported by FeeManager and GovernanceVault. Publishing, adding versions, comments, and similar actions may charge fees according to protocol configuration.

The point of the fee model is not short-term revenue maximization. It is to create governable resource boundaries:

- discouraging spam publications and spam comments;
- providing adjustable operational parameters;
- supporting future treasury and ecosystem incentives;
- expressing different costs across artifact types.

Fees may be zero and may be adjusted through governance. Free does not mean boundaryless, because object identity, type state, length constraints, and official paths remain constrained by the contracts.

## 14. Events and Indexers

The event system of PaperProof is the main interface between the protocol and the off-chain world.

Indexers can reconstruct:

- series publication;
- version additions;
- artifact codes;
- owner changes;
- metadata updates;
- comments tree and likes book bindings;
- comments and replies;
- likes and unlikes;
- governance proposals, votes, settlement, and claims;
- fee and role changes.

But indexers must follow the trusted-entry principle:

- use the official PaperProofRoot as the root;
- verify the official object IDs of TypeRegistry, FeeManager, GovernanceVault, and GovernanceConfig;
- treat only comments trees and likes books created by the official publishing path as protocol objects;
- avoid mixing naked events, fake-object events, or old-deployment events into current protocol statistics;
- apply anti-abuse interpretation to gameable actions such as likes, comments, and publications.

Events are not a database replacement. They are streams of verifiable facts. The value of an indexer is to organize those facts into application data that can be queried, displayed, and scored.

## 15. Concurrency and Object Design

Sui's object model requires the protocol design to handle shared-object contention carefully.

PaperProof makes several concurrency tradeoffs:

- artifact codes do not depend on a global incrementing counter;
- comments tree and likes book are separated;
- comments and likes do not force reads of the global root;
- pause mainly controls publish and add-version paths rather than freezing all interactions;
- type governance and publishing paths retain stronger object binding because they are lower-frequency, higher-value operations.

This reflects a principle: low-frequency, high-value paths can carry stronger constraints, while high-frequency interaction paths should minimize unnecessary shared-object dependencies.

## 16. Security Boundaries

PaperProof's security boundaries rest on several core assumptions.

First, official object IDs are the trusted root. Checking only a type or registry id is insufficient; critical paths must verify object origin.

Second, content truth is not automatically endorsed by the contracts. The contracts can prove that an address published a hash, but they cannot prove that the content is original, correct, non-infringing, or academically valuable.

Third, events require filtering. Any points, airdrop, or reputation system based on events must use official object binding and anti-abuse rules.

Fourth, PPRF proof of holding is not staking. Interaction signals based on proof of holding should be treated as weak signals.

Fifth, upgrade authority is part of protocol risk. PaperProof chooses upgradeability to support early evolution, so upgrade risk must be managed through governance, documentation, announcements, and multi-party oversight.

## 17. Protocol Vision

The long-term vision of PaperProof is to become the trusted publication and participation layer for digital artifacts.

It does not attempt to replace all content platforms, nor does it attempt to encode every social judgment into contracts. Its goal is to provide a sufficiently strong protocol base so that digital artifacts have verifiable identity, traceable versions, governable types, composable interactions, and interpretable events.

On this base, preprints can be cited, software releases can be verified, datasets can be indexed, comments can be organized, likes can become participation signals, governance can adjust protocol direction, and PPRF can connect contribution, fees, participation, and long-term ecosystem value.

The core of PaperProof is not to put content on-chain, but to give content a verifiable protocol life.

## 18. Closing

The core contract design of PaperProof seeks a balance:

- content is not stored on-chain, but content commitments are;
- types are not infinitely open, but are governance-extensible;
- metadata is extensible, but strongly constrained;
- versions can be added, but not altered;
- interactions can occur at low cost, but are not simply equated with strong incentives;
- events are broadly open, but must be filtered through official objects;
- PPRF connects governance and the ecosystem, but its social-layer risks require continuous governance.

This design makes PaperProof closer to a long-term protocol than a one-off application. It gives digital artifacts a verifiable structure, leaves room for community participation to evolve, and provides a dependable on-chain foundation for future ecosystems around content, reputation, contribution, and incentives.
