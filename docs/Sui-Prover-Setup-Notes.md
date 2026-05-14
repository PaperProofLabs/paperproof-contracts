Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

# Sui Prover Setup Record

This note records the setup baseline that was used for the completed
`paperproof-contracts` formal-verification work. It is retained as a
reproduction and environment reference for the completed verification baseline.

## 1. Verification workspace

The verification work is now maintained in a dedicated WSL workspace and branch,
separate from the Windows development checkout used for routine contract work.

- Windows development workspace:
  - `paperproof-contracts`
- WSL verification workspace:
  - `paperproof-contracts`
- WSL verification branch:
  - `formal-verification`
- Companion token dependency workspace:
  - `PPRF-token-contracts` under `~/work/sui-depends`
- Local prover source tree:
  - `sui-prover` under `~/work/sui-depends`

This separation is intentional. It avoids path translation issues, Windows-side
workspace pollution, and accidental mixing between routine contract development
and prover-oriented edits.

## 2. Toolchain Baseline

The following pieces are confirmed working:

- `sui-prover` builds successfully in WSL
- the WSL verification checkout can build the `publishing` package and run the
  bootstrap `publishing-specs` proof successfully
- `Z3` is installed on Windows via Chocolatey
- `Boogie` was built successfully from source
- `.NET 8 SDK` is installed on Windows

Relevant external paths:

- `Z3_EXE`:
  - `/mnt/c/ProgramData/chocolatey/bin/z3.exe` or the equivalent local Z3 path
- `BoogieDriver`:
  - `/mnt/c/Users/{user}/.tools/boogie-src/Source/BoogieDriver/bin/Release/net8.0/BoogieDriver.exe` or the equivalent local Boogie path

These are referenced from WSL using `/mnt/c/...` paths.

## 3. Important finding: specs should not be mixed into production modules

An initial experiment added `#[spec_only]`, `#[spec(...)]`, and
`use prover::prover::{...}` directly into `publishing/sources/*.move`.

That approach was rejected and reverted for the following reason:

- normal `sui move build` reported:
  - unknown `spec_only` attribute
  - unknown `spec` attribute
  - unresolved `prover::prover`

This matches the `sui-prover` guidance:

> if specs cause compile errors alongside regular Move code, place them in a
> separate package and use `target = ...`

Therefore, PaperProof should use a dedicated spec package for prover work.

## 4. Separate spec package attempt

A first dedicated package was created:

- `publishing-specs/Move.toml`
- `publishing-specs/sources/publishing_spec.move`

Its purpose is to host early P0 specifications for:

- supported artifact type space
- artifact type name mapping
- basic validation input constraints

The package is intended to use:

- `paperproof_publishing` as the target package
- `Prover` as the prover support package
- local overrides for `MoveStdlib` and `Sui`

## 5. Bootstrap result

The separate `publishing-specs` package is now running successfully in the WSL
verification workspace.

The first proved property is:

- `paperproof_publishing::artifact_types::assert_supported`

That proof was executed with:

- a dedicated spec package: `publishing-specs/`
- a vendored prover support Move package under `publishing-specs/vendor/prover`
- local WSL-visible caches for:
  - `asymptotic-code/sui`
  - `asymptotic-code/sui-prover`
  - `OpenZeppelin/contracts-sui`

The key command shape is:

```bash
/home/{user}/dev/sui-prover/target/release/sui-prover \
  -p . \
  -g \
  -v \
  --timeout 120 \
  --keep-temp \
  --skip-fetch-latest-git-deps
```

Environment variables used during the successful run:

- `BOOGIE_EXE=/mnt/c/Users/{user}/.tools/boogie-src/Source/BoogieDriver/bin/Release/net8.0/BoogieDriver.exe`
- `Z3_EXE=/mnt/c/ProgramData/chocolatey/bin/z3.exe`

## 6. Historical Setup Limitations

During bootstrap, the prover setup had the following rough edges:

- the current spec package explicitly lists `MoveStdlib` and `Sui`, which causes
  a prover warning about implicit dependencies being disabled;
- the workflow currently assumes WSL-visible local cache paths under
  `/home/{user}/.move/` and Windows-mounted source paths under `/mnt/c/...`;
- only the first bootstrap property has been proved so far.

These setup rough edges were not blockers for the completed verification
baseline recorded in this branch.

## 7. Practical Conclusion

The setup work established three concrete outcomes:

1. the prover runtime stack is usable for PaperProof;
2. the correct PaperProof integration model is a separate prover-spec package,
   not inline spec annotations inside production contract modules;
3. the first bootstrap spec has already been proved successfully.

The later verification work expanded from this bootstrap into the completed
module coverage and run matrix documented in
`docs/Formal-Verification-Final-Report.md`.

