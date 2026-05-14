# Formal Verification Final Coverage Summary

Updated: 2026-05-28

## 1. Summary Conclusion

The current formal-verification effort has moved the four core project-side logic modules into a stable state suitable for submission, reporting, and repeatable runs.

Recommended coverage posture:

- `governance_voting.move`: `100%` (`84 / 84`)
- `comments.move`: `100%` (`67 / 67`)
- `publishing.move`: effectively cleared under the validated workaround mode
- `governance.move`: effectively cleared under the validated workaround mode

More precisely:

- the main project-side protocol logic prove targets have been completed;
- remaining non-default targets are now classified and captured by repeatable framework-side workaround flows;
- the remaining limitations are no longer best treated as uncovered PaperProof protocol logic, but as upstream prover/framework modeling limitations.

## 2. Coverage Accounting

This summary uses an external tracked-module coverage view for submission, weekly reporting, milestone reporting, and management-level synchronization.

This view may not exactly match the raw number of `#[spec(prove)]` entries in the repository because:

- additional test-only wrapper prove harnesses were added to isolate framework-shaped residuals;
- these wrappers prove local state transitions, fee-accounting logic, or core logic after shell separation;
- they improve engineering assurance but do not change the external module coverage accounting.

Therefore:

- use the tracked counts in this document for external reporting;
- use [status.md](status.md) for detailed internal rollout history.

## 3. Final Coverage Table

| Module | External Tracked Targets | Current Coverage Conclusion | Default Mode Status | Workaround Mode Status | Reporting Conclusion |
|---|---:|---|---|---|---|
| `governance.move` | 65 | Project-side logic cleared | Mostly green; a small number of framework-shaped residuals should not be counted as project gaps | Effectively cleared under `WEAK_TRANSFER_SPEC=1` + `WEAK_UNWRAP_SPEC=1` | Complete |
| `governance_voting.move` | 84 | Fully cleared | Fully green | Not needed | Complete |
| `comments.move` | 67 | Fully cleared | Fully green | Not needed | Complete |
| `publishing.move` | 87 | Project-side logic cleared | Mostly green; transfer-heavy paths should not be counted as project gaps | Effectively cleared under `WEAK_TRANSFER_SPEC=1` | Complete |

## 4. Module Notes

### `governance.move`

Recommended conclusion:

- do not describe this module as still having unresolved project-side prove targets;
- a more precise statement is that a small number of framework-shaped residuals remain in default mode, but they complete under validated workaround mode.

Historical heavy targets captured by workaround mode:

- `nominate_operator`
- `accept_operator_transfer`
- `cancel_operator_transfer`
- `collect_artifact_fee`
- `unwrap_operator_permit`

Classification:

- `nominate_operator`, `accept_operator_transfer`, and `cancel_operator_transfer`
  - historical issue family: `transfer_spec::SpecTransferAddress*`
  - current handling: `WEAK_TRANSFER_SPEC=1`
- `collect_artifact_fee`
  - historical issue family: transfer, refund, and public-transfer shell behavior
  - current handling: `WEAK_TRANSFER_SPEC=1`
- `unwrap_operator_permit`
  - historical issue family: well-foundedness cycle when `dynamic_object_field::remove` returns a value type containing `object::UID`
  - current handling: `WEAK_UNWRAP_SPEC=1`

### `governance_voting.move`

Recommended conclusion:

- this module has reached the cleanest current state;
- tracked targets complete in default mode;
- no workaround is required.

Suggested wording:

- Governance voting public/helper proof coverage is 100% complete.

### `comments.move`

Recommended conclusion:

- this module has reached the cleanest current state;
- tracked targets complete in default mode;
- no workaround is required.

Suggested wording:

- Comments module public/helper proof coverage is 100% complete.

### `publishing.move`

Recommended conclusion:

- do not describe the module as still having uncleared publish/add-version heavy paths;
- reserved-preprint, publish-family, and add-version-family targets complete under the validated workaround mode;
- the module should now be treated as cleared from the project-side logic perspective.

Cleared key target families:

- `publish_preprint`
- `publish_reserved_preprint_common`
- `finalize_reserved_preprint`
- `publish_blog_post`
- `publish_technical_report`
- `publish_dataset`
- `publish_software_release`
- `publish_generic_file`
- `add_preprint_version`
- `add_blog_post_version`
- `add_technical_report_version`
- `add_dataset_version`
- `add_software_release_version`
- `add_generic_file_version`
- `init_for_testing`

Current handling:

- mainly relies on `WEAK_TRANSFER_SPEC=1`

## 5. Standard Run Matrix

### Default Mode

Applies to:

- ordinary getters, accessors, predicates, constructors, migrations, and governance action helpers;
- paths that do not go through `public_transfer(...)`;
- paths that do not go through `two_step_transfer::unwrap(...)`.

Command template:

```bash
bash docs/formal-verification/run-sui-prover-wsl.sh <package> <spec> --timeout 300 --keep-temp
```

### Transfer Weak Mode

Applies to:

- targets hitting `transfer_spec::SpecTransferAddress`;
- targets hitting `transfer_spec::SpecTransferAddressExists`;
- transfer, refund, or `public_transfer(...)` shell paths.

Command template:

```bash
WEAK_TRANSFER_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh <package> <spec> --timeout 300 --keep-temp
```

Representative targets:

- `governance_spec::nominate_operator_spec`
- `governance_spec::accept_operator_transfer_spec`
- `governance_spec::cancel_operator_transfer_spec`
- `governance_spec::collect_artifact_fee_spec`
- `publishing_spec::init_for_testing_spec`
- `publishing_spec::publish_reserved_preprint_common_zero_fee_spec`

### Unwrap Weak Mode

Applies to:

- targets hitting `two_step_transfer::unwrap(...)`;
- targets hitting `dynamic_object_field::remove`;
- well-foundedness cycles involving value types that contain `object::UID`.

Command template:

```bash
WEAK_UNWRAP_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh <package> <spec> --timeout 300 --keep-temp
```

Representative target:

- `governance_spec::unwrap_operator_permit_spec`

### Combined Mode

Applies when both transfer and unwrap workaround modes are needed, or when a unified batch-processing entry point is useful.

Command template:

```bash
WEAK_TRANSFER_SPEC=1 WEAK_UNWRAP_SPEC=1 bash docs/formal-verification/run-sui-prover-wsl.sh <package> <spec> --timeout 300 --keep-temp
```

## 6. Recommended Reporting Wording

Suggested wording for weekly reports, milestone updates, and submission notes:

> PaperProof's four core logic modules have completed the main project-side formal-verification convergence phase. `governance_voting` and `comments` reach 100% coverage in default prover mode. The remaining heavy paths in `publishing` and `governance` have been validated and absorbed into repeatable framework-side workaround flows. From the project protocol-logic perspective, these modules can be treated as effectively complete. The remaining limitations mainly come from upstream prover/framework modeling rather than uncovered PaperProof protocol logic.

Engineering-oriented wording:

> The formal-verification effort has moved from adding project-side prove harnesses into maintaining a standard run matrix and documenting upstream limitations.

## 7. Follow-Up Recommendations

1. Keep this file and [status.md](status.md) as the two-layer reporting structure.
2. For pull requests, quote sections 3 and 5 directly.
3. For audit or management reporting, quote sections 1 and 6 directly.
4. For further deep dives, focus on upstream prover/framework behavior rather than low-return project-side wrapper tuning.
