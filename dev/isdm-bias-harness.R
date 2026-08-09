## dev/isdm-bias-harness.R
##
## Phase C harness: does unmodelled, spatially structured, covariate-correlated
## presence-only recording bias get absorbed by the latent factors and
## re-reported as residual ecological correlation?
##
## Design contract: dev/isdm-phase-c-design.md (read that file first; this
## comment block is a pointer, not a restatement).
## Reuse map:       dev/isdm-phase-c-reuse-map.md
##
## This file SOURCES dev/isdm-gate-harness.R for two small reusable utilities
## (.rmse(), run_grid()'s dispatch *pattern*) but does NOT reuse its
## simulate_cell()/fit_cell()/score_fit()/run_one() -- those are the T=6,
## d=1, single-latent-factor mixed-curvature GATE study, a different DGM
## entirely (no PO/PA bias term). Per the reuse map's own recommendation,
## Phase C builds its own simulate/fit/score trio modelled on
## dev/isdm-plumbing.R::sim_isdm() instead of force-fitting that harness.
## Sourcing gate-harness.R is safe: it only defines constants/functions, no
## top-level executable stage code (unlike isdm-gate-campaign.R, which MUST
## NOT be sourced -- it runs the full 24,000-fit gate campaign at top level
## when its STAGES default to "all").
##
## Uses devtools::load_all() per the lane rule (see CLAUDE.md task header);
## the branch carries the unmerged #946 offset fix that installed 0.6.0
## does not have. Set NOT_CRAN=true before running any test that touches
## this file's functions through testthat.
##
## Lane rule: Lane C branch only. No PR, no merge, no main, no src/ changes.

suppressPackageStartupMessages({
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("Phase C requires devtools::load_all(); the installed package is not an allowed fallback.")
  }
  devtools::load_all(".", quiet = TRUE)
})

source("dev/isdm-gate-harness.R")  # for .rmse() only; see header note

## =========================================================================
## D7 -- planted truth, copied verbatim from the design doc
## =========================================================================

LAMBDA_D7 <- rbind(
  sp1 = c( 0.90,  0.00),
  sp2 = c( 0.70,  0.65),
  sp3 = c( 0.55, -0.60),
  sp4 = c(-0.45,  0.70),
  sp5 = c( 0.80,  0.20),
  sp6 = c(-0.65, -0.50),
  sp7 = c( 0.25,  0.75),
  sp8 = c( 0.60, -0.15)
)
PSI_D7   <- c(sp1 = 0.30, sp2 = 0.45, sp3 = 0.35, sp4 = 0.55, sp5 = 0.25, sp6 = 0.50, sp7 = 0.40, sp8 = 0.30)
BETA_D7  <- c(sp1 = 0.80, sp2 = 0.50, sp3 = -0.40, sp4 = 0.30, sp5 = -0.70, sp6 = 0.60, sp7 = 0.10, sp8 = -0.25)
BETA0_D7 <- rep(-1.2, 8)
A0_D7    <- c(-2.8, -3.2, -2.5, -3.0, -3.4, -2.7, -3.1, -2.9)

## Boundary criteria, pre-declared (mirrors dev/isdm-gate-campaign.R).
PSI_ABS_THRESH  <- 1e-4
PSI_REL_THRESH  <- 0.01
LOADING_RUNAWAY <- 25

ARMS <- c("A1", "A2", "A3", "A4", "A5", "A6")

#' species_truth(): planted Lambda/psi/beta/beta0/a0 for T_sp in {6, 8, 12}.
#' T_sp = 8 is D7 verbatim. T_sp = 6 takes the first 6 rows. T_sp = 12
#' recycles rows 1:4 of D7 as species 9:12 (deterministic, jitter-free,
#' preserves the both-signs property of D7 automatically since it only
#' repeats existing rows). Per design doc "The grid, in full" section.
species_truth <- function(T_sp, beta0_shift = 0) {
  stopifnot(T_sp %in% c(6L, 8L, 12L))
  idx <- switch(as.character(T_sp),
    "6"  = 1:6,
    "8"  = 1:8,
    "12" = c(1:8, 1:4)
  )
  sp_names <- sprintf("sp%d", seq_len(T_sp))
  Lambda <- LAMBDA_D7[idx, , drop = FALSE]; rownames(Lambda) <- sp_names
  psi   <- setNames(PSI_D7[idx],   sp_names)
  beta  <- setNames(BETA_D7[idx],  sp_names)
  beta0 <- setNames(BETA0_D7[idx] + beta0_shift, sp_names)
  a0    <- setNames(A0_D7[idx],    sp_names)
  list(Lambda = Lambda, psi = psi, beta = beta, beta0 = beta0, a0 = a0, T_sp = T_sp)
}

## =========================================================================
## D3/D4 -- spatial kernel, cached per (n, phi)
## =========================================================================

.kernel_cache <- new.env(parent = emptyenv())

#' phi <= 1e-8 is treated as the i.i.d. limit of C(h) = exp(-h/phi): every
#' off-diagonal entry -> 0, i.e. the identity covariance. Used by G6 (phi=0).
.kernel_chol <- function(n, phi) {
  key <- sprintf("n%d_phi%.6f", as.integer(n), phi)
  cached <- .kernel_cache[[key]]
  if (!is.null(cached)) return(cached)
  if (phi <= 1e-8) {
    out <- list(L = NULL, iid = TRUE)
  } else {
    m <- round(sqrt(n))
    if (m * m != n) stop("n must be a perfect square for the lattice DGM: got n = ", n)
    ix <- rep(seq_len(m), times = m); iy <- rep(seq_len(m), each = m)
    coords <- cbind(ix, iy) / m
    D <- as.matrix(stats::dist(coords))
    C <- exp(-D / phi)
    L <- t(chol(C + 1e-8 * diag(n)))
    out <- list(L = L, iid = FALSE, coords = coords)
  }
  .kernel_cache[[key]] <- out
  out
}

#' One standardised Gaussian field over the (n, phi) lattice, consuming
#' exactly one rnorm(n) draw from whatever RNG stream is active -- callers
#' control ordering via set.seed() before calling this (D8 discipline).
.gp_field <- function(n, phi) {
  kern <- .kernel_chol(n, phi)
  z <- stats::rnorm(n)
  raw <- if (isTRUE(kern$iid)) z else as.numeric(kern$L %*% z)
  as.numeric(scale(raw))
}

## Exact finite-sample geometry repair (Phase C amendment 2).
##
## Symbolic -> implementation alignment:
##   x_i       environmental component       unchanged standardised GP x
##   g_i       shared bias component          first whitened column
##   h_ij      species-specific component     remaining whitened columns
##   B_ij      kappa[rho*x + sqrt(1-rho^2){sqrt(omega)g+
##                    sqrt(1-omega)h_j}]       Bmat below
##   truth     Var(B_j)=kappa^2, cor(B_j,x)=rho,
##             cor(B_j,B_k)=rho^2+(1-rho^2)omega
##
## The projection and symmetric whitening are deterministic arithmetic after
## the original draws.  They therefore preserve RNG seed streams and draw
## counts.  phi_bias remains the sole kernel parameter for every raw bias
## field; the finite-sample projection/whitening is the declared repair, not a
## claim that the transformed columns are untouched GP realisations.
.exact_bias_basis <- function(x, g, H, rank_tol = 1e-10,
                              geometry_tol = 1e-10) {
  x <- as.numeric(x)
  H <- as.matrix(H)
  Z <- cbind(g = as.numeric(g), H)
  n <- length(x)
  if (nrow(Z) != n || n < 3L || any(!is.finite(c(x, Z)))) {
    stop("Exact bias geometry requires finite, conformable fields and n >= 3", call. = FALSE)
  }
  if (n - 1L < ncol(Z) + 1L) {
    stop("Exact bias geometry is rank-impossible: n - 1 must be at least T_sp + 2", call. = FALSE)
  }

  x <- x - mean(x)
  sx <- stats::sd(x)
  if (!is.finite(sx) || sx <= sqrt(.Machine$double.eps)) {
    stop("Exact bias geometry failed: x has zero or non-finite sample variance", call. = FALSE)
  }
  x <- x / sx
  Z <- sweep(Z, 2L, colMeans(Z), `-`)
  ## x'x = n-1 because x has sample variance one.
  Z <- Z - tcrossprod(x, as.numeric(crossprod(x, Z)) / (n - 1))
  gram <- crossprod(Z) / (n - 1)
  ee <- tryCatch(eigen(gram, symmetric = TRUE), error = function(e) e)
  if (inherits(ee, "condition") || any(!is.finite(ee$values))) {
    stop("Exact bias geometry failed: non-finite eigendecomposition", call. = FALSE)
  }
  cutoff <- rank_tol * max(1, max(ee$values))
  if (min(ee$values) <= cutoff) {
    stop(sprintf("Exact bias geometry failed rank check: min eigenvalue %.3e <= %.3e",
                 min(ee$values), cutoff), call. = FALSE)
  }
  inv_root <- ee$vectors %*% diag(1 / sqrt(ee$values), nrow = length(ee$values)) %*%
    t(ee$vectors)
  Q <- Z %*% inv_root
  colnames(Q) <- colnames(Z)
  realised_gram <- crossprod(cbind(x = x, Q)) / (n - 1)
  max_error <- max(abs(realised_gram - diag(ncol(realised_gram))))
  if (!is.finite(max_error) || max_error > geometry_tol) {
    stop(sprintf("Exact bias geometry failed numerical check: max Gram error %.3e > %.3e",
                 max_error, geometry_tol), call. = FALSE)
  }
  list(x = x, g = Q[, 1L], H = Q[, -1L, drop = FALSE],
       component_gram = realised_gram, max_gram_error = max_error,
       min_residual_eigenvalue = min(ee$values))
}

.bias_geometry_diagnostics <- function(Bmat, x, kappa, rho, omega) {
  target_sharing <- rho^2 + (1 - rho^2) * omega
  if (kappa == 0) {
    realised_rho <- rep(NA_real_, ncol(Bmat))
    realised_var <- rep(0, ncol(Bmat))
    realised_sharing <- matrix(NA_real_, ncol(Bmat), ncol(Bmat))
  } else {
    realised_rho <- as.numeric(cor(Bmat, x))
    realised_var <- apply(Bmat, 2L, stats::var)
    realised_sharing <- stats::cor(Bmat)
  }
  off <- realised_sharing[upper.tri(realised_sharing)]
  list(
    theoretical_variance = kappa^2,
    realised_variance = realised_var,
    theoretical_rho = rho,
    realised_rho = realised_rho,
    theoretical_sharing = target_sharing,
    realised_sharing = realised_sharing,
    realised_sharing_offdiag = off,
    max_variance_error = if (kappa == 0) 0 else max(abs(realised_var - kappa^2)),
    max_rho_error = if (kappa == 0) NA_real_ else max(abs(realised_rho - rho)),
    max_sharing_error = if (kappa == 0 || !length(off)) NA_real_ else
      max(abs(off - target_sharing))
  )
}

## =========================================================================
## D1-D9 -- sim_phase_c(): the data-generating mechanism
## =========================================================================

#' @param seed integer seed; fully determines the dataset (D8 discipline)
#' @param n number of lattice cells (must be a perfect square: 100, 400, 1600)
#' @param T_sp number of species/traits (6, 8, or 12; see species_truth())
#' @param d_true TRUE latent dimension (always 2 per D7; not a free knob)
#' @param phi_x spatial range for the environmental x field; prospectively
#'   frozen at 0.15 by the Phase C amendment
#' @param phi_bias spatial range for the bias fields g/h; G6 varies this while
#'   leaving phi_x fixed; values <= 1e-8 give the i.i.d. limit
#' @param kappa bias amplitude (D4); kappa = 0 gives b_ij = 0 identically
#' @param rho correlation of bias with x, per species (D4 ladder variable)
#' @param omega cross-species bias sharing weight (D5); total sharing is
#'   rho^2 + (1-rho^2)*omega, NOT omega alone -- see attr(df,"bias_sharing")
#' @param k PA repeat-visit count (D6); k = 3 is the design default, k = 1 is
#'   the G5 sensitivity (re-triggers the theta_diag_B skip for A2 alone)
#' @param beta0_shift one common, prospectively frozen prevalence calibration
#' @param retain_streams retain exact design and bias RNG draws as attributes;
#'   FALSE in campaigns and TRUE only in structural contract tests
#' @param truth output of species_truth(T_sp, beta0_shift); pass explicitly to avoid
#'   recomputing per call in a tight loop
#' @return long-format data.frame per the D9 schema, with design attributes
sim_phase_c <- function(seed, n = 400, T_sp = 8, d_true = 2,
                         phi_x = 0.15, phi_bias = 0.15,
                         kappa = 1, rho = 0.6, omega = 0.5, k = 3,
                         beta0_shift = 0, retain_streams = FALSE,
                         truth = species_truth(T_sp, beta0_shift)) {
  stopifnot(k >= 1, n > 0, T_sp == truth$T_sp,
            is.finite(kappa), kappa >= 0,
            is.finite(rho), abs(rho) <= 1,
            is.finite(omega), omega >= 0, omega <= 1)
  Lambda <- truth$Lambda; psi <- truth$psi; beta <- truth$beta
  beta0 <- truth$beta0; a0 <- truth$a0
  sp_names <- sprintf("sp%d", seq_len(T_sp))

  ## ---- D8 design stream: x; u; eps; A; U_po; U_pa, in this fixed order ----
  set.seed(seed)
  x <- .gp_field(n, phi_x)                        # x field (first draw)
  x_raw <- x
  u <- matrix(stats::rnorm(n * d_true), n, d_true) # u (n x d)
  eps <- matrix(stats::rnorm(n * T_sp), n, T_sp)   # eps (n x T)
  eps <- sweep(eps, 2, sqrt(psi), `*`)
  A <- stats::runif(n, 50, 200)                    # A (n)
  U_po <- matrix(stats::runif(n * T_sp), n, T_sp)  # U_po (n x T)
  U_pa <- matrix(stats::runif(n * T_sp), n, T_sp)  # U_pa (n x T)

  ## ---- D8 bias stream: g, then h_.1 .. h_.T, in this fixed order ---------
  set.seed(seed + 1e6L)
  g <- .gp_field(n, phi_bias)
  H <- matrix(NA_real_, n, T_sp)
  for (j in seq_len(T_sp)) H[, j] <- .gp_field(n, phi_bias)
  g_raw <- g; H_raw <- H

  ## Deterministic finite-sample repair: x, g, and every h_j are mean-zero,
  ## sample-variance one and mutually sample-orthogonal.  No RNG calls occur.
  bias_basis <- .exact_bias_basis(x, g, H)
  x <- bias_basis$x; g <- bias_basis$g; H <- bias_basis$H

  ## ---- D4 bias field: kappa, rho, omega applied as pure arithmetic -------
  ## (this is the ONLY place kappa/rho/omega enter -- changing them never
  ## touches the design or bias RNG streams, which is what makes the
  ## kappa = 0 pairing exact, D8 point 3)
  Bmat <- kappa * (rho * x + sqrt(1 - rho^2) *
                     (sqrt(omega) * g + sqrt(1 - omega) * H))
  bias_geometry <- .bias_geometry_diagnostics(Bmat, x, kappa, rho, omega)

  ## ---- D2 ecological process ----------------------------------------------
  xi <- u %*% t(Lambda) + eps                                # n x T
  eta_eco <- sweep(xi, 2, beta0, `+`) + outer(x, beta)        # n x T

  ## ---- D6 observation model, via inversion (D8 point 3) -------------------
  eta_po <- sweep(eta_eco, 2, a0, `+`) + Bmat + log(A)        # n x T
  y_po <- matrix(stats::qpois(U_po, exp(eta_po)), n, T_sp)

  eta_pa <- eta_eco                                            # log(a) = 0
  p_pa <- 1 - exp(-exp(eta_pa))
  y_pa <- matrix(stats::qbinom(U_pa, k, p_pa), n, T_sp)

  ## ---- D9 long-format assembly --------------------------------------------
  df_po <- data.frame(
    cell = rep(seq_len(n), T_sp), trait = rep(sp_names, each = n),
    source = "po", x = rep(x, T_sp), bstar = as.numeric(Bmat),
    is_po = 1, off = rep(log(A), T_sp), ntrials = 1L,
    value = as.integer(as.numeric(y_po)), stringsAsFactors = FALSE
  )
  df_pa <- data.frame(
    cell = rep(seq_len(n), T_sp), trait = rep(sp_names, each = n),
    source = "pa", x = rep(x, T_sp), bstar = 0,
    is_po = 0, off = 0, ntrials = k,
    value = as.integer(as.numeric(y_pa)), stringsAsFactors = FALSE
  )
  df <- rbind(df_po, df_pa)
  df <- df[order(df$cell, df$trait, df$source), ]
  rownames(df) <- NULL
  df$cell   <- factor(df$cell)
  df$trait  <- factor(df$trait, levels = sp_names)
  df$source <- factor(df$source, levels = c("po", "pa"))

  attr(df, "seed") <- seed
  attr(df, "n") <- n; attr(df, "T_sp") <- T_sp; attr(df, "d_true") <- d_true
  attr(df, "phi_x") <- phi_x; attr(df, "phi_bias") <- phi_bias
  attr(df, "kappa") <- kappa
  attr(df, "rho") <- rho; attr(df, "omega") <- omega; attr(df, "k") <- k
  attr(df, "beta0_shift") <- beta0_shift
  attr(df, "truth") <- truth
  attr(df, "realised_prevalence") <- mean(p_pa)
  ## bias_sharing is retained as the legacy theoretical field.  New code uses
  ## the explicitly named theoretical and realised diagnostics below.
  attr(df, "bias_sharing") <- bias_geometry$theoretical_sharing
  attr(df, "bias_sharing_theoretical") <- bias_geometry$theoretical_sharing
  attr(df, "bias_rho_theoretical") <- bias_geometry$theoretical_rho
  attr(df, "bias_variance_theoretical") <- bias_geometry$theoretical_variance
  attr(df, "bias_geometry") <- bias_geometry
  attr(df, "bias_component_gram") <- bias_basis$component_gram
  if (isTRUE(retain_streams)) {
    attr(df, "design_streams") <- list(
      x = x_raw, u = u, eps = eps, A = A, U_po = U_po, U_pa = U_pa
    )
    ## Preserve the exact pre-repair draws under the historical attribute.
    attr(df, "bias_streams") <- list(g = g_raw, H = H_raw)
    attr(df, "bias_basis") <- list(g = g, H = H)
  }
  df
}

## =========================================================================
## M -- fit_arm(): the six arms, per the design's formula table
## =========================================================================

.family_list_c <- function() {
  fl <- list(po = poisson(), pa = binomial(link = "cloglog"))
  attr(fl, "family_var") <- "source"
  fl
}

#' @param df output of sim_phase_c()
#' @param arm one of "A1".."A6" (see design doc M table)
#' @param d_fit fitted latent dimension (2 in the main grid; 1 or 3 for G4)
#' @param control optional gllvmTMBcontrol(...)
fit_arm <- function(df, arm = c("A1", "A2", "A3", "A4", "A5", "A6"),
                     d_fit = 2, control = NULL) {
  arm <- match.arg(arm)
  oracle_collapsed <- arm == "A6" && all(df$bstar == 0)
  rhs <- switch(arm,
    A1 = "0 + trait + trait:x + offset(off)",
    A2 = "0 + trait + trait:x",
    A3 = "0 + trait + trait:x",
    A4 = "0 + trait + trait:x + trait:is_po",
    A5 = "0 + trait + trait:x + trait:is_po + offset(off)",
    A6 = if (oracle_collapsed) {
      "0 + trait + trait:x + trait:is_po + offset(off)"
    } else {
      "0 + trait + trait:x + trait:is_po + trait:bstar + offset(off)"
    }
  )
  form <- stats::as.formula(sprintf(
    "value ~ %s + latent(0 + trait | cell, d = %d, unique = TRUE)", rhs, d_fit
  ))

  if (arm == "A1") {
    sub <- df[df$source == "po", , drop = FALSE]; sub$trait <- droplevels(sub$trait)
    fam <- poisson()
  } else if (arm == "A2") {
    sub <- df[df$source == "pa", , drop = FALSE]; sub$trait <- droplevels(sub$trait)
    fam <- binomial(link = "cloglog")
  } else {
    sub <- df
    fam <- .family_list_c()
  }

  args <- list(form, data = sub, trait = "trait", unit = "cell", cluster = "trait",
               family = fam, weights = sub$ntrials, silent = TRUE)
  if (!is.null(control)) args$control <- control
  fit <- do.call(gllvmTMB, args)
  attr(fit, "oracle_collapsed") <- oracle_collapsed
  fit
}

## =========================================================================
## E/P -- score_phase_c(): recovery metrics against planted truth
## =========================================================================

#' Orthogonal Procrustes RMSE. Pads the narrower matrix with zero columns so
#' d_fit != d_true (G4 sensitivity) does not error; this is a documented
#' approximation, not a claim that the two are on equal footing (see the
#' "could not implement as specified" note in the return summary).
.orth_procrustes_rmse <- function(Lambda_hat, Lambda_true) {
  if (is.null(Lambda_hat) || !all(is.finite(Lambda_hat))) return(NA_real_)
  dh <- ncol(Lambda_hat); dt <- ncol(Lambda_true)
  dmax <- max(dh, dt)
  A <- Lambda_true; B <- Lambda_hat
  if (dt < dmax) A <- cbind(A, matrix(0, nrow(A), dmax - dt))
  if (dh < dmax) B <- cbind(B, matrix(0, nrow(B), dmax - dh))
  sv <- tryCatch(svd(t(B) %*% A), error = function(e) NULL)
  if (is.null(sv)) return(NA_real_)
  Q <- sv$u %*% t(sv$v)
  sqrt(mean((B %*% Q - A)^2))
}

.mcse_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2) return(NA_real_)
  stats::sd(x) / sqrt(length(x))
}

#' @param fit output of fit_arm(), or a condition object from tryCatch
#' @param arm "A1".."A6"
#' @param cfg one-row data.frame/list with stage, block, kappa, rho, omega,
#'   phi_x, phi_bias, n, T_sp,
#'   d_fit, k, seed, block -- stamped verbatim onto the output row
#' @param truth output of species_truth() (planted Lambda/psi/beta)
#' @param elapsed_sec fit wall time in seconds (caller times it)
#' @param realised_prevalence,bias_sharing pulled from sim_phase_c()'s df attrs
score_phase_c <- function(fit, arm, cfg, truth, elapsed_sec = NA_real_,
                           realised_prevalence = NA_real_, bias_sharing = NA_real_,
                           bias_geometry = NULL, fit_attempted = TRUE) {
  Lambda_true <- truth$Lambda; psi_true <- truth$psi; beta_true <- truth$beta
  Tn <- nrow(Lambda_true)
  Sigma_true <- Lambda_true %*% t(Lambda_true) + diag(psi_true, Tn)
  R_true <- stats::cov2cor(Sigma_true)
  off_true <- R_true[upper.tri(R_true)]

  base <- data.frame(
    stage = cfg$stage, block = cfg$block,
    kappa = cfg$kappa, rho = cfg$rho, omega = cfg$omega,
    phi_x = cfg$phi_x, phi_bias = cfg$phi_bias,
    n = cfg$n, T_sp = cfg$T_sp, d_fit = cfg$d_fit, k = cfg$k,
    beta0_shift = cfg$beta0_shift,
    seed = cfg$seed, arm = arm, elapsed_sec = elapsed_sec,
    realised_prevalence = realised_prevalence,
    bias_sharing = bias_sharing,
    theoretical_bias_rho = if (is.null(bias_geometry)) cfg$rho else bias_geometry$theoretical_rho,
    theoretical_bias_sharing = if (is.null(bias_geometry)) bias_sharing else bias_geometry$theoretical_sharing,
    theoretical_bias_variance = if (is.null(bias_geometry)) cfg$kappa^2 else bias_geometry$theoretical_variance,
    realised_bias_rho_mean = if (is.null(bias_geometry)) NA_real_ else mean(bias_geometry$realised_rho),
    realised_bias_rho_max_abs_error = if (is.null(bias_geometry)) NA_real_ else bias_geometry$max_rho_error,
    realised_bias_sharing_mean = if (is.null(bias_geometry)) NA_real_ else mean(bias_geometry$realised_sharing_offdiag),
    realised_bias_sharing_max_abs_error = if (is.null(bias_geometry)) NA_real_ else bias_geometry$max_sharing_error,
    realised_bias_variance_mean = if (is.null(bias_geometry)) NA_real_ else mean(bias_geometry$realised_variance),
    realised_bias_variance_max_abs_error = if (is.null(bias_geometry)) NA_real_ else bias_geometry$max_variance_error,
    fit_attempted = isTRUE(fit_attempted),
    fit_error = NA_character_,
    convergence = NA_integer_, pdHess = NA, diag_B_skip = NA_integer_,
    oracle_collapsed = NA, estimand = "total_sigma",
    D_bias = NA_real_, D_rmse = NA_real_, D_max = NA_real_, D_z = NA_real_,
    rank_d_D_bias = NA_real_, rank_d_D_rmse = NA_real_,
    signflip = NA_real_, diag_rmse = NA_real_, psi_rmse = NA_real_,
    lambda_proc_rmse = NA_real_, beta_bias = NA_real_, beta_rmse = NA_real_,
    n_heywood_psi = NA_integer_, n_heywood_loading = NA_integer_,
    stringsAsFactors = FALSE
  )

  if (inherits(fit, "condition")) {
    base$fit_error <- conditionMessage(fit)
    return(base)
  }

  base$convergence <- fit$opt$convergence
  base$pdHess <- isTRUE(fit$sd_report$pdHess)
  base$oracle_collapsed <- isTRUE(attr(fit, "oracle_collapsed"))
  base$diag_B_skip <- if (!is.null(fit$tmb_data$diag_B_skip)) {
    as.integer(sum(fit$tmb_data$diag_B_skip))
  } else NA_integer_

  ## G5/A2 is loadings-only because theta_diag_B is mapped off for k = 1.
  ## Its rank-d comparison is deliberately separate from total-Sigma metrics.
  if (arm == "A2" && cfg$k == 1L) {
    base$estimand <- "loadings_only_rank_d"
    Lambda_hat <- tryCatch(extract_loadings(fit, level = "unit"), error = function(e) e)
    if (inherits(Lambda_hat, "condition")) {
      base$fit_error <- paste("extract_loadings failed:", conditionMessage(Lambda_hat))
      return(base)
    }
    Lambda_hat <- as.matrix(Lambda_hat)
    Sigma_load <- Lambda_hat %*% t(Lambda_hat)
    R_load <- stats::cov2cor(Sigma_load)
    eig <- eigen(R_true, symmetric = TRUE)
    keep <- seq_len(min(cfg$d_fit, length(eig$values)))
    R_rank <- eig$vectors[, keep, drop = FALSE] %*%
      diag(pmax(eig$values[keep], 0), length(keep)) %*%
      t(eig$vectors[, keep, drop = FALSE])
    R_rank <- stats::cov2cor(R_rank)
    rank_diff <- R_load[upper.tri(R_load)] - R_rank[upper.tri(R_rank)]
    base$rank_d_D_bias <- mean(rank_diff)
    base$rank_d_D_rmse <- sqrt(mean(rank_diff^2))
    base$lambda_proc_rmse <- .orth_procrustes_rmse(Lambda_hat, Lambda_true)
    base$n_heywood_loading <- sum(abs(Lambda_hat) > LOADING_RUNAWAY)
  } else {
  ## ---- R / Sigma: the headline (E3) ---------------------------------------
  Sigma_res <- tryCatch(
    extract_Sigma(fit, level = "unit", part = "total", link_residual = "none"),
    error = function(e) e
  )
  if (inherits(Sigma_res, "condition")) {
    base$fit_error <- paste("extract_Sigma failed:", conditionMessage(Sigma_res))
    return(base)
  }
  R_hat <- Sigma_res$R; Sigma_hat <- Sigma_res$Sigma
  off_hat <- R_hat[upper.tri(R_hat)]

  diffs <- off_hat - off_true
  base$D_bias <- mean(diffs)
  base$D_rmse <- sqrt(mean(diffs^2))
  base$D_max  <- max(abs(diffs))
  off_hat_c <- pmin(pmax(off_hat, -0.999999), 0.999999)
  base$D_z <- mean(atanh(off_hat_c) - atanh(off_true))

  strong <- abs(off_true) > 0.1
  base$signflip <- if (any(strong)) {
    mean(sign(off_hat[strong]) != sign(off_true[strong]))
  } else NA_real_

  base$diag_rmse <- .rmse(diag(Sigma_hat), diag(Sigma_true))
  }

  ## ---- Lambda (secondary, Procrustes-aligned) -----------------------------
  if (base$estimand == "total_sigma") {
    Lambda_hat <- tryCatch(extract_loadings(fit, level = "unit"), error = function(e) e)
    if (!inherits(Lambda_hat, "condition")) {
      base$lambda_proc_rmse <- .orth_procrustes_rmse(as.matrix(Lambda_hat), Lambda_true)
      base$n_heywood_loading <- sum(abs(as.matrix(Lambda_hat)) > LOADING_RUNAWAY)
    }
  }

  ## ---- psi (secondary; identified per E2 given k = 3) ---------------------
  if (base$estimand == "total_sigma") {
    psi_res <- tryCatch(
      extract_Sigma(fit, level = "unit", part = "unique", link_residual = "none"),
      error = function(e) e
    )
    if (!inherits(psi_res, "condition")) {
      psi_hat <- if (is.list(psi_res) && !is.null(psi_res$s)) psi_res$s else as.numeric(psi_res)
      base$psi_rmse <- .rmse(psi_hat, psi_true)
      med_psi <- stats::median(psi_hat[is.finite(psi_hat)])
      base$n_heywood_psi <- sum(is.finite(psi_hat) &
        (psi_hat < PSI_ABS_THRESH |
           (is.finite(med_psi) && med_psi > 0 & psi_hat / med_psi < PSI_REL_THRESH)))
    }
  }

  ## ---- beta: environmental slopes (E2: identified in every arm) ----------
  ## X_fix_names ordering matches opt$par's leading "b_fix" block 1:1
  ## (confirmed empirically: fit$opt$par carries no names of its own, but is
  ## in X_fix_names order -- see dev/isdm-bias-harness.R smoke check).
  beta_idx <- grep(":x$", fit$X_fix_names)
  if (length(beta_idx) == Tn) {
    beta_hat <- fit$opt$par[beta_idx]
    ## order beta_hat by species suffix so it lines up with beta_true's
    ## sp1..spT order regardless of X_fix_names' internal ordering.
    sp_of <- sub("^trait(sp[0-9]+):x$", "\\1", fit$X_fix_names[beta_idx])
    beta_hat <- beta_hat[match(names(beta_true), sp_of)]
    base$beta_bias <- mean(beta_hat - beta_true)
    base$beta_rmse <- .rmse(beta_hat, beta_true)
  }

  base
}

## =========================================================================
## Runner: run_dataset_c() simulates ONE dataset and fits ALL SIX arms on it
## (not one row per arm -- see the design note in isdm-bias-campaign.R on why
## this deviates cosmetically from the gate harness's one-row-per-config
## pattern), then run_grid_c() drives it over a configuration table.
## =========================================================================

#' @param cfg one row of a configuration data.frame with the amended schema
#' @return rbind of 6 score_phase_c() rows (one per arm), never throws
run_dataset_c <- function(cfg, control = NULL) {
  truth <- species_truth(cfg$T_sp, cfg$beta0_shift)
  df <- tryCatch(
    sim_phase_c(seed = cfg$seed, n = cfg$n, T_sp = cfg$T_sp, d_true = 2,
                phi_x = cfg$phi_x, phi_bias = cfg$phi_bias,
                kappa = cfg$kappa, rho = cfg$rho,
                omega = cfg$omega, k = cfg$k,
                beta0_shift = cfg$beta0_shift, truth = truth),
    error = function(e) e
  )
  if (inherits(df, "condition")) {
    rows <- lapply(ARMS, function(a) score_phase_c(
      df, a, cfg, truth, fit_attempted = FALSE
    ))
    return(do.call(rbind, rows))
  }
  rp <- attr(df, "realised_prevalence"); bs <- attr(df, "bias_sharing")
  bg <- attr(df, "bias_geometry")
  rows <- lapply(ARMS, function(a) {
    fit_seed <- cfg$seed + match(a, ARMS) * 100000L
    if (cfg$kappa == 0 && a == "A6") fit_seed <- cfg$seed + match("A5", ARMS) * 100000L
    set.seed(fit_seed)
    t0 <- Sys.time()
    fit <- tryCatch(fit_arm(df, arm = a, d_fit = cfg$d_fit, control = control),
                     error = function(e) e)
    el <- as.numeric(Sys.time() - t0, units = "secs")
    tryCatch(
      score_phase_c(fit, a, cfg, truth, elapsed_sec = el,
                    realised_prevalence = rp, bias_sharing = bs,
                    bias_geometry = bg, fit_attempted = TRUE),
      error = function(e) score_phase_c(
        e, a, cfg, truth, elapsed_sec = el,
        realised_prevalence = rp, bias_sharing = bs,
        bias_geometry = bg, fit_attempted = TRUE
      )
    )
  })
  do.call(rbind, rows)
}

#' @param config_df data.frame, one row per DATASET (no arm column -- all six
#'   arms are fit per row by run_dataset_c())
#' @param n_cores number of cores; 1 = serial
#' @param backend "serial" (default, portable) or "mclapply" (Unix fork)
run_grid_c <- function(config_df, control = NULL, n_cores = 1L,
                        backend = c("serial", "mclapply")) {
  backend <- match.arg(backend)
  cfgs <- split(config_df, seq_len(nrow(config_df)))
  results <- if (backend == "mclapply" && n_cores > 1L) {
    parallel::mclapply(cfgs, run_dataset_c, control = control, mc.cores = n_cores)
  } else {
    lapply(cfgs, run_dataset_c, control = control)
  }
  do.call(rbind, results)
}

## =========================================================================
## Bias-correlation control check (required by the task brief -- PRINT it)
## =========================================================================

#' Verifies, by direct measurement on simulated data (no fitting), the exact
## finite-sample variance, x-correlation, and sharing identities.
verify_bias_control <- function(seed = 1, n = 400, T_sp = 8,
                                phi_x = 0.15, phi_bias = 0.15,
                                kappa = 1, k = 3) {
  cat("=== Bias-correlation control check (sim_phase_c(), no fitting) ===\n")
  cat(sprintf("%-6s %-7s %18s %18s %20s %20s\n",
              "rho", "omega", "mean cor(b,x)", "target rho",
              "mean cor(b_j,b_k)", "target sharing"))
  out <- list()
  for (rho in c(0, 0.6)) {
    for (omega in c(0, 0.5, 1)) {
      df <- sim_phase_c(seed = seed, n = n, T_sp = T_sp,
                         phi_x = phi_x, phi_bias = phi_bias, kappa = kappa,
                         rho = rho, omega = omega, k = k)
      po <- df[df$source == "po", ]
      cs <- vapply(levels(po$trait), function(sp) {
        sub <- po[po$trait == sp, ]
        stats::cor(sub$bstar, sub$x)
      }, numeric(1))
      bmat <- do.call(cbind, lapply(levels(po$trait), function(sp) po$bstar[po$trait == sp]))
      cor_bb <- stats::cor(bmat)
      offpairs <- cor_bb[upper.tri(cor_bb)]
      expected_sharing <- rho^2 + (1 - rho^2) * omega
      cat(sprintf("%-6.2f %-7.2f %18.4f %18.2f %20.4f %20.4f\n",
                  rho, omega, mean(cs), rho, mean(offpairs), expected_sharing))
      geom <- attr(df, "bias_geometry")
      out[[sprintf("rho%.2f_omega%.2f", rho, omega)]] <- c(
        list(rho = rho, omega = omega, mean_cor_bx = mean(cs),
             mean_cor_bb = mean(offpairs), expected_sharing = expected_sharing),
        geom[c("max_variance_error", "max_rho_error", "max_sharing_error")]
      )
    }
  }
  invisible(out)
}
