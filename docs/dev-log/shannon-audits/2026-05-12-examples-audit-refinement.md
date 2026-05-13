# Audit: @examples refinement (Phase 5 CRAN-readiness follow-up)

**Trigger**: refines the @examples section of
`2026-05-12-phase5-cran-readiness-pre-audit.md` (PR #44) after
overnight verification that several listed exports have already
been demoted to `@keywords internal` since the audit was written.

**Audience**: Codex implementation PR for the Phase 5 @examples
round, plus the maintainer for sequencing decisions.

**Scope**: enumerate the actual current set of exports that lack
both `\examples` and `@keywords internal` in their rendered Rd
files, and propose concrete `@examples` blocks for each.

**Out of scope**: applying the changes. This audit is Claude-lane
prep; the R/ roxygen edits are Codex-lane work.

## Verification method

```sh
for rd in man/*.Rd; do
  name=$(basename "$rd" .Rd)
  has_ex=$(grep -c '\\examples' "$rd" || echo 0)
  has_int=$(grep -c '\\keyword{internal}' "$rd" || echo 0)
  if [ "$has_ex" = "0" ] && [ "$has_int" = "0" ]; then
    echo "MISSING: $name"
  fi
done
```

Run against `origin/main` HEAD `0d189a3` (after PR #54 merged).

## Findings: 11 exports lack both `\examples` and `@keywords internal`

The original PR #44 audit listed 22 exports without examples; 13
of those are already `@keywords internal` (back-compat wrappers,
diagnostic helpers, internal `profile_ci_*` family, the
deprecated `unique_keyword` alias). The actual remaining work is
much smaller. Of the 11 missing, 6 are listed in the original
audit and 5 are S3 methods the original audit did not enumerate:

| # | Export | Source file | Original audit? | Class |
|---|---|---|---|---|
| 1 | `gllvmTMBcontrol` | `R/gllvmTMB.R:647` | yes | control |
| 2 | `latent` | `R/parser.R` (estimate) | yes | formula keyword |
| 3 | `meta_known_V` | `R/brms-sugar.R:929` | yes | formula keyword |
| 4 | `plot_anisotropy` | `R/plot.R` (inherited from sdmTMB) | yes | plot helper |
| 5 | `sanity_multi` | `R/methods-gllvmTMB.R:778` | yes | diagnostic |
| 6 | `traits` | `R/traits-keyword.R:96` | yes | LHS marker |
| 7 | `gllvmTMB_multi-methods` | `R/methods-gllvmTMB.R` | NO | S3 method aggregate |
| 8 | `plot.gllvmTMB_multi` | `R/plot-gllvmTMB.R` | NO | S3 plot method |
| 9 | `predict.gllvmTMB_multi` | `R/methods-gllvmTMB.R` | NO | S3 predict method |
| 10 | `simulate.gllvmTMB_multi` | `R/methods-gllvmTMB.R` | NO | S3 simulate method |
| 11 | `tidy.gllvmTMB_multi` | `R/methods-gllvmTMB.R:475` | NO | broom S3 method |

## Proposed `@examples` blocks

All use `\dontrun{}` because each invokes a TMB fit, which can
take seconds to minutes. CRAN's per-example budget is short;
runnable examples would block submission.

### 1. `gllvmTMBcontrol`

```r
#' @examples
#' \dontrun{
#' ## Customise convergence and verbosity for a slow fit.
#' ctrl <- gllvmTMBcontrol(silent = FALSE, maxit = 1500)
#' fit  <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, control = ctrl
#' )
#' }
```

### 2. `latent`

```r
#' @examples
#' \dontrun{
#' ## Shared latent axes plus trait-specific residual diagonal.
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' ## Wide-formula equivalent under traits() LHS sugar (PR #39):
#' fit <- gllvmTMB(
#'   traits(t1, t2, t3) ~ 1 +
#'     latent(1 | site, d = 2) +
#'     unique(1 | site),
#'   data = df_wide, unit = "site"
#' )
#' }
```

### 3. `meta_known_V`

```r
#' @examples
#' \dontrun{
#' ## Meta-analytic sampling covariance V (T x T per study).
#' fit <- gllvmTMB(
#'   y ~ 0 + trait + meta_known_V(V = V_known),
#'   data = ma_df, unit = "study"
#' )
#' }
```

### 4. `plot_anisotropy`

```r
#' @examples
#' \dontrun{
#' ## Plot anisotropy of a fitted spatial gllvmTMB / sdmTMB model.
#' plot_anisotropy(fit)
#' plot_anisotropy2(fit)  ## stylised version
#' }
```

(Inherited from sdmTMB; the example follows sdmTMB's own
`plot_anisotropy` example to preserve cross-package familiarity.)

### 5. `sanity_multi`

```r
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' sanity_multi(fit)
#' ## Tighter thresholds for a high-stakes fit.
#' sanity_multi(fit, gradient_thresh = 1e-3, se_thresh = 50)
#' }
```

### 6. `traits`

```r
#' @examples
#' \dontrun{
#' ## Wide data frame: one row per unit, one column per trait.
#' fit <- gllvmTMB(
#'   traits(length, mass, wing, tarsus, bill) ~ 1 +
#'     latent(1 | individual, d = 2) +
#'     unique(1 | individual),
#'   data = df_wide, unit = "individual"
#' )
#' ## Tidyselect verbs work too:
#' fit <- gllvmTMB(
#'   traits(starts_with("y")) ~ 1 +
#'     latent(1 | site, d = 2),
#'   data = df_wide_y, unit = "site"
#' )
#' }
```

### 7. `gllvmTMB_multi-methods`

Aggregate Rd for `print`, `summary`, `print.summary`, `logLik`.
A single example showing the four methods on one fit:

```r
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' print(fit)
#' summary(fit)
#' logLik(fit)
#' }
```

### 8. `plot.gllvmTMB_multi`

```r
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' plot(fit, type = "correlation", level = "unit")
#' plot(fit, type = "loadings",    level = "unit")
#' plot(fit, type = "ordination",  level = "unit", axes = c(1, 2))
#' }
```

### 9. `predict.gllvmTMB_multi`

```r
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' ## Predictions on the linear-predictor (link) scale, training data.
#' pred_link <- predict(fit)
#' ## Predictions on the response scale.
#' pred_resp <- predict(fit, type = "response")
#' ## Predict for a new unit (population-level: re_form = NA).
#' pred_pop <- predict(fit, newdata = newdata, re_form = NA)
#' }
```

### 10. `simulate.gllvmTMB_multi`

```r
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' ## One simulated replicate from the fitted parameters.
#' sim1 <- simulate(fit, nsim = 1)
#' ## Ten simulated replicates for a parametric bootstrap.
#' sim_boot <- simulate(fit, nsim = 10, seed = 42)
#' }
```

### 11. `tidy.gllvmTMB_multi`

```r
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | site, d = 2) +
#'           unique(0 + trait | site),
#'   data = df, unit = "site"
#' )
#' ## Fixed effects as a tibble.
#' broom.mixed::tidy(fit, effects = "fixed")
#' ## Random-effect SDs and correlations.
#' broom.mixed::tidy(fit, effects = "ran_pars")
#' ## With profile-likelihood confidence intervals.
#' broom.mixed::tidy(fit, effects = "fixed", conf.int = TRUE)
#' }
```

## Shared structure (template)

Nine of the 11 examples open with the same fit skeleton:

```r
fit <- gllvmTMB(
  value ~ 0 + trait +
          latent(0 + trait | site, d = 2) +
          unique(0 + trait | site),
  data = df, unit = "site"
)
```

That fit needs a `df` long-format data frame. Codex's implementation
should either:
- Define `df` once per file via the existing `simulate_site_trait`
  helper called inside a `setup` chunk, or
- Use `@examplesIf interactive()` so the examples never run on
  CRAN's check machine (cleaner than `\dontrun{}` if the
  intent is "show but never run").

I recommend `\dontrun{}` over `@examplesIf interactive()` here
because CRAN reviewers can still read the example body in the
Rd file without running it; the `interactive()` form hides the
body in `R CMD check --as-cran` rendering.

## Effort estimate

11 `@examples` additions, all `\dontrun{}` and small (5-15 lines
each). One bounded Codex PR, ~1-2 hours of focused work plus
re-running `devtools::document()` and the rendered-Rd spot-check
(`tail -5 man/<file>.Rd` + `grep -c '^\\keyword' man/<file>.Rd`)
per PR #33 -> PR #36 lessons.

Risk: very low. Each example is a self-contained roxygen comment
addition; no signature change, no NAMESPACE change.

## Recommended sequencing

1. **Merge the in-flight PRs first**: PR #51 (Codex ordinal-probit)
   and PR #55 (Rose article-sweep). Neither touches `man/*.Rd`
   for these 11 exports, so no merge conflict; but keeping the
   PR queue clean makes the @examples PR easier to review.
2. **Codex implementation PR** applies the 11 `@examples` blocks
   above plus `devtools::document()` plus the rendered-Rd
   spot-check. Self-merge eligible per the merge-authority rule
   (R/ + Rd changes, all in one bounded module).
3. **Optional follow-up**: re-run this audit script
   (`MISSING:` printer) after the implementation lands; expected
   output is empty.

## What this audit changes about the original PR #44 audit

- Counts: PR #44 said "22 exports without examples"; the actual
  remaining count is 11 (the other 11 were demoted to internal
  during PR #43/#44 prep or earlier).
- Coverage: PR #44 missed the 5 S3-method Rds
  (`plot.gllvmTMB_multi`, `predict.gllvmTMB_multi`,
  `simulate.gllvmTMB_multi`, `tidy.gllvmTMB_multi`,
  `gllvmTMB_multi-methods`). Those are CRAN-reviewer-visible
  user-facing methods and should have examples.
- Concreteness: PR #44 listed "add example" as a TODO per
  export; this refinement provides the actual proposed
  `@examples` block text for each.
