<!--
Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available
-->

# PaperProof Formal Verification Report Structure

This document records the report structure used to shape the final
formal-verification reporting for `paperproof-contracts`.

It is not meant to capture the raw output of one prover command. It organizes a
durable report that can support internal review, external communication, audit
collaboration, and ecosystem presentation.

The completed outcome is captured in `docs/Formal-Verification-Final-Report.md`.

---

## 1. Document Information

- Project name:
- Repository:
- Protocol version:
- Report version:
- Report date:
- Covered deployment version:
- Prover tool version:
- Boogie version:
- Z3 version:
- Report scope:
- Maintainer or reporting team:

---

## 2. Executive Summary

Use this section for a one-page high-level summary aimed at protocol maintainers, reviewers, auditors, and ecosystem partners.

Recommended questions:

1. Which modules are covered?
2. What is the verification goal?
3. Which high-value properties have been proved?
4. Which parts are outside the completed baseline?
5. What are the boundaries of the current conclusion?

Suggested structure:

- Covered modules:
- Proved high-value properties:
- Outside-baseline or toolchain-limited parts:
- Known toolchain limitations:
- Overall conclusion:

---

## 3. Verification Scope

This section defines what was verified and what was not verified.

### Contract Scope

List the Move packages and modules covered by the report:

- `publishing/sources/artifact_types.move`
- `publishing/sources/validation.move`
- `publishing/sources/publishing.move`
- `governance/sources/governance.move`
- `governance/sources/governance_voting.move`
- `comments/sources/comments.move`

### Specification Scope

List the spec packages and files included in the report:

- `publishing-specs`
- `governance-specs`
- `comments-specs`

### Reporting Criteria

Clarify:

- whether only `#[spec(prove, ...)]` targets are counted;
- whether `Assume` and `SpecNoAbortCheck` are counted separately;
- whether targets that reach the check phase but time out are counted as covered;
- whether toolchain failures are separated from protocol-logic failures.

---

## 4. Verification Method

Describe how formal verification was performed.

### Toolchain

- `sui-prover`
- `Boogie`
- `Z3`
- WSL or local execution environment

### Execution Model

Explain:

- whether prover runs are target-by-target or batch-based;
- whether a unified script is used;
- whether timeout, split-path, and keep-temp options are used.

### Specification Design Principles

Recommended principles:

- prioritize public entry points;
- prioritize observable protocol behavior;
- prioritize high-value state transitions;
- avoid treating restricted helpers as standalone proof targets unless useful;
- separate toolchain blockers from protocol issues.

---

## 5. Specification Checklist And Coverage Matrix

Align this section with the formal specification checklist.

### Overall Statistics

- total checklist items:
- spec items implemented:
- targets proved successfully:
- timeout targets:
- toolchain-blocked targets:
- items outside the completed baseline:

### Coverage By Module

| Module | Checklist Items | Specs Written | Proved | Timeout | Toolchain Blocked | Outside Baseline |
|---|---:|---:|---:|---:|---:|---:|
| artifact_types |  |  |  |  |  |  |
| validation |  |  |  |  |  |  |
| governance |  |  |  |  |  |  |
| governance_voting |  |  |  |  |  |  |
| publishing |  |  |  |  |  |  |
| comments |  |  |  |  |  |  |
| cross-module |  |  |  |  |  |  |

### Coverage By Priority

| Priority | Checklist Items | Specs Written | Proved | Timeout | Toolchain Blocked | Outside Baseline |
|---|---:|---:|---:|---:|---:|---:|
| P0 |  |  |  |  |  |  |
| P1 |  |  |  |  |  |  |
| P2 |  |  |  |  |  |  |

---

## 6. Key Proved Properties

This section should list only high-value, externally understandable results.

### Comments

Examples:

- comment tree ownership transfer preserves the ownership boundary;
- like and unlike paths preserve address-level state consistency;
- tree-status and comment-status transitions satisfy the intended constraints.

### Governance And Voting

Examples:

- proposal terminal-state transitions follow the governance lifecycle;
- early-decision and expiry logic satisfy the intended status constraints;
- locked voting-token claim paths satisfy basic correctness requirements;
- executable proposals bridge correctly into action tickets.

### Publishing

Examples:

- metadata attributes satisfy boundary constraints;
- artifact series status changes do not break core identity fields;
- artifact ownership transfer remains consistent with comments-tree binding;
- publishing governance execution paths satisfy configuration-change semantics.

### Function-Level Inventory

| Module | Proved Targets | Notes |
|---|---|---|
| comments |  |  |
| governance |  |  |
| publishing |  |  |

---

## 7. Outside-Baseline Or Toolchain-Limited Parts

Use this section to avoid overclaiming.

### Timeout Targets

| Target | Module | Current Status | Likely Cause | Follow-Up Plan |
|---|---|---|---|---|
|  |  | timeout | path complexity, quantifiers, or large state space | split paths or refine specs |

### Toolchain-Blocked Targets

| Target | Module | Current Status | Typical Error | Classification |
|---|---|---|---|---|
|  |  | blocked | `transfer_spec::SpecTransferAddress*` | toolchain limitation, not protocol counterexample |

### Specs Outside The Completed Baseline

List:

- high-priority items intentionally left outside the completed baseline;
- reason;
- whether they are maintenance, upstream-tooling, or future-scope items.

---

## 8. Known Limitations And Interpretation Boundary

This section is important for precisely bounding the conclusion.

Clarify that:

1. formal verification does not mean the protocol is absolutely vulnerability-free;
2. proved properties only cover the specifications listed in the report;
3. prover timeouts do not imply discovered vulnerabilities;
4. toolchain blockers do not imply discovered vulnerabilities;
5. some complex paths may remain outside current coverage.

Suggested wording:

> "Proved" in this report means that the corresponding specification has been checked under the current toolchain, contract version, and specification model. It should not be interpreted as a guarantee for all properties that were not modeled.

---

## 9. Final Conclusion

Use this section for the formal conclusion.

Recommended angles:

- strongest verified areas;
- weakest or most boundary-sensitive areas;
- whether a first trustworthy baseline exists;
- how the report should be used.

Example:

> PaperProof has established a formal-verification baseline around key public surfaces in comments, governance, and publishing. This baseline supports audit collaboration and ecosystem presentation, while keeping clear boundaries around properties outside the current specification and tooling model.

---

## 10. Maintenance And Extension Plan

### Maintain High-Value P0/P1 Coverage

- comments
- governance
- publishing
- cross-module binding

### Reduce Timeout Targets

- split paths;
- adjust spec-only predicates;
- refine postconditions.

### Isolate Toolchain Issues

- record transfer ghost-global blockers;
- avoid misclassifying them as protocol defects.

### Prepare External Report Versions

Recommended report types:

- engineering status document;
- external formal report.

---

## 11. Appendices

### Appendix A: Run Environment

- operating system:
- WSL version:
- Rust version:
- prover executable path:
- Boogie executable path:
- Z3 executable path:

### Appendix B: Command Examples

```bash
docs/formal-verification/run-sui-prover-wsl.sh governance-specs finalize_proposal_spec --timeout 240 --keep-temp
docs/formal-verification/run-sui-prover-wsl.sh comments-specs like_paper_spec --timeout 240 --keep-temp
docs/formal-verification/run-sui-prover-wsl.sh publishing-specs set_series_status_spec --timeout 240 --keep-temp
```

### Appendix C: Terms

- proved baseline
- processed target
- timeout target
- toolchain-shaped blocker
- transfer ghost global
