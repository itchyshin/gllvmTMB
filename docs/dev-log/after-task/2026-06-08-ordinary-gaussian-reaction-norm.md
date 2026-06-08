# After Task: Ordinary Gaussian Reaction-Norm Random Regression

**Branch**: `codex/status-random-regression-article-2026-06-08`  
**Date**: `2026-06-08`  
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Curie / Fisher / Pat / Rose / Grace`

## 1. Task Goal

Implement the ordinary individual-level Gaussian random-regression path more
thoroughly by adding the paired augmented `unique()` diagonal to the existing
augmented `latent()` engine, then synchronize the internal reaction-norm
article and status ledger.

## 2. Implemented Claim

For Gaussian responses, `gllvmTMB()` now accepts and fits
`latent(1 + x | unit, d = K) + unique(1 + x | unit)` and the long-form
`latent(0 + trait + (0 + trait):x | unit, d = K) +
unique(0 + trait + (0 + trait):x | unit)`. The fitted augmented covariance
extracts through `extract_Sigma(level = "unit_slope", part = "shared" /
"unique" / "total")`. The capability remains `partial` under RE-12 because
non-Gaussian augmented `unique()` is guarded and broad coverage evidence is
not established.

## 3. Mathematical Contract

For trait `t`, individual `i`, and context value `x_ij`,

```text
eta_ijt = fixed_ijt + u_it + b_it x_ij
b_aug_i = (u_i1, b_i1, ..., u_iT, b_iT)'
b_aug_i = Lambda_aug z_i + q_i
z_i ~ N(0, I_K)
q_i ~ N(0, Psi_B,aug)
Sigma_B,aug = Lambda_aug Lambda_aug' + Psi_B,aug
```

The row-level matrices `Z_B_lat` and `Z_B_diag` use the same interleaved
coefficient order:

```text
intercept.t1, slope.x.t1, intercept.t2, slope.x.t2, ...
```

`Z_B_lat` multiplies `Lambda_B_slope z_B_slope`; `Z_B_diag` multiplies the
independent augmented diagonal effects `s_B_slope`.

| Symbol | R syntax | TMB object | Extractor | Status |
|---|---|---|---|---|
| `z_i` | `latent(... | unit, d = K)` | `z_B_slope` | random effect only | implemented |
| `Lambda_aug` | `latent(..., d = K)` | `Lambda_B_slope` | `part = "shared"` via `Sigma_B_slope` | implemented |
| `q_i` | `unique(... | unit)` | `s_B_slope` | `part = "unique"` via `sd_B_slope^2` | implemented for Gaussian |
| `Psi_B,aug` | augmented `unique()` | `theta_diag_B_slope`, `sd_B_slope` | named diagonal vector | implemented for Gaussian |
| `Sigma_B,aug` | paired `latent + unique` | `Sigma_B_slope + Sigma_B_unique_slope` | `part = "total"` | implemented for Gaussian |

This change is ordinary unit-tier random regression only. It is not a
structured phylogenetic or spatial slope cell, not a delta / hurdle slope
covariance path, and not a multi-slope (`s >= 2`) ordinary path.

## 4. Files Changed

Implementation:

- `R/brms-sugar.R`
- `R/fit-multi.R`
- `R/extract-sigma.R`
- `R/normalise-level.R`
- `src/gllvmTMB.cpp`

Tests:

- `tests/testthat/test-ordinary-latent-random-regression.R`
- `tests/testthat/test-augmented-lhs-guard.R`

Documentation and status:

- `man/extract_Sigma.Rd`
- `README.md`
- `NEWS.md`
- `ROADMAP.md`
- `_pkgdown.yml`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `vignettes/articles/random-slopes-nongaussian.Rmd`

Dev-log / recovery:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-08-ordinary-latent-reaction-norm.md`
- `docs/dev-log/after-task/2026-06-08-ordinary-gaussian-reaction-norm.md`
- `docs/dev-log/recovery-checkpoints/2026-06-08-142436-codex-post-compaction-checkpoint.md`

The generated Rd files `man/add_utm_columns.Rd`,
`man/extract_correlations.Rd`, `man/make_mesh.Rd`, and `man/reexports.Rd`
also remain changed from the earlier `devtools::check()` documentation pass,
which refreshed current-R link formatting.

## 5. Tests And Checks

- Focused RE-12 random-regression test:
  `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 60`.
- Augmented-LHS guard test:
  `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 27`.
- Full `devtools::test()` with `NOT_CRAN=true`:
  `FAIL 0`, `WARN 0`, `SKIP 704`, `PASS 2612` in `301.2s`.
- `devtools::document(quiet = TRUE)` completed and regenerated
  `man/extract_Sigma.Rd`.
- Rendered-Rd spot check: `tail -12 man/extract_Sigma.Rd` showed the
  `\seealso{}` block intact; `grep -c '^\\keyword' man/extract_Sigma.Rd`
  returned `0`.
- `pkgdown::build_article("articles/random-regression-reaction-norms",
  new_process = FALSE)` rendered
  `pkgdown-site/articles/random-regression-reaction-norms.html`.
- `pkgdown::build_article("articles/random-slopes-nongaussian",
  new_process = FALSE)` rendered
  `pkgdown-site/articles/random-slopes-nongaussian.html`.
- `pkgdown::check_pkgdown()` returned `No problems found` after the final
  article wording patch.
- `git diff --check` was clean.
- `devtools::check(args = "--no-manual", quiet = TRUE)` reported
  `0 errors`, `1 warning`, `2 notes`, exit status `1` because warnings fail
  check. The summary identified an install warning, a future timestamp note,
  and the existing `NEWS.md` section-title parsing note. No test, example, or
  pkgdown failure was reported.

The exact commands and stale-wording scans are recorded in
`docs/dev-log/check-log.md` under
`2026-06-08 - Ordinary Gaussian reaction-norm latent + unique follow-on`.

## 6. Tests Of The Tests

The new tests satisfy the project test contract in three ways:

- **Boundary / malformed input:** augmented ordinary slopes are rejected at the
  `unit_obs` tier, excessive `d` is rejected, `common = TRUE` is rejected on
  augmented `unique()`, paired latent/unique terms must use the same slope
  covariate, and non-Gaussian augmented `unique()` fails loud.
- **Feature combination:** the paired Gaussian test combines augmented
  `latent()` and augmented `unique()` in one model and checks
  `shared + diag(unique) == total`.
- **Recovery:** the deterministic Gaussian fixture recovers
  `Lambda_aug Lambda_aug'`, the augmented diagonal standard deviations, and
  the total intercept/slope covariance matrix within the focused tolerance.

## 7. Consistency Audit

Rose checks:

- Escaped-pipe scans over the source and generated HTML found no `x \\|` or
  ` \\|` hits in the two random-slope articles.
- Stale `unique()`-pending scans found only expected rows: the article gate
  says broader coverage remains pending, the coevolution register has its own
  unrelated pending second-slot engine note, and old NEWS rows keep their
  historical slope-family boundaries.
- Long-format `gllvmTMB()` calls in the touched articles carry
  `trait = "trait"`; wide `traits(...)` examples do not.
- Legacy `phylo_slope()` / `animal_slope()` hits are limited to legacy/status
  rows and the article gate row that explicitly rejects them as substitutes.

## 8. Team Learning

Ada kept the lane narrow: ordinary Gaussian `latent + unique`, not Julia,
non-Gaussian `unique()`, delta/hurdle slopes, or a public article promotion.

Boole checked that the formula grammar stays in the existing
`latent()` / `unique()` surface and that augmented unsupported forms fail loud
instead of silently dropping slope columns.

Gauss checked the TMB plumbing: positive diagonal standard deviations stay on
the log scale, `s_B_slope` enters as a random block, and the augmented unique
contribution is added to `eta` through `Z_B_diag`.

Noether checked the symbolic contract against implementation: the same `2T`
coefficient order drives `Z_B_lat`, `Z_B_diag`, `Lambda_B_slope`,
`sd_B_slope`, and `extract_Sigma(level = "unit_slope")`.

Curie checked that acceptance tests and rejection tests both exist, and that
the recovery test targets identifiable covariance summaries rather than raw
rotatable loadings.

Fisher kept the status as `partial` because a deterministic recovery test is
not a coverage-calibration claim and non-Gaussian augmented `unique()` remains
guarded.

Pat kept the article oriented around the behavioural-syndrome reader:
individuals, repeated sessions, context gradients, personality, plasticity, and
personality-plasticity covariance.

Rose caught the old public intro that still said augmented `unique()` was
pending and required the check-log / after-task supersession so the branch does
not contain two contradictory closeouts.

Grace checked the package gates: focused tests, full tests, roxygen,
pkgdown article renders, pkgdown check, diff check, and the package check
summary.

## 9. Roadmap Tick

**Roadmap tick**: `random-regression-reaction-norms` remains internal, but its
return condition changed from "needs augmented unique" to "needs polished
behavioural-syndrome example object, rendered long + wide examples,
diagnostics/figure review, and explicit non-Gaussian boundary wording."

## 10. GitHub Issue Ledger

- `gh issue list --state open --search "RE-12 random regression reaction norm unique" ...`
  returned #340, `Capability matrix — live status board`.
- `gh issue list --state open --search "ordinary random regression unit_slope" ...`
  returned no issues.
- `gh issue list --state open --search "random-regression-reaction-norms" ...`
  returned #347, `[roadmap] Article completion (public learning path)`, and
  #340.
- No issue comments were posted from this local branch. #340 and #347 are the
  relevant follow-up handles.

## 11. Known Limitations

- Non-Gaussian augmented ordinary `unique(1 + x | unit)` is guarded.
- Non-Gaussian ordinary augmented `latent()` has smoke evidence only.
- Delta, hurdle, and two-stage zero-inflated families remain out of scope for
  latent-scale slope covariance.
- Ordinary `s >= 2` random slopes remain planned, not implemented.
- `lambda_constraint$B` is still rejected on the augmented ordinary
  random-regression path.
- The reaction-norm article is still Tier 3/internal because it lacks the final
  behavioural example object, diagnostics, figures, and rendered public review.

## 12. Next Bounded Action

Build the behavioural-syndrome example object for
`random-regression-reaction-norms`, using `individual` as `unit` and
`session_id` as `unit_obs`, then render a reader-facing long + wide workflow
that uses the now-implemented Gaussian `latent + unique` engine.

## 13. Verdict

RE-12 is now a stronger `partial`: ordinary Gaussian `latent + unique`
reaction-norm random regression is implemented, documented, and tested locally.
It should not be advertised as broadly covered until non-Gaussian boundaries
and coverage evidence are resolved.
