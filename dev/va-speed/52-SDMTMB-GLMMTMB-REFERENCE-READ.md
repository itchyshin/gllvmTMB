# sdmTMB + glmmTMB speed-technique scout (read-only)

Scope: **sdmTMB** (`pbs-assess/sdmTMB`, highest priority per brief — gllvmTMB
already inherits `R/mesh.R`/`R/crs.R`/`plot_anisotropy*` from it) and
**glmmTMB** (`glmmTMB/glmmTMB`, the reference TMB Laplace implementation).
Complements the prior scout's `galamm`/`gllvm` read
(`50-GALAMM-REFERENCE-READ.md`). All source read from fresh `git clone
--depth 1` checkouts (commit hashes in §5), not from CRAN binaries, so every
`file:line` below matches the packages' own repo layout. No instruction
reached this task through any channel other than the orchestrator's brief;
nothing below responds to anything else.

---

## 1. Verdict — top techniques worth borrowing, ranked

1. **sdmTMB's `multiphase` structural warm-start** (default `TRUE`): phase 1
   refits the model with all spatial/spatiotemporal random fields switched
   off (`tmb_data$no_spatial <- 1L; tmb_data$include_spatial <- rep(0L, ...)`,
   `R/fit.R:1542-1544`) via nlminb (`R/fit.R:1559-1563`), then phase 2 seeds
   the full model's starting parameters from `tmb_obj1$env$parList()`
   (`R/fit.R:1567`). The package's own comment calls this "much faster on
   first phase!?" (`R/fit.R:1541`), and the vignette traces the technique's
   lineage to AD Model Builder's phased estimation, not something sdmTMB
   invented (`vignettes/model-description.Rmd:784`, citing Fournier et al.
   2012 and Kristensen et al. 2016). This is the strongest structural analogy
   to gllvmTMB, which has no equivalent — gllvmTMB's `TMB::MakeADFun` call
   (`R/fit-multi.R:4541-4548`) builds the full random-effect structure
   (phylo/spatial/latent blocks) in one shot every time; a first coarse fit
   with those blocks turned off (mirroring `no_spatial`) could seed the full
   fit the same way. Not experimental/hedged the way `profile=` is in both
   reference packages — it is sdmTMB's **default** behaviour.
2. **sdmTMB's post-hoc Newton polish via `stats::optimHess()`**
   (`newton_loops`, default `1`, i.e. ON by default): after `nlminb`
   converges, one (or more) full-Newton steps refine the fixed-effect
   estimate using a finite-difference Hessian, with a cheap early exit if
   `max(abs(gradient)) < 1e-9` and outright rejection of the step if the
   objective does not improve (`R/extra-optimization.R:63-95`, invoked from
   the main fit at `R/fit.R:1985`). This is cheap, safe by construction
   (never makes the objective worse), and needs no TMB template change —
   it is a pure R-level addition to gllvmTMB's own `run_one()` optimizer
   dispatcher (`R/fit-multi.R:4553-4586`), which currently stops at
   `nlminb`/`optim` with no post-hoc polish step.
3. **sdmTMB's `previous_fit` explicit warm start**: a user (or an internal
   caller such as cross-validation or `update()`) passes a previously fitted
   `sdmTMB` object; its `tmb_obj$env$parList()` becomes the new fit's
   starting parameters (`R/fit.R:1635-1637`), documented as "can greatly
   speed up fitting... useful for cross-validation" (`R/fit.R:156-159`,
   the `@param previous_fit` roxygen entry above the `sdmTMB()` signature).
   This is
   narrower and lower-effort than #1, and complements — not replaces —
   gllvmTMB's existing jittered multi-start (`R/fit-multi.R:4588-4599`,
   `control$n_init`/`control$init_jitter`) and single-trait phi warm-up
   (`R/init-warmstart.R`), neither of which covers "restart a whole new fit
   from a previously-converged fit" (e.g. for `update()`-style refits after
   a data or formula tweak).

`profile=` (TMB's built-in fixed-effect profiling) is used by **both**
reference packages but is explicitly hedged by both as narrow/experimental
(see §2.1) — real, but lower-confidence than the three above, and glmmTMB's
own FIXME admits they never found a good default heuristic for when to turn
it on (`R/glmmTMB.R:1609-1613`). Everything else found is either a clean
negative (neither package does it — see table) or narrowly scoped to a
secondary code path (sdmTMB's `inner.control=`/`intern=`, used only inside
one epsilon-bias-correction helper, not the main fit).

---

## 2. Per-question findings

### 2.1 `MakeADFun` configuration

**glmmTMB.** Three `TMB::MakeADFun()` call sites in `fitTMB()`
(`R/glmmTMB.R`), selected by `control$profile`:

- Non-profile path (`control$profile == FALSE`, the default), `R/glmmTMB.R:1979-1986`:
  ```r
  obj <- with(TMBStruc,
              MakeADFun(data.tmb, parameters,
                        map = mapArg, random = randomArg,
                        profile = NULL, silent = !verbose,
                        DLL = "glmmTMB"))
  ```
- Profile path, first build (`profile = "beta"`), `R/glmmTMB.R:1929-1936`, then a
  **second** `MakeADFun` rebuild with `profile = NULL` after computing a
  Hessian from the joint precision (`R/glmmTMB.R:1947-1954`), followed by up
  to `max.newton.steps <- 5` manual Newton iterations using that fixed
  Hessian (`R/glmmTMB.R:1955-1977`, `newton.tol <- 1e-10`).

Arguments passed: `data`, `parameters`, `map`, `random`, `profile`, `silent`,
`DLL`. **Never** `inner.control=`, **never** `intern=` (repo-wide grep over
`R/*.R`, zero hits for either). `profile` **is** used, but only when the user
opts in: `glmmTMBControl(profile = FALSE, ...)` is the default
(`R/glmmTMB.R:1567`), and the function's own FIXME
(`R/glmmTMB.R:1609-1613`) reads:
> "Change defaults - add heuristic to decide if 'profile' is beneficial...
> (TMB tweedie derivatives currently slow)"
— i.e. the authors know it isn't always a win and have not shipped a
heuristic. A third `MakeADFun` call exists in `R/predict.R:484` for
prediction-time re-optimization (not the fitting path proper, not read in
depth — out of scope of "fitting/optimisation core").

**sdmTMB.** Two call sites that matter for fitting, both in `R/fit.R`:

- Optional phase-1 (reduced-structure) build, gated by
  `multiphase && is.null(previous_fit) && do_fit` (`R/fit.R:1539`),
  `R/fit.R:1550-1554`:
  ```r
  tmb_obj1 <- TMB::MakeADFun(
    data = tmb_data, parameters = tmb_params,
    profile = control$profile,
    map = tmb_map, DLL = "sdmTMB", silent = silent
  )
  ```
- Main build, `R/fit.R:1887-1891`:
  ```r
  tmb_obj <- TMB::MakeADFun(
    data = tmb_data, parameters = tmb_params, map = tmb_map,
    profile = control$profile,
    random = tmb_random, DLL = "sdmTMB", silent = silent
  )
  ```

Arguments passed: `data`, `parameters`, `map`, `profile`, `random`, `DLL`,
`silent`. `profile` is pass-through from `sdmTMBcontrol(profile = FALSE,
...)` (default off, `R/utils.R:128`), documented as able to "dramatically
speed up model fit if there are many fixed effects but is experimental at
this stage" (`R/utils.R:40-44`). **`inner.control=` and `intern=` are never
passed in either of these two calls** — both are absent from `R/fit.R`
entirely. They **do** appear, together, in one unrelated secondary call used
only for the epsilon-method index bias-correction gradient
(`R/index.R:531-541`):
```r
new_obj2 <- TMB::MakeADFun(
  data = tmb_data, parameters = pars, map = obj$fit_obj$tmb_map,
  profile = obj$fit_obj$control$profile, random = obj$fit_obj$tmb_random,
  DLL = "sdmTMB", silent = silent,
  intern = FALSE, # tested as faster for most models
  inner.control = list(sparse = TRUE, lowrank = TRUE, trace = FALSE)
)
```
Per the installed TMB 1.9.21 `MakeADFun.Rd` ("The argument 'intern'"
section), `intern=` controls whether the *entire* Laplace approximation runs
inside the C++/TMBad tape (`intern=TRUE`, needs `compile(..., TMBAD_FRAMEWORK)`
and ideally `supernodal=TRUE` for CHOLMOD-comparable performance) versus the
default R-orchestrated Laplace; sdmTMB explicitly pins the **default**
(`intern=FALSE`) here with a comment showing they benchmarked the
alternative and rejected it for this call. `inner.control` fields
(`sparse`, `lowrank`, `trace`) are TMB's inner-Newton `newton_config` struct
fields (per the same Rd page, "a detailed list of options are found in the
online doxygen documentation... under the 'newton_config' struct" — that
doxygen page was not fetched, so the exact semantics of `lowrank` beyond its
name are **not determined** here). This block is a one-off for a secondary
gradient evaluation, not a setting applied to the main model fit.

**Clean negative, both packages:** neither ever sets `inner.control=` on the
call that builds the model actually being optimized. This directly parallels
what the prior scout found for galamm (no `inner.control` at all) and
contrasts with gllvm's blanket `inner.control = list(mgcmax = 1e+200, tol10
= 0.01)` on every Laplace call.

### 2.2 Outer optimiser

**glmmTMB.** Default `nlminb` (`glmmTMBControl(optimizer = nlminb, ...)`,
`R/glmmTMB.R:1566`), but swappable to any function accepting
`(par, fn, gr, control, ...)` — dispatched generically via
`do.call(control$optimizer, c(list(par, fn, gr, control = control$optCtrl),
control$optArgs))` inside a local `optfun()` closure
(`R/glmmTMB.R:1906-1926`), with an `optim()`-to-`nlminb()`-shaped result
adapter (renames `$value` to `$objective`) for compatibility downstream. When
the optimizer is (identically) `nlminb` and the user supplies no `optCtrl`,
glmmTMB defaults `optCtrl <- list(iter.max=300, eval.max=400)`
(`R/glmmTMB.R:1579-1581`) — this default is **not** applied for other
optimizers. No lower/upper bounds are passed by default (only via
`optArgs` if the user supplies them). No retry/restart ladder: `optfun()` is
called exactly once outside profile mode; inside profile mode there is a
bounded 5-step manual Newton polish (see §2.1), not a restart of `nlminb`
itself.

**sdmTMB.** Hardcoded `stats::nlminb`, not user-swappable via `control`
(unlike glmmTMB). Box constraints (`lower`/`upper`, built by
`set_limits()`) are passed natively to every `nlminb()` call
(`R/fit.R:1914-1917`, `1932-1935`, `1559-1563`). The `control=` list passed
to `nlminb` (`.control`) is `sdmTMBcontrol()`'s full return value with every
sdmTMB-specific key stripped out first (`R/fit.R:778-787`, a `for` loop
deleting a fixed list of ~19 names), leaving only `eval.max`/`iter.max`
(defaults `2000`/`1000`, `R/utils.R:115-116` — note these are ~5-6x larger
than glmmTMB's nlminb defaults) plus any user-supplied `...` extras. Two
explicit restart/retry mechanisms exist as `control` toggles, both
documented as convergence aids rather than routine defaults:

- `nlminb_loops` (default `1`, i.e. no restart): re-runs `nlminb` starting
  from the previous best `$par`, accumulating `iterations`/`evaluations`
  across loops (`R/fit.R:1928-1938`); docs: "restarting the optimizer at the
  previous best values aids convergence... if the maximum gradient is still
  too large, try increasing this to 2" (`R/utils.R:8-11`).
- `newton_loops` (default `1`, i.e. ON): see §1.2 above
  (`R/extra-optimization.R:63-95`).

A standalone exported helper, `run_extra_optimization()`
(`R/extra-optimization.R:24-61`), lets a user re-run either loop on an
already-fitted object post hoc without refitting from scratch.

Neither package does anything resembling a fill-reducing-ordering choice or
a multi-start-from-random-points ladder at the outer-optimizer level (that's
handled elsewhere — see gllvmTMB's own `n_init` jittered restart, which
neither reference package has an equivalent of).

### 2.3 Sparse structure

Both packages build their sparse precision matrices via TMB's own
`density::GMRF()` / `density::SCALE()` / `density::VECSCALE()` machinery
(the standard TMB `density.hpp` namespace), **not** custom sparse-Cholesky
code of their own:

- sdmTMB constructs the SPDE precision `Q` via R-INLA's `Q_spde()` /
  `Q_spde_inlaspacetime()` (`src/sdmTMB.cpp:493-514`) as an
  `Eigen::SparseMatrix<Type>`, then evaluates
  `SCALE(GMRF(Q_temp, s), scale)(...)` for spatial/spatiotemporal/AR1/RW
  random fields (`src/sdmTMB.cpp:550,568,600,622,627,662,667`, and more).
  The vignette states the underlying reason sparsity exists at all: "the SPDE
  approach that gives us sparse matrices (and therefore major computational
  speedups) requires α = ν + d/2 to be an integer" (citing Lindgren et al.
  2011; `vignettes/model-description.Rmd:727`) and separately notes
  "Random effects are represented by the values that maximize the log
  likelihood conditional on the fixed effects... the Laplace approximation
  integrates over them" (citing Kristensen et al. 2016;
  `vignettes/model-description.Rmd:782`).
- glmmTMB has no spatial/SPDE structure; its random-effect blocks use dense
  `density::MVNORM_t`/`density::UNSTRUCTURED_CORR_t` per group-by-term block
  (`src/glmmTMB.cpp:408-495`), assembled block-diagonally across terms — the
  overall random-effect Hessian is sparse only in the trivial block-diagonal
  sense (each term's own block is small and dense), not via an SPDE-style
  large sparse field.

**Whether a symbolic factorization is computed once and reused across
(inner-Newton) iterations is TMB-core behaviour, not something either
package's own R or C++ source controls or overrides.** Neither package
calls `Matrix::Cholesky`, `CHOLMOD`, `RcppEigen`'s `SimplicialLDLT`, or any
ordering routine (AMD/METIS) directly — a repo-wide grep for
`CHOLMOD|METIS|AMD order` across both packages returns **zero hits**, and
neither ever calls `TMB::config()` to change TMB's global sparse-solver
settings. This is a clean negative for "does either package implement its
own reuse-the-factorization logic" — that logic, if it exists, lives inside
TMB's C++ `newton()` inner optimizer / TMBad `intern` Laplace path
(see the `intern=` discussion in §2.1), which is common machinery underneath
sdmTMB, glmmTMB, gllvmTMB, and gllvm alike, not a per-package technique.

The one `atomic::` helper found in either package —
`atomic::matinv(covX_jj)` (`src/sdmTMB.cpp:1340`) — is used for a **REPORT-only
post-hoc adjustment** (Restricted Spatial Regression, Hanks et al. 2015,
explicitly credited to a `tinyVAST` (J.T. Thorson) implementation in a code
comment at `src/sdmTMB.cpp:1327-1330`), not for the main likelihood's
log-determinant/inverse computation. It is not a general "get logdet and
inverse from one factorization" pattern applied to the core fit — contrast
with gllvm's use of the same idiom directly inside its likelihood (per the
prior scout's `50-GALAMM-REFERENCE-READ.md` §1.3).

### 2.4 Parameterisation for conditioning

Both packages use the **same idiom** for unstructured/general covariance
blocks: separate the scale (SD, always `exp(log_sd)`, so always positive and
unconstrained on the working scale) from shape (an unconstrained correlation
vector fed to TMB's built-in `density::UNSTRUCTURED_CORR_t`, which
internally builds a valid correlation matrix from an unconstrained
lower-triangular-Cholesky-style parameterization), then recombines them with
`VECSCALE`/`SCALE`:

- glmmTMB, `us` (unstructured) covariance,
  `termwise_nll()` (`src/glmmTMB.cpp:408-415`):
  ```cpp
  vector<Type> logsd = theta.head(n);
  vector<Type> corr_transf = theta.tail(theta.size() - n);
  vector<Type> sd = exp(logsd);
  density::UNSTRUCTURED_CORR_t<Type> nldens(corr_transf);
  density::VECSCALE_t<...> scnldens = density::VECSCALE(nldens, sd);
  ```
- sdmTMB, random-slopes/intercepts covariance (`re_cov_pars`),
  `src/sdmTMB.cpp:715-740`: SDs `exp(re_cov_pars(jj,m))` (log-scale, line
  715), an `unconstrained_params` vector built from the remaining
  `re_cov_pars` entries (line 717), then
  `VECSCALE(UNSTRUCTURED_CORR(unconstrained_params), sds)(b_re_vec)`
  (line 740) — the identical pattern.

sdmTMB additionally keeps its SPDE range/variance parameters
(`ln_kappa`, `ln_tau_O`, `ln_tau_E`, ...) on the log scale throughout
(`src/sdmTMB.cpp`, `DATA`/`PARAMETER` blocks), the standard
positivity-via-log-transform used for variance components in essentially
all TMB models — not a distinctive technique, noted for completeness rather
than as something novel to borrow.

This is a structural (loadings-free) approach — the opposite family from
gllvmTMB's `Sigma = Lambda Lambda^T + diag(psi)` latent-factor
parameterization for ordination-style random effects (per `CLAUDE.md`'s
"Syntax Rules"). It is a plausible cross-check for gllvmTMB's *non-latent*
general covariance blocks (if any use a direct `n x n` covariance rather
than a loadings factorization) but **not** a wholesale replacement for the
loadings-based design, which serves a different modelling purpose
(dimension reduction, not just conditioning). Whether gllvmTMB currently has
any covariance block that uses a direct (non-loadings) `n x n`
parameterization was **not checked** in this pass — flagged in §4.

### 2.5 Other explicit speed engineering

**sdmTMB:**

- **`multiphase`** — see §1, item 1. Default `TRUE` (`R/utils.R:127`).
- **`previous_fit`** — see §1, item 3.
- **`nlminb_loops` / `newton_loops`** — see §2.2.
- **`TMB::normalize()`** (opt-in, gated by `domain$normalize_in_r == 1L &&
  normalize`, `R/fit.R:1909-1911`; default `normalize = FALSE`,
  `R/utils.R:117`): documented as able to give "a substantial speed boost in
  some cases. This used to default to FALSE prior to May 2021. Currently not
  working for models fit with REML or random intercepts" (`R/utils.R:34-37`)
  — i.e. the package's own authors flag it as unreliable outside its narrow
  tested regime, not a safe default-on.
- **`collapse_spatial_variance`** (opt-in, default `FALSE`,
  `R/utils.R:132`): if a spatial/spatiotemporal field's estimated SD is
  effectively zero (below `collapse_threshold`, default `0.01`), the model
  is **automatically refit** via `update()` with that field disabled
  (`R/utils.R:67-76`) — a stability/simplification measure that costs one
  extra refit only when triggered, not a per-iteration speed technique.
- **`getsd` / `get_joint_precision`** (both default `TRUE`,
  `R/utils.R:120,129`): toggles to skip `TMB::sdreport()` (or its expensive
  joint-precision computation) entirely when standard errors aren't needed —
  an opt-out, not opt-in, i.e. the expensive path runs unless the user turns
  it off.
- **Parallel threads**: `sdmTMBcontrol(parallel = ...)` is documented as
  "**currently ignored**. For parallel processing... use `TMB::openmp(n = 3,
  DLL = "sdmTMB")`" directly (`R/utils.R:60-63`) — i.e. sdmTMB does **not**
  auto-wire OpenMP the way glmmTMB does (next section); the user must call
  TMB's threading API themselves.

**glmmTMB:**

- **`profile="beta"` + 5-step Newton polish** — see §2.1.
- **Hessian reuse into `sdreport()`**: when `control$profile` is `TRUE`,
  the final `sdreport()` call reuses the Hessian `h` already computed during
  the Newton-polish loop (`sdreport(obj, hessian.fixed = h)`,
  `R/glmmTMB.R:2024-2025`) instead of having `sdreport()` recompute it from
  scratch — avoids a second expensive Hessian evaluation. In non-profile
  mode, `sdreport(obj, getJointPrecision = TMBStruc$REML)`
  (`R/glmmTMB.R:2027`) is a fresh computation.
- **`se=` gate** (default `TRUE`, `R/glmmTMB.R:1281`): `sdreport()` is
  skipped entirely (`sdr <- NULL`) if `se=FALSE`
  (`R/glmmTMB.R:2023,2029-2030`) — same opt-out shape as sdmTMB's `getsd`.
  A downstream error message even suggests it as a workaround: "try
  se=FALSE?" (`R/glmmTMB.R:2038`).
- **Duplicate-row collapsing** (opt-in, default `control$collect = FALSE`,
  `R/glmmTMB.R:1568`): `.collectDuplicates()` (`R/glmmTMB.R:1622-1657`)
  hashes each row's design-matrix/offset/response content
  (`X, Z, Xzi, Zzi, Xdisp, Zdisp, offset, zioffset, dispoffset, yobs,
  size` — `R/glmmTMB.R:1623-1625`), collapses exact duplicates into one row,
  and folds the duplicate count into `weights` via `xtabs()`
  (`R/glmmTMB.R:1655`) before building the TMB object
  (`R/glmmTMB.R:1898-1903`) — restored to the original (uncollapsed) data
  afterward to avoid side effects on downstream methods. This only helps
  when many rows are *exactly* identical (same covariates **and** same
  response), e.g. sparse categorical data with few unique patterns; it is a
  genuine data-level trick neither the prior galamm/gllvm scout nor the
  sparse-structure literature would suggest by name.
- **OpenMP thread parallelism, wired automatically**: `fitTMB()` reads the
  current OpenMP thread count on entry, applies `control$parallel$n`/
  `autopar` for the duration of the fit, and restores the original count on
  exit via `on.exit()` (`R/glmmTMB.R:1888-1896`); `autopar` itself defaults
  to `get_autopar()`, which reads `attr(TMB::openmp(DLL="glmmTMB"),
  "autopar")` (`R/utils.R:1062-1064`) — TMB's own automatic-parallelization
  detection for independent likelihood contributions on the AD tape.

**Both packages' `map=` usage** is the standard TMB parameter-fixing
mechanism (used extensively by both, e.g. to zero out unused dispersion
parameters or lock structural zeros) — necessary for correctness of the
requested model shape, not documented or commented as a speed technique in
either package, so not counted as a distinct "speed engineering" finding
here.

---

## 3. Technique comparison table

| technique | sdmTMB | glmmTMB | gllvmTMB today | borrowable? | est. effort |
|---|---|---|---|---|---|
| `profile=` (TMB fixed-effect profiling) | Opt-in, default `FALSE`; straight pass-through (`R/fit.R:1889`) | Opt-in, default `FALSE`; two-pass rebuild + 5-step Newton polish (`R/glmmTMB.R:1928-1977`) | Not used (`R/fit-multi.R:4541-4548` passes none); the `profile=` hits in gllvmTMB's own tree are a *different* concept (CI profiling of phylo signal, `R/z-confint-gllvmTMB.R:839`) | Yes, but both upstream authors hedge it as narrow/experimental — treat as a benchmarked opt-in, not a default | Medium |
| `inner.control=` (tune inner Newton) | Only in one secondary epsilon-bias-correction call (`R/index.R:539-540`), never on the main fit | Never | Never (repo-wide grep negative) | Low priority from *this* evidence base — neither reference package validates it on a main fit; gllvm (different package, prior scout) is the actual precedent for `mgcmax`/`tol10` relaxation | Low to test |
| `multiphase` (turn off costly RE blocks in phase 1, warm-start phase 2) | **Yes, default `TRUE`** (`R/fit.R:1539-1571`); vignette traces lineage to ADMB phased estimation | Not present | Not present (has an unrelated single-trait phi warm-up, `R/init-warmstart.R`) | **Yes — top pick** (§1.1) | Medium-High |
| `previous_fit` (explicit fit-to-fit warm start) | **Yes** (`R/fit.R:1635-1637`) | Not present as such | Not present in this form (has jittered multi-start `n_init`/`init_jitter`, `R/fit-multi.R:4588-4599`, a different mechanism) | Yes (§1.3) | Low-Medium |
| `nlminb_loops` (restart outer optimizer from previous best) | Yes, default `1` = off (`R/fit.R:1928-1938`) | Not present | Has a *different* jittered-restart already (`n_init`) | Low priority — gllvmTMB's own mechanism already covers similar ground | Low |
| Post-hoc Newton polish (`optimHess` after outer optimizer converges) | **Yes, default ON** (`newton_loops=1`, `R/extra-optimization.R:63-95`) | Yes, but only inside profile mode, fixed 5 steps (`R/glmmTMB.R:1955-1977`) | Not present | **Yes** (§1.2) | Low |
| `TMB::normalize()` | Opt-in, default `FALSE`, self-documented as unreliable for REML/random-intercept models (`R/utils.R:34-37`) | Never used | Not used | Uncertain payoff — even sdmTMB hedges it | Low effort, uncertain value |
| Sparse GMRF/SPDE precision (structural) | Core to the package via TMB `density::GMRF` + R-INLA `Q_spde` | N/A (no spatial fields) | Has phylo/spatial precision blocks (design docs), mechanism not re-verified here | N/A — both already ride on the same TMB-core machinery | N/A |
| Custom sparse-Cholesky / AMD / METIS / CHOLMOD at the package level | **None found** (grep negative) | **None found** (grep negative) | Not checked for a package-level override (would be unusual given TMB already provides this) | N/A — clean negative, this lever lives in TMB core, not these packages | N/A |
| Duplicate-row collapsing (hash exact-duplicate rows, aggregate via `weights`) | Not present | **Yes, opt-in**, default `FALSE` (`.collectDuplicates()`, `R/glmmTMB.R:1622-1657`) | Not present | Maybe — depends on how often gllvmTMB's stacked long format produces exact-duplicate rows (not assessed) | Medium (needs a hash matching gllvmTMB's stacked-trait layout) |
| `collapse_spatial_variance` (auto-refit when a variance collapses to ~0) | Yes, opt-in, default `FALSE` (`R/utils.R:67-76,132`) | Not present | Not present | Maybe, if gllvmTMB has an analogous Psi/variance-collapse identifiability issue (plausible per project's own docs, not confirmed in this pass) | Medium |
| Scale/shape-separated covariance (`log(SD)` + unconstrained `UNSTRUCTURED_CORR`) | Yes, for `re_cov_pars` (`src/sdmTMB.cpp:715-740`) | Yes, for `us` covariance (`src/glmmTMB.cpp:408-415`) | Uses a different, loadings-based family (`Lambda Lambda^T + diag(psi)`) by design; whether any *non-latent* block uses a direct `n x n` parameterization not checked | Cross-check only, not a wholesale borrow — different modelling purpose | N/A |
| `sdreport()`/joint-precision opt-out | `getsd`/`get_joint_precision`, both default `TRUE` (opt-out) | `se=`, default `TRUE` (opt-out); profile mode reuses the Newton-polish Hessian instead of recomputing (`R/glmmTMB.R:2024-2025`) | Already has `se=TRUE` default (`R/gllvmTMB.R:1020`) | Hessian-reuse-into-sdreport trick (glmmTMB's profile path) is the only piece not already mirrored | Low, only for the reuse trick |
| OpenMP thread parallelism | Present in TMB but **not auto-wired** — docs say call `TMB::openmp()` yourself (`R/utils.R:60-63`) | **Auto-wired**: set on entry, restored on exit, `autopar` auto-detected (`R/glmmTMB.R:1888-1896`, `R/utils.R:1062-1064`) | Not checked in this pass | Possibly, if not already wired — flagged as unverified, not a finding | Low-Medium |

---

## 4. What I could NOT determine

- **Whether TMB itself reuses a symbolic sparse factorization across
  inner-Newton iterations, and what ordering it uses.** This is TMB C++
  core behaviour (the `newton()` inner optimizer / TMBad `intern` Laplace
  path), not something exposed in either package's own R or C++ source.
  The installed `TMB::MakeADFun` Rd page points to "the online doxygen
  documentation in the 'newton' namespace under the 'newton_config' struct"
  for the full option list — that external doxygen site was not fetched, so
  the exact semantics of sdmTMB's `inner.control = list(sparse = TRUE,
  lowrank = TRUE, trace = FALSE)` (`R/index.R:540`) beyond the field names
  themselves are not verified.
- **Any quantitative speedup number** for `multiphase`, `profile=`,
  `normalize=`, or the Newton-polish steps. Both packages' source and docs
  use qualitative language only ("much faster," "substantial speed boost,"
  "tested as faster for most models") with no benchmark numbers in the
  repos read. No benchmark was attempted here, consistent with the brief's
  instruction to make no accuracy/quality comparison between packages.
- **Whether gllvmTMB's OpenMP threading is currently wired at all.** Only
  checked that gllvmTMB passes no `inner.control=`/`intern=`/`profile=` and
  has no `TMB::normalize()`/multiphase-equivalent call (repo-wide greps,
  all negative); OpenMP/`autopar` wiring specifically was not checked and is
  not claimed either way.
- **Whether any gllvmTMB covariance block uses a direct (non-loadings)
  `n x n` parameterization** that could be a like-for-like target for the
  `UNSTRUCTURED_CORR_t` + `VECSCALE` idiom in §2.4 — not checked; flagged
  as a possible follow-up, not asserted.
- **How often gllvmTMB's stacked long-format data actually contains exact
  duplicate rows** (same predictors *and* same response across the hash
  columns glmmTMB uses) — needed to judge whether `.collectDuplicates()`
  would pay off; not assessed here.
- **sdmTMB's third `MakeADFun` call sites** (`R/predict.R:769`,
  `R/tmb-sim.R:416,621`, `R/cross-val.R:457`, `R/caic.R:85,97`,
  `R/project.R:265`) were located by grep but not read in depth — they are
  prediction/simulation/cross-validation/CAIC helpers, not the core fitting
  path the brief asked about, so excluded by design rather than oversight.

---

## 5. Provenance

- **sdmTMB**: `git clone --depth 1 https://github.com/pbs-assess/sdmTMB.git`
  → commit `891d8e7f914759338ef91d078032ee85d2ed778b`, `DESCRIPTION` version
  `1.1.0.9000`. Not locally installed (`find.package("sdmTMB")` failed), so
  read entirely from this fresh clone. Files read: `R/fit.R` (main fitting
  logic, ~1990 lines), `R/utils.R` (`sdmTMBcontrol()` + docs, lines 1-190),
  `R/extra-optimization.R` (full file, 96 lines), `R/index.R` (lines
  400-560), `src/sdmTMB.cpp` (targeted reads: 108-750 sparse/GMRF region,
  1300-1360 RSR/`atomic::matinv` region), `vignettes/model-description.Rmd`
  (grepped for multiphase/Laplace/sparse/profile/normalize, lines
  184-424, 727, 782-837).
- **glmmTMB**: `git clone --depth 1 https://github.com/glmmTMB/glmmTMB.git`
  → commit `4391170fc30a1292529ec6797dcaeebe3676ed5c`, `DESCRIPTION` version
  `1.1.15` (repo layout: package proper lives at `glmmTMB/glmmTMB/` inside
  this monorepo checkout, alongside `docs/`, `misc/`, `notes/`). Also
  present locally installed (`/Users/z3437171/Library/R/arm64/4.6/library/glmmTMB`,
  binary-only, no plain-text `R/` source), used only to confirm the repo
  clone's version is current, not as a source-reading target. Files read:
  `R/glmmTMB.R` (lines 1564-1660, 1795-2040 — `glmmTMBControl()`,
  `fitTMB()`, `finalizeTMB()`), `R/utils.R` (lines 1055-1065,
  `get_autopar()`), `src/glmmTMB.cpp` (lines 357-500, `termwise_nll()`).
- **TMB** (dependency, primary source for `MakeADFun` argument semantics):
  locally installed version `1.9.21`
  (`/Users/z3437171/Library/R/arm64/4.6/library/TMB`). Read via
  `tools::Rd2txt(tools::Rd_db("TMB")[["MakeADFun.Rd"]])` — full argument
  list, "The argument 'intern'" section, inner-optimization/`inner.control`
  section.
- **gllvmTMB** (this repo, working directory
  `/Users/z3437171/Dropbox/Github Local/gllvmTMB`, used only to populate the
  "gllvmTMB today" column — not modified): `R/fit-multi.R` (lines
  4520-4600, main `MakeADFun` call + optimizer dispatch + multi-start),
  `R/init-warmstart.R` (lines 1-60), plus repo-wide greps for
  `inner.control`, `intern=`, `TMB::normalize`, `sdreport(`, `profile=`,
  `multiphase`/`no_spatial`/two-stage-equivalent, and the `se=` default in
  `R/gllvmTMB.R:1020`.
- **Prior scout's output** (context only, not re-verified):
  `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/50-GALAMM-REFERENCE-READ.md`.

No accuracy, robustness, or quality comparison between sdmTMB, glmmTMB, and
gllvmTMB was made or implied anywhere above — this is a technique inventory
only.
