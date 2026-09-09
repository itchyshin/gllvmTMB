# After Task: Destination B S3b receipt runner hardening

## Goal

Make the authorised frozen-R three-cell S3b verifier fail before expensive
fits on invalid provenance and retain its evidence without overwrite risk.

## Implemented

The runner is now sourceable in explicit define-only mode for contract tests.
It validates frozen ancestry, the exact approved S3b/S4 changed-path set, and
clean, unchanged R and Julia source snapshots before parsing/loading the
package or running native fits. It binds the actual R-loaded shared object to
this checkout's `src/gllvmTMB.so`, and binds both Julia's active project and
the loaded `GLLVM` package root to the supplied clean checkout. Its JSON
receipt uses a caller-supplied path constrained to the artifact directory, a
temporary file, and an exclusive hard link; an existing receipt is preserved.

## Files Changed

- `tests/testthat/run-destination-b-s3b-native-pairs-isolated.R`
- `tests/testthat/test-destination-b-s3b-native-pairs-runner.R`
- `docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt-v2.json`
- `docs/dev-log/check-log.md`
- this report

No R likelihood/C++, public API, NAMESPACE, formula, documentation surface,
or Julia consumer changed.

## Checks Run

- RED: the old runner ignored define-only mode and demanded live environment
  variables.
- RED/GREEN follow-up: a clean source tree exposed a zero-length Git-output
  bug before package loading. The new clean-repository test failed first; the
  clean-status guard now accepts an empty vector while preserving multi-line
  Git output. Focused runner tests now pass **16 expectations**.
- A live pre-run then exposed a second pre-fit runner defect: treating Git
  output as scalar fixed clean statuses but collapsed a multi-file changed-path
  list. A two-file Git-diff test now preserves the vector contract while the
  clean-status guard handles an empty vector.
- The first package-load pre-run showed that `pkgload` copies a verified shared
  library to a temporary path. The runner therefore records both the
  authenticated source and loaded paths, and accepts the latter only when its
  SHA-256 is identical; a same-bytes copy passes while a different binary
  fails.
- The new configured receipt path is mandatory; this prevents accidental
  overwrite of the historical receipt. Authenticated live replay passed all
  **48** selected expectations with no failures, skips, errors, or warnings in
  **28.1 seconds**. Its immutable v2 receipt is
  `docs/dev-log/artifacts/2026-09-09-destination-b-s3b-native-pairs-receipt-v2.json`
  (SHA-256 `6b4c19670e154bd7f64d706ee98fc0fe974ae7834225b8cf70749a16228faa97`).
  It binds frozen ancestry, clean/stable R and Julia commits, source and
  loaded-DLL paths with equal SHA-256, runner hash, fixtures, seeds, and pair
  deltas. `git diff --check` passed.

## Tests Of The Tests

The tests reject an unapproved changed path, a mismatched loaded path, an
uncontrolled receipt location, a source revision change, and an untracked
source file. They also prove write-once evidence: first write succeeds, the
second is rejected, and the original bytes remain. Its controlled overwrite
mutation failed this preservation assertion.

## Known Limitations

The replay covers only three controlled Gaussian, closed-adapter cells. It
does not qualify S3b/S4, recovery, coverage, dense VCV beyond its recorded
cell, scalable-gradient performance, or generic `engine = "julia"` support.

## Next Actions

Persist the immutable receipt with its exact allowlist entry, then pay the
separate S4 seven-target-census and authoritative-route gates.
