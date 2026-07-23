# After Task: RC.2 honesty correction and non-CRAN v0.6.0 tag

**Branch**: `claude/0.6-m1-close-20260722`  
**Date**: 2026-07-23  
**Roles (engaged)**: Ada, Rose, Grace, Noether

## 1. Goal

Replace every active calibration-claim class with an honest boundary: point
estimates and focused route tests are supported; no interval is
coverage-calibrated. Freeze and verify an exact RC.2 candidate, then make the
maintainer-authorised GitHub-only `v0.6.0` tag without a CRAN upload.

## 2. Implemented

The original 11-file rewording sweep was completed, then the shipped internal
`R/coverage-study.R` prototype and its focused test wording were corrected when
an independent review found a legacy 94% coverage gate. `v0.6.0-rc.2` and
`v0.6.0` both point to `c0af58d3f64593bff2d11adfeb0dba0c24c0ca5b`.

## 3. Files Changed

- Claim correction: `R/coverage-study.R`, `tests/testthat/test-coverage-study.R`.
- Original 11 sweep files and regenerated Rd pages: committed in `e4fdc370`.
- Release record: `cran-comments.md`, `docs/dev-log/check-log.md`, and this
  after-task report.

No public R API, likelihood, formula grammar, family, NAMESPACE, vignette, or
pkgdown-navigation change occurred. No user-facing example convention changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** release `v0.6.0` on GitHub only at the verified RC.2 source.
**Rationale:** the maintainer explicitly separated versioning from CRAN
distribution and authorised the non-CRAN release. **Rejected:** CRAN upload;
it remains solely a later maintainer decision. **Confidence:** high for the
tag identity and non-CRAN boundary; R-devel email remains supplementary.

## 4. Checks Run

- `devtools::document()` — expected Rd-only regeneration in the original sweep.
- `pkgdown::check_pkgdown()` and `urlchecker::url_check()` — passed.
- Full structured test suite — 0 failures/errors, 779 skips.
- Corrected exact tarball: SHA-256
  `559db1f97260326633bac540aae0df2bd14f7afd46345b71c401df15aacd6aee`,
  3,241,935 bytes, 595 files, clean forbidden-path scan.
- `R CMD check --as-cran --run-donttest` on that tarball — 0 errors, 0
  warnings, 1 expected New-submission NOTE.
- Fast exact-tag CI `30011350134` — macOS/Windows/Ubuntu `Status: OK`.
- Heavy exact-tag CI `30011327933` — public workflow Success at `c0af58d3`;
  public macOS and Ubuntu job receipts success; overall Success proves Windows
  success. Raw GitHub job logs were unavailable after an API rate limit.
- `devtools::check_win_devel()` — submitted; email result pending at closeout.
- `git rev-parse v0.6.0^{}` and `git rev-parse v0.6.0-rc.2^{}` — both
  `c0af58d3f64593bff2d11adfeb0dba0c24c0ca5b`.

Exact scans:

```sh
rg -n -i 'coverage[- ]calibrat|calibrated coverage|coverage gate|95% coverage|94% coverage' R man README.md NEWS.md vignettes docs
rg -n -i 'coverage[- ]calibrat|calibrated coverage|coverage gate|95% coverage|94% coverage' . --glob '!docs/dev-log/**' --glob '!docs/design/**'
```

## 5. Tests of the Tests

The focused coverage-study test is a boundary/prophylactic wording guard: it
fails if the prototype again labels exploratory output as a coverage gate. The
full tarball check exercised the installed test suite independently of the
source tree.

## 6. Consistency Audit

The two exact scans above found historical records only in the first broad
scope and no positive claim on active shipped surfaces in the second scope.
Design 75 remains the authority: no matrix cell is empirical-coverage-
calibrated; CI-08 and CI-10 remain open/failing.

## 7. Roadmap Tick

**Roadmap tick:** N/A — this is a release-evidence and claim-boundary closure;
no `ROADMAP.md` status row changed.

## 7a. GitHub Issue Ledger

PR #780 was inspected as the active M1 closeout vehicle. No issue was closed or
created: the correction is a release-recorded scope repair, and EVA/Design-86
remains a separately deferred lane.

## 8. What Did Not Go Smoothly

The late internal prototype wording required an RC.2 tag replacement. GitHub
then rate-limited authenticated Actions and release APIs: public workflow status
was recoverable, raw job text and GitHub-release creation were not. The
R-devel win-builder email was also pending.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** kept the frozen source and the later non-CRAN ceremony separate from
the Design-86 lane. **Rose:** found that an internal shipped source can still
contradict public claim boundaries. **Grace:** retained tarball, exact-tag, and
platform provenance; never promoted a pending R-devel email to a pass.
**Noether:** anchored wording to the Design 75 truth matrix rather than a
legacy empirical gate.

## 10. Known Limitations And Next Actions

`v0.6.0` is experimental and non-CRAN. There is no CRAN submission. Capture the
R-devel email and, after GitHub API recovery, create the matching GitHub release
from the already-pushed `v0.6.0` tag. EVA remains cut to a new 0.7 decision lane;
do not mix it into this release branch.
