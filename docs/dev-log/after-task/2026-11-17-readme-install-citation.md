# After Task: README CRAN install and citation version

**Branch**: `cursor/readme-install-citation-197e`
**Date**: `2026-11-17`
**Roles (engaged)**: `Pat / Rose / Grace / Shannon`

## 1. Goal

Fix two README errors on the same page: the citation hard-coded
`0.8.0.9000` while `DESCRIPTION` and `citation()` give `0.8.0` (#1807),
and the Install section showed only the GitHub `pak` route even though
gllvmTMB is on CRAN (#1809).

## 2. Implemented

No public API / likelihood / grammar / family change.

- README citation now says `R package version 0.8.0`, matching
  `DESCRIPTION` `Version: 0.8.0` and `inst/CITATION` (which reads that
  field). `citation("gllvmTMB")` remains the canonical formatted entry.
- README Install now leads with `install.packages("gllvmTMB")` and names
  the CRAN release as **0.7.1** (CRAN page
  <https://cran.r-project.org/package=gllvmTMB>, published 2026-10-28),
  then keeps the GitHub `pak` command for the development source.
- The getting-started vignette has one sentence pointing at that Install
  section.
- There is no `README.Rmd`; `README.md` is the source.

## 3. Files Changed

- `README.md` — Install section and citation version
- `vignettes/gllvmTMB.Rmd` — one-sentence pointer to README Install
- `docs/dev-log/check-log.d/2026-11-17-readme-install-citation.md`
- `docs/dev-log/after-task/2026-11-17-readme-install-citation.md`

Not changed: `NEWS.md` (docs-only README/vignette wording is not a NEWS
convention here; 0.8.0 NEWS records behaviour and test-path changes, not
README install copy), `DESCRIPTION`, `inst/CITATION`, `_pkgdown.yml`,
tests, R, src.

## 3a. Decisions and Rejected Alternatives

**Decision**: Keep a hard-coded README citation at `0.8.0` and add the
CRAN install command without the phrase
`The released package is available from CRAN`.
**Rationale**: Issue #1807 allows either matching DESCRIPTION or dropping
the hard-coded line; matching is the smaller edit. The existing source
checkout test still requires `pak::pak("itchyshin/gllvmTMB")` and forbids
that exact CRAN sentence (added in #1311 before the package was on CRAN).
This slice does not change tests.
**Rejected alternative**: Replace the citation bullet with a pointer to
`citation("gllvmTMB")` only. The README already tells the reader to run
that function; the bullet is the copy-pasteable example.
**Confidence**: high.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-17-readme-install-citation.md`.
This VM has no R binary, so `devtools::test()` / `pkgdown::check_pkgdown()`
were not run here. The README/vignette assertions from
`test-reader-facing-no-register-codes.R`,
`test-issue-1328-first-fit-messages.R`, and the #1327 visible-chunk
contract were replicated on the edited files. GitHub Actions is the R
check.

## 5. Tests of the Tests

No tests added or changed.

## 6. Consistency Audit

Exact patterns and verdicts:

- `rg -n "0\\.8\\.0\\.9000" README.md vignettes/gllvmTMB.Rmd` — no hits
  (PASS for the two files this slice owns; `_pkgdown.yml` still has the
  development-banner string and was left alone).
- `rg -n 'install.packages\\("gllvmTMB"\\)|pak::pak\\("itchyshin/gllvmTMB"\\)|R package version 0\\.8\\.0' README.md` —
  CRAN command, GitHub command, and citation `0.8.0` all present.
- `rg -n "The released package is available from CRAN" README.md` — no
  hit, so the #1311 assertion still holds.
- `rg "\\bS_B\\b|\\bS_W\\b|\\\\bf S" README.md vignettes/gllvmTMB.Rmd` —
  no hits.
- `rg "in prep|in preparation" README.md vignettes/gllvmTMB.Rmd` — no hits.
- `rg "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/gllvmTMB.Rmd` —
  no hits.
- `rg "meta_known_V" README.md vignettes/gllvmTMB.Rmd` — no hits.
- `rg "gllvmTMB_wide" README.md vignettes/gllvmTMB.Rmd` — no hits.
- `rg -n "Fixes |Closes |Resolves " README.md vignettes/gllvmTMB.Rmd` —
  no hits.
- Reader-facing register-code scan of the two files — no `FAM-` / `FG-` /
  `MIX-` / `SPA-` / `VA-` / `CI-` / `ISDM-` hits.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

- Inspected [#1807](https://github.com/itchyshin/gllvmTMB/issues/1807)
  (README citation `0.8.0.9000` vs DESCRIPTION `0.8.0`).
- Inspected [#1809](https://github.com/itchyshin/gllvmTMB/issues/1809)
  (README Install omitted the CRAN route).
- Neither issue is closed by this PR (`refs #1807` / `refs #1809` only).
- No new issue created.

## 8. What Did Not Go Smoothly

This Cloud Agent VM has no R, so the package tests could not be executed
locally. The GitHub `R-CMD-check` workflow is the R-side evidence.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Pat**: a first-use reader now sees `install.packages("gllvmTMB")`
  before compiling from GitHub, and the citation they copy matches the
  installed development version.
- **Rose**: the CRAN sentence is the drmTMB Install wording, not the
  #1311-forbidden "released package is available" line. Citation version
  is DESCRIPTION, not the old `0.8.0.9000` development tag.
- **Grace**: CRAN version 0.7.1 was read from the live CRAN package page
  on 2026-11-17; GitHub CI owns the package check because this VM has no
  R.
- **Shannon**: no open PR edits source `README.md`. This is a docs-only
  draft PR on a `cursor/` branch.

## 10. Known Limitations And Next Actions

- `_pkgdown.yml` still labels the site as experimental development
  documentation for `0.8.0.9000`. That is outside #1807 / #1809.
- `test-reader-facing-no-register-codes.R` still forbids the old CRAN
  sentence and does not yet require `install.packages("gllvmTMB")`. A
  later test-only slice could require the CRAN command.
- The hard-coded CRAN version `0.7.1` will need a README bump when a
  newer CRAN release lands.
