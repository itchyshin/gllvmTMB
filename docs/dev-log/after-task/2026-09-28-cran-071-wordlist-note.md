# After Task: Correct 0.7.1 DESCRIPTION spelling suggestions

**Branch**: `codex/cran-071-first-20260927`  
**Date**: 2026-09-28  
**Roles (engaged)**: Ada

## 1. Goal

Correct only the DESCRIPTION spelling suggestions reported by both exact-candidate Win-builder logs and prepare a new 0.7.1 candidate without carrying forward the old tarball's checks as current evidence.

## 2. Implemented

Added the six observed terms `Lindstrom`, `Nakagawa`, `SDMs`, `al`, `et`, and `multispecies` to the package's existing `inst/WORDLIST`. The spelling package now reports no spelling errors. The old hash is marked superseded in the release-only `cran-comments.md`; a new source commit, tarball, and full check set are still required.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown navigation change.

## 4. Files Touched

- `inst/WORDLIST`: added only the six terms reported in the Win-builder DESCRIPTION NOTE.
- `cran-comments.md`: marked hash `69a3b4ae851c5995e0d8470411368c13fce996fb2b0842b0751420849b57bb2c` as superseded and listed the new candidate evidence as pending. This file is excluded from the package archive.
- `docs/dev-log/check-log.md`: records the observed spelling result and the next-candidate boundary.
- `docs/dev-log/after-task/2026-09-28-cran-071-wordlist-note.md`: this phase report.

No README, NEWS, roadmap, design document, vignette, generated help, or model source changed.

## 3a. Decisions and Rejected Alternatives

Keep the DESCRIPTION text unchanged and use the existing package word list to record technical terms and proper names. This directly addresses the observed spell-check suggestions while avoiding changes to product wording. No alternative was tested.

## 5. Checks Run

- `Rscript --vanilla -e 'x <- spelling::spell_check_package(".", vignettes = FALSE); print(x[grepl("DESCRIPTION", x[["FOUND IN"]]), , drop = FALSE])'`: exit 0; `No spelling errors found.` The function uses the package word list. This screening found no spelling errors across checked package text and the word list. The new tarball CRAN incoming check remains outstanding.
- `git diff --check`: passed with no output.
- The prior exact-candidate R-devel and R 4.6.1 `00check.log` files were inspected; both report the six suggestions and 1 NOTE. They are predecessor evidence and were not reused for the new source.
- Not yet run: new tarball build, exact-tarball `R CMD check --as-cran --run-donttest`, fresh three-OS CI, or fresh Win-builder checks.

## 6. Tests of the Tests

No package test was changed. The failure-before-fix evidence is the predecessor Win-builder log's DESCRIPTION suggestions. The post-edit spelling screen returns no spelling errors. The exact incoming check must still verify the result on the new tarball.

## 8. Consistency Audit

- `rg -n 'Lindstrom|Nakagawa|SDMs|multispecies|\b(al|et)\b' inst/WORDLIST`: each of the six reported terms is now present; no package prose or DESCRIPTION wording was changed.
- `git diff --check`: passed; no whitespace errors.
- Model/API stale-wording scans were not run because no user-facing model claim, syntax, or package API changed.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. Issue Ledger

Inspected open issue [#345](https://github.com/itchyshin/gllvmTMB/issues/345), the CRAN readiness umbrella. Its current text still describes the earlier 0.6.0 plan; the current 0.7.1 preparation is governed by the maintainer-approved release plan and `.unlazy/cran-071/GATES.md`. No issue comment or issue state change was made in this phase. No other open issue was relevant to this spelling correction.

## 9. What Did Not Go Smoothly

Both Windows logs passed substantive checks but still reported avoidable DESCRIPTION spelling suggestions. Their 14-minute test stage and roughly 18-minute full check also leave the separate local timing gate unresolved.

## 11. Team Learning

**Ada:** Compare every incoming NOTE with the shipped word list before freezing; a package-wide spelling screen is useful, but the exact incoming check remains authoritative. Keep prior-hash logs labelled as predecessor evidence after any installed-byte change.

## 12. Cross-Product Coverage

No design documentation, pkgdown article, or reader-facing documentation changed. The CRAN comment draft records that a new candidate is pending. This spelling correction does NOT cover any API, model engine, feature, or reader-facing claim.

## 10. Known Residuals

The source tree is not yet committed cleanly and no new tarball exists. Commit the word-list correction, build and identify a new archive, verify the incoming NOTE, then rerun exact-artifact checks and external services. The Windows timing gate, Ubuntu result for the predecessor source, R-hub, and live-site G4 distinction remain open. This phase does not establish submission readiness and no upload has occurred.
