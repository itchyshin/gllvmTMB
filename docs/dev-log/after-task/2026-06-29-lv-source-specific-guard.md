# After Task: LV Source-Specific Fail-Loud Guard

**Branch**: `codex/lv-source-guard-20260628`
**Date**: `2026-06-29`
**Roles (engaged)**: `Ada / Boole / Fisher / Curie / Rose / Grace`

## 1. Goal

Protect the Design 73 `latent(..., lv = ~ x)` claim boundary while phylo Model
A and source-specific R exposure remain gated. Ordinary unit-tier `latent()`
may carry predictor-informed LV metadata; source-specific phylo, animal,
spatial, kernel, and deprecated/internal aliases must fail loudly rather than
silently dropping `lv`.

## 2. Implemented

- Added `tests/testthat/test-lv-source-specific-guard.R`.
- The test proves ordinary `latent(0 + trait | unit, d = 1, lv = ~x)` stores
  the `lv_formula` metadata.
- It checks fail-loud behaviour for `phylo_latent()`, `phylo_unique()`,
  `animal_latent()`, `animal_unique()`, `spatial_latent()`, generic
  `spatial(..., mode = "latent")`, `kernel_latent()`, and `kernel_unique()`.
- It checks deprecated/internal aliases so `rr()` can still desugar to
  ordinary `latent()` with `lv`, while `diag()`, `phylo_rr()`, and `spde()`
  cannot carry unsupported `lv` metadata into fitting setup.

## 3. Files Changed

Tests:

- `tests/testthat/test-lv-source-specific-guard.R`

Evidence records:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-29-lv-source-specific-guard.md`

## 3a. Decisions and Rejected Alternatives

Decision: make this a fail-loud guard, not a source-specific implementation.
Rationale: phylo Model A still needs DRAC evidence and maintainer sign-off
before R grammar exposure.
Rejected alternative: accept `lv = ~ x` in `phylo_latent()` now and rely on a
later bridge layer to reject unsupported cases.
Confidence: high; this matches the current LV arc claim boundary.

Decision: keep deprecated alias coverage in the same guard test.
Rationale: the risk is silent metadata loss through compatibility syntax, not
only through the public keyword grid.
Rejected alternative: test only canonical source-specific functions.
Confidence: high.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; no open gllvmTMB PRs after PR #572 merged.
- `git log --all --oneline --since="6 hours ago" -- docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-29-lv-source-specific-guard.md tests/testthat/test-lv-source-specific-guard.R tests/testthat/test-lv-parser-guard.R`
  -> REVIEWED; only this queued source-guard branch and the just-merged
  Bernoulli branch had touched nearby LV files.
- `git rebase origin/main`
  -> PASS; branch rebased cleanly after PR #572.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-source-specific-guard", reporter = "summary")'`
  -> PASS; focused source-specific guard tests completed with no failures.
  Expected lifecycle messages appeared for deprecated aliases.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; parser guard remained green with the existing informational
  sigma-eps auto-suppression message.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 5m05.8s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.
- `git diff --check`
  -> PASS; no whitespace errors.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-29-lv-source-specific-guard.md`
  -> PASS; validator returned successfully.

## 5. Tests of the Tests

This is a prophylactic grammar-boundary test. It would fail if source-specific
or deprecated aliases started accepting `lv` silently, if ordinary `latent()`
stopped preserving `lv_formula`, or if the unsupported-source error stopped
mentioning the LV boundary.

## 6. Consistency Audit

- `rg -n "phylo_latent\\([^\\n]*lv|animal_latent\\([^\\n]*lv|spatial_latent\\([^\\n]*lv|kernel_latent\\([^\\n]*lv|LV-07|source-specific" tests/testthat/test-lv-source-specific-guard.R docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-29-lv-source-specific-guard.md`
  -> REVIEWED; source-specific `lv` appears only as rejected syntax in the
  test and evidence records.
- `rg -n "source-specific.*support|phylo.*support|Model A.*R exposure|complete|coverage" tests/testthat/test-lv-source-specific-guard.R docs/dev-log/after-task/2026-06-29-lv-source-specific-guard.md`
  -> REVIEWED; support/completion language is limited to explicit rejected or
  not-yet-exposed boundaries.

## 7. Roadmap Tick

No roadmap row is promoted. This branch strengthens the `LV-07` fail-loud
boundary while source-specific `lv` support remains blocked pending phylo Model
A DRAC evidence, Design 73 bridge work, and maintainer sign-off.

## 7a. GitHub Issue Ledger

No new issue was created. This is a guardrail slice inside the ongoing
Design 73 LV arc rather than a standalone user-facing feature.

## 8. What Did Not Go Smoothly

Nothing substantive. The main CI lane had cleared by the time the full local
package check was run.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: this is a small guardrail slice that protects the larger LV arc from
overclaiming.

Boole: the grammar boundary is explicit: ordinary `latent()` can carry `lv`;
source-specific keywords cannot yet.

Fisher: no inference claim moves here. This is routing/guard evidence only.

Curie: deprecated aliases are included because compatibility syntax is a
realistic source of silent metadata loss.

Grace: focused tests and full local package check passed; this is ready for the
next one-PR slot.

Rose: the after-task keeps source-specific support blocked and names the
missing gates before R exposure.

## 10. Known Limitations And Next Actions

- No source-specific `lv` support is implemented.
- No phylo Model A R bridge or grammar exposure is claimed.
- No interval, recovery, mixed-family, mask, or `X + X_lv` claim moves.
- Next safest action: open this as the next PR, monitor CI, and merge only if
  the GitHub R-CMD-check is green.
