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
- GREEN: focused runner tests passed **10 expectations**.
- The new configured receipt path is mandatory; this prevents accidental
  overwrite of the historical receipt. A live run has not been attempted
  because the new branch does not yet have its authenticated frozen DLL.
  `git diff --check` passed.

## Tests Of The Tests

The tests reject an unapproved changed path, a mismatched loaded path, and an
uncontrolled receipt location. They also prove write-once evidence: first
write succeeds, the second is rejected, and the original bytes remain. Its
controlled overwrite mutation failed this preservation assertion.

## Known Limitations

No native pair was rerun here. The runner must still be invoked from a clean,
frozen build to refresh a receipt. This does not qualify S3b/S4, recovery,
coverage, dense VCV, or generic `engine = "julia"` support.

## Next Actions

Run the repaired verifier from an authenticated clean frozen build, then pay
the separate S4 seven-target-census and authoritative-route gates.
