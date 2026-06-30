# After Task: LV Native Non-Gaussian Fail-Loud Guard

**Branch**: `codex/lv-native-nongaussian-guard-20260628`
**Date**: `2026-06-29`
**Roles (engaged)**: `Ada / Boole / Noether / Fisher / Curie / Grace / Rose`

## 1. Goal

Protect the Design 73 claim boundary for predictor-informed latent scores by
proving that native TMB rejects unsupported non-binomial
`latent(..., lv = ~ x)` families before fitting. This keeps the admitted C1
native surface at ordinary Gaussian plus pure binomial logit/probit/cloglog
until each other family has its own derivation, recovery tests, and interval
evidence.

## 2. Implemented

- Added `tests/testthat/test-lv-native-nongaussian-guard.R`.
- The guard checks top-level `gllvmTMB()` calls with Poisson, NB1, NB2,
  lognormal, Gamma, Beta, Tweedie, Student-t, truncated Poisson, truncated NB2,
  beta-binomial, delta-lognormal, and delta-Gamma families.
- NEWS, Design 73, the validation-debt register, and capability status now cite
  the guard test while keeping `LV-05` partial.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family implementation,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed.

The admitted native C1 score-mean model remains:

```text
u_i = X_lv,i alpha + e_i,    e_i ~ N(0, I_K)
B_lv = Lambda alpha'
```

This branch does not implement native non-binomial `lv` support. It proves that
unsupported native family rows fail loudly.

## 4. Files Changed

Tests:

- `tests/testthat/test-lv-native-nongaussian-guard.R`

User-facing and status prose:

- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Evidence records:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-29-lv-native-nongaussian-guard.md`

## 4a. Decisions and Rejected Alternatives

Decision: test the failure through top-level `gllvmTMB()` calls rather than only
the parser helper. Rationale: the risk is a user-visible unsupported family
silently entering native TMB setup. Top-level calls prove the boundary the user
would actually hit. Rejected alternative: helper-only unit tests. Confidence:
high.

Decision: keep `LV-05` partial. Rationale: pure binomial native recovery is
admitted, the Julia bridge has narrow point routes, but this branch only adds
native fail-loud evidence for unsupported families. Rejected alternative:
promote native count or continuous-positive LV support based on rejection tests.
Confidence: high.

## 5. Checks Run

- `date '+%Y-%m-%d %H:%M %Z' && gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,url && git log --all --oneline --since='6 hours ago' -- NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md docs/dev-log/check-log.md docs/dev-log/after-task tests/testthat/test-lv-native-nongaussian-guard.R`
  -> REVIEWED; local time was 2026-06-29 22:47 MDT, no open PRs were present,
  and recent shared-file history showed the preceding LV guard/status slices.
- `git fetch origin +refs/heads/main:refs/remotes/origin/main --prune && git rebase origin/main`
  -> PASS; branch rebased cleanly onto main after PR #576.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-native-nongaussian-guard", reporter = "summary")'`
  -> PASS; 13 native non-Gaussian rejection cases passed.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; focused parser guard completed with no failures. The existing
  sigma-eps auto-suppression informational message appeared.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no pkgdown reference/navigation problems found.
- `git diff --check`
  -> PASS; no whitespace errors.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 4m48.9s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.

## 6. Tests of the Tests

The new file would fail if any unsupported native non-binomial family began
fitting with `latent(..., lv = ~ x)` on the native TMB path. The family list
covers count, continuous positive, truncated, beta-binomial, and delta-family
constructors rather than a single convenient representative. The paired parser
guard still protects the neighbouring Design 73 formula boundaries.

## 7. Consistency Audit

- `rg -n 'FG-18|RE-13|LV-05|test-lv-native-nongaussian-guard|native non-binomial|native count-family|unsupported native' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md tests/testthat/test-lv-native-nongaussian-guard.R`
  -> REVIEWED; hits show the new guard evidence on `FG-18`, `RE-13`, and
  `LV-05`, with the native non-binomial path still blocked.
- `rg -n 'native (count-family|non-binomial|non-Gaussian).*(admitted|supported|covered|validated)|NB1.*native.*lv.*(admitted|supported)|Poisson.*native.*lv.*(admitted|supported)|native non-binomial support' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; hits were the deliberate "not native non-binomial support" and
  fail-loud/blocked wording, not a promoted support claim.
- `rg -n 'gllvmTMB_wide|meta_known_V|\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(|\bS_B\b|\bS_W\b|\\bf S|in prep|in preparation' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md`
  -> REVIEWED; hits are historical/compatibility mentions, not new stale LV
  wording.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design | head -n 220`
  -> REVIEWED; this branch adds no new `gllvmTMB()` examples. Touched
  NEWS/design text does not introduce long-format calls requiring a new
  `trait =` audit.

Rose verdict: PASS for the narrow pre-publish gate. The docs now consistently
say that unsupported native non-binomial `lv` rows are fail-loud guarded, not
implemented.

## 8. Roadmap Tick

N/A. This branch closes one fail-loud guard inside the Design 73 LV arc; it does
not change `ROADMAP.md` status chips or public progress bars.

## 8a. GitHub Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'native non-Gaussian lv' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; no matching open issue.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'latent lv non-Gaussian' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned only issue #348, the broad family-validation
  completion umbrella. This guard does not close #348.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'LV-05' --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned only issue #348.

No issue was closed or commented on by this branch.

## 9. Documentation And Pkgdown

No roxygen, generated Rd, NAMESPACE, exported function docs, vignette source, or
`_pkgdown.yml` navigation changed. NEWS and design/status docs were updated to
record the native non-Gaussian fail-loud boundary.

`pkgdown::check_pkgdown()` passed. Full article rendering was not run because
this branch does not change article examples or parser/user-call examples.

## 10. What Did Not Go Smoothly

The first multi-file patch attempt missed one Design 73 line wrap and applied no
changes. I re-read the exact line numbers, split the patch, and applied the same
intended edits cleanly.

## 11. Team Learning

Ada: this is another small LV arc slice that lowers overclaiming risk without
pretending a hard family-extension problem has been solved.

Boole: the user-facing boundary is now visible at the formula-entry level: the
unsupported family calls stop before fitting instead of relying on downstream
numeric failure.

Noether: the mathematical contract does not move. The score-mean model remains
the Gaussian/pure-binomial C1 surface, with native non-binomial rows still
awaiting derivation.

Fisher: no inference row moves. Rejection tests prevent unsupported families
from being mistaken for recovery or coverage evidence.

Curie: the guard covers a family spread rather than one proxy family, which
makes accidental future widening much easier to catch.

Grace: focused tests, parser guard, pkgdown check, whitespace check, and local
R CMD check all passed in the clean `/private/tmp` worktree.

Rose: the validation register, Design 73, capability status, and NEWS now tell
the same story: `LV-05` remains partial, native non-binomial `lv` is blocked,
and the new evidence is fail-loud only.

## 12. Known Limitations And Next Actions

- Native non-binomial `lv` support remains blocked.
- No family-specific derivation, recovery, interval, mixed-family, mask,
  source/tier, phylo, or bridge-parity claim moves.
- The next LV guard PR slot should be either the family-boundary guard or the
  REML/lv-formula guard, keeping the one-PR-at-a-time discipline.
