## Design 108 recovery campaign: FITTING HARNESS.
##
## ============================================================================
## THE QUESTION (pre-registered before any cell was fit)
## ============================================================================
## Does the experimental VA-R3 engine recover the two-tier
##   Sigma_B = Lambda Lambda' + diag(psi)
## (ordinary species-iid tier + phylogenetic tier, BOTH latent(unique = TRUE))
## better than the shipped Laplace engine, on binomial-probit data, at
## realistic size?
##
## THE FALSIFIER: if VA's rel_frob(Sigma_hat, Sigma_true) is NOT reliably
## smaller than Laplace's, on the SAME simulated data, across the n-ladder,
## the headline hypothesis is false and must be reported as false. A result
## where VA and Laplace track each other closely is NOT evidence either is
## accurate -- see THE TRAP below. A result where VA is better only inside
## the toy regime and crosses over (or never clears Laplace) at realistic n
## also falsifies the "VA is better in practice" claim even if it holds in
## the toy regime.
##
## SECOND QUESTION (Design 106 section 3.6, untested prediction): does the
## AUGMENTED (sparse, tips + internal nodes) factorised ELBO sit further
## BELOW the reference marginal log-likelihood than the TIPS-ONLY (dense,
## tips-only) ELBO does, on the SAME data? This harness records the
## ingredients (elbo per VA arm, reference_loglik copied from the PAIRED
## Laplace fit of the same cell) so the gap = reference_loglik - bound_value
## can be computed per row downstream; it does not itself adjudicate the
## question. THE FALSIFIER for this question: the augmented gap is NOT
## reliably larger (more negative relative to the reference) than the
## tips-only gap, or the two are indistinguishable within run-to-run noise.
##
## ============================================================================
## THE TRAP (state it, obey it)
## ============================================================================
## "Agreement between two approximations is not accuracy." Both engines
## under-recovered planted Sigma_B on a toy seed during development of this
## harness (see the SMOKE report in the handoff). EVERY comparison in this
## campaign is against PLANTED TRUTH (`sim$truth$tier{1,2}$Sigma_B`), never
## one engine against the other. `rel_frob()` (from dgp.R) is always called
## with the truth as its second argument.
##
## ============================================================================
## THE SEVEN NON-NEGOTIABLES, and where each is encoded
## ============================================================================
##  1. Pre-registered hypothesis + falsifier: this header, above.
##  2. PAIRED DESIGN: run_cell() calls simulate_two_tier() EXACTLY ONCE per
##     cell and passes the SAME `sim` object to every arm (gaussian_control,
##     laplace, va_augmented, va_tips_only). Every row also carries `y_sum`/
##     `y_len`, a cheap fingerprint of the shared response vector, so pairing
##     can be checked mechanically downstream (identical fingerprint within a
##     cell => same data reached every arm).
##  3. GAUSSIAN POSITIVE CONTROL, gated: the "gaussian_control" arm fits the
##     SAME two-tier structure with a Gaussian response built from the SAME
##     realized eta (`sim$data$eta_true`) plus small iid noise -- a sanity
##     check on the whole pipeline (DGP + formula + extractor), not a test of
##     engine differences. `.d108_positive_control_gate()` below mirrors the
##     gate idiom in dev/design108-stage8/analyse-silent-divergence.R
##     ("if the control is not clean, no other number is interpretable");
##     the full campaign's own analysis script should call the equivalent of
##     it (or this function directly) before reading any other column.
##  4. NO POOLING: every row of every cell carries its own coordinates
##     (N, T, q, seed, phylo_scale, n_trials, arm) -- see `mkrow()` in
##     run_cell(). Analysis must always group_by() these before summarising.
##  5. N-LADDER AND q ARE GRID COLUMNS: run_cell() takes `cell$N` and `cell$q`
##     from the caller's grid row; neither is hard-coded here. (The grid
##     itself -- the full n-ladder x q x phylo_scale x seed factorial -- is
##     explicitly OUT OF SCOPE for this harness; it is "a later slice on a
##     remote server," per the brief.)
##  6. profile_variational = TRUE above N ~ 1500: `.d108_fit_va()`'s
##     `profile_variational` argument defaults to NULL, which resolves to
##     `N > 1500`; passing TRUE/FALSE explicitly overrides that rule (e.g. to
##     force it on for a benchmarking comparison at smaller N), but the
##     UNSET default always obeys the rule.
##  7. WILSON INTERVALS for rates compared against a prior number: this is an
##     ANALYSIS-time concern (a rate is a summary over many cells' rows, which
##     this per-cell harness does not compute). The mechanism to reuse is
##     already implemented in dev/design108-stage8/analyse-silent-divergence.R
##     (`wilson()`); the campaign's analysis script should call it on the
##     rbind()ed output of many run_cell() calls, exactly as stage8 does. Not
##     re-implemented here to avoid a second copy drifting from the original.
##
## ============================================================================
## THE SHARED-DLL FIX (read before touching the VA arms)
## ============================================================================
## gllvmTMB:::.va_r3_load_dll() (R/va-r3-proto.R ~line 889) computes its build
## directory as `file.path(tempdir(), paste0("gllvmTMB-va-r3-", md5(source)))`.
## `tempdir()` is a FRESH, randomly-named directory created once per R
## session/process. On a multi-worker run (mirai daemons, parallel::mclapply,
## or separate Rscript processes) every worker's `tempdir()` differs, so
## EVERY worker independently recompiles the ~2246-line TMB template (minutes
## each) the first time it calls `.va_r3_fit()` -- unaffordable at scale, and
## package source may not be modified to fix it at the source.
##
## The fix implemented here is entirely at the CALL SITE: compile the
## template ONCE (in whichever process runs first / the orchestrator), then
## before every worker's FIRST `.va_r3_fit()` call, pre-populate THAT
## worker's own tempdir()-keyed build directory with the already-compiled
## source + shared object, so `.va_r3_load_dll()`'s own
## `if (!file.exists(dll) || rebuild) { ...compile... }` check is FALSE and
## it just `dyn.load()`s the copy -- i.e. this imitates exactly what a warm
## cache would look like in that worker's own tempdir(), without editing
## `.va_r3_load_dll()` itself.
##   - `.d108_build_va_r3_dll_stash(source)`: call ONCE, in the orchestrator,
##     before dispatching any worker. Compiles via the package's own
##     `.va_r3_load_dll()` and returns a small list (paths + checksum) that
##     is cheap to serialize/broadcast to workers (e.g. as a `mirai_map()`
##     closure capture, or via `daemons(..., .args = list(dll_stash = ...))`).
##   - `.d108_seed_va_r3_dll(dll_stash)`: call in EVERY worker, before its
##     first `.va_r3_fit()`/`.va_r3_load_dll()` call (both `.d108_fit_va()`
##     below do this automatically when given `dll_stash`).
## VERIFIED (see the handoff report) by running the seed step in a genuinely
## separate `Rscript` subprocess (its own `tempdir()`, no shared session
## state) and confirming (a) no `TMB::compile` output appears the second
## time, and (b) the compiled `.so`'s mtime is unchanged after the "warm"
## call.

suppressPackageStartupMessages({
  library(gllvmTMB)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

## Run from the package root, exactly like dgp-selfcheck.R (see its own
## header for the invocation). Source is relative to the working directory
## on purpose, matching the existing dev/design108-recovery convention.
source("dev/design108-recovery/dgp.R")

## ---------------------------------------------------------------- sources ---

## Resolve the VA-R3 TMB source ONCE, as an absolute path, so every call
## (stash-build, seed, and every arm's fit) agrees on the same file
## regardless of a worker's working directory.
.d108_va_source <- function() {
  gllvmTMB:::.va_r3_find_source()
}

## ---------------------------------------------------------- shared-DLL fix ---

## Compiles via the package's own `.va_r3_load_dll()` (into ITS caller's own
## `tempdir()`, as usual), then copies the result into a PERSISTENT cache
## directory outside any process's `tempdir()` -- so the stash stays valid
## for the whole campaign (workers may outlive, or start after, whatever
## process happened to build it) rather than only as long as the building
## process's own session tempdir survives.
.d108_build_va_r3_dll_stash <- function(source = NULL,
                                        cache_dir = file.path(
                                          Sys.getenv("HOME"), ".cache",
                                          "gllvmtmb-va-r3-dll")) {
  source <- source %||% .d108_va_source()
  dll <- gllvmTMB:::.va_r3_load_dll(source = source, rebuild = FALSE)
  build_dir <- dirname(dll$path)
  persist_dir <- file.path(cache_dir, dll$checksum)
  if (!dir.exists(persist_dir)) dir.create(persist_dir, recursive = TRUE)
  src_dst <- file.path(persist_dir, "gllvmTMB_va_r3.cpp")
  dll_dst <- file.path(persist_dir, basename(dll$path))
  if (!file.exists(dll_dst)) {
    file.copy(file.path(build_dir, "gllvmTMB_va_r3.cpp"), src_dst, overwrite = TRUE)
    file.copy(dll$path, dll_dst, overwrite = TRUE)
  }
  list(checksum = dll$checksum, source_file = src_dst, dll_file = dll_dst)
}

.d108_seed_va_r3_dll <- function(dll_stash) {
  build_dir <- file.path(tempdir(), paste0("gllvmTMB-va-r3-", dll_stash$checksum))
  dll_dst <- file.path(build_dir, basename(dll_stash$dll_file))
  if (file.exists(dll_dst)) return(invisible(dll_dst))  # already warm
  if (!dir.exists(build_dir)) dir.create(build_dir, recursive = TRUE)
  file.copy(dll_stash$source_file, file.path(build_dir, "gllvmTMB_va_r3.cpp"),
            overwrite = TRUE)
  file.copy(dll_stash$dll_file, dll_dst, overwrite = TRUE)
  invisible(dll_dst)
}

## --------------------------------------------------- VA tier reconstruction --

## `report`'s `Lambda`/`Sigma_B` only cover tier[0] (Design 108 Stage 6+7: the
## TMB template REPORT()s the pre-Stage-6 names for back-compat, tier 0 only).
## To recover the OTHER tiers (the phylo dense loadings, and BOTH tiers' psi
## companions) this mirrors the cpp reconstruction (Lambda_tier[]/sd_tier,
## inst/tmb/gllvmTMB_va_r3.cpp ~line 584-614) using the same `theta_rr`/
## `log_sd_tier` flat parameter vectors and the tier_layout offsets that
## `.va_r3_validate_data()` computed for this exact call. Verified against
## `report$Lambda`/`report$Sigma_B` (tier 1) matching this function's
## reconstruction for tier 1 in the harness's own smoke test.
.d108_va_tier_sigma <- function(par, layout, tier_idx_dense, tier_idx_diag, T) {
  if (is.null(par) || is.null(names(par))) return(NULL)
  nm <- names(par)
  stopifnot(identical(layout$kind[tier_idx_dense], "dense"),
            identical(layout$kind[tier_idx_diag], "diagonal"))

  theta_full <- par[nm == "theta_rr"]
  d <- layout$dim[tier_idx_dense]
  len <- gllvmTMB:::.va_r3_theta_length(T, d)
  off <- layout$theta_offset[tier_idx_dense]
  if (length(theta_full) < off + len) return(NULL)
  Lambda <- gllvmTMB:::.va_r3_unpack_theta_rr(theta_full[(off + 1L):(off + len)], T, d)

  logsd_full <- par[nm == "log_sd_tier"]
  off_sd <- layout$sd_offset[tier_idx_diag]
  if (length(logsd_full) < off_sd + T) return(NULL)
  psi <- exp(logsd_full[(off_sd + 1L):(off_sd + T)])^2

  list(Lambda = Lambda, psi = psi, Sigma_B = Lambda %*% t(Lambda) + diag(psi, T))
}

## Build the phylo tier pair (dense loadings + diagonal psi companion) for
## one route. "augmented": the sparse n_aug x n_aug structured precision from
## `.va_r3_phylo_structure()` (tips + internal nodes, O(1) inner-solve entries
## per coordinate). "tips_only": the DENSE N x N tip correlation matrix
## inverted directly (Design 108 Stage 7 test
## "tips-only is admitted too -- and it is the route that densifies") -- an
## O(N^2) inner solve, expected to become unaffordable at large N; that is a
## REPORTABLE result, not a bug, so callers must catch failures here rather
## than let them abort the cell (see `.d108_fit_va()`).
.d108_va_phylo_tiers <- function(route, tree, sp, unit, T, q) {
  route <- match.arg(route, c("augmented", "tips_only"))
  if (identical(route, "augmented")) {
    st <- gllvmTMB:::.va_r3_phylo_structure(tree, sp)
    structured <- st$structured
    lid_dense <- st$node_of_species[unit]   # 0-based, into Ainv's n_aug rows
  } else {
    N <- length(sp)
    A <- ape::vcv(tree, corr = TRUE)[sp, sp] + diag(1e-8, N)
    structured <- list(Ainv = solve(A),
                       log_det_A = as.numeric(determinant(A, logarithm = TRUE)$modulus))
    lid_dense <- unit - 1L                  # 0-based tip index directly
  }
  ## FIXED 2026-08-02 (Noether's confound diagnostic): the phylo_psi tier
  ## MUST be structured=TRUE over the SAME node index as the phylo dense
  ## tier (`lid_dense`), not an unstructured N-level tier over `unit - 1L`.
  ## Before this fix, this tier's declaration (kind="diagonal", dim=T,
  ## n_levels=N, level_id=unit-1L, structured=FALSE) was BYTE-IDENTICAL to
  ## the ordinary-tier's own automatic Psi companion (tier 2, built inside
  ## `.va_r3_build_tiers()`'s `want_psi` branch) -- same kind/dim/n_levels/
  ## level_id/structured. The objective could not tell the two apart, so
  ## psi mass split between "ordinary psi" and "phylo psi" was determined by
  ## the OPTIMIZER'S STARTING VALUES, not the data (measured: mirrored
  ## starts both reached the same objective with tier-4 shares of 0.00% and
  ## 100.00%; the harness's own default `n_starts = 4` gave 52.74% on one
  ## call and 0.00% on another, same objective to 7 s.f. -- an interior
  ## stall on a flat ridge, invisible to both the multi-start `agreement`
  ## gate and to `v_by_obs`, which only ever sums across tiers). With
  ## `structured = TRUE` and `level_id = lid_dense`, this tier's `n_levels`
  ## becomes `nrow(structured$Ainv)` (n_aug for "augmented", N for
  ## "tips_only") -- generically DIFFERENT from the ordinary Psi tier's `N`
  ## for the augmented route (n_aug = 2N-2 != N for N > 2), so the two
  ## tiers' parameter blocks are different lengths and the swap that caused
  ## the confound can no longer even be FORMED. This is also now the
  ## correct match to what `phylo_latent(unique = TRUE)`'s shipped Laplace
  ## engine puts on the diagonal companion: `Psi_phy (x) A`, phylogenetically
  ## structured, not iid per species (src/gllvmTMB.cpp:1181-1208).
  extra_tiers <- list(
    list(kind = "dense", dim = as.integer(q), level_id = as.integer(lid_dense),
         structured = TRUE, label = "phylo"),
    list(kind = "diagonal", dim = as.integer(T), level_id = as.integer(lid_dense),
         structured = TRUE, label = "phylo_psi")
  )
  list(structured = structured, extra_tiers = extra_tiers)
}

## ------------------------------------------------------------- fit: VA-R3 ---

## Fits ONE arm (route = "augmented" or "tips_only") of the VA-R3 engine on
## `sim` (a `simulate_two_tier()` return). `time_budget_s` is a BEST-EFFORT
## wall-clock cutoff via `base::setTimeLimit()` -- R checks the limit at
## bytecode interrupt points, which are hit between nlminb/optim iterations
## and between the (up to 4) multi-starts in `.va_r3_fit()`'s health-gate
## loop, but NOT necessarily inside a single very long C-level linear-algebra
## call. This is the right tool available without adding a dependency; it is
## not a hard guarantee. On a hit (or any other error) the arm is marked
## status = "ERROR" and the cell continues -- an unaffordable tips-only cell
## is a REPORTABLE result, never a crashed run.
.d108_fit_va <- function(sim, q, route, source, dll_stash = NULL,
                         profile_variational = NULL, n_starts = 4L, H = 15L,
                         time_budget_s = Inf) {
  if (!is.null(dll_stash)) .d108_seed_va_r3_dll(dll_stash)

  dat <- sim$data
  unit <- dat$unit; trait <- dat$trait
  T <- sim$T; N <- sim$N
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  sp <- sim$species_levels
  phy <- .d108_va_phylo_tiers(route, sim$tree, sp, unit, T, q)

  ## Non-negotiable 6: profile_variational = TRUE above N ~ 1500, unless the
  ## caller explicitly names it (then their value wins either way).
  use_profile <- if (is.null(profile_variational)) N > 1500 else isTRUE(profile_variational)

  t0 <- proc.time()[["elapsed"]]
  gc(reset = TRUE)
  setTimeLimit(elapsed = time_budget_s, transient = TRUE)
  fit <- tryCatch(
    withCallingHandlers(
      gllvmTMB:::.va_r3_fit(
        y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
        q = q, family = "binomial_probit", link = "probit", unique = TRUE,
        structured = phy$structured, extra_tiers = phy$extra_tiers,
        source = source, H = H, n_starts = n_starts,
        profile_variational = use_profile
      ),
      warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "va_cell_error")
  )
  setTimeLimit(elapsed = Inf, transient = TRUE)
  secs <- proc.time()[["elapsed"]] - t0
  peak_mb <- .d108_peak_rss_mb()

  if (inherits(fit, "va_cell_error")) {
    return(list(status = "ERROR", note = fit$msg, elapsed_s = secs, peak_rss_mb = peak_mb,
                elbo = NA_real_, admitted = NA, Sigma1 = NULL, Sigma2 = NULL))
  }
  if (identical(fit$status, "not_applicable_rank_zero")) {
    return(list(status = fit$status, note = fit$reason, elapsed_s = secs,
                peak_rss_mb = peak_mb, elbo = NA_real_, admitted = NA,
                Sigma1 = NULL, Sigma2 = NULL))
  }

  layout <- tryCatch({
    v <- gllvmTMB:::.va_r3_validate_data(
      y = dat$y, n_trials = dat$n_trials, X = X, unit_id = unit, trait_id = trait,
      q = q, family = "binomial_probit", link = "probit", unique = TRUE,
      structured = phy$structured, extra_tiers = phy$extra_tiers)
    v$tier_layout
  }, error = function(e) NULL)

  par <- fit$best$par
  s1 <- tryCatch(.d108_va_tier_sigma(par, layout, 1L, 2L, T), error = function(e) NULL)
  s2 <- tryCatch(.d108_va_tier_sigma(par, layout, 3L, 4L, T), error = function(e) NULL)

  list(status = fit$status, note = "", elapsed_s = secs, peak_rss_mb = peak_mb,
       elbo = if (is.list(fit$report)) fit$report$elbo %||% NA_real_ else NA_real_,
       admitted = isTRUE(fit$health$admitted),
       Sigma1 = s1$Sigma_B, Sigma2 = s2$Sigma_B)
}

## ------------------------------------------------------- fit: Laplace/glm ---

## `env` MUST be the caller's own evaluation frame (pass `environment()`): the
## formula token `tree = tree` is resolved later, when gllvmTMB() evaluates
## the formula, by looking up `tree` in the formula's environment -- which
## defaults to wherever as.formula() happens to be CALLED, i.e. this
## function's own (short-lived, tree-less) frame, not the caller's. Without
## this, the fit fails with "phylo_vcv (or phylo_tree) is NULL" even though
## `tree` is clearly in scope one frame up -- caught empirically while
## building this harness.
.d108_two_tier_formula <- function(q, env) {
  fml <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | species, d = %d, unique = TRUE) + phylo_latent(0 + trait | species, d = %d, tree = tree, unique = TRUE)",
    q, q))
  environment(fml) <- env
  fml
}

## Reads .Mb of gc()'s "max used" column by NAME rather than a hard-coded
## index -- R 4.x added a "limit (Mb)" column between "gc trigger (Mb)" and
## "max used", shifting the Mb value one column to the right of where it sat
## in older R (caught empirically: naive `gc()[, 6]` silently read the wrong,
## huge, non-Mb "max used" cell count instead).
.d108_peak_rss_mb <- function() {
  g <- tryCatch(gc(), error = function(e) NULL)
  if (is.null(g)) return(NA_real_)
  idx <- which(colnames(g) == "max used")
  if (!length(idx)) return(NA_real_)
  sum(g[, idx + 1L])
}

## Shipped Laplace engine, two-tier binomial-probit, both tiers
## `unique = TRUE`. `link_residual = "none"` in the extract_Sigma() calls
## below is a deliberate choice: extract_Sigma()'s default ("auto") adds a
## theoretical link-scale residual variance (1 for probit) to the diagonal,
## which has no counterpart in `sim$truth$tier*$Sigma_B` (built purely from
## the DGP's own Lambda/psi) -- including it would inflate rel_frob for a
## reason that has nothing to do with recovery quality. `weights = n_trials`
## is REQUIRED for n_trials > 1 (see the multi-trial design note in run_cell()
## below): passing n_trials = 1 (pure Bernoulli) silently triggers the
## shipped engine's family-specific identifiability gate, which DROPS the
## between-unit Psi term entirely for single-trial binomial traits -- caught
## empirically while building this harness (message: "Skipping the default
## between-unit Psi for ... binary / categorical-contrast traits"). That
## would make the Laplace arm's tier target a DIFFERENT (Psi-free) quantity
## than `sim$truth$tier*$Sigma_B`, breaking the apples-to-apples comparison.
.d108_fit_laplace <- function(sim, q) {
  dat <- sim$data
  dat$trait <- factor(dat$trait)
  dat$species <- factor(dat$species, levels = sim$tree$tip.label)
  tree <- sim$tree
  fml <- .d108_two_tier_formula(q, environment())

  t0 <- proc.time()[["elapsed"]]
  gc(reset = TRUE)
  fit <- tryCatch(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(fml, data = dat, unit = "species", trait = "trait",
                          family = stats::binomial(link = "probit"),
                          weights = dat$n_trials,
                          control = gllvmTMB::gllvmTMBcontrol()),
      warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "lap_cell_error"))
  secs <- proc.time()[["elapsed"]] - t0
  peak_mb <- .d108_peak_rss_mb()

  if (inherits(fit, "lap_cell_error")) {
    return(list(status = "ERROR", note = fit$msg, elapsed_s = secs, peak_rss_mb = peak_mb,
                loglik = NA_real_, convergence = NA_integer_, pdHess = NA,
                Sigma1 = NULL, Sigma2 = NULL))
  }
  conv <- tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_)
  pdh  <- tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA)
  ll   <- tryCatch(as.numeric(stats::logLik(fit)), error = function(e) NA_real_)
  S1 <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "unit", part = "total",
                                         link_residual = "none")$Sigma,
                error = function(e) NULL)
  S2 <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "phy", part = "total",
                                         link_residual = "none")$Sigma,
                error = function(e) NULL)
  list(status = "OK", note = "", elapsed_s = secs, peak_rss_mb = peak_mb,
       loglik = ll, convergence = conv, pdHess = pdh, Sigma1 = S1, Sigma2 = S2)
}

## Positive control (non-negotiable 3): SAME two-tier structure and the SAME
## realized eta (`sim$data$eta_true`, paired to this cell's draw), but a
## Gaussian response, fit via the shipped Laplace engine. This is a sanity
## check on the pipeline (DGP -> formula -> extractor), not a comparison
## between engines, so it always uses Laplace regardless of which arms are
## under test. It MUST recover cleanly; `.d108_positive_control_gate()`
## below checks that mechanically.
##
## DELIBERATELY LAPLACE-ONLY, not just for the reason above -- a symmetric
## VA-side gaussian control is NOT comparable without further work, and is
## NOT added here (flagged 2026-08-02, Noether's third comparability
## finding, "handle now rather than let it surface later"). The two
## engines parameterise Gaussian residual noise differently for this
## two-tier, no-explicit-residual-term formula: the shipped Laplace route
## auto-inserts a per-row OLRE (`indep(0 + trait | <row>)`) and auto-
## SUPPRESSES the explicit `sigma_eps` to near-zero (~1/1000 sd(y); message
## "Auto-suppressing `sigma_eps`: ... already absorbs the observation
## residual" -- observed on every gaussian_control fit in this harness),
## whereas `.va_r3_fit(family = "gaussian_anchor"/"gaussian", ...)` carries
## a FREE per-trait `log_sigma` (`estimate_gaussian_sd = TRUE` by default,
## R/va-r3-proto.R ~866, ~1826) with no auto-inserted row-level OLRE tier in
## this harness's declaration. A VA gaussian arm built by naively swapping
## `family` on the SAME tier declaration would therefore be fitting a
## DIFFERENT residual-noise model than the Laplace control, not a comparable
## one -- exactly the class of silent mismatch this campaign exists to
## catch. Until that is resolved (either add a matching per-row OLRE tier to
## the VA declaration and pin `log_sigma` near-zero via
## `estimate_gaussian_sd = FALSE`, or find and cite the equivalent
## identifiability argument on the VA side), no VA gaussian control is run,
## and none should be added without addressing this comment.
.d108_fit_gaussian_control <- function(sim, q, gauss_sd = 0.3, obs_seed) {
  dat <- sim$data
  set.seed(obs_seed)
  dat$y <- dat$eta_true + stats::rnorm(nrow(dat), 0, gauss_sd)
  dat$trait <- factor(dat$trait)
  dat$species <- factor(dat$species, levels = sim$tree$tip.label)
  tree <- sim$tree
  fml <- .d108_two_tier_formula(q, environment())

  t0 <- proc.time()[["elapsed"]]
  gc(reset = TRUE)
  fit <- tryCatch(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(fml, data = dat, unit = "species", trait = "trait",
                          family = stats::gaussian(),
                          control = gllvmTMB::gllvmTMBcontrol()),
      warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "gc_cell_error"))
  secs <- proc.time()[["elapsed"]] - t0
  peak_mb <- .d108_peak_rss_mb()

  if (inherits(fit, "gc_cell_error")) {
    return(list(status = "ERROR", note = fit$msg, elapsed_s = secs, peak_rss_mb = peak_mb,
                loglik = NA_real_, convergence = NA_integer_, pdHess = NA,
                Sigma1 = NULL, Sigma2 = NULL))
  }
  conv <- tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_)
  pdh  <- tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA)
  ll   <- tryCatch(as.numeric(stats::logLik(fit)), error = function(e) NA_real_)
  S1 <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "unit", part = "total",
                                         link_residual = "none")$Sigma,
                error = function(e) NULL)
  S2 <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "phy", part = "total",
                                         link_residual = "none")$Sigma,
                error = function(e) NULL)
  list(status = "OK", note = "", elapsed_s = secs, peak_rss_mb = peak_mb,
       loglik = ll, convergence = conv, pdHess = pdh, Sigma1 = S1, Sigma2 = S2)
}

## ------------------------------------------------------------- run_cell() ---

## Fits ONE CELL (one row of design coordinates) across all four arms and
## returns ONE ROW PER ARM (long format), all sharing the cell's coordinates
## plus a `y_sum`/`y_len` fingerprint of the shared response vector (proof of
## pairing -- non-negotiable 2).
##
## `cell` must supply N, T, q, seed, phylo_scale (all grid columns -- non-
## negotiable 5 for N and q specifically); `n_trials` is optional (default 6L,
## MULTI-trial by design -- see `.d108_fit_laplace()`'s doc comment on why
## n_trials = 1 breaks the Laplace-vs-truth comparison via the shipped
## engine's own identifiability gate). `source`/`dll_stash` thread the shared-
## DLL fix through to the VA arms; see the header. `tips_only_time_budget_s`
## is the best-effort cutoff for the arm expected to become unaffordable.
run_cell <- function(cell, source = NULL, dll_stash = NULL,
                     n_starts = 4L, H = 15L, profile_variational = NULL,
                     gauss_sd = 0.3, tips_only_time_budget_s = Inf) {
  N <- as.integer(cell$N); T <- as.integer(cell$T); q <- as.integer(cell$q)
  seed <- as.integer(cell$seed); phylo_scale <- as.numeric(cell$phylo_scale)
  n_trials <- as.integer(cell$n_trials %||% 6L)
  if (is.null(source)) source <- .d108_va_source()

  sim <- simulate_two_tier(N = N, T = T, q = q, seed = seed,
                           phylo_scale = phylo_scale, n_trials = n_trials)
  y_sum <- sum(sim$data$y); y_len <- nrow(sim$data)

  mkrow <- function(arm, status, note = "", elapsed_s = NA_real_, peak_rss_mb = NA_real_,
                    convergence0 = NA_integer_, pdHess = NA, bound_type = NA_character_,
                    bound_value = NA_real_, reference_loglik = NA_real_,
                    rel_frob_tier1 = NA_real_, rel_frob_tier2 = NA_real_,
                    bias_tier1 = NA_real_, bias_tier2 = NA_real_) {
    data.frame(N = N, T = T, q = q, seed = seed, phylo_scale = phylo_scale,
               n_trials = n_trials, arm = arm, status = status, note = note,
               elapsed_s = elapsed_s, peak_rss_mb = peak_rss_mb,
               convergence = as.integer(convergence0), pdHess = as.logical(pdHess),
               bound_type = bound_type, bound_value = bound_value,
               reference_loglik = reference_loglik,
               rel_frob_tier1 = rel_frob_tier1, rel_frob_tier2 = rel_frob_tier2,
               bias_tier1 = bias_tier1, bias_tier2 = bias_tier2,
               y_sum = y_sum, y_len = y_len, stringsAsFactors = FALSE)
  }
  score <- function(Sigma_hat, Sigma_true) {
    if (is.null(Sigma_hat)) return(list(rf = NA_real_, bias = NA_real_))
    list(rf = rel_frob(Sigma_hat, Sigma_true), bias = mean(Sigma_hat - Sigma_true))
  }

  rows <- vector("list", 4L)

  ## --- positive control (non-negotiable 3) ---
  gcf <- .d108_fit_gaussian_control(sim, q, gauss_sd = gauss_sd, obs_seed = seed + 900000L)
  gc1 <- score(gcf$Sigma1, sim$truth$tier1$Sigma_B)
  gc2 <- score(gcf$Sigma2, sim$truth$tier2$Sigma_B)
  rows[[1]] <- mkrow("gaussian_control", gcf$status, gcf$note, gcf$elapsed_s, gcf$peak_rss_mb,
                     gcf$convergence, gcf$pdHess, "marginal_loglik", gcf$loglik, NA_real_,
                     gc1$rf, gc2$rf, gc1$bias, gc2$bias)

  ## --- shipped Laplace engine (also the reference bound for question 2) ---
  lap <- .d108_fit_laplace(sim, q)
  l1 <- score(lap$Sigma1, sim$truth$tier1$Sigma_B)
  l2 <- score(lap$Sigma2, sim$truth$tier2$Sigma_B)
  rows[[2]] <- mkrow("laplace", lap$status, lap$note, lap$elapsed_s, lap$peak_rss_mb,
                     lap$convergence, lap$pdHess, "marginal_loglik", lap$loglik, lap$loglik,
                     l1$rf, l2$rf, l1$bias, l2$bias)

  ## --- VA augmented (sparse, structured phylo tier) ---
  va_aug <- tryCatch(
    .d108_fit_va(sim, q, route = "augmented", source = source, dll_stash = dll_stash,
                profile_variational = profile_variational, n_starts = n_starts, H = H),
    error = function(e) list(status = "ERROR", note = conditionMessage(e), elapsed_s = NA_real_,
                             peak_rss_mb = NA_real_, elbo = NA_real_, admitted = NA,
                             Sigma1 = NULL, Sigma2 = NULL))
  a1 <- score(va_aug$Sigma1, sim$truth$tier1$Sigma_B)
  a2 <- score(va_aug$Sigma2, sim$truth$tier2$Sigma_B)
  rows[[3]] <- mkrow("va_augmented", va_aug$status, va_aug$note, va_aug$elapsed_s,
                     va_aug$peak_rss_mb, ifelse(isTRUE(va_aug$admitted), 0L, 1L), NA,
                     "elbo", va_aug$elbo, lap$loglik, a1$rf, a2$rf, a1$bias, a2$bias)

  ## --- VA tips-only (dense, O(N^2) inner solve; expected to become
  ## unaffordable high on the n-ladder -- caught, not fatal) ---
  va_tip <- tryCatch(
    .d108_fit_va(sim, q, route = "tips_only", source = source, dll_stash = dll_stash,
                profile_variational = profile_variational, n_starts = n_starts, H = H,
                time_budget_s = tips_only_time_budget_s),
    error = function(e) list(status = "ERROR", note = conditionMessage(e), elapsed_s = NA_real_,
                             peak_rss_mb = NA_real_, elbo = NA_real_, admitted = NA,
                             Sigma1 = NULL, Sigma2 = NULL))
  t1 <- score(va_tip$Sigma1, sim$truth$tier1$Sigma_B)
  t2 <- score(va_tip$Sigma2, sim$truth$tier2$Sigma_B)
  rows[[4]] <- mkrow("va_tips_only", va_tip$status, va_tip$note, va_tip$elapsed_s,
                     va_tip$peak_rss_mb, ifelse(isTRUE(va_tip$admitted), 0L, 1L), NA,
                     "elbo", va_tip$elbo, lap$loglik, t1$rf, t2$rf, t1$bias, t2$bias)

  do.call(rbind, rows)
}

## ------------------------------------------------------------ analysis hook -

## Convenience gate check mirroring
## dev/design108-stage8/analyse-silent-divergence.R's positive-control gate
## ("gaussian_control silent-divergence rate ... WARNING: the positive
## control is diverging. A null result elsewhere is NOT interpretable until
## this is explained."). Call on the rbind()ed output of many run_cell()
## calls before reading any other column.
.d108_positive_control_gate <- function(results, rel_frob_gate = 0.5) {
  gc_rows <- results[results$arm == "gaussian_control", ]
  gc_ok <- gc_rows[gc_rows$status == "OK" & !is.na(gc_rows$rel_frob_tier1) &
                     !is.na(gc_rows$rel_frob_tier2) &
                     gc_rows$rel_frob_tier1 <= rel_frob_gate &
                     gc_rows$rel_frob_tier2 <= rel_frob_gate, ]
  n_checked <- nrow(gc_rows)
  n_pass <- nrow(gc_ok)
  list(pass = n_checked > 0L && n_pass == n_checked,
       n_checked = n_checked, n_pass = n_pass,
       failed_rows = gc_rows[!(rownames(gc_rows) %in% rownames(gc_ok)), ])
}
