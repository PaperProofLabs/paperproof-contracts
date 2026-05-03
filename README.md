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

It is not distributed under a permissive open-source license. Use of the source
code and repository materials is governed by the root `LICENSE`, `NOTICE`, and
`TRADEMARKS.md` files.

No patent license is granted by access to this repository or by any public
availability of the source code.
