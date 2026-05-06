# docs

This directory is reserved for documentation related to the PaperProof
contracts repository.

The documentation layer is intended to describe the architecture, package
boundaries, deployment assumptions, governance expectations, and integration
surface of the publishing, governance, comments, and shared contract packages.

Typical contents of this directory may include:

- package-level design notes
- contract architecture diagrams
- deployment and upgrade notes
- integration guides for frontends, indexers, and other clients
- protocol-specific documentation that belongs with the contracts repository

Current documents include:

- `PPRF-governance-voting.md`: implemented `PPRF` governance voting structure,
  lock-based voting rules, and executable governance actions including the
  official upgrade-authority path
- `Governance-Modes.md`: detailed explanation of directly executable governance
  and signal governance in the current `PaperProof` system, including upgrade
  authority as an executable governance item
- `Deployment-and-Upgrade-Runbook.md`: deployment order, root object
  initialization, managed `UpgradeCap` custody, and recommended protocol
  upgrade workflow for the three-package contract system
- `Deployment-Manifest-Template.md`: fillable deployment manifest template for
  recording package IDs, root object IDs, governance addresses, upgrade-cap
  custody, smoke tests, and frontend/runtime configuration
- `Mainnet-GoLive-Checklist.md`: concise launch-readiness checklist for final
  mainnet validation before opening the official frontend to the public
- `Observability-and-Read-APIs.md`: current events/getters across
  `publishing`, `comments`, and `governance`, including governance-control,
  upgrade/migration observability, and remaining future additions for off-chain
  monitoring and tooling
- `Treasury-and-Fee-Management.md`: current fee routing model and planned
  treasury evolution path for protocol income and future disbursement
- `Versioned-Upgrade-Design.md`: current versioned-upgrade preparation,
  migration hooks, version guards, and the expected future package-upgrade
  workflow

Unless otherwise expressly stated, all documentation and materials in this
directory are governed by the repository root `LICENSE`, `NOTICE`, and
`TRADEMARKS.md` files.
