# docs

This directory is reserved for documentation related to the PaperProof
contracts repository.

The documentation layer is intended to describe the architecture, package
boundaries, deployment assumptions, governance expectations, and integration
surface of the publishing, governance, comments, and shared contract packages.

Documentation in this directory is protected project material. In addition to
the repository root `LICENSE`, `NOTICE`, and `TRADEMARKS.md`, see
`CONTENT_NOTICE.md` for the documentation-specific content notice.

Typical contents of this directory may include:

- package-level design notes
- contract architecture diagrams
- deployment and upgrade notes
- integration guides for frontends, indexers, and other clients
- protocol-specific documentation that belongs with the contracts repository

Current documents include:

- `Artifact-Publishing.md`: current artifact publishing architecture,
  built-in types, `ArtifactSeries`/typed-version model, comments binding,
  type-specific fees, and governance activation flow
- `PPRF-governance-voting.md`: implemented `PPRF` governance voting structure,
  lock-based voting rules, and executable governance actions including the
  official upgrade-authority and executor-cap artifact paths
- `Governance-Modes.md`: detailed explanation of directly executable governance
  and signal governance in the current `PaperProof` system, including
  publishing-specific executor-cap governance actions
- `Deployment-and-Upgrade-Runbook.md`: deployment order, root object
  initialization, artifact type governance, managed `UpgradeCap` custody, and
  recommended protocol upgrade workflow for the three-package contract system
- `Deployment-Manifest-Template.md`: fillable deployment manifest template for
  recording package IDs, root object IDs, governance addresses, upgrade-cap
  custody, smoke tests, and frontend/runtime configuration
- `Mainnet-Deployment-Record-2026-05-06.md`: mainnet deployment record template
  for the current contract system, including package IDs, canonical root
  objects, governance configuration, and frontend/runtime parameters
- `Mainnet-Post-Deployment-Funds-And-Authority-Migration.md`: operational
  checklist for moving funds, role authorities, operator custody, fee
  recipient, and package `UpgradeCap` custody after the 2026-05-07 mainnet
  deployment
- `Mainnet-GoLive-Checklist.md`: concise launch-readiness checklist for final
  mainnet validation before opening the official frontend to the public
- `Second-Round-Prelaunch-Audit.md`: second-round prelaunch security review,
  remaining chain-off filtering risks, official object binding rules, and
  community participant notes
- `Observability-and-Read-APIs.md`: current events/getters across
  `publishing`, `comments`, and `governance`, including artifact events,
  governance-control, upgrade/migration observability, and indexing guidance
- `PPRF-Utility-Paths.md`: protocol-native and non-protocol utility paths for
  the `PPRF` token across governance, frontend, community, treasury, and
  future incentive design
- `Treasury-and-Fee-Management.md`: current fee routing model and planned
  treasury evolution path, including artifact-type fee levels in `FeeManager`
- `Versioned-Upgrade-Design.md`: current versioned-upgrade preparation,
  migration hooks, version guards, and the expected future package-upgrade
  workflow

Unless otherwise expressly stated, all documentation and materials in this
directory are governed by the repository root `LICENSE`, `NOTICE`, and
`TRADEMARKS.md` files, together with the documentation-specific
`CONTENT_NOTICE.md` in this directory.
