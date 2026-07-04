# Recovery checkpoint -- standalone scalar `indep(common = TRUE)`

Date: 2026-06-18 20:12 MDT

Branch: `codex/r-bridge-grouped-dispersion`, ahead 56 of
`origin/codex/r-bridge-grouped-dispersion`.

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Current status

`git status --short --branch` shows the inherited broad local stack still
modified, plus untracked after-task/recovery files. No staging or push was
performed.

Key tracked files touched by this narrow continuation:

- `R/brms-sugar.R`
- `R/unique-keyword.R`
- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-article-unique-cleanup.md`
- `man/indep.Rd`
- `man/diag_re.Rd`
- `tests/testthat/test-canonical-keywords.R`

Representative `git diff --stat` at checkpoint:

```text
86 files changed, 3145 insertions(+), 853 deletions(-)
```

The broad stat includes earlier coevolution, Psi cleanup, article, README, and
fixture slices. This checkpoint's new gate is the standalone scalar
`indep(common = TRUE)` slice only.

## Completed in this slice

- Added `common = FALSE` to `indep()` and rewrote
  `indep(form, common = TRUE)` to the existing scalar diagonal path:
  `diag(form, common = TRUE, .indep = TRUE)`.
- Added a canonical-keyword regression gate showing standalone
  `indep(..., common = TRUE)` is objective-equivalent to legacy standalone
  `unique(..., common = TRUE)` and estimates one shared marginal SD.
- Kept paired `latent() + unique(..., common = TRUE)` as compatibility syntax;
  paired common has not been re-homed on `latent()`.
- Updated formula grammar, validation-debt FG-07, NEWS, roxygen/Rd, check log,
  after-task report, and dashboard JSON.
- Synced the dashboard source to `/tmp/gllvm-dashboard/` for
  `http://127.0.0.1:8770/`.

## Commands run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Passed; regenerated `man/indep.Rd` and `man/diag_re.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|unique-family-deprecation|stage2-rr-diag", reporter = "summary")'`
  - Passed; expected skips were three INLA-dependent spatial checks and one
    glmmTMB non-PD comparison.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null`
  - Passed.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  - Passed.
- `rg -n 'common= re-homing|common = TRUE re-hom|common= was not re-homed|No \`common = TRUE\` re-homing|common= rehome|common re-home' NEWS.md R man docs/design docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/dashboard tests/testthat`
  - Remaining hits are older historical log/report entries or explicit paired
    common-boundary wording.
- `rg -n 'paired.*indep\\(\\.\\.\\., common = TRUE\\)|indep\\(\\.\\.\\., common = TRUE\\).*paired|latent\\(\\).*indep\\(\\.\\.\\., common = TRUE\\)|unique\\(\\.\\.\\., common = TRUE\\).*removed|common = TRUE.*removed' NEWS.md R/unique-keyword.R R/brms-sugar.R man/diag_re.Rd man/indep.Rd docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json tests/testthat/test-canonical-keywords.R`
  - Remaining hits are intended boundary/evidence statements.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed: `No problems found.`
- `git diff --check`
  - Clean.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  - Completed.

## Still not claimed

- No `unique()` or `*_unique()` removal.
- No paired `latent() + unique(..., common = TRUE)` re-home.
- No source-specific or `kernel_*()` latent-Psi fold.
- No Paper 2 multi-kernel explicit-Psi support.
- No bridge completion, release readiness, or scientific coverage completion.

## Next safest action

Continue the overall plan from the dashboard. The next narrow `unique()`
deprecation slice should likely stay source-bound or parser-bound, not touch
Paper 2 `kernel_unique()` expansion. Run the pre-edit lane check before editing
shared files.

## 20:17 MDT addendum

One additional narrow doc-cleanup slice landed after the checkpoint above:

- `docs/design/01-formula-grammar.md` no longer uses ordinary explicit
  `latent() + unique()` in its long/wide first examples, non-default trait
  examples, or nested `unit` / `unit_obs` example.
- The random-effect mini-example now contrasts default `latent()`,
  `latent(..., residual = FALSE)`, and standalone `indep()`.
- Compatibility rows and the augmented random-regression boundary still mention
  explicit `unique()` intentionally.

Additional checks:

- Pre-edit lane check rerun:
  - `gh pr list --state open` -> only draft PR #489.
  - `git log --all --oneline --since="6 hours ago"` -> current coevolution
    stack, headed by `5346391`.
- `rg -n 'latent\\([^\\n]+\\) \\+\\s*unique|\\+\\s*unique\\(|unique\\(0 \\+ trait \\| site\\)|unique\\(1 \\| individual\\)|unique\\(0 \\+ behavior \\| individual\\)|unique\\(0 \\+ trait \\| individual\\)|unique\\(0 \\+ trait \\| session_id\\)' docs/design/01-formula-grammar.md`
  -> only intentional compatibility mentions remain.
- Dashboard JSON validation passed.
- `git diff --check` passed.
- Dashboard synced again to `/tmp/gllvm-dashboard/`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`

## 20:21 MDT addendum

One additional reference-page cleanup landed:

- `R/brms-sugar.R` `unique_keyword` roxygen now says new standalone scalar
  marginal fits should use `indep(..., common = TRUE)`.
- `man/unique_keyword.Rd` regenerated from roxygen.
- Legacy standalone `unique(..., common = TRUE)` remains compatibility syntax,
  and paired `latent() + unique(..., common = TRUE)` remains compatibility
  syntax; neither is removed.

Additional checks:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/unique_keyword.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|unique-family-deprecation", reporter = "summary")'`
  -> passed with three expected INLA-dependent spatial skips.
- Active-reference stale scan for misleading `common = TRUE` recommendations
  found only intended boundary statements.
- Dashboard JSON validation passed.
- `git diff --check` passed.
- Dashboard synced again to `/tmp/gllvm-dashboard/`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
