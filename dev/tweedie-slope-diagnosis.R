#!/usr/bin/env Rscript
## =============================================================================
## dev/tweedie-slope-diagnosis.R
##
## Slice B1 (Design-80 gap closure): diagnose the tweedie random-SLOPE-SD
## ~44% OVER-estimate. AUTHOR-ONLY script -- it is NOT run here; the orchestrator
## runs it later, locally or on Totoro (<=100 cores, D-50: results stay LOCAL,
## never GitHub artifacts).
##
## ---------------------------------------------------------------------------
## WHAT WE KNOW (verified, cited)
## ---------------------------------------------------------------------------
##  * tweedie random slopes over-estimate the slope SD (`sd_b`) by ~44%.
##    Source: docs/dev-log/after-task/2026-07-12-re-surface-arc-start.md:86-94
##    ("a bare gate-removal fit converges but over-estimates the slope SDs by
##     ~44% (the sigma_u^2 <-> p <-> phi ridge)").
##  * The p<->phi<->sigma ridge is RULED OUT as the sole cause: the bias is
##    identical with p fixed. Source: tests/testthat/test-tweedie-fixed-p.R:6-10.
##  * The slope-variance construction Sigma_b = L L^T, sd_b(j)=sqrt(Sigma_b(j,j))
##    is BYTE-SHARED with Gaussian slope cells that DO recover, so this is almost
##    certainly Laplace-approximation error on the skewed compound-Poisson-Gamma
##    marginal (a Design-80 "Bar-3" property), with small-cluster as a secondary
##    confound. Construction: src/gllvmTMB.cpp:1239-1246 (dep path, sd_b length C)
##    and src/gllvmTMB.cpp:1280-1282 (indep path, sd_b = exp(log_sd_b)).
##  * The p-fix escape hatch already exists: tweedie(p = 1.6) pins the power via
##    tmb_map$logit_p_tweedie = qlogis(p - 1). Source: R/families.R:438-460,
##    R/fit-multi.R:4090-4111.
##
## ---------------------------------------------------------------------------
## SYMBOLIC ALIGNMENT (the DGP truth must match what `sd_b` reports, term-by-term)
## ---------------------------------------------------------------------------
## DGP (mirrors tests/testthat/test-family-slope-recovery.R make_family_slope_mu,
## the EXACT cell where the 44% was observed -- a phylo random slope):
##   For trait t and species i:
##     b_int[i,t]   = sqrt(s2_int[t])   * (L_A %*% z_int)[i]
##     b_slope[i,t] = sqrt(s2_slope[t]) * (L_A %*% z_slope)[i]     z ~ N(0, I)
##     eta_it       = beta0 + b_int[i,t] + x_it * b_slope[i,t]
##     y_it         ~ Tweedie(mu = exp(eta_it), phi, p)
##   where A = ape::vcv(tree, corr = TRUE), L_A = t(chol(A)), so diag(A) = 1.
##   Hence marginal Var(b_slope[,t]) = s2_slope[t] * A, and because diag(A)=1 the
##   per-species slope SD is exactly sqrt(s2_slope[t]).  TRUTH for trait t slope
##   SD = sqrt(s2_slope[t]).
##
## ENGINE report:  fit$report$sd_b is length 2T, INTERLEAVED per trait as
##   (int_1, slope_1, int_2, slope_2, ...).  Odd entries = intercept SDs, EVEN
##   entries = slope SDs.  Verified: test-family-slope-recovery.R:55-60
##   (`sd_b[c(2,4,6)]` are the slopes; `expect_length(sd_b, 6L)  # 2T`) and
##   test-dep-uncorrelated-slope-gaussian.R:57-61 (`odd = intercept, even = slope`).
##   The engine's Sigma_b factors the A-structure out (A enters separately through
##   Ainv_phy), so sd_b(slope_t) estimates sqrt(s2_slope[t]) TERM-FOR-TERM.
##
##   TERM-FOR-TERM MAP:   truth sqrt(s2_slope[t])   <->   estimate sd_b[2*t]
##   Metric per cell:     rel_bias = (mean(sd_b_slope) - mean(sqrt(s2_slope)))
##                                   / mean(sqrt(s2_slope))
##   The ~44% over-estimate is rel_bias ~ +0.44.
##
## ---------------------------------------------------------------------------
## ENGINE DETAILS I HAD TO PIN (flagged UNVERIFIED where I could not confirm)
## ---------------------------------------------------------------------------
##  [PINNED, verified] sd_b indexing: length 2T interleaved, EVEN entries are the
##    slope SDs (test-family-slope-recovery.R:55-60). The task also cited the dep
##    closed-form path (cpp:1210-1272) whose sd_b is length C=n_lhs_cols; that
##    path is the SINGLE-TRAIT phylo_unique cell (sd_b length 2 = int,slope, slope
##    = sd_b[2]; see test-matrix-slope-beta.R:13-14). Both conventions are handled
##    below by `slope_sd_from_fit()`.
##  [PINNED, verified] fixed-p fit: family = tweedie(p = p_true) pins logit_p per
##    trait (R/fit-multi.R:4105-4110). No other map needed.
##  [PINNED, verified] REML is Gaussian-only and stops loudly for non-Gaussian
##    (R/gllvmTMB.R:176-177, 231, 463-464) -> arm 2 for tweedie is a documented
##    placeholder; the honest REML gap is computable only on a Gaussian control.
##  [UNVERIFIED] mode = "star" (i.i.d. control via a star phylogeny giving A = I)
##    rides the SAME verified phylo-slope engine path but has not been smoke-tested
##    here; the orchestrator should run ONE star cell first (see run notes).
##  [UNVERIFIED] the exact numeric value of max|gradient| field name across
##    versions; we read fit$opt$convergence (always present) and, if present,
##    fit's health/gradient fields defensively.
##
## ---------------------------------------------------------------------------
## ARMS
## ---------------------------------------------------------------------------
##  Arm 1 -- n-ladder at FIXED p. Vary cluster count (n_groups) x cluster size
##           (obs/group). Fit with tweedie(p = p_true). Record slope-SD rel_bias.
##           Question: does the 44% SHRINK as obs/group grows (-> small-sample /
##           Laplace decays, Bar-2 limitation) or PERSIST (-> intrinsic Laplace
##           bias, Bar-3, needs AGHQ to admit)?
##  Arm 2 -- ML - REML gap (Design-80 cheap Bar-3 warning signal). REML is
##           Gaussian-only today, so for TWEEDIE this arm is an honest placeholder;
##           it computes the gap on a matched GAUSSIAN control as the reference
##           calibration signal and records the tweedie limitation explicitly.
##  Arm 3 -- AGHQ / GHQ spot-check on ONE scalar-RE tweedie cell. A self-contained
##           1D Gauss-Hermite-vs-Laplace profiled fit (tweedie::dtweedie only, no
##           engine) isolates Laplace bias on the tweedie scalar-RE marginal, PLUS
##           a precise stub for the authoritative aghq-around-MakeADFun route.
##
## Reference #388: validate BEFORE advertising. Decision rule at the bottom.
##
## RUN NOTES (orchestrator):
##   Sys.setenv(GLLVMTMB_HEAVY_TESTS = "1", NOT_CRAN = "true")
##   Rscript dev/tweedie-slope-diagnosis.R --arm 1        # n-ladder (heavy, resumable)
##   Rscript dev/tweedie-slope-diagnosis.R --arm 2        # ML-REML gap (Gaussian control)
##   Rscript dev/tweedie-slope-diagnosis.R --arm 3        # 1D GHQ-vs-Laplace scalar-RE
##   Rscript dev/tweedie-slope-diagnosis.R --reduce       # tabulate bias x n + MCSE + verdict
##   Env overrides: TWEEDIE_DIAG_OUT (results dir), TWEEDIE_DIAG_SEEDS (e.g. "1:20"),
##                  TWEEDIE_DIAG_MODE ("phylo" default | "star" i.i.d. control).
##   SMOKE FIRST: run a single small cell (n_groups=50, obs=small, one seed) to
##   confirm convergence and the sd_b length before launching the full ladder;
##   and if using mode="star", smoke ONE star cell (UNVERIFIED path).
## =============================================================================

suppressWarnings(suppressMessages({
  ## gllvmTMB is required for arms 1-2; tweedie/mgcv for the DGP + arm 3.
  have_gllvmTMB <- requireNamespace("gllvmTMB", quietly = TRUE)
}))

## Heavy fits: satisfy any internal test-gating that keys on these env vars.
if (!nzchar(Sys.getenv("GLLVMTMB_HEAVY_TESTS"))) Sys.setenv(GLLVMTMB_HEAVY_TESTS = "1")
if (!nzchar(Sys.getenv("NOT_CRAN")))             Sys.setenv(NOT_CRAN = "true")

## -----------------------------------------------------------------------------
## CONFIG (env-overridable; edit here for a different sweep)
## -----------------------------------------------------------------------------
cfg <- local({
  out_dir <- Sys.getenv("TWEEDIE_DIAG_OUT", unset = "dev/tweedie-slope-diagnosis-results")
  seeds_s <- Sys.getenv("TWEEDIE_DIAG_SEEDS", unset = "1:20")
  seeds   <- eval(parse(text = seeds_s))
  mode    <- Sys.getenv("TWEEDIE_DIAG_MODE", unset = "phylo")  # "phylo" | "star"
  list(
    out_dir      = out_dir,
    seeds        = as.integer(seeds),
    mode         = mode,
    ## n-ladder axes. n_groups = number of clusters (species); obs_per_group =
    ## replicate observations per cluster (the axis that drives per-cluster
    ## information, hence Laplace bias decay).
    n_groups     = c(50L, 150L, 400L),
    obs_per_grp  = c(small = 4L, large = 20L),
    ## Fixed generative constants (log-scale intercept, tweedie power/dispersion).
    beta0        = 0.5,
    p_true       = 1.5,       # mid compound-Poisson-Gamma regime (matches recovery tests)
    phi_true     = 1.0,
    ## Per-trait intercept and slope variances (T = 3), matched to
    ## make_family_slope_mu (test-family-slope-recovery.R:27).
    s2_int       = c(0.4, 0.6, 0.3),
    s2_slope     = c(0.3, 0.5, 0.2),
    ## decision-rule tolerance on |rel_bias| at the LARGEST cell.
    tol_bias     = 0.10
  )
})
cfg$n_traits <- length(cfg$s2_slope)

## -----------------------------------------------------------------------------
## Helpers
## -----------------------------------------------------------------------------

## Build the covariance-structure tree. "phylo" = coalescent (the observed-bias
## cell, tree structure a confound with n_groups). "star" = star phylogeny with
## unit branch lengths so vcv(corr=TRUE) = I -> a clean i.i.d. random-slope
## control that removes the phylogenetic confound while riding the SAME verified
## engine path.  [star path is UNVERIFIED -- smoke ONE cell first.]
.build_tree <- function(n_groups, mode, seed) {
  set.seed(seed)
  if (identical(mode, "star")) {
    tr <- ape::stree(n_groups, type = "star")
    tr$edge.length <- rep(1, nrow(tr$edge))     # unit lengths -> A = I under corr=TRUE
    tr$tip.label   <- paste0("g", seq_len(n_groups))
    tr
  } else {
    ape::rcoal(n_groups)
  }
}

## Simulate one tweedie random-slope data set aligned to the engine (see the
## SYMBOLIC ALIGNMENT block). Returns df, tree, and the slope-SD truth vector.
simulate_tweedie_slope <- function(seed, n_groups, obs_per_grp, cfg) {
  tree <- .build_tree(n_groups, cfg$mode, seed)
  set.seed(seed + 1e6)                            # draws independent of tree seed
  A  <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(A))
  sp <- rownames(A)
  Tn <- cfg$n_traits
  b_int <- b_slope <- matrix(0, n_groups, Tn)
  for (t in seq_len(Tn)) {
    b_int[, t]   <- sqrt(cfg$s2_int[t])   * (LA %*% stats::rnorm(n_groups))
    b_slope[, t] <- sqrt(cfg$s2_slope[t]) * (LA %*% stats::rnorm(n_groups))
  }
  rows <- vector("list", n_groups * obs_per_grp * Tn)
  k <- 0L
  for (i in seq_len(n_groups)) for (r in seq_len(obs_per_grp)) {
    x <- stats::rnorm(1)
    for (t in seq_len(Tn)) {
      eta <- cfg$beta0 + b_int[i, t] + x * b_slope[i, t]
      k <- k + 1L
      rows[[k]] <- data.frame(species = sp[i], trait = paste0("t", t),
                              x = x, mu = exp(eta), stringsAsFactors = FALSE)
    }
  }
  df <- do.call(rbind, rows)
  df$value   <- .rtweedie(df$mu, p = cfg$p_true, phi = cfg$phi_true)
  df$species <- factor(df$species, levels = sp)
  df$trait   <- factor(df$trait, levels = paste0("t", seq_len(Tn)))
  list(df = df, tree = tree, slope_sd_true = sqrt(cfg$s2_slope))
}

## Tweedie RNG: mgcv::rTweedie is the canonical DGP in the recovery/matrix tests
## (test-tweedie-recovery.R:28, test-matrix-tweedie.R:64); tweedie::rtweedie is
## the fallback (test-tweedie-fixed-p.R:26). Signatures differ -- wrap both.
.rtweedie <- function(mu, p, phi) {
  if (requireNamespace("mgcv", quietly = TRUE))
    return(mgcv::rTweedie(mu, p = p, phi = phi))
  if (requireNamespace("tweedie", quietly = TRUE))
    return(tweedie::rtweedie(length(mu), mu = mu, phi = phi, power = p))
  stop("Need one of {mgcv, tweedie} installed for the Tweedie DGP.")
}

## Extract the slope-SD vector from a fit, handling BOTH sd_b conventions:
##  * length 2T interleaved -> slopes are the EVEN entries (multi-trait indep/dep);
##  * length 2 (single-trait phylo_unique closed-form) -> slope is entry 2.
## Verified: test-family-slope-recovery.R:55-60; test-matrix-slope-beta.R:13-14.
slope_sd_from_fit <- function(fit, n_traits) {
  sd_b <- as.numeric(fit$report$sd_b)
  if (length(sd_b) == 2L * n_traits) return(sd_b[seq(2L, 2L * n_traits, by = 2L)])
  if (length(sd_b) == 2L)            return(sd_b[2L])
  ## Fallback: assume interleaved even-entry slopes for any even length.
  if (length(sd_b) %% 2L == 0L)      return(sd_b[seq(2L, length(sd_b), by = 2L)])
  stop(sprintf("Unexpected sd_b length %d for %d traits.", length(sd_b), n_traits))
}

## Fit ONE fixed-p tweedie phylo random-slope cell; return a compact record.
fit_arm1_cell <- function(seed, n_groups, obs_per_grp, cfg) {
  sim <- simulate_tweedie_slope(seed, n_groups, obs_per_grp, cfg)
  t0  <- Sys.time()
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(1 + x | species),
      data       = sim$df,
      phylo_tree = sim$tree,
      unit       = "species",
      family     = gllvmTMB::tweedie(p = cfg$p_true),   # <-- fixed-p hatch
      control    = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    error = function(e) structure(list(error = conditionMessage(e)), class = "arm1_error")
  )
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (inherits(fit, "arm1_error"))
    return(list(seed = seed, n_groups = n_groups, obs_per_grp = obs_per_grp,
                mode = cfg$mode, ok = FALSE, error = fit$error, secs = secs))
  slope_hat  <- tryCatch(slope_sd_from_fit(fit, cfg$n_traits), error = function(e) NA_real_)
  slope_true <- sim$slope_sd_true
  rel_bias   <- (mean(slope_hat) - mean(slope_true)) / mean(slope_true)
  list(
    seed = seed, n_groups = n_groups, obs_per_grp = obs_per_grp, mode = cfg$mode,
    ok = isTRUE(fit$opt$convergence == 0L),
    convergence = fit$opt$convergence,
    slope_sd_hat = slope_hat, slope_sd_true = slope_true,
    rel_bias = rel_bias,
    ## singular-fit / boundary flag (mirrors the fit_health near-zero sd guard).
    boundary = any(slope_hat < 1e-4, na.rm = TRUE),
    phi_hat = tryCatch(as.numeric(fit$report$phi_tweedie), error = function(e) NA_real_),
    p_hat   = tryCatch(as.numeric(fit$report$p_tweedie),   error = function(e) NA_real_),
    p_fixed = cfg$p_true, secs = secs
  )
}

.cell_path <- function(cfg, seed, n_groups, obs_per_grp) {
  file.path(cfg$out_dir,
            sprintf("arm1_%s_ng%d_np%d_p%s_seed%d.rds",
                    cfg$mode, n_groups, obs_per_grp,
                    sub("\\.", "", format(cfg$p_true)), seed))
}

## -----------------------------------------------------------------------------
## ARM 1 -- n-ladder at fixed p (resumable: skip cells whose RDS already exists)
## -----------------------------------------------------------------------------
run_arm1 <- function(cfg, force = FALSE) {
  if (!have_gllvmTMB) stop("gllvmTMB not installed; arm 1 requires the engine.")
  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  grid <- expand.grid(seed = cfg$seeds, n_groups = cfg$n_groups,
                      obs_per_grp = unname(cfg$obs_per_grp),
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  message(sprintf("[arm1] %d cells (mode=%s, p fixed at %s)",
                  nrow(grid), cfg$mode, cfg$p_true))
  for (r in seq_len(nrow(grid))) {
    g  <- grid[r, ]
    fp <- .cell_path(cfg, g$seed, g$n_groups, g$obs_per_grp)
    if (!force && file.exists(fp)) { message(sprintf("  skip %s", basename(fp))); next }
    message(sprintf("  fit  ng=%d obs=%d seed=%d ...", g$n_groups, g$obs_per_grp, g$seed))
    rec <- fit_arm1_cell(g$seed, g$n_groups, g$obs_per_grp, cfg)
    saveRDS(rec, fp)
    message(sprintf("       rel_bias=%.3f ok=%s (%.1fs)",
                    rec$rel_bias %||% NA, rec$ok %||% FALSE, rec$secs %||% NA))
  }
  invisible(TRUE)
}

## -----------------------------------------------------------------------------
## ARM 2 -- ML - REML gap (Design-80 cheap Bar-3 warning). Honest limitation:
## REML is Gaussian-only (R/gllvmTMB.R:176-177,463-464), so for TWEEDIE this is a
## PLACEHOLDER. We compute the gap on a MATCHED GAUSSIAN control (same design,
## Gaussian responses on the SAME latent eta) as the reference calibration signal,
## and record that the tweedie REML gap is not available today.
## -----------------------------------------------------------------------------
run_arm2 <- function(cfg) {
  if (!have_gllvmTMB) stop("gllvmTMB not installed; arm 2 requires the engine.")
  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  recs <- list()
  for (ng in cfg$n_groups) for (npg in unname(cfg$obs_per_grp)) {
    seed <- cfg$seeds[1]
    sim  <- simulate_tweedie_slope(seed, ng, npg, cfg)
    ## Gaussian control on the SAME eta (value_gauss = log(mu) + N(0, 0.3^2)),
    ## i.e. identity-link Gaussian slope recovery, where REML is available.
    d <- sim$df; d$value_gauss <- log(d$mu) + stats::rnorm(nrow(d), 0, 0.3)
    fit_ml <- .try_gauss_slope(d, sim$tree, REML = FALSE)
    fit_re <- .try_gauss_slope(d, sim$tree, REML = TRUE)
    sd_ml  <- .safe_slope(fit_ml, cfg$n_traits)
    sd_re  <- .safe_slope(fit_re, cfg$n_traits)
    recs[[length(recs) + 1L]] <- data.frame(
      n_groups = ng, obs_per_grp = npg,
      gauss_slope_ml   = mean(sd_ml),
      gauss_slope_reml = mean(sd_re),
      ml_reml_gap      = mean(sd_ml) - mean(sd_re),
      tweedie_reml     = NA_real_,  # UNAVAILABLE: REML Gaussian-only today
      note = "tweedie REML not implemented (E2); gap shown on Gaussian control only"
    )
  }
  out <- do.call(rbind, recs)
  saveRDS(out, file.path(cfg$out_dir, sprintf("arm2_mlreml_%s.rds", cfg$mode)))
  print(out); invisible(out)
}

.try_gauss_slope <- function(d, tree, REML) {
  tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value_gauss ~ 0 + trait + phylo_indep(1 + x | species),
    data = d, phylo_tree = tree, unit = "species",
    family = stats::gaussian(), REML = REML))),
    error = function(e) NULL)
}
.safe_slope <- function(fit, n_traits) {
  if (is.null(fit)) return(NA_real_)
  tryCatch(slope_sd_from_fit(fit, n_traits), error = function(e) NA_real_)
}

## -----------------------------------------------------------------------------
## ARM 3 -- scalar-RE tweedie: GHQ vs Laplace (self-contained, engine-free).
##
## Model:  for group g (i.i.d.), scalar random slope b_g ~ N(0, sigma^2);
##         y_{g,j} ~ Tweedie(mu = exp(beta0 + b_g * x_{g,j}), phi, p), j = 1..m.
## The single scalar RE per group is integrated per group. We profile the TOTAL
## marginal NLL over sigma TWO ways and compare the maximisers:
##   (i)  GHQ:     nq-node ADAPTIVE Gauss-Hermite over b_g (near-exact for small m)
##   (ii) Laplace: b_g inner mode + Hessian (what TMB does)
## sigma_hat_GHQ vs sigma_hat_Laplace isolates Laplace bias on the tweedie
## scalar-RE marginal WITHOUT the gllvmTMB engine. If sigma_hat_Laplace is biased
## UP relative to sigma_hat_GHQ, Laplace is confirmed as the ~44% mechanism.
##
## This is the CHEAP confirmatory check. The AUTHORITATIVE engine-level check is
## the aghq-around-MakeADFun stub below (precise TODO for the orchestrator).
## -----------------------------------------------------------------------------
run_arm3 <- function(cfg,
                     G = 200L, m = 6L, sigma_true = 0.6,
                     beta0 = 0.5, phi = 1.0, p = 1.5, nq = 32L, seed = 1L) {
  if (!requireNamespace("tweedie", quietly = TRUE))
    stop("arm 3 needs the `tweedie` package (dtweedie).")
  if (!requireNamespace("statmod", quietly = TRUE))
    stop("arm 3 needs `statmod` for gauss.quad (GHQ nodes).")
  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)

  set.seed(seed)
  ## simulate G groups
  b   <- stats::rnorm(G, 0, sigma_true)
  X   <- matrix(stats::rnorm(G * m), G, m)
  Y   <- matrix(NA_real_, G, m)
  for (g in seq_len(G))
    Y[g, ] <- .rtweedie(exp(beta0 + b[g] * X[g, ]), p = p, phi = phi)

  gh <- statmod::gauss.quad(nq, kind = "hermite")   # nodes z, weights w

  ## per-group conditional log-lik given b (fixed beta0, phi, p)
  grp_cll <- function(bg, g) sum(log(pmax(tweedie::dtweedie(
    Y[g, ], power = p, mu = exp(beta0 + bg * X[g, ]), phi = phi), .Machine$double.xmin)))

  ## group marginal via ADAPTIVE GHQ: expand around inner mode bhat with scale s.
  grp_ll_ghq <- function(sigma, g) {
    opt  <- stats::optimize(function(bg) -(grp_cll(bg, g) +
              stats::dnorm(bg, 0, sigma, log = TRUE)), c(-8 * sigma, 8 * sigma))
    bhat <- opt$minimum
    h    <- .neg_hess(function(bg) grp_cll(bg, g) +
              stats::dnorm(bg, 0, sigma, log = TRUE), bhat)
    s    <- 1 / sqrt(max(h, 1e-8))
    nodes <- bhat + sqrt(2) * s * gh$nodes
    lg <- vapply(seq_along(nodes), function(k) grp_cll(nodes[k], g) +
              stats::dnorm(nodes[k], 0, sigma, log = TRUE), numeric(1))
    ## adaptive-GHQ marginal (log): log sum_k w_k * exp(z_k^2) * s*sqrt(2) * exp(lg_k)
    a <- lg + gh$nodes^2 + log(gh$weights) + log(s * sqrt(2))
    matrixStats_logSumExp(a)
  }
  ## group marginal via LAPLACE around the same inner mode.
  grp_ll_lap <- function(sigma, g) {
    opt  <- stats::optimize(function(bg) -(grp_cll(bg, g) +
              stats::dnorm(bg, 0, sigma, log = TRUE)), c(-8 * sigma, 8 * sigma))
    bhat <- opt$minimum
    h    <- .neg_hess(function(bg) grp_cll(bg, g) +
              stats::dnorm(bg, 0, sigma, log = TRUE), bhat)
    (grp_cll(bhat, g) + stats::dnorm(bhat, 0, sigma, log = TRUE)) +
      0.5 * log(2 * pi) - 0.5 * log(max(h, 1e-8))
  }

  nll_total <- function(sigma, per_group) {
    if (sigma <= 0) return(1e10)
    -sum(vapply(seq_len(G), function(g) per_group(sigma, g), numeric(1)))
  }
  sig_ghq <- stats::optimize(nll_total, c(1e-3, 5), per_group = grp_ll_ghq)$minimum
  sig_lap <- stats::optimize(nll_total, c(1e-3, 5), per_group = grp_ll_lap)$minimum

  rec <- list(G = G, m = m, sigma_true = sigma_true, p = p, phi = phi, nq = nq,
              sigma_hat_ghq = sig_ghq, sigma_hat_laplace = sig_lap,
              rel_bias_ghq     = (sig_ghq - sigma_true) / sigma_true,
              rel_bias_laplace = (sig_lap - sigma_true) / sigma_true,
              laplace_minus_ghq = sig_lap - sig_ghq)
  saveRDS(rec, file.path(cfg$out_dir, sprintf("arm3_scalarRE_G%d_m%d_seed%d.rds", G, m, seed)))
  message(sprintf("[arm3] sigma_true=%.3f  GHQ=%.3f (bias %+.1f%%)  Laplace=%.3f (bias %+.1f%%)",
                  sigma_true, sig_ghq, 100 * rec$rel_bias_ghq,
                  sig_lap, 100 * rec$rel_bias_laplace))
  message("[arm3] Interpretation: if Laplace bias >> GHQ bias and GHQ ~ 0, the ",
          "tweedie slope over-estimate is a Laplace artefact (Bar-3) -> AGHQ admits it.")
  invisible(rec)
}

## Tiny 1D numerical negative-second-derivative (curvature) helper.
.neg_hess <- function(f, x, eps = 1e-4) {
  -(f(x + eps) - 2 * f(x) + f(x - eps)) / eps^2
}
## log-sum-exp without a hard dependency on matrixStats.
matrixStats_logSumExp <- function(a) {
  M <- max(a); M + log(sum(exp(a - M)))
}

## ---- ARM 3 (authoritative) -- aghq around MakeADFun: STUB + precise TODO ------
## TODO(orchestrator): the engine-exact check. Steps:
##   1. Fit ONE small scalar-RE tweedie cell with gllvmTMB(..., family=tweedie(p=p))
##      and pull the TMB object: obj <- fit$tmb_obj (a MakeADFun with random REs).
##   2. Re-`MakeADFun` (or reuse obj) with the SINGLE slope RE as the `random`
##      argument and ALL other parameters fixed at their fitted values via `map`,
##      so only the scalar RE is integrated.
##   3. aghq::aghq(ff = list(fn=obj$fn, gr=obj$gr, he=...), k = 25,
##                 startingvalue = obj$par[fixed]) to integrate that RE with
##      25 adaptive GH nodes; compare the implied marginal / sigma to the engine's
##      Laplace value (k = 1 equivalent).
##   4. If aghq's sigma < Laplace's sigma by ~the 44% seen in arm 1, the Laplace
##      hypothesis is CONFIRMED at the engine level -> Bar-3, AGHQ admission path.
## This stub is intentionally NOT executed; wiring aghq to the multivariate engine
## object needs a live-TMB (Codex) session. The self-contained run_arm3() above is
## the cheap stand-in that already discriminates the mechanism.
run_arm3_aghq_engine <- function(...) {
  stop("STUB: aghq-around-MakeADFun engine check -- see the TODO above. ",
       "Run run_arm3() (self-contained GHQ vs Laplace) for the cheap mechanism check.")
}

## -----------------------------------------------------------------------------
## REDUCER -- tabulate rel_bias x (n_groups, obs/group) with Monte-Carlo SE,
## then apply the decision rule.
## -----------------------------------------------------------------------------
reduce_arm1 <- function(cfg) {
  files <- list.files(cfg$out_dir,
                      pattern = sprintf("^arm1_%s_.*\\.rds$", cfg$mode), full.names = TRUE)
  if (!length(files)) { message("[reduce] no arm1 RDS in ", cfg$out_dir); return(invisible(NULL)) }
  recs <- lapply(files, readRDS)
  df <- do.call(rbind, lapply(recs, function(r) data.frame(
    n_groups = r$n_groups, obs_per_grp = r$obs_per_grp, seed = r$seed,
    ok = isTRUE(r$ok), rel_bias = r$rel_bias %||% NA_real_,
    boundary = isTRUE(r$boundary))))
  df <- df[df$ok & is.finite(df$rel_bias), , drop = FALSE]
  agg <- do.call(rbind, by(df, list(df$n_groups, df$obs_per_grp), function(s) {
    data.frame(n_groups = s$n_groups[1], obs_per_grp = s$obs_per_grp[1],
               n_seeds = nrow(s),
               mean_rel_bias = mean(s$rel_bias),
               mcse = stats::sd(s$rel_bias) / sqrt(nrow(s)))
  }))
  agg <- agg[order(agg$obs_per_grp, agg$n_groups), ]
  rownames(agg) <- NULL
  cat("\n=== Arm 1: slope-SD rel_bias by (n_groups x obs/group), mode =", cfg$mode, "===\n")
  print(agg, digits = 3)

  ## ---- DECISION RULE (Design 80 Bars 2 vs 3; #388 validate-before-advertise) --
  big <- agg[agg$n_groups == max(agg$n_groups) &
             agg$obs_per_grp == max(agg$obs_per_grp), ]
  cat("\n--- Decision ---\n")
  if (nrow(big) == 1L && is.finite(big$mean_rel_bias)) {
    decays <- abs(big$mean_rel_bias) < cfg$tol_bias
    ## does bias shrink as obs/group grows (at the largest n_groups)?
    at_bigN <- agg[agg$n_groups == max(agg$n_groups), ]
    trend <- if (nrow(at_bigN) >= 2)
      at_bigN$mean_rel_bias[which.max(at_bigN$obs_per_grp)] -
      at_bigN$mean_rel_bias[which.min(at_bigN$obs_per_grp)] else NA_real_
    if (decays) {
      cat(sprintf(
        "BAR-2 LIMITATION: |bias|=%.3f < tol=%.2f at the largest cell -> small-sample/\n",
        abs(big$mean_rel_bias), cfg$tol_bias))
      cat("  Laplace decay. Document as a known small-cluster limitation; tweedie slopes\n",
          " STAY gated with the p-fix hatch advertised. No Bar-3 claim needed.\n", sep = "")
    } else {
      cat(sprintf(
        "BIAS PERSISTS: |bias|=%.3f >= tol=%.2f at the largest cell (obs/group trend=%.3f).\n",
        abs(big$mean_rel_bias), cfg$tol_bias, trend))
      cat("  -> intrinsic Laplace bias suspected. ARM 3 (GHQ/AGHQ) decides admission:\n",
          "  if GHQ removes the bias, tweedie needs AGHQ to be admitted (Bar-3);\n",
          "  until then tweedie slopes remain GATED (validate before advertising, #388).\n", sep = "")
    }
  } else {
    cat("Largest cell missing or non-finite; run more seeds at max(n_groups) x max(obs).\n")
  }
  invisible(agg)
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

## -----------------------------------------------------------------------------
## CLI dispatch
## -----------------------------------------------------------------------------
if (identical(environment(), globalenv()) && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  arm  <- if (length(args) >= 2 && args[1] == "--arm") args[2] else NA
  if (!is.na(arm) && arm == "1")      run_arm1(cfg)
  else if (!is.na(arm) && arm == "2") run_arm2(cfg)
  else if (!is.na(arm) && arm == "3") run_arm3(cfg)
  else if (length(args) && args[1] == "--reduce") reduce_arm1(cfg)
  else {
    cat("Usage: Rscript dev/tweedie-slope-diagnosis.R [--arm 1|2|3 | --reduce]\n")
    cat("  Set env GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true for heavy fits.\n")
    cat("  Env: TWEEDIE_DIAG_OUT, TWEEDIE_DIAG_SEEDS (e.g. 1:20), TWEEDIE_DIAG_MODE (phylo|star).\n")
  }
}
