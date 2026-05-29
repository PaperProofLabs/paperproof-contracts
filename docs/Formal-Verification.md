<!--
Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available
-->

# Formal Verification

PaperProof completed a dedicated Sui Prover formal-verification baseline for
the core contract modules. The full proof workspace, specification packages,
runner scripts, and rollout history are intentionally kept outside `main` on
the `formal-verification-merge` evidence branch.

Evidence branch:

- branch: `formal-verification-merge`
- consolidated commit:
  `67ae94f8836060f499186600255e9a010b602b2c`
- final report on that branch:
  `docs/Formal-Verification-Final-Report.md`
- final coverage summary on that branch:
  `docs/formal-verification/final-coverage-summary.md`

The `main` branch keeps the production contract packages, deployment records,
and ordinary documentation focused on build, deployment, and integration. It
does not include the prover-only spec packages or local Sui Prover workflow
files, so normal contract builds, deployments, and tests remain unaffected.

## Coverage Posture

The completed verification baseline covers the four core project-side logic
modules:

| Module | Reported posture |
|---|---|
| `governance_voting.move` | 100% tracked coverage, complete in default prover mode |
| `comments.move` | 100% tracked coverage, complete in default prover mode |
| `publishing.move` | Project-side logic effectively cleared under the validated workaround mode |
| `governance.move` | Project-side logic effectively cleared under the validated workaround mode |

The formal-verification work classified the remaining non-default prover
residuals as upstream Sui Prover or framework-modeling limitations, especially
around transfer-heavy paths and `two_step_transfer::unwrap(...)` handling,
rather than identified defects in PaperProof protocol logic.

Within the current formal-verification coverage, no confirmed and reproducible
PaperProof contract-logic counterexample was found. This statement is bounded:
formal verification proves the properties that were specified and modeled, and
should not be read as a guarantee about properties outside the current
specification and tooling boundary.

## Why The Evidence Lives On A Separate Branch

The evidence branch preserves the complete verification record without turning
the production branch into a prover workspace. This gives reviewers a stable
audit trail while keeping `main` small and operational:

- `main` remains the production contract and deployment branch;
- `formal-verification-merge` remains the complete verification evidence
  branch;
- this document gives main-branch readers the verified baseline and the exact
  evidence pointer.

