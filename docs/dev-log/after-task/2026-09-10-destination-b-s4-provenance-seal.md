# After Task: Destination B S4 provenance seal

## Goal

Seal the selected committed S4 adapter/test source and its locally built R DLL
identity without reusing the retained S3b binary identity or running an S4 fit.

## Implemented

`docs/dev-log/artifacts/2026-09-10-destination-b-s4-phylo-dep-build-seal/`
contains a Git archive of clean commit `8889d8a4d2d88e1cfd60f7b644eb79e71a7346f4`,
the isolated installation, both build attempt records, and an immutable JSON
seal. The S4 runner now reads that seal explicitly. Before any runtime work it
uses two roots. The archive/build root is the exact pinned source archive at
`8889d8a4d2d88e1cfd60f7b644eb79e71a7346f4`, with its archive and DLL hashes.
The runner/runtime root must instead be a clean descendant with an empty
`8889d8..HEAD -- R src DESCRIPTION` diff and unchanged selected adapter/test
hashes; later runner or documentation commits are permitted and its actual HEAD
is recorded. The old S3b frozen manifest remains retained but unselected. This
is a DLL build identity seal, not a fully reproducible runtime: dependency
binaries are not sealed.

## Files Changed

- `tests/testthat/run-destination-b-s4-public-phylo-dep-isolated.R`
- `tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R`
- `docs/dev-log/artifacts/2026-09-10-destination-b-s4-phylo-dep-build-seal/`
- `docs/dev-log/check-log.md`
- this report

## Tests Added

The runner contract rejects altered seal bytes/source hashes, a stale archive
root, a non-descendant runtime root, a dirty runtime root, and package-source
drift. It accepts a clean descendant containing only later runner/docs changes.
The test was RED before the runtime-root validator existed.

## Build Evidence

The archive SHA-256 is
`62208640189794c6e442b98e6917f22abb9d6f78ae0d15edc85ccaeac6929080`.
The successful isolated build took 74.4 seconds. Its source and loaded DLL
SHA-256 is `eba1d3c5d5c26303f0e730a87ee70a627eb508c35f9419610fad08e37ccbb2f8`,
UUID `793A5DB4-227D-33C4-9DCE-2BE66FD6865F`, and size 4,988,376 bytes.
The initial staged-build failure and the one successful no-staged-install
remedy are both retained under the seal directory.

## Checks Run

`Rscript --vanilla -e 'devtools::test_active_file("tests/testthat/test-destination-b-s4-public-phylo-dep-runner.R", reporter = "summary")'`
passed with no failures, errors, or warnings. `git diff --check`
is clean for authored runner/test/docs paths; raw retained compiler and
installed-package evidence is excluded because modifying it would alter evidence.

## Parity, JET, Allocs, Aqua

N/A — this is provenance-only runner/artifact work; no likelihood, Julia, or
fit path was exercised.

## Remaining Risks

- The seal authenticates this local ARM macOS build only.
- Dependency binaries are not sealed; this is not a fully reproducible runtime.
- The runtime root may differ from the archive/build root only outside `R`,
  `src`, and `DESCRIPTION`; it remains a provenance boundary, not qualification.
- It is build identity, not S4 qualification. No fit, receipt, recovery,
  coverage, generic-engine admission, or parity claim is created.

## Rose Verdict

Rose verdict: PASS WITH NOTES — the S4 build identity is sealed; qualification
remains intentionally absent.
