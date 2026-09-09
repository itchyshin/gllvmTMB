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
- `docs/dev-log/check-log.md`
- this report

No R likelihood/C++, public API, NAMESPACE, formula, documentation surface,
or Julia consumer changed.

## Checks Run

- RED: the old runner ignored define-only mode and demanded live environment
  variables.
- RED/GREEN follow-up: a clean source tree exposed a zero-length Git-output
  bug before package loading. The new clean-repository test failed first;
  scalarising successful empty Git output fixes the guard. Focused runner
  tests now pass **16 expectations**.
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
  overwrite of the historical receipt. A live run has not been attempted
  because the new branch does not yet have its authenticated frozen DLL.
  `git diff --check` passed.

## Tests Of The Tests

The tests reject an unapproved changed path, a mismatched loaded path, an
uncontrolled receipt location, a source revision change, and an untracked
source file. They also prove write-once evidence: first write succeeds, the
second is rejected, and the original bytes remain. Its controlled overwrite
mutation failed this preservation assertion.

## Known Limitations

No native pair was rerun here. The runner must still be invoked from a clean,
frozen build to refresh a receipt. This does not qualify S3b/S4, recovery,
coverage, dense VCV, or generic `engine = "julia"` support.

## Next Actions

Run the repaired verifier from an authenticated clean frozen build, then pay
the separate S4 seven-target-census and authoritative-route gates.
