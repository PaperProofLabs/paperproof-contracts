# paperproof-contracts

This repository is the main smart-contract repository for the PaperProof
protocol, excluding the separately maintained `PPRF-token-contracts`
repository.

It is intended to host the protocol-side Sui Move packages for publication,
governance, comments, shared components, and related contract documentation.

## Repository structure

- `publishing/` for publication and artifact-state contracts
- `governance/` for administrative and governance-related contracts
- `comments/` for comment and interaction contracts
- `shared/` for reusable shared packages and common modules
- `docs/` for contract architecture, deployment, and integration documentation

Each contract area may evolve as its own Sui Move package within this monorepo.

## Rights and license

This repository is made publicly available for transparency, security review,
research, evaluation, and interoperability with the official PaperProof
ecosystem.

PaperProof Protocol refers to the open protocol layer and official deployed
protocol instances. PaperProof Labs refers to the originating team and
maintainer of the official interface, SDKs, reference indexer, documentation,
and brand identity.

It is not distributed under a permissive open-source license. Use of the source
code and repository materials is governed by the root `LICENSE`, `NOTICE`, and
`TRADEMARKS.md` files.

No patent license is granted by access to this repository or by any public
availability of the source code.

Third parties may build independent applications, indexers, wallets,
dashboards, agents, explorers, developer tools, and other integrations that
interoperate with the official PaperProof protocol using public contract
interfaces, SDKs, official deployment identifiers, object IDs, event schemas,
and other factual protocol metadata, provided they do not copy official
contract source code, misuse PaperProof marks, redeploy protected contract code
as a competing implementation, or falsely claim official status.

This repository protects the official PaperProof contract source, protocol
implementation, operational records, and brand identity. It is not intended to
prevent compatible third-party protocol applications, independent interfaces,
indexers, analytics tools, or ecosystem entrypoints.

## License Matrix

This repository uses differentiated rights for different kinds of material.
The repository-level `LICENSE` is the default for contract source and repository
materials unless a file, dependency, or notice states otherwise.

| Material | Terms |
|---|---|
| Official PaperProof contract source, Move packages, tests, configuration, operational records, and protected repository materials | `LicenseRef-PaperProof-Source-Available` under the root `LICENSE` |
| Third-party dependencies and external packages | Their own upstream licenses |
| Public contract interfaces, official deployment identifiers, object IDs, event schemas, Move entrypoint names, and other factual protocol metadata | May be used for interoperability with the official PaperProof protocol |
| Contract documentation, runbooks, deployment records, governance notes, diagrams, and protocol narratives | Protected by the root `LICENSE` and `docs/CONTENT_NOTICE.md`; limited factual reference and linking are allowed as described there |
| PaperProof names, marks, logos, and branding | Reserved under `TRADEMARKS.md`; no implied endorsement or official status |
| Independent third-party applications, wallets, indexers, dashboards, agents, explorers, and developer tools | Permitted when they interoperate through public protocol interfaces and do not copy official contract source, redeploy protected contract code as a competing implementation, misuse marks, or falsely claim official status |

This matrix is intended to protect the protocol implementation and official
identity while keeping PaperProof open to compatible Web3 applications,
independent indexers, analytics tools, and ecosystem entrypoints.

For protocol-use, event/object interpretation, user-content, official-interface
non-display, and abuse-boundary notes, see
[docs/Protocol-Use-and-Abuse-Boundaries.md](./docs/Protocol-Use-and-Abuse-Boundaries.md).

For official account, authority, personal-address, and deployment-authority
boundaries, see
[docs/Official-Accounts-and-Authority-Boundaries.md](./docs/Official-Accounts-and-Authority-Boundaries.md).

For the distinction between pre-launch mainnet setup activity and formal public
official operations, see
[docs/Official-Operations-Effective-Time.md](./docs/Official-Operations-Effective-Time.md).
