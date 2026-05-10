# PaperProof Protocol Yellow Paper

## Abstract

PaperProof is a Sui-native protocol for verifiable digital artifacts. Its central claim is narrow: important digital works should be able to acquire a durable protocol identity that survives individual frontends, hosting choices, social feeds, organizational changes, and market cycles. A PaperProof artifact is not merely a file. It is a series of commitments, versions, typed publication semantics, official interaction objects, governance-bounded parameters, and events that other systems can independently verify.

The protocol divides responsibility between Sui and Walrus. Walrus carries the large content surface: PDFs, datasets, software packages, source archives, images, long comments, and other blobs. Sui carries constrained state that should remain publicly auditable: artifact series, typed version records, content hashes, Walrus references, type state, fee configuration, governance state, official comments trees, likes books, and canonical events. This division is not only a cost optimization. It is a statement about what deserves to become protocol state and what should remain content or application state.

PaperProof is not a replacement for social networks, group chats, software collaboration tools, academic archives, storage networks, or hosted publishing platforms. It is a protocol layer beneath and beside them. Existing platforms can remain where users discover, discuss, review, distribute, and operate around content. PaperProof supplies durable identity, version commitments, official object bindings, and governance records that those platforms usually cannot provide in a neutral, composable, and long-lived form.

The protocol is intentionally small at the core. It begins with a limited set of built-in artifact types, governance-controlled type activation, constrained metadata, official object binding, unified fee management, and a TypeScript SDK for applications, indexers, and operator tools. This smallness is deliberate: the core should be strong enough to anchor trust, but not so large that it becomes a social platform, search engine, moderation system, reward engine, and archive all at once.

## Intended Readers

This paper is written for protocol developers, auditors, indexer builders, frontend developers, ecosystem partners, governance participants, and long-term community contributors. It is not an end-user tutorial and it is not a market pitch. Its purpose is to make the design boundary of PaperProof explicit: what the contracts promise, what the SDK helps with, what indexers must still interpret, and what the protocol intentionally refuses to decide.

For developers, the paper should clarify how PaperProof objects compose and why official object binding matters. For auditors, it should expose trust roots, state machines, upgrade assumptions, and event risks. For indexer and frontend builders, it should distinguish canonical protocol facts from application interpretation. For governance participants, it should explain why type space, fees, upgrade authority, and incentive policy should evolve cautiously rather than through unlimited self-service expansion.

## 1. Purpose

PaperProof exists to answer a narrow but important question: what does the protocol recognize as the durable, verifiable identity of a digital artifact?

An artifact may be a preprint, a technical report, a dataset, a software release, a long-form post, or a generic file. The raw bytes matter, but they are not enough. A serious artifact also needs a publisher, a type, a version history, a content commitment, a storage reference, an owner, an interaction space, a fee and governance context, and an event trail that can be read by systems that were not present when the artifact was first published.

PaperProof therefore is not a file registry. A registry records that something exists. PaperProof records how an artifact enters a protocol, how it evolves, which objects are allowed to speak for it, and which events may later be used as evidence by frontends, indexers, governance dashboards, scoring systems, or community tools. The protocol does not make every downstream judgment, but it does provide the facts that downstream judgment needs.

## 2. Non-Goals

PaperProof deliberately avoids several platform-layer goals. It does not provide a social feed, recommendation algorithm, follower graph, group chat, issue tracker, pull request workflow, peer-review judgment, full-text search engine, ranking oracle, or reward engine inside the core contracts.

It also does not claim that an on-chain publication proves truth, originality, academic quality, license compliance, or social value. The contracts can prove that an address committed to specific metadata and content references at a specific protocol state. Interpretation remains an application, community, and governance problem.

This restraint is part of the design. A protocol core should produce trusted facts. It should not pretend to solve every editorial, social, economic, or legal question by emitting an event. If PaperProof tried to encode discovery, moderation, academic judgment, reward accounting, and community operations directly into its core contracts, the result would be expensive, brittle, and politically confused. The protocol instead chooses a smaller responsibility: define durable artifact identity and the official objects around it, then let many applications interpret that identity in different ways.

## 3. Relationship With Existing Platforms

PaperProof complements existing platforms rather than replacing them.

Social platforms are strong at attention distribution and public conversation. PaperProof does not replicate feeds, follower graphs, trending topics, or recommendation systems. It provides protocol facts that social platforms normally do not preserve in a durable and composable way: artifact identity, version chain, content commitments, official interaction objects, and trusted event streams. A PaperProof artifact may be discussed on a social platform, but its identity should not depend on that platform's database, account system, or recommendation policy.

Community tools such as Telegram and Discord are strong at coordination, announcements, informal consensus, and daily operations. PaperProof does not turn group chat into on-chain state. It records the high-value outputs that a community wants to recognize over time: publications, versions, comments, likes, type decisions, fee changes, authority changes, and governance results. Every chat message and reaction should not become protocol state; protocol state should be scarce, verifiable, indexable, and interpretable over long periods.

GitHub and other software collaboration tools are strong at source hosting, issues, pull requests, code review, CI, and release engineering. PaperProof does not reproduce the software development lifecycle on-chain. A software release may still be developed and distributed through GitHub, while PaperProof records its protocol identity, source hash, package hash, Walrus reference, publisher, version, and event record. Repositories may migrate and release pages may be rewritten, but an on-chain release commitment can remain a stable verification coordinate.

arXiv and academic archives are strong at researcher habits, academic distribution, field classification, and archival workflows. PaperProof does not replace academic entry points or judge research merit. It gives preprints and related materials an additional verifiable protocol life: series identity, version commitments, content anchors, official comments, likes, and future indexer-readable participation records.

This layered relationship matters because content should not have to live in a single frontend. A paper can be discussed on social platforms, archived in an academic venue, accompanied by code in a repository, and still share one PaperProof protocol identity.

## 4. Low-Maintenance Survival Model

PaperProof is designed to remain usable even when the application layer is minimal. Core rules and object relationships live in Sui Move contracts. Raw content and long-form blobs live on Walrus. A basic frontend can be published as a static site, including through Walrus Sites or equivalent static hosting. The TypeScript SDK can build transactions, read state, filter canonical events, and verify Walrus content. Indexers and dashboards can be added gradually when usage justifies them.

This does not mean the application layer is unimportant. Search, moderation tools, analytics, scoring, airdrop accounting, anti-abuse filtering, and ecosystem dashboards are valuable. They simply should not be mandatory for the protocol to continue existing. The contracts and SDK define the minimum durable layer; richer applications can compete or cooperate above it.

This choice matters during cold start. A protocol that needs servers, active operators, recommendation systems, and constant content operations from day one is fragile when attention is low. PaperProof is designed to tolerate long quiet periods. The minimum system can keep accepting artifacts, preserving versions, and exposing canonical events while the ecosystem waits for stronger demand, better tooling, new distribution channels, or a more favorable market cycle.

Low maintenance is not the same as no maintenance. Package upgrades, SDK updates, deployment manifests, frontend refreshes, and governance operations still require care. The point is that the protocol should not collapse merely because the first official website, indexer, or operator workflow is not being actively expanded every week.

## 5. Core Design Tensions

PaperProof is shaped by several tensions that cannot be eliminated; they can only be made explicit and managed.

The first tension is between durability and experience. Sui and Walrus can anchor identity and content commitments, but they do not automatically provide the search, recommendation, discovery, moderation, and social context that users expect from mature platforms. PaperProof chooses to secure the durable layer first and leave richer experience to SDK-based applications and indexers.

The second tension is between open expression and protocol-recognized type semantics. Users can describe content freely through metadata, frontends, and off-chain communities, but the protocol core should not accept unlimited artifact types as first-class semantics. Built-in types are scarce because indexers, fee policy, governance, and typed records need stable meaning.

The third tension is between event openness and incentive integrity. Events make the protocol observable, but observability is not the same as value. A comment can be spam, a like can be cheap, a publication can be low quality, and a governance vote can reflect temporary token concentration. Incentive systems must interpret events through official object bindings, time windows, content verification, identity analysis, and community rules.

The fourth tension is between upgradeability and trust minimization. PaperProof is early enough that upgradeability is necessary for security fixes, new artifact types, SDK alignment, and governance improvements. At the same time, upgrade authority is itself a trust surface. The protocol therefore treats upgrades as a governed operational path that must be documented, observable, and gradually constrained as the ecosystem matures.

The fifth tension is between low-maintenance survival and future ambition. A static frontend and SDK-centered integration model are enough for the protocol to remain alive, but not enough to realize every possible product experience. This is intentional. PaperProof can survive as a small protocol seed and later support richer applications when usage, funding, or community energy justifies them.

## 6. Layered Architecture

PaperProof is best understood as four layers.

### 6.1 Content Layer

The content layer is carried by Walrus. It stores large blobs: PDFs, datasets, software packages, source archives, images, text files, and long comment content. Sui does not store these bytes. Sui stores enough information to locate and verify them, such as Walrus blob IDs, blob object IDs, content hashes, digests, and content types.

The content layer answers where the data is and whether it matches the commitment.

### 6.2 Protocol State Layer

The state layer is carried by Sui Move contracts. It records official protocol objects such as `PaperProofRoot`, `TypeRegistry`, per-type indexes, `ArtifactSeries`, typed version records, `CommentsTree`, `LikesBook`, `GovernanceVault`, `FeeManager`, `GovernanceConfig`, proposals, and governance execution state.

This layer answers what PaperProof recognizes.

### 6.3 Event Layer

Events connect on-chain state to off-chain systems. PaperProof emits events for publication, versioning, metadata changes, ownership changes, comments, likes, fee changes, role changes, governance proposals, voting, settlement, execution, and upgrade-related authority operations.

Events are evidence, not conclusions. An event may prove that something happened through an official path, but it does not automatically prove that the action deserves reputation, rewards, ranking, or endorsement.

### 6.4 Application and SDK Layer

The application layer includes frontends, SDK integrations, indexers, search systems, moderation views, governance dashboards, bots, analytics, and reward pipelines.

The PaperProof TypeScript SDK is the bridge between applications and the protocol. It provides deployment-aware transaction builders, read clients, typed views, event extraction, canonical event filtering, Move abort explanations, coin selection helpers, Walrus content verification, and operator/governance transaction wrappers.

The SDK does not replace the contracts as the source of truth. It reduces integration mistakes and gives applications a stable way to follow package upgrades and canonical object bindings.

## 7. Core Object Model

### 7.1 PaperProofRoot

`PaperProofRoot` is the top-level trust anchor. It records the official governance vault, fee manager, type registry, and internal capabilities used by official publishing and governance execution paths.

Frontends and indexers should treat the root object as the starting point for trust. Matching a Move type or registry ID is not enough. Critical objects must trace back to the official root binding.

### 7.2 TypeRegistry and TypeIndex

`TypeRegistry` records the artifact types recognized by the protocol, whether each type is enabled, its schema version, and related type metadata.

Each built-in type has a TypeIndex. The first index responsibility is simple: mapping a human-readable artifact code to the corresponding series ID. More complex discovery such as authors, tags, fields, rankings, and search belongs to indexers and applications unless it becomes important enough for a future protocol extension.

The type system is intentionally not an arbitrary string marketplace. Built-in types provide stable semantics for frontends, SDK validation, event filtering, fee configuration, and governance.

### 7.3 ArtifactSeries

`ArtifactSeries` is the stable identity of a published artifact. It represents a continuing work, not a single file upload.

A series stores its artifact type, artifact code, owner, current version number, current version ID, prior version IDs, official comments tree ID, official likes book ID, status, metadata extensions, and timestamps generated by the Sui `Clock`.

The series owner can add versions while the series is active, update bounded series metadata, and transfer ownership. Ownership transfer also updates the owner boundary of the official comments tree.

### 7.4 Typed Version Records

A version record is an immutable snapshot under a series. Each built-in artifact type has a typed version record instead of a single generic paper record.

All version records share a common header: series ID, artifact type, version number, previous version ID, author, content hash, Walrus blob ID, Walrus blob object ID, content type, status, created timestamp from Sui `Clock`, and bounded version metadata extensions.

Each type then adds only the fields necessary for that type. Examples include preprint titles and authors, dataset format and size, software source/package hashes, or generic file names. The goal is strong enough typing for protocol semantics without turning contracts into a large business database.

### 7.5 CommentsTree

`CommentsTree` is the official comment space for an artifact series. It is created automatically when a series is published and is bound to the root, series, artifact type, governance vault, and fee manager.

Comments may be stored directly on-chain when short, or as blob-backed comments when the content is longer. The tree enforces depth limits, parent existence, parent active status, content limits, tree status, and official fee manager binding.

The tree owner may hide, restore, or delete comments. A comment author may delete their own comment, but cannot restore a comment hidden by the tree owner. This keeps author autonomy from overriding moderation authority.

### 7.6 LikesBook

`LikesBook` records like state separately from comments. This separation reduces shared-object contention on popular artifacts: comment traffic and like traffic do not compete over the same interaction object.

The current like semantics are proof of PPRF holding. A like is a lightweight participation signal, not staking, burning, payment, or a final reward claim. Applications should treat likes as useful but gameable evidence.

### 7.7 GovernanceVault and FeeManager

`GovernanceVault` records protocol authority boundaries, role addresses, direct authority mode, fee recipient, managed upgrade state, and executable governance action support.

`FeeManager` stores fee levels for artifact types and comments. Publishing, adding versions, and writing comments use the official fee manager bound to the root or comments tree. Fake objects with matching types must not be accepted as official configuration.

## 8. Artifact Types

PaperProof starts with six built-in artifact types: `preprint`, `blog_post`, `technical_report`, `dataset`, `software_release`, and `generic_file`.

The type list is intentionally small. Each type is a protocol-recognized class with typed publication functions, typed version records, validation rules, indexer semantics, fee configuration, and governance-controlled enabled state.

Adding a new type is a structural protocol change, not a user preference flag. It normally requires contract support for the new type constant, name, code mapping, index, typed record, publish function, add-version function, validation, events, tests, and read APIs. It also requires SDK support for builders, validators, typed views, constants, event parsing, and examples; documentation describing the type semantics and field limits; and governance activation so the new type can be enabled for use.

This design keeps type semantics high quality. Free-form labels, tags, and communities can exist at the application layer, but protocol-recognized types should remain scarce and governable.

## 9. Artifact Code

Artifact code is a human-readable identifier for sharing and display. The contract derives it from the artifact type, the current Sui epoch, and a short fragment of the series ID, using a format in the family of:

`PaperProof-{type}-{epoch6}-{series_id_hex_12}`

The artifact code is not the strongest identity. Object IDs and official root binding remain authoritative. The code exists because people, documents, and frontends benefit from a compact reference that is easier to display than a full object ID.

## 10. Time Semantics

PaperProof uses the Sui `Clock` for millisecond timestamps stored in contract objects and events. Timestamps are therefore produced by the chain execution environment rather than supplied by the frontend.

Epoch values remain useful for coarse governance and artifact-code context, but epoch alone is too coarse for user-facing event timelines. The protocol uses chain-provided timestamps for publication, versioning, comments, status changes, and governance events where a finer ordering signal is useful.

Applications may still display local times, but they should derive protocol time from on-chain fields and events, not from user-submitted timestamps.

## 11. Metadata Extensions

PaperProof supports bounded metadata extensions for series and versions. Extensions are key/value pairs with strict count, key length, value length, and duplicate-key limits.

Series metadata can be updated by the series owner and emits events. Version metadata is immutable because a version is a fixed content commitment.

Metadata extensions are useful for display and indexing, but they should not be used as the basis of core authority, fees, governance security, or trusted type semantics. Critical semantics belong in typed fields and protocol objects.

## 12. Governance

PPRF is the governance asset of PaperProof. Governance supports executable proposals and signal proposals.

Executable proposals can change protocol state when they pass and are executed through the correct entry point. Supported actions include fee changes, artifact type enablement, artifact type activation, fee recipient changes, operator nomination, operator-transfer cancellation, governance parameter changes, governance action enablement, direct authority mode changes, governance authority changes, and upgrade authority changes.

Signal proposals express community direction without directly mutating state. They are appropriate for policy positions, feature direction, and replacement signals where the final execution path requires additional operational work.

Proposal creation validates known action types and basic payload legality. Execution revalidates action enablement, proposal status, governance config, vault binding, and business state. This prevents a stale or malformed proposal from becoming a permanent executable privilege.

## 13. Authority and Decentralization Path

PaperProof includes direct authority because early-stage protocols need a way to deploy, configure, pause, recover, and upgrade responsibly. The authority model is not intended to be the final political structure of the ecosystem.

The governance vault supports direct authority modes ranging from full direct authority to emergency, read-only, and disabled modes. Governance can move the protocol toward a DAO-first structure by reducing direct authority. Permanent disablement is one-way: once direct authority is disabled permanently, it cannot be restored to a stronger mode.

This creates a practical transition path. Early operation can rely on controlled authority for deployment and recovery. As contracts, SDKs, frontends, and community processes mature, PPRF governance can progressively take over parameter changes, role changes, fee management, and activation of new capabilities.

## 14. Upgrade Model

PaperProof is upgradeable because the protocol is expected to evolve. New artifact types, improved validation, security fixes, SDK adapters, and governance features may require package upgrades.

The preferred pattern is not to make every upgrade itself a single magic proposal action. Structural code changes happen through Sui package upgrade mechanisms under controlled upgrade authority. New capabilities that affect users should then be activated through governance-controlled state where practical.

For example, adding a new artifact type normally has two phases: upgrade the contracts and SDK so the type exists, then activate or enable the type through governance so it becomes usable. This separates technical deployment from protocol consent. The same principle can apply to other features where the code can be installed first and opened later through governance.

Managed upgrade custody, role events, deployment manifests, SDK deployment adapters, and public documentation are part of the upgrade safety model.

## 15. Fee Model

PaperProof fees are configured through `FeeManager` and collected under the official governance vault.

Artifact publishing and versioning can have fee levels by artifact type. Comments use the same fee manager rather than a separate fee regime. This keeps fee policy consistent and makes canonical fee configuration easier for frontends, SDKs, indexers, and governance tooling to read.

Fees are not primarily a revenue-maximization tool. They are a governable spam and resource boundary. Fees may be set to zero, but free actions still remain bounded by official object binding, type enablement, length limits, status checks, and object ownership rules.

Fee recipient changes are protocol-sensitive and should be treated as treasury governance decisions, not routine application configuration.

## 16. Events and Indexers

PaperProof events are designed for integration. Applications and indexers can listen for creation of protocol roots, registries, indexes, vaults, and fee managers; artifact publication and version additions; artifact status, metadata, and ownership changes; comments tree and likes book creation; comment creation and status changes; likes and unlikes; fee collection and fee level changes; proposal creation, voting, finalization, execution, expiration, and claims; role changes, authority mode changes, operator transfers, and upgrade events.

Indexers must apply the trusted-entry principle. They should start from the official `PaperProofRoot`, verify the official type registry, governance vault, and fee manager IDs, treat only official comments trees and likes books bound through the publishing path as protocol interaction objects, filter events by canonical package IDs and object bindings, and treat events as evidence for later interpretation rather than final scoring or reward conclusions.

The SDK supports this model through canonical event filtering and deployment configuration. An indexer should not simply collect every event with a familiar struct name.

## 17. Concurrency and Object Design

PaperProof follows Sui's shared-object model and avoids unnecessary contention where possible.

Important concurrency decisions follow from this priority. Artifact codes avoid a single global incrementing counter. Each type has its own index object. Comments and likes use separate objects. Comments and likes do not require reading the global root on every write. Publishing and versioning keep stronger root, registry, vault, and fee manager checks because they are lower-frequency, higher-value actions. Official comments tree identity is stored on the series, so applications can verify the canonical interaction object without trusting arbitrary trees.

This supports the original product reason for multiple artifact types: frontends and indexers can follow the categories they care about instead of pulling every publication through one undifferentiated stream.

## 18. Security Boundaries

PaperProof security depends on several explicit boundaries, and these boundaries should be treated as part of the protocol rather than footnotes.

Official object IDs are the trust root. A fake vault, fake fee manager, fake comments tree, or fake event with the right Move shape must not be accepted as official.

Typed records and length constraints protect the protocol from unbounded object growth and ambiguous metadata. Large content belongs on Walrus, not in Sui objects.

Series status and type enabled state affect future publication. Disabled types cannot be used for new series or new versions. Inactive series cannot receive new versions.

Proposal execution is not a generic capability leak. Governance tickets are consumed through specific execution paths and must match the intended action, registry, payload, and official object bindings.

Direct authority is useful during early operation, but it is a governance risk. The direct authority mode system gives the ecosystem a way to reduce that risk over time.

PPRF proof of holding is a weak participation signal, not staking. Reward, ranking, and airdrop systems must apply additional anti-abuse rules.

PaperProof also does not guarantee token value, traffic, academic acceptance, or content quality. Those outcomes belong to markets, communities, creators, reviewers, and applications. The protocol can make artifacts easier to verify and coordinate around; it cannot make them important by decree.

## 19. SDK and Integration Contract

The SDK is part of the protocol's practical surface.

Applications should use the SDK to build publish and add-version transactions for all built-in types; build comment, blob comment, like, unlike, metadata, and ownership transactions; create, vote on, finalize, execute, and claim from governance proposals; verify deployment configuration and canonical object bindings; filter canonical events; parse publish, version, comment, like, and governance results; read typed object views; verify Walrus content against on-chain hashes; and handle Move aborts with user-readable explanations.

The SDK is deployment-adapter based. Package IDs and canonical object IDs live in deployment configuration, so applications can follow package upgrades without hard-coding every object in UI logic.

The SDK improves developer safety, but it is not the security root. Contracts remain authoritative. SDK validation catches mistakes early; on-chain checks enforce the protocol.

## 20. PPRF Utility

PPRF connects governance, proof of holding, fee policy, ecosystem participation, and future incentives.

Its current core roles are proposal creation, voting power, locked-token voting flows, proof-of-holding checks for lightweight participation such as likes, and governance control over fees, authority, and executable actions.

Future incentive systems may use PaperProof events and object state as input, but they should not treat a single event type as sufficient proof of value. High-integrity incentives require official object filtering, behavior quality checks, time windows, identity analysis, content verification, and community rules.

## 21. Design Philosophy

PaperProof aims to be durable rather than maximal.

The protocol keeps the core small, typed, and governable. It stores only the state that must be verified on-chain. It leaves raw content to Walrus. It lets frontends and indexers provide richer experiences without asking contracts to become a social platform, search engine, archive, reward engine, and moderation system at the same time.

The long-term value of PaperProof is not that every action happens on-chain. The value is that important content can acquire a verifiable protocol life: stable identity, immutable versions, official interactions, governed types, auditable fees, observable authority changes, and event evidence that other systems can build on.

That is the core promise: content may travel across platforms, but its PaperProof identity remains independently verifiable.
