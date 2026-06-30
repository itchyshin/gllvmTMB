# After Task: LV Family Boundary Guard

**Branch**: `codex/lv-family-boundary-guard-20260628`
**Date**: `2026-06-30`
**Roles (engaged)**: `Ada / Boole / Noether / Fisher / Curie / Grace / Rose`

## 1. Goal

Protect the Design 73 claim boundary for predictor-informed latent scores by
proving that unsupported native family/link combinations fail loudly before
fitting. This slice covers binomial cauchit, ordinal-probit, and mixed
Gaussian/binomial/Poisson `latent(..., lv = ~ x)` calls.

## 2. Implemented

- Added `tests/testthat/test-lv-family-boundary-guard.R`.
- The guard exercises top-level `gllvmTMB()` calls for:
  - `stats::binomial(link = "cauchit")`;
  - `ordinal_probit()`;
  - a mixed `list(gaussian(), binomial(), poisson())` family with
    `family_var`.
- NEWS, Design 73, the validation-debt register, and capability status now cite
  this guard while keeping `FG-18`, `RE-13`, and `LV-05` partial.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family implementation,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed.

The admitted native C1 score-mean model remains:

```text
u_i = X_lv,i alpha + e_i,    e_i ~ N(0, I_K)
B_lv = Lambda alpha'
```

This branch does not implement nonstandard binomial links, ordinal
predictor-informed latent scores, or mixed-family `lv` support. It proves that
those unsupported rows fail loudly before fitting.

## 4. Files Changed

Tests:

- `tests/testthat/test-lv-family-boundary-guard.R`

User-facing and status prose:

- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Evidence records:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-30-lv-family-boundary-guard.md`

## 4a. Decisions and Rejected Alternatives

Decision: test these boundaries through top-level `gllvmTMB()` calls. Rationale:
the failure must be visible at the user entry point, not only inside a helper.
Rejected alternative: parser-helper-only tests. Confidence: high.

Decision: keep `LV-05` partial. Rationale: pure binomial logit/probit/cloglog is
admitted, and the Julia bridge has narrow point routes, but this branch only
adds fail-loud evidence for nonstandard binomial, ordinal, and mixed-family
boundaries. Rejected alternative: treating rejection tests as support evidence.
Confidence: high.

## 5. Checks Run

- `gh pr list --state open --repo itchyshin/gllvmTMB`
  -> REVIEWED; no open gllvmTMB PRs were present before editing the dev-log
  files.
- `git log --all --oneline --since="6 hours ago"`
  -> REVIEWED; recent history showed the preceding LV guard/status slices and
  this branch's first test commit.
- `git fetch origin +refs/heads/main:refs/remotes/origin/main --prune && git rebase origin/main`
  -> PASS; branch rebased cleanly onto current `origin/main` after PR #577.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-family-boundary-guard", reporter = "summary")'`
  -> PASS; 3 family-boundary rejection cases passed.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; focused parser guard completed with no failures. The existing
  sigma-eps auto-suppression informational message appeared.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-native-nongaussian-guard", reporter = "summary")'`
  -> PASS; 13 native non-Gaussian rejection cases passed.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no pkgdown reference/navigation problems found.
- `git diff --check`
  -> PASS; no whitespace errors before the report/check-log edit.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 4m46.2s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-30-lv-family-boundary-guard.md`
  -> PASS; validator returned successfully.
- `git diff --check`
  -> PASS; no whitespace errors after the report/check-log edit.

## 6. Tests of the Tests

The new file is a boundary test: it would fail if binomial cauchit,
ordinal-probit, or a mixed Gaussian/binomial/Poisson family list began entering
the native `latent(..., lv = ~ x)` fit path without a validation row moving.
The paired parser and native non-Gaussian guards protect neighbouring Design 73
boundaries.

## 7. Consistency Audit

- `rg -n 'FG-18|RE-13|LV-05|test-lv-family-boundary-guard|binomial cauchit|ordinal-probit|mixed Gaussian/binomial/Poisson|nonstandard binomial|family/link' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md tests/testthat/test-lv-family-boundary-guard.R`
  -> REVIEWED; hits show the new fail-loud evidence on `FG-18`, `RE-13`, and
  `LV-05`, with nonstandard binomial, ordinal, and mixed-family support still
  blocked.
- `rg -n '(cauchit|ordinal|mixed-family|mixed family|family/list|family list).*(admitted|supported|covered|validated)|native.*(ordinal|mixed-family|cauchit).*(admitted|supported|covered|validated)|nonstandard binomial.*(admitted|supported|covered|validated)' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; the broad scan is intentionally noisy because older unrelated
  ordinal/mixed-family rows exist, but the touched Design 73 and `LV-05` rows
  use fail-loud/blocked wording, not support wording.
- `rg -n 'gllvmTMB_wide|meta_known_V|\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(|\bS_B\b|\bS_W\b|\\bf S|in prep|in preparation' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; hits are historical/compatibility mentions, not new stale LV
  wording.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design | head -n 220`
  -> REVIEWED; this branch adds no new user-facing `gllvmTMB()` examples.
  Touched NEWS/design text does not introduce long-format calls requiring a new
  `trait =` audit.

Rose verdict: PASS for the narrow pre-publish gate. The docs consistently say
that these family/link boundaries are fail-loud guarded, not implemented.

## 8. Roadmap Tick

N/A. This branch closes one fail-loud guard inside the Design 73 LV arc; it does
not change `ROADMAP.md` status chips or public progress bars.

## 8a. GitHub Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'lv family boundary' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned only issue #348, the broad family-validation umbrella.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'latent lv ordinal mixed' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned only issue #348.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'LV-05' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned only issue #348.

No issue was closed or commented on by this branch.

## 9. Documentation And Pkgdown

No roxygen, generated Rd, NAMESPACE, exported function docs, vignette source, or
`_pkgdown.yml` navigation changed. NEWS and design/status docs were updated to
record the family/link fail-loud boundary.

`pkgdown::check_pkgdown()` passed. Full article rendering was not run because
this branch does not change article examples or parser/user-call examples.

## 10. What Did Not Go Smoothly

The broad stale-claim scan for ordinal/mixed-family wording was too noisy to be
a clean yes/no probe because those words appear in many older non-LV status
rows. I recorded the focused Design 73 / `LV-05` verdict instead of overstating
that broad scan.

## 11. Team Learning

Ada: this is another small LV arc slice that lowers overclaiming risk without
pretending nonstandard binomial, ordinal, or mixed-family LV support is solved.

Boole: the boundary is now visible at the formula-entry level and covers the
family-list path, not only single-family constructors.

Noether: the mathematical contract does not move. The score-mean model remains
the current ordinary Gaussian and pure standard-link binomial C1 surface.

Fisher: no inference row moves. Rejection tests prevent unsupported rows from
being mistaken for recovery or coverage evidence.

Curie: the guard covers three qualitatively different boundaries: unsupported
link, unsupported ordinal family, and mixed-family dispatch.

Grace: focused tests, neighbouring parser/native guards, pkgdown check,
whitespace check, and local R CMD check all passed in the clean `/private/tmp`
worktree.

Rose: the validation register, Design 73, capability status, and NEWS now tell
the same story: `LV-05` remains partial, and the new evidence is fail-loud only.

## 12. Known Limitations And Next Actions

- Nonstandard binomial links, ordinal `lv`, and mixed-family `lv` remain
  blocked.
- Native count-family, NB/Gamma/Beta native TMB, delta/hurdle,
  response-mask/mixed-family, source/tier, phylo, and interval claims do not
  move.
- The next LV guard PR slot should be the REML/lv-formula guard, keeping the
  one-PR-at-a-time discipline.
