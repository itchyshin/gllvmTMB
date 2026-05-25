# After Task: Diagnostic Table Infrastructure

**Branch**: `codex/diagnostic-table-2026-05-25`
**Date**: `2026-05-25`
**Roles (engaged)**: `Ada / Shannon / Fisher / Curie / Grace / Rose`

## 1. Goal

Set B added a small report-ready table path for fitted-model diagnostic
objects so public articles and reports can consume diagnostic rows without
inspecting `attr(x, "gllvmTMB_diagnostic")` directly.

## 2. Implemented

- Added exported `diagnostic_table()`.
- `diagnostic_table(x, table = "data")` returns plotted data for
  `predictive_check()` plots or residual rows for diagnostic residual
  data frames.
- `table = "row_status"` returns status counts when a `status` column is
  present.
- `table = "fit_health_status"` returns the attached `PASS` / `WARN` /
  `FAIL` counts from `check_gllvmTMB()`.
- `table = "check_gllvmTMB"` returns the attached full fit-health table.
- Registered the helper in `_pkgdown.yml`, `NEWS.md`, Design 51, and
  validation-debt row DIA-13.

## 3. Files Changed

- `R/diagnostic-tables.R`: new exported helper and internal metadata
  extraction helpers.
- `tests/testthat/test-predictive-diagnostics.R`: focused table
  extraction test over real residual and predictive-check objects.
- `man/diagnostic_table.Rd`: generated roxygen reference page.
- `NAMESPACE`: generated export for `diagnostic_table()`.
- `_pkgdown.yml`: placed `diagnostic_table` in first-line diagnostics.
- `NEWS.md`: added DIA-13 scope-boundary bullet.
- `ROADMAP.md`: updated the extraction-tables row to name
  `diagnostic_table()`.
- `docs/design/35-validation-debt-register.md`: added DIA-13.
- `docs/design/51-posterior-predictive-diagnostics.md`: documented the
  table path as the public alternative to direct attribute inspection.
- `docs/dev-log/check-log.md`: recorded Set B evidence.
- `docs/dev-log/after-task/2026-05-25-diagnostic-table-infrastructure.md`:
  this report.

## 3a. Decisions And Rejected Alternatives

Decision: export `diagnostic_table()` rather than an `extract_*()` helper.

Rationale: the helper consumes diagnostic objects, not fitted-model
estimands, and does not need to join the extractor return-value contract
recorded in `docs/design/06-extractors-contract.md`.

Rejected alternative: ask articles to keep reading
`attr(x, "gllvmTMB_diagnostic")` directly. That would preserve the
internal-looking pattern Set B was meant to remove.

Confidence: high. The function is a thin table extractor over already
tested metadata.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url,files --limit 20`
  -> open PRs showed #264 on M3 design/dev files and #261 on diagnostic
  teaching reset files; #261 overlapped `ROADMAP.md` and
  `docs/dev-log/check-log.md`.
- `git log --all --oneline --since="6 hours ago"`
  -> recent #257/#260/#263 main merges, #261 branch commits, and #264
  maintainer binomial-psi guard.
- `gh pr comment 261 ...`
  -> posted coordination notes for the check-log and ROADMAP overlaps.
- `air format R/diagnostic-tables.R tests/testthat/test-predictive-diagnostics.R`
  -> completed.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> loaded `gllvmTMB`; wrote `NAMESPACE` and `diagnostic_table.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "predictive-diagnostics")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 117` in 3.1s.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found` before and after the ROADMAP edit.
- `Rscript --vanilla -e 'devtools::test()'`
  -> `FAIL 0 | WARN 1 | SKIP 13 | PASS 2748` in 652.4s. The one warning
  is the pre-existing `level = "spde"` deprecation warning in
  `test-spatial-latent-recovery.R`.
- `git diff --check`
  -> clean.
- `tail -5 man/diagnostic_table.Rd && grep -c '^\\keyword' man/diagnostic_table.Rd`
  -> reference page ends after examples; keyword count `0`.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "diagnostic OR residual OR predictive OR ppcheck OR pp_check" --json number,title,url,labels --limit 20`
  -> #230 is the relevant open article/tooling gate.

## 5. Tests Of The Tests

The new test is a feature-combination test: it combines the new
`diagnostic_table()` helper with both existing diagnostic residuals and
existing `predictive_check()` plot metadata. It verifies residual/plotted
data extraction, row-status counts, fit-health status counts, the attached
`check_gllvmTMB()` table, and removal of the direct diagnostic attribute
from the returned plain data frame.

## 6. Consistency Audit

- `rg -n "diagnostic_table|DIA-13|gllvmTMB_diagnostic" NAMESPACE _pkgdown.yml NEWS.md R/diagnostic-tables.R man/diagnostic_table.Rd docs/design/35-validation-debt-register.md docs/design/51-posterior-predictive-diagnostics.md tests/testthat/test-predictive-diagnostics.R`
  -> export, reference placement, NEWS, DIA-13, Design 51, Rd, and tests
  all mention the same table path.
- `rg -n "gllvmTMB\\(" R/diagnostic-tables.R man/diagnostic_table.Rd NEWS.md docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md`
  -> the only new long-format example is the `diagnostic_table()` example
  and it includes `trait = "trait"`.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" R/diagnostic-tables.R man/diagnostic_table.Rd NEWS.md docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md`
  -> no output.
- `rg -n "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|meta_known_V|gllvmTMB_wide" R/diagnostic-tables.R man/diagnostic_table.Rd NEWS.md docs/design/51-posterior-predictive-diagnostics.md docs/design/35-validation-debt-register.md`
  -> existing validation-register and NEWS compatibility hits only; no
  new Set B stale syntax.
- `rg -n "diagnostic_table|Diagnostics tables beyond current fit-health rows|DIA-13" ROADMAP.md docs/design/35-validation-debt-register.md docs/design/51-posterior-predictive-diagnostics.md NEWS.md _pkgdown.yml R/diagnostic-tables.R man/diagnostic_table.Rd tests/testthat/test-predictive-diagnostics.R`
  -> `diagnostic_table()` is visible; the stale ROADMAP phrase has no hit.

Rose verdict: PASS for the touched public surface. DIA-13 backs the new
claim, the exported helper appears in `_pkgdown.yml`, and the roxygen
example follows the long-format `trait = "trait"` rule.

## 7. Roadmap Tick

**Roadmap tick**: Infrastructure-first / Extraction tables row updated to
name `diagnostic_table()` as the diagnostics table path. No progress chip
changed.

## 7a. GitHub Issue Ledger

- Inspected #230, "Article surface reset and user-first tooling gate."
  Set B advances the report-ready diagnostic-table infrastructure that
  issue needs, but does not close the article gate.
- No new issue created. Set C remains the next remembered slice for
  joint-SDM restoration prep.

## 8. What Did Not Go Smoothly

The pre-edit lane check found #261 already touching `ROADMAP.md` and
`docs/dev-log/check-log.md`. I posted two coordination comments on #261
before editing those ledger/status files and kept Set B otherwise
separate from the teaching-reset PR.

The full test suite was clean but slow: `phylo-q-decomposition` alone took
341.6s.

## 9. Team Learning

**Ada** kept the slice narrow: one helper over existing metadata, one
test, and the required public-surface records.

**Shannon** caught the open-PR overlap before the ledger edits. The
coordination note now lives on #261 rather than only in chat.

**Fisher** kept the claim diagnostic-only. `diagnostic_table()` extracts
metadata and does not imply formal residual tests, interval calibration,
latent-rank evidence, or Bayesian posterior prediction.

**Curie** shaped the test as a feature-combination guard over both
residual and plot objects.

**Grace** checked roxygen, `_pkgdown.yml`, pkgdown reference parity, and
the full local test suite.

**Rose** checked that the new public claim is backed by DIA-13 and that
the stale ROADMAP sentence was removed.

## 10. Known Limitations And Next Actions

- `diagnostic_table()` does not compute new diagnostics; it only extracts
  existing metadata.
- `row_status` is most informative for residual/Q-Q objects where the
  diagnostic data include a `status` column. Plot types without row status
  return `status = "not_recorded"`.
- Full local `devtools::check(args = "--no-manual")` was not run; ordinary
  3-OS PR CI should cover the package check.
- Set C should start with the remembered joint-SDM restoration audit and
  use `diagnostic_table()` rather than direct attribute inspection.
