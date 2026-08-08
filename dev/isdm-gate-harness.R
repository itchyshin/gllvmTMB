## dev/isdm-gate-harness.R
##
## Decisive-gate harness for the "mixed-curvature loading" question:
## does ONE species' loading, informed by TWO likelihoods of very
## different curvature (Poisson-log vs Bernoulli-cloglog), still give a
## unique, well-scaled Lambda/Sigma solution?
##
## Three cells (identical except observation families), T = 6 species,
## d = 1 latent factor. Each (cell, species) contributes two rows
## ("block1", "block2") sharing the same latent score u_i and the same
## loading lambda_j:
##
##   PP: block1 = Poisson(log),      block2 = Poisson(log)        (ceiling)
##   BB: block1 = Bernoulli(cloglog),block2 = Bernoulli(cloglog)  (info poverty)
##   PB: block1 = Poisson(log),      block2 = Bernoulli(cloglog)  (the gate cell)
##
## Generative model (matches the estimand of latent(unique = TRUE),
## Sigma = Lambda Lambda' + diag(psi), on the shared link-scale linear
## predictor): for species j, cell i,
##   eta_ij = log(t) + Lambda_j * u_i + delta_ij,   delta_ij ~ N(0, psi_j)
## where u_i ~ N(0,1) is one score per cell (shared by all species and
## both blocks), delta_ij is one nugget per (cell, species) (shared by
## both blocks of that species -- it lives at the unit_obs tier, which
## cluster = "trait" collapses to one level per (cell, species), exactly
## where both blocks land). log(t) is a COMMON baseline across species
## (the intensity-ladder value); only Lambda_j and psi_j vary by species.
## Each block then draws its own observation given the SAME eta_ij:
##   Poisson block:   y ~ Poisson(exp(eta_ij))
##   Bernoulli block: y ~ Bernoulli(1 - exp(-exp(eta_ij)))   [cloglog inverse]
## Both links share eta = log(t) on the linear-predictor scale at the
## same t, which is why the SAME t can drive both families off one ladder.
##
## Uses the INSTALLED gllvmTMB (do not devtools::load_all()).
## Lane rule: this worktree only. Do not touch R/, src/, tests/. Do not
## git add -A / commit / open a PR.

suppressPackageStartupMessages(library(gllvmTMB))

## =========================================================================
## Design constants
## =========================================================================

T_SP <- 6L  # number of species (traits); df = T(T-3)/2 = 9 at d = 1

## Planted truth: heterogeneous loadings including one small one (sp1),
## on the link (linear-predictor) scale. psi is the per-species unique
## (nugget) variance, also link scale.
PLANTED <- list(
  Lambda = c(sp1 = 0.15, sp2 = 0.90, sp3 = 0.60, sp4 = -0.70, sp5 = 0.30, sp6 = -0.45),
  psi    = c(sp1 = 0.30, sp2 = 0.50, sp3 = 0.40, sp4 = 0.60, sp5 = 0.35, sp6 = 0.45)
)
stopifnot(length(PLANTED$Lambda) == T_SP, length(PLANTED$psi) == T_SP)

## Intensity ladder: parameterised by the mean prevalence it induces,
## p = 1 - exp(-t)  =>  t = -log(1 - p).
PREVALENCE_LADDER <- c(0.1, 0.3, 0.6, 0.9)
t_from_prevalence <- function(p) -log1p(-p)

## n (units) ladder for the full grid (not all exercised in the smoke).
N_LADDER <- c(100, 200, 400, 800, 1600)

CELL_TYPES <- c("PP", "BB", "PB")

## =========================================================================
## simulate_cell(): build one dataset
## =========================================================================

#' @param cell_type one of "PP", "BB", "PB"
#' @param n_units number of cells (units)
#' @param prevalence target mean prevalence p in (0,1); sets t = -log(1-p)
#' @param seed integer seed (fully determines the dataset)
#' @param planted list(Lambda = <T-vector>, psi = <T-vector>)
#' @return a data.frame with attributes cell_type/fam1/fam2 recording the
#'   two block families for this cell
simulate_cell <- function(cell_type, n_units, prevalence, seed, planted = PLANTED) {
  cell_type <- match.arg(cell_type, CELL_TYPES)
  stopifnot(prevalence > 0, prevalence < 1, n_units > 0)
  set.seed(seed)

  Tn <- length(planted$Lambda)
  t_val <- t_from_prevalence(prevalence)
  log_t <- log(t_val)

  fam1 <- switch(cell_type, PP = "poisson", BB = "binomial", PB = "poisson")
  fam2 <- switch(cell_type, PP = "poisson", BB = "binomial", PB = "binomial")

  u <- rnorm(n_units, 0, 1)  # one latent score per cell, shared across species+blocks

  rows <- vector("list", Tn)
  for (j in seq_len(Tn)) {
    delta <- rnorm(n_units, 0, sqrt(planted$psi[j]))  # one nugget per (cell, species)
    eta <- log_t + planted$Lambda[j] * u + delta

    draw <- function(fam) {
      if (fam == "poisson") {
        rpois(n_units, exp(eta))
      } else {
        rbinom(n_units, 1, 1 - exp(-exp(eta)))
      }
    }
    y1 <- draw(fam1)
    y2 <- draw(fam2)

    rows[[j]] <- rbind(
      data.frame(cell = seq_len(n_units), trait = sprintf("sp%d", j), block = "block1", value = y1),
      data.frame(cell = seq_len(n_units), trait = sprintf("sp%d", j), block = "block2", value = y2)
    )
  }
  df <- do.call(rbind, rows)
  df <- df[order(df$cell, df$trait), ]
  rownames(df) <- NULL
  df$cell  <- factor(df$cell)
  df$trait <- factor(df$trait, levels = sprintf("sp%d", seq_len(Tn)))
  df$block <- factor(df$block, levels = c("block1", "block2"))

  attr(df, "cell_type") <- cell_type
  attr(df, "fam1") <- fam1
  attr(df, "fam2") <- fam2
  attr(df, "n_units") <- n_units
  attr(df, "prevalence") <- prevalence
  attr(df, "t_val") <- t_val
  attr(df, "seed") <- seed
  df
}

## =========================================================================
## fit_cell(): fit one arm (U1 = unique(psi) TRUE, U0 = unique(psi) FALSE)
## =========================================================================

.family_obj <- function(name) {
  if (identical(name, "poisson")) poisson() else binomial(link = "cloglog")
}

#' @param df output of simulate_cell()
#' @param arm "U1" (Sigma = Lambda Lambda' + diag(psi), the package default
#'   estimand) or "U0" (Sigma = Lambda Lambda' only, all three cells then
#'   estimate the SAME model class)
#' @param control optional gllvmTMBcontrol(...) object
fit_cell <- function(df, arm = c("U1", "U0"), control = NULL) {
  arm <- match.arg(arm)
  unique_str <- if (arm == "U1") "TRUE" else "FALSE"

  fam1 <- .family_obj(attr(df, "fam1"))
  fam2 <- .family_obj(attr(df, "fam2"))
  family_list <- list(block1 = fam1, block2 = fam2)
  attr(family_list, "family_var") <- "block"

  form <- stats::as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | cell, d = 1, unique = %s)", unique_str
  ))

  args <- list(
    form, data = df, trait = "trait", unit = "cell", cluster = "trait",
    family = family_list, silent = TRUE
  )
  if (!is.null(control)) args$control <- control

  do.call(gllvmTMB, args)
}

## =========================================================================
## score_fit(): one-row data.frame of recovery metrics
## =========================================================================

#' abs(cor()) is used for Lambda recovery because at d = 1 the loading
#' vector is identified only up to sign (reflection, not just rotation).
.sign_free_cor <- function(a, b) {
  ok <- is.finite(a) & is.finite(b)
  if (sum(ok) < 2) return(NA_real_)
  abs(stats::cor(a[ok], b[ok]))
}

.rmse <- function(a, b) {
  ok <- is.finite(a) & is.finite(b)
  if (!any(ok)) return(NA_real_)
  sqrt(mean((a[ok] - b[ok])^2))
}

#' @param fit output of fit_cell(), or a condition object from tryCatch
#' @param cell_type, n_units, prevalence, seed, arm: config identifiers to
#'   stamp onto the row
#' @param planted list(Lambda=, psi=) planted truth
#' @param elapsed_sec fit wall time in seconds (caller times it)
score_fit <- function(fit, cell_type, n_units, prevalence, seed, arm,
                       planted = PLANTED, elapsed_sec = NA_real_) {
  Tn <- length(planted$Lambda)

  base <- data.frame(
    cell = cell_type, n_units = n_units, prevalence = prevalence, seed = seed,
    arm = arm, elapsed_sec = elapsed_sec,
    fit_error = NA_character_,
    convergence = NA_integer_, pdHess = NA, diag_B_skip = NA_integer_,
    off_diag_rmse = NA_real_, off_diag_cor = NA_real_,
    diag_rmse = NA_real_,
    lambda_cor = NA_real_,
    comm_rmse = NA_real_, comm_cor = NA_real_,
    n_heywood_psi = NA_integer_, n_heywood_loading = NA_integer_,
    stringsAsFactors = FALSE
  )

  if (inherits(fit, "condition")) {
    base$fit_error <- conditionMessage(fit)
    return(base)
  }

  base$convergence <- fit$opt$convergence
  base$pdHess <- isTRUE(fit$sd_report$pdHess)
  base$diag_B_skip <- if (!is.null(fit$tmb_data$diag_B_skip)) as.integer(sum(fit$tmb_data$diag_B_skip)) else NA_integer_

  ## planted Sigma / R on the link scale (sign-invariant: Lambda Lambda' is
  ## invariant to a sign flip of Lambda, so no reflection alignment needed
  ## for Sigma/R -- only for the raw Lambda vector itself, below).
  Lambda_true <- planted$Lambda
  psi_true <- planted$psi
  Sigma_true <- outer(Lambda_true, Lambda_true) + diag(psi_true)
  R_true <- stats::cov2cor(Sigma_true)

  Sigma_res <- tryCatch(
    extract_Sigma(fit, level = "unit", part = "total", link_residual = "none"),
    error = function(e) e
  )
  if (inherits(Sigma_res, "condition")) {
    base$fit_error <- paste("extract_Sigma failed:", conditionMessage(Sigma_res))
    return(base)
  }
  Sigma_hat <- Sigma_res$Sigma
  R_hat <- Sigma_res$R

  off_true <- R_true[upper.tri(R_true)]
  off_hat  <- R_hat[upper.tri(R_hat)]
  base$off_diag_rmse <- .rmse(off_hat, off_true)
  base$off_diag_cor  <- if (sum(is.finite(off_hat) & is.finite(off_true)) >= 2) {
    stats::cor(off_hat[is.finite(off_hat) & is.finite(off_true)],
               off_true[is.finite(off_hat) & is.finite(off_true)])
  } else NA_real_

  base$diag_rmse <- .rmse(diag(Sigma_hat), diag(Sigma_true))

  ## Lambda recovery: sign-free correlation (reflection permitted, no
  ## `lambda_1 > 0` convention imposed).
  Lambda_hat <- tryCatch(extract_loadings(fit, level = "unit"), error = function(e) e)
  if (!inherits(Lambda_hat, "condition")) {
    lam_hat_vec <- as.numeric(Lambda_hat[, 1])
    base$lambda_cor <- .sign_free_cor(lam_hat_vec, Lambda_true)
  }

  ## Communality h_j^2 = lambda_j^2 / (lambda_j^2 + psi_j) -- U1 arm only
  ## (in U0 there is no separately-estimated psi to compute it from).
  if (arm == "U1" && !inherits(Lambda_hat, "condition")) {
    psi_res <- tryCatch(
      extract_Sigma(fit, level = "unit", part = "unique", link_residual = "none"),
      error = function(e) e
    )
    if (!inherits(psi_res, "condition")) {
      ## extract_Sigma(part = "unique") returns the psi vector in field $s
      ## (a named length-T numeric), not $psi or $Sigma -- confirmed by str().
      psi_hat_vec <- if (is.list(psi_res) && !is.null(psi_res$s)) psi_res$s else as.numeric(psi_res)
      lam_hat_vec <- as.numeric(Lambda_hat[, 1])
      comm_hat <- lam_hat_vec^2 / (lam_hat_vec^2 + psi_hat_vec)
      comm_true <- Lambda_true^2 / (Lambda_true^2 + psi_true)
      base$comm_rmse <- .rmse(comm_hat, comm_true)
      base$comm_cor  <- if (sum(is.finite(comm_hat) & is.finite(comm_true)) >= 2) {
        stats::cor(comm_hat[is.finite(comm_hat)], comm_true[is.finite(comm_hat)])
      } else NA_real_

      ## Boundary / Heywood rate: psi_hat within tolerance of its lower
      ## bound (near zero). Criterion declared in advance, mirroring
      ## check_gllvmTMB()'s own psi_thresh/psi_rel_thresh defaults.
      psi_thresh <- 1e-4
      psi_rel_thresh <- 0.01
      med_psi <- stats::median(psi_hat_vec[is.finite(psi_hat_vec)])
      base$n_heywood_psi <- sum(is.finite(psi_hat_vec) &
        (psi_hat_vec < psi_thresh | (is.finite(med_psi) && med_psi > 0 & psi_hat_vec / med_psi < psi_rel_thresh)))
    }
  }

  ## Loading runaway (Heywood's other face): |lambda_hat_j| far beyond the
  ## planted scale. check_gllvmTMB()'s own runaway threshold is 25 on the
  ## link scale; use the same value as a pre-declared criterion here.
  if (!inherits(Lambda_hat, "condition")) {
    base$n_heywood_loading <- sum(abs(as.numeric(Lambda_hat[, 1])) > 25)
  }

  base
}

## =========================================================================
## run_one() / run_grid(): drive the harness over a configuration table
## =========================================================================

#' @param cfg one row of a configuration table: cell, n_units, prevalence,
#'   seed, arm
#' @param planted planted truth list
#' @return one-row data.frame from score_fit(), with elapsed_sec filled in,
#'   never throws (errors are captured into fit_error)
run_one <- function(cfg, planted = PLANTED, control = NULL) {
  t0 <- Sys.time()
  df <- tryCatch(
    simulate_cell(cfg$cell, cfg$n_units, cfg$prevalence, cfg$seed, planted),
    error = function(e) e
  )
  if (inherits(df, "condition")) {
    return(score_fit(df, cfg$cell, cfg$n_units, cfg$prevalence, cfg$seed, cfg$arm,
                      planted, elapsed_sec = NA_real_))
  }
  fit <- tryCatch(fit_cell(df, arm = cfg$arm, control = control), error = function(e) e)
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  score_fit(fit, cfg$cell, cfg$n_units, cfg$prevalence, cfg$seed, cfg$arm,
            planted, elapsed_sec = elapsed)
}

#' Drive run_one() over every row of a configuration table.
#' @param config_df data.frame with columns cell, n_units, prevalence, seed, arm
#' @param n_cores number of cores; 1 = serial (default, portable)
#' @param backend "serial" (default) or "mclapply" (Unix fork -- use this on
#'   the multicore Linux box; do NOT use on Windows)
#' @return rbind of run_one() rows, one per config row
run_grid <- function(config_df, planted = PLANTED, control = NULL,
                      n_cores = 1L, backend = c("serial", "mclapply")) {
  backend <- match.arg(backend)
  cfgs <- split(config_df, seq_len(nrow(config_df)))

  results <- if (backend == "mclapply" && n_cores > 1L) {
    parallel::mclapply(cfgs, run_one, planted = planted, control = control,
                        mc.cores = n_cores)
  } else {
    lapply(cfgs, run_one, planted = planted, control = control)
  }
  do.call(rbind, results)
}
