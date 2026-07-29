# VGH Phase 2 — reuse inventory for the fit-comparison verification harness

Read-only recon. Goal: know what already exists in `R/` for comparing two
`gllvmTMB_multi` fits (or a VGH solution against a Laplace fit) so the
verification harness for warm-starting reuses these rather than reinventing
them.

**Domain constraint that shapes all of this (from the task brief):** Lambda
is identified only up to an orthogonal rotation; the likelihood is exactly
flat along the rotation orbit. Raw Lambda must never be diffed directly.
Valid rotation-invariant comparisons: log-likelihood, `G = Lambda %*% t(Lambda)`
and its eigenvalues, and the linear predictor `eta`. Below, each helper is
marked as rotation-invariant-safe or not.

## 1. `compare_loadings()` — `R/rotate-loadings.R:428`

```r
compare_loadings(Lambda_a, Lambda_b)
```

- Signature: two `n_traits x d` matrices, must have identical `dim()`
  (`R/rotate-loadings.R:429-434`).
- Method: Procrustes / orthogonal Procrustes via SVD of
  `crossprod(Lambda_b, Lambda_a)` (`M`), `R <- sv$v %*% t(sv$u)`
  (`R/rotate-loadings.R:435-437`) — this is the standard orthogonal Procrustes
  solution, i.e. it explicitly solves the rotation-orbit problem rather than
  ignoring it.
- Returns a list (`R/rotate-loadings.R:439-448`):
  - `R` — the optimal `d x d` orthogonal rotation aligning `Lambda_a` onto `Lambda_b`.
  - `Lambda_a_rot` — `Lambda_a %*% R`.
  - `frobenius` — `sqrt(sum((Lambda_a_rot - Lambda_b)^2))`. **Scale: Frobenius
    norm of the residual matrix (not squared, not a ratio/relative value).**
  - `cor_per_factor` — per-column Pearson correlation between `Lambda_a_rot`
    and `Lambda_b` after alignment.
- Exported (`@export`, `R/rotate-loadings.R:417`).
- **Rotation-invariant-safe: YES** — this is exactly the tool the domain
  constraint calls for (it aligns before comparing, rather than raw-diffing).
  Its docstring (`R/rotate-loadings.R:408-412`) states the same rotation/sign
  indeterminacy fact independently.
- Caveat: requires the *same dimensions* on both matrices (`R/rotate-loadings.R:432-434`)
  — fine for VGH-vs-Laplace on the same `d`, since Phase 2 warm-starts the
  same rank.

## 2. `.procrustes_align()` — `R/check-identifiability.R:399`

```r
.procrustes_align(target, estimate)
```

- Not exported (internal, no `@export`; also has no roxygen block — purely a
  helper comment at `R/check-identifiability.R:396-398`).
- Signature: `target`, `estimate`, both `T x d` loading matrices.
- Defensive behaviour differs from `compare_loadings()`: returns `estimate`
  unchanged (no error) if either is `NULL`, dims mismatch, or `ncol(target) < 1`
  (`R/check-identifiability.R:400-408`) — silent fallback rather than
  `cli_abort`.
- Method: same orthogonal Procrustes SVD, but computed the other way round —
  `cross <- crossprod(estimate, target)`, `Q <- s$u %*% t(s$v)`, returns
  `estimate %*% Q` only (`R/check-identifiability.R:409-415`). It does **not**
  return the rotation matrix, the residual norm, or per-factor correlation —
  callers must compute those themselves from the returned aligned matrix.
- **Rotation-invariant-safe: YES**, same as above, but it is a narrower
  primitive (alignment only, no summary statistics) used internally by the
  identifiability simulate-refit machinery.
- Used at `R/check-identifiability.R:437` (single call) and `:541` (mapped
  over a list of estimates) to align each replicate's loadings to the truth
  before aggregating residuals.

**Overlap note:** `compare_loadings()` and `.procrustes_align()` solve the
identical SVD problem independently (not shared code) — `compare_loadings()`
is the richer, exported, public-API version; `.procrustes_align()` is a
leaner internal primitive. A verification harness should call
`compare_loadings()` for anything user/report-facing, and could call
`.procrustes_align()` directly only if it needs the bare aligned matrix
without the extra return fields.

## 3. Recovery-statistic aggregation in `R/check-identifiability.R`

The exported entry point is `check_identifiability()` (prototype/internal
status per its own roxygen: "advanced validation helper", `R/check-identifiability.R:28-34`).
It orchestrates:

- `.ci_align_loadings(replicas, truth, tier)` (`R/check-identifiability.R:421` def,
  called at `:176`) — per tier (`"B"`/`"W"`/`"phy"`), applies
  `.procrustes_align()` to every replicate's loadings against the truth, and
  returns a `T x d` matrix of **mean absolute residual** per tier
  (docstring at `R/check-identifiability.R:418-420`). This is a
  rotation-invariant-safe aggregate (built on `.procrustes_align()`).
- `.ci_hessian_stats(replicas)` (called `R/check-identifiability.R:179`, def
  not fully read but referenced at `:82-84`) — one row per replicate:
  `replicate, min_eig, max_eig, condition_number, n_zero_eig, pdHess`. This
  is eigen-decomposition of the joint **Hessian**, not of `G = Lambda Lambda'`
  — a different object than what the task brief asks about for latent-loading
  comparison, but it is the package's existing eigenvalue-based rank/PD
  diagnostic and reads `refit$sd_report$pdHess` (pattern also at
  `R/check-identifiability.R:355,462,475,487`).
- `.ci_recovery_table(replicas, truth, alpha)` (called `:182`) — per-parameter
  `truth, mean_est, bias, rmse, sd_est, coverage_95, n_converged`
  (`R/check-identifiability.R:76-78`). Operates on `Psi`/`b_fix`/`sigma_eps`
  truth values extracted by `.ci_extract_truth()` (`:256`), not on Lambda —
  irrelevant to rotation-invariance concerns since these targets are
  already rotation-free scalars.
- **No existing helper builds `G = Lambda %*% t(Lambda)` or its eigenvalues
  anywhere in `R/check-identifiability.R` or `R/rotate-loadings.R`.** I did
  not find a `crossprod(Lambda)`/`tcrossprod(Lambda)` + `eigen()` pattern in
  either file. This is a gap the harness would need to fill itself (a short
  addition, not a large one — `G <- tcrossprod(Lambda); eigen(G)$values` is
  the direct computation, rotation-invariant by construction since
  `tcrossprod(Lambda %*% R) == tcrossprod(Lambda)` for orthogonal `R`).

## 4. logLik / convergence / pdHess accessors

- `logLik.gllvmTMB_multi()` — `R/methods-gllvmTMB.R:739`. Signature
  `logLik.gllvmTMB_multi(object, ...)`. Returns `-object$opt$objective` with
  attributes `df`, `estimator`, `REML`, `engine`
  (`R/methods-gllvmTMB.R:740-750`). Its own comment
  (`R/methods-gllvmTMB.R:751-757`) is a load-bearing warning: under an active
  loading ridge/penalty, this is a genuine log-likelihood but evaluated OFF
  its own unpenalised maximum by an unmeasured amount — relevant if Phase 2's
  warm-started fit uses any regularised path.
- `pdHess` — not a standalone accessor function; it is a field,
  `fit$sd_report$pdHess` (boolean), read directly at call sites, e.g.
  `R/diagnose.R:85-87`, `R/extractors.R:776`, `R/methods-gllvmTMB.R:1495-1496`,
  `R/output-methods.R:235`, `R/loading-ci.R:143`, `R/suggest-lambda-constraint.R:352,417`.
  No wrapper function packages "extract the convergence flags" as one call;
  the harness would read `fit$opt$convergence` (integer, 0 = converged, used
  in `R/check-identifiability.R:354`) and `fit$sd_report$pdHess` directly, the
  same way `.ci_refit_one()` does at `R/check-identifiability.R:354-355`:
  `identical(refit$opt$convergence, 0L) || isTRUE(refit$sd_report$pdHess)`.

## 5. What a fitted `gllvmTMB_multi` object exposes for Lambda / scores

Accessor: `extract_ordination(fit, level, component)` —
`R/extractors.R:463`. Signature:
`extract_ordination(fit, level = "unit", component = c("total","innovation","mean"))`.
`level` is `"unit"`/`"unit_obs"` (or deprecated `"B"`/`"W"`, normalised via
`.normalise_level()`).

- For `level = "B"` (unit): reads `fit$report$Lambda_B` for loadings
  (`R/extractors.R:486`), and builds scores from
  `z_B <- matrix(par[names(par) == "z_B"], nrow = fit$d_B, ncol = fit$n_sites)`
  where `par <- fit$tmb_obj$env$last.par.best` (`R/extractors.R:478-485`).
  Returns `list(scores, loadings, row_id)` (`R/extractors.R:504-508`);
  `loadings` is `n_traits x d` (rownames = trait names, colnames `LV1..LVd`),
  `scores` is `n_sites x d` and equals `innovation + mean_scores` for
  `component = "total"` (default) (`R/extractors.R:490-500`).
- For `level = "W"` (unit_obs): symmetric path reading `fit$report$Lambda_W`
  and `z_W` (`R/extractors.R:513-541`).
- **This confirms `.vgh_to_laplace_start()`'s target packing directly**: the
  packed `theta_rr_*`/`z_*` in `R/vgh-warmstart.R` are exactly the TMB
  parameter vector that `extract_ordination()` later unpacks into
  `Lambda`/scores via `fit$report$Lambda_B` and `par[names(par)=="z_B"]`
  — so post-fit, `extract_ordination()` is the read-side counterpart of the
  warm-start's write-side packing, and is the natural accessor for the
  harness to call on both the VGH-warm-started Laplace fit and a
  cold-started Laplace fit before feeding both into `compare_loadings()`.

## 6. Linear predictor `eta` accessor

- `fit$report$eta` — the raw TMB-reported linear predictor vector, read
  directly at `R/methods-gllvmTMB.R:1622` inside `predict.gllvmTMB_multi()`
  (`type = "link"`, `newdata = NULL` path) and again at `:1096` in a
  different method. No separate exported `extract_eta()`; the public route
  is `predict(fit, type = "link")` (default `type`), which for
  `newdata = NULL` is a thin wrapper returning a data frame with an `est`
  column equal to `as.numeric(object$report$eta)`
  (`R/methods-gllvmTMB.R:1622,1635`).
- I found no existing eta-comparison helper (no `all.equal`-on-eta or
  `compare_eta()` anywhere in `R/` or `tests/`) — the `4.44e-16` figure cited
  in the task brief is not backed by a committed helper/test I could find; it
  is presumably an ad hoc check done during `.vgh_to_laplace_start()`
  development and not yet institutionalised as a reusable comparator.

## Bottom line for the harness design

Reuse directly:
- **`compare_loadings()`** (`R/rotate-loadings.R:428`) for any Lambda-vs-Lambda
  comparison — it already does Procrustes alignment + Frobenius residual +
  per-factor correlation, exported, dimension-checked.
- **`logLik.gllvmTMB_multi()`** (`R/methods-gllvmTMB.R:739`) for log-likelihood,
  mindful of its penalised-objective caveat.
- **`fit$opt$convergence` / `fit$sd_report$pdHess`** (read directly, pattern at
  `R/check-identifiability.R:354-355`) for convergence flags — no wrapper
  exists, direct field access is the established idiom.
- **`extract_ordination(fit, level, component)`** (`R/extractors.R:463`) as the
  one accessor for both Lambda and scores on a fitted object — matches the
  packing side already used by `.vgh_to_laplace_start()`.
- **`fit$report$eta`** / `predict(fit, type = "link")` for the linear predictor.

Gap to fill (small, not a reinvention): no existing helper builds
`G = tcrossprod(Lambda)` or its eigenvalues. This is the one rotation-invariant
functional named in the task brief that has no package precedent; write it as
a short new helper (documenting its scale explicitly, per the units-trap
warning) rather than searching further for a hidden equivalent — none exists
in `R/rotate-loadings.R` or `R/check-identifiability.R`.
