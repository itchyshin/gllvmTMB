# After Task: LV REML And Formula Boundary Guard

**Branch**: `codex/lv-reml-boundary-guard-20260628`
**Date**: `2026-06-30`
**Roles (engaged)**: `Ada / Boole / Noether / Fisher / Curie / Grace / Rose`

## 1. Goal

Protect the Design 73 claim boundary for predictor-informed latent scores by
proving that unsupported REML and richer `lv` formula routes fail loudly before
fitting. This slice covers `REML = TRUE`, `offset()`, `mi()`, smooth terms, and
random-effect terms inside `lv`.

## 2. Implemented

- Added `tests/testthat/test-lv-reml-boundary-guard.R`.
- The guard exercises top-level `gllvmTMB()` calls for:
  - `REML = TRUE` with `latent(..., lv = ~ x)`;
  - `lv = ~ offset(x)`;
  - `lv = ~ mi(x)`;
  - `lv = ~ s(x)`;
  - `lv = ~ (1 | block)`.
- NEWS, Design 73, the validation-debt register, and capability status now cite
  this guard while keeping `FG-18`, `RE-13`, and `LV-01` partial.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family implementation,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed.

The admitted native C1 score-mean model remains:

```text
u_i = X_lv,i alpha + e_i,    e_i ~ N(0, I_K)
B_lv = Lambda alpha'
```

This branch does not implement REML / AI-REML for predictor-informed latent
scores and does not broaden `lv` beyond one-sided fixed-effect formulas. It
proves that these unsupported routes fail loudly before fitting.

## 4. Files Changed

Tests:

- `tests/testthat/test-lv-reml-boundary-guard.R`

User-facing and status prose:

- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Evidence records:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-30-lv-reml-boundary-guard.md`

## 4a. Decisions and Rejected Alternatives

Decision: test these boundaries through top-level `gllvmTMB()` calls. Rationale:
the failure must be visible at the user entry point, not only inside a formula
helper. Rejected alternative: parser-helper-only tests. Confidence: high.

Decision: keep `LV-01` partial. Rationale: ordinary Gaussian `lv` has point,
recovery, response-mask, and current interval evidence, but this branch only
adds fail-loud evidence for unsupported REML and formula terms. Rejected
alternative: treating rejection tests as support evidence. Confidence: high.

## 5. Checks Run

- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,url,isDraft`
  -> REVIEWED; no open gllvmTMB PRs were present before editing the dev-log
  files.
- `git log --all --oneline --since="6 hours ago" -- NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md docs/dev-log/check-log.md docs/dev-log/after-task tests/testthat/test-lv-reml-boundary-guard.R`
  -> REVIEWED; recent history showed the preceding LV guard/status slices and
  this branch's first two test commits.
- `git fetch origin +refs/heads/main:refs/remotes/origin/main --prune && git rebase origin/main`
  -> PASS; branch rebased cleanly onto current `origin/main` after PR #578.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-reml-boundary-guard", reporter = "summary")'`
  -> PASS; 5 REML/lv-formula boundary rejection cases passed.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; focused parser guard completed with no failures. The existing
  sigma-eps auto-suppression informational message appeared.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-family-boundary-guard", reporter = "summary")'`
  -> PASS; 3 neighbouring family-boundary rejection cases passed.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no pkgdown reference/navigation problems found.
- `git diff --check`
  -> PASS; no whitespace errors before the report/check-log edit.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 4m46.1s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.

## 6. Tests of the Tests

The new file is a boundary test: it would fail if `REML = TRUE`, `offset()`,
`mi()`, smooth terms, or random-effect terms inside `lv` began entering the
native `latent(..., lv = ~ x)` fit path without a validation row moving. The
paired parser and family-boundary guards protect neighbouring Design 73
boundaries.

## 7. Consistency Audit

- `rg -n 'FG-18|RE-13|LV-01|test-lv-reml-boundary-guard|REML = TRUE|offset\(\)|mi\(\)|smooth|random-effect|lv-formula|richer `lv`|fail-loud' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md tests/testthat/test-lv-reml-boundary-guard.R`
  -> REVIEWED; hits show the new fail-loud evidence on `FG-18`, `RE-13`, and
  `LV-01`, with REML/lv-formula support still blocked.
- `rg -n 'REML.*lv.*(admitted|supported|covered|validated)|richer.*lv.*formula.*(admitted|supported|covered|validated)|offset.*lv.*(admitted|supported|covered|validated)|mi\(\).*lv.*(admitted|supported|covered|validated)|smooth.*lv.*(admitted|supported|covered|validated)|random-effect.*lv.*(admitted|supported|covered|validated)' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; the broad scan is intentionally conservative and matched long
  rows that also contain `covered` / `validated` evidence for other LV
  subclaims, but the touched Design 73, capability-status, and register rows
  say REML/richer `lv` formulas are fail-loud or blocked, not supported.
- `rg -n 'gllvmTMB_wide|meta_known_V|\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(|\bS_B\b|\bS_W\b|\\bf S|in prep|in preparation' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; hits are historical/compatibility mentions, not new stale LV
  wording.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design | head -n 220`
  -> REVIEWED; this branch adds no new user-facing `gllvmTMB()` examples.
  Touched NEWS/design text does not introduce long-format calls requiring a new
  `trait =` audit.

Rose verdict: PASS for the narrow pre-publish gate. The docs consistently say
that these REML/lv-formula boundaries are fail-loud guarded, not implemented.

## 8. Roadmap Tick

N/A. This branch closes one fail-loud guard inside the Design 73 LV arc; it does
not change `ROADMAP.md` status chips or public progress bars.

## 8a. GitHub Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'lv reml' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned only issue #348, the broad family-validation umbrella.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'lv formula boundary' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; no matching open issue.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'LV-01' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; no matching open issue.

No issue was closed or commented on by this branch.

## 9. Documentation And Pkgdown

No roxygen, generated Rd, NAMESPACE, exported function docs, vignette source, or
`_pkgdown.yml` navigation changed. NEWS and design/status docs were updated to
record the REML/lv-formula fail-loud boundary.

`pkgdown::check_pkgdown()` passed. Full article rendering was not run because
this branch does not change article examples or parser/user-call examples.

## 10. What Did Not Go Smoothly

The broad stale-claim scan for REML/lv-formula wording was too conservative as
a clean yes/no probe because the same long LV status rows also mention covered
or validated evidence for ordinary Gaussian and binomial subclaims. I recorded
the focused Design 73 / `FG-18` / `RE-13` / `LV-01` verdict instead of
overstating that broad scan.

## 11. Team Learning

Ada: this closes the last queued-ready LV guard without widening the public
claim.

Boole: richer `lv` formula syntax is now guarded at the user-facing entry point,
including random-effect bars and formula specials.

Noether: REML / AI-REML still needs separate derivation for predictor-informed
latent scores before any claim can move.

Fisher: no inference row moves. Rejection tests prevent unsupported REML or
formula rows from being mistaken for recovery or coverage evidence.

Curie: the guard covers five qualitatively different boundaries: estimator,
offset, missing-predictor modelling, smooth terms, and random-effect terms.

Grace: focused tests, neighbouring parser/family guards, pkgdown check,
whitespace check, and local R CMD check all passed in the clean `/private/tmp`
worktree.

Rose: the validation register, Design 73, capability status, and NEWS now tell
the same story: `LV-01` remains partial, and the new evidence is fail-loud only.

## 12. Known Limitations And Next Actions

- REML / AI-REML with predictor-informed latent scores remains blocked.
- Richer `lv` formulas with offsets, `mi()`, smooth terms, random-effect terms,
  response/trait columns, or nonconstant within-unit predictors remain blocked.
- Native count-family, NB/Gamma/Beta native TMB, delta/hurdle, mixed-family,
  source/tier, phylo, and interval claims do not move.
- The next LV arc slots should move from local guard closure into phylo DRAC
  evidence, bridge intervals, and the mixed-family backlog.
