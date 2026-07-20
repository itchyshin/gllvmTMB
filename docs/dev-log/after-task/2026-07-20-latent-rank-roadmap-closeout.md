# After Task: Latent-rank article roadmap closeout

## 1. Goal

Reconcile ROADMAP with the already-shipped `model-selection-latent-rank`
article, using current source, fixture, test, and rendered HTML evidence.

## 2. Implemented

ROADMAP item 16 is now `Done`, with concrete paths to the public article,
tested Gaussian fixture, and prior rendered-check receipt. The completed lane
was removed from the Next Shared Work Queue and the remaining items were
renumbered.

No R API, likelihood, formula grammar, family, validation-debt status,
article prose, generated Rd, pkgdown navigation, or public inference claim
changed. The existing boundary remains: this is a Gaussian ordinary-`latent()`
teaching fixture, not universal latent-rank calibration.

## 3a. Decisions and Rejected Alternatives

- **Decision:** mark item 16 done and remove it from the next-work queue.
  **Rationale:** the public article, fixture, long/wide calls, diagnostic AIC/BIC
  table, prior rendered receipt, fresh fixture test, and fresh rendered HTML all
  meet the queue's stated stop condition. **Rejected alternative:** leave a
  completed lane at queue position 1, which would misroute the next owner.
  **Confidence:** high.
- **Decision:** do not alter the article while closing its roadmap status.
  **Rationale:** fresh rendering confirmed the existing prose already preserves
  the Gaussian-only and no-universal-calibration boundary. **Rejected
  alternative:** broaden the slice into REML, AGHQ, VA, or rank-calibration
  work. **Confidence:** high.

## 4. Files Touched

- `ROADMAP.md` — item 16 and Next Shared Work Queue only.
- `docs/dev-log/after-task/2026-07-20-latent-rank-roadmap-closeout.md` — this
  closeout receipt.

Untouched: the article, its fixture, tests, validation register, README, NEWS,
`_pkgdown.yml`, generated Rd, CI-11/Ayumi files, and `check-log.md`.

## 5. Checks Run

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` → `No problems found.`
- `Rscript --vanilla -e 'devtools::test(filter =
  "example-model-selection-rank", reporter = "summary")'` → 29 passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/model-selection-latent-rank",
  lazy = FALSE, new_process = FALSE, quiet = TRUE)'` → rendered successfully.
- `rg -n 'How many latent dimensions|AIC|BIC|does not calibrate|does not.*rank|Gaussian'
  pkgdown-site/articles/model-selection-latent-rank.html` → rendered H1,
  Gaussian description, AIC/BIC table/figure, ML-versus-REML boundary, and
  no-universal-calibration language present.
- `git diff --check` → passed.

`devtools::test()` in full and `R CMD check --as-cran` were not rerun because
this is a ROADMAP-only documentation state correction; the article's focused
fixture test and render are the relevant live checks.

## 6. Tests of the Tests

`test-example-model-selection-rank.R` is a feature-combination test: the
shipped fixture is read through the public formula path and exercises the
Gaussian rank-selection workflow that the ROADMAP row names. The rebuilt HTML
then checks the reader-facing integration surface beyond the unit test.

## 7a. Issue Ledger

No issue was created, commented on, or closed. Open PR #774 was inspected for
file overlap; it changes only the AGHQ reference-harness receipt/spec/test
files, not ROADMAP, and was not modified.

## 8. Consistency Audit

Rose pre-publish audit: **PASS**. The ROADMAP wording makes no new method,
default, export, family, grammar, or validation-status claim. It names the
fixture and receipt that support completion, preserves the Gaussian-only
boundary, and does not advertise REML, AGHQ, VA, or universal calibration.
`pkgdown::check_pkgdown()` also passed. No convention-change cascade applied.

## 9. What Did Not Go Smoothly

The article itself had been complete since its earlier receipt, but the Next
Shared Work Queue and item 16 still labelled it as work to start. That stale
coordination state could have caused duplicate article work.

## 10. Known Residuals

This closes only the documentation/article prerequisite. CI-11 remains open
pending its independent Ayumi hardening/certification receipt. The VA decision
arc cannot start until that gate is closed, and this receipt makes no coverage,
REML, AGHQ, or VA claim.

## 11. Team Learning

**Rose:** an existing after-task report is useful evidence but is not enough by
itself; fresh fixture and rendered-surface checks are needed before updating a
live queue.

**Pat:** the rendered H1, explanatory prose, table, and figure make the stop
condition reader-visible, not merely source-visible.

**Grace:** `pkgdown::check_pkgdown()` passed before a ROADMAP status change was
treated as safe to publish.

## 12. Cross-Product Coverage

This closure covers only one Gaussian ordinary-`latent()` article fixture with
ML AIC/BIC selection and a rank-conditional Gaussian REML refit explanation.
It does NOT cover repeated-sampling rank-selection calibration, non-Gaussian
rank selection, weighted or missing-response variants, `mi()` terms,
structured providers, profile/interval coverage, q>=3 AGHQ, VA optimisation,
a public AGHQ/VA API, non-Gaussian REML, CI-11 certification, or a release
rung.
