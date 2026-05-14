# PaperProof Publishing Specs

This package is a prover-only specification package for the
`paperproof_publishing` Move package.

It exists because `sui-prover` specifications may cause normal Move compilation
errors when they are placed directly alongside production modules. The specs here
use `target = ...` annotations to verify selected `paperproof_publishing`
functions without changing the runtime package layout.
