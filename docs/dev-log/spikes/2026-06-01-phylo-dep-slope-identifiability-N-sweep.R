## Identifiability of the non-Gaussian phylo_dep(1 + x1 + ... + xs | sp)
## augmented slope across sample size N, for ALL reserved core families.
## Spike for GAP-B1 (PHY-18, s = 1) and RE-03 (s = 2) per
## docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md.
##
## QUESTION: every non-Gaussian phylo_dep slope fit returns conv != 0 /
## non-PD Hessian at n_sp <= 100 (PHY-18, SPA-10). Is that genuine non-
## identifiability, or just finite-sample power? This sweeps n_sp and reports
## whether conv == 0 + pdHess == TRUE + recovery-within-band is reached, per
## family.
##
## METHOD (no engine change): build a scaffold fit under the TARGET family
## with the family-general correlated-unique augmented slope
## `phylo_unique(1 + x | species)` (sets up family_id_vec, link_id_vec, the
## augmented random-effect arrays and every family-specific dispersion param),
## then override the harvested tmb_data to the DEP path
## (use_phylo_dep_slope = 1L, full unstructured C x C Sigma_b via
## theta_dep_chol) and refit via TMB::MakeADFun. For s = 2 this deliberately
## bypasses the public fail-loud RE-03 guard: the harness is evidence-gathering,
## not capability admission. The C++ accumulates the dep slope into eta BEFORE
## the family dispatch, so each family's likelihood is exercised with the dep
## covariance. RESEARCH SPIKE -- not a gating test and not an engine change.
##
## REQUIRES an R environment with the package compiled (devtools::load_all).
## Authored in a container WITHOUT R; NOT executed there. Run locally or via
## the `dep-slope-identifiability-sweep` GitHub Actions dispatch workflow.
##
## Env knobs (all optional; the dispatch workflow sets them):
##   GLLVMTMB_SWEEP_FAMILIES  comma list (default all reserved cores + gaussian control)
##   GLLVMTMB_SWEEP_SGRID     comma list of slope counts s (default 1; use 2 for RE-03)
##   GLLVMTMB_SWEEP_NGRID     comma list of n_sp (default 80,150,300,600,1200)
##   GLLVMTMB_SWEEP_SEEDS     comma list of seeds (default 101,202,303)
##   GLLVMTMB_SWEEP_NREP      comma list of reps per (species,trait) cell (default 10)
##   GLLVMTMB_SWEEP_X_SD_GRID comma list of slope-covariate SDs (default 1)
##   GLLVMTMB_SWEEP_SLOPE_SCALE_GRID
##                            comma list of multiplicative slope-coordinate
##                            standard-deviation scales
##                            (default 1; RE-03 diagnostic sensitivity only)
##   GLLVMTMB_SWEEP_OUT       CSV output path (default dep-identifiability-sweep-results.csv)
##
## Run:  Rscript docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R

suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(ape))
suppressMessages(library(TMB))

T_tr <- 2L

## KNOWN PD unstructured (1+s)T x (1+s)T Sigma_b, column-major lower-tri incl
## diag. s = 1 is identical to the validated Gaussian recovery harness /
## original sweep fixture. s = 2 mirrors test-phylo-dep-slope-s2-gaussian.R.
.dep_Ltrue <- function(n_slope) {
  n_slope <- as.integer(n_slope)
  stride <- 1L + n_slope
  C <- stride * T_tr
  L <- matrix(0, C, C)
  if (identical(n_slope, 1L)) {
    L[lower.tri(L, diag = TRUE)] <- c(
      0.8, 0.2, -0.1, 0.15,   # col 1 (rows 1..4)
           0.6,  0.1, -0.05,  # col 2 (rows 2..4)
                 0.5,  0.1,   # col 3 (rows 3..4)
                       0.45   # col 4 (row 4)
    )
    return(L)
  }
  if (identical(n_slope, 2L)) {
    L[lower.tri(L, diag = TRUE)] <- c(
      0.80, 0.15, 0.10, -0.10, 0.08, -0.05, # col 1 (rows 1..6)
      0.55, 0.08, 0.05, -0.04, 0.03,        # col 2 (rows 2..6)
      0.50, 0.06, 0.04, -0.03,              # col 3 (rows 3..6)
      0.75, 0.10, 0.06,                     # col 4 (rows 4..6)
      0.55, 0.05,                           # col 5 (rows 5..6)
      0.50                                  # col 6 (row 6)
    )
    return(L)
  }
  stop("this sweep currently supports s = 1 or s = 2, not s = ", n_slope)
}
.Sigma_b_true <- function(n_slope, slope_scale = 1) {
  L <- .dep_Ltrue(n_slope)
  Sigma <- L %*% t(L)
  slope_scale <- as.numeric(slope_scale)
  if (!is.finite(slope_scale) || slope_scale <= 0) {
    stop("slope_scale must be finite and positive")
  }
  if (!identical(slope_scale, 1)) {
    ## Scale only the slope coordinates. Matrix subassignment with
    ## `D[idx, idx] <- value` fills the whole slope-by-slope block and makes
    ## the scaling matrix singular; use paired diagonal indices instead.
    D <- diag(1, nrow(Sigma))
    idx <- .slope_var_idx(n_slope)
    D[cbind(idx, idx)] <- slope_scale
    Sigma <- D %*% Sigma %*% D
  }
  Sigma
}
.slope_var_idx <- function(n_slope) {
  stride <- 1L + as.integer(n_slope)
  unlist(lapply(seq_len(T_tr), function(t) {
    base <- stride * (t - 1L)
    base + 1L + seq_len(n_slope)
  }), use.names = FALSE)
}
.slope_col_names <- function(n_slope) {
  if (identical(as.integer(n_slope), 1L)) "x" else paste0("x", seq_len(n_slope))
}

.blank_diagnostics <- function() {
  list(
    eta_min = NA_real_, eta_max = NA_real_, eta_sd = NA_real_,
    x_abs_cor_max = NA_real_, response_mean = NA_real_,
    response_min = NA_real_, response_max = NA_real_,
    response_zero_frac = NA_real_, response_boundary_frac = NA_real_
  )
}

.fixture_diagnostics <- function(fx) {
  y <- fx$df$value
  y_num <- suppressWarnings(as.numeric(y))
  boundary <- rep(FALSE, length(y_num))
  if (identical(fx$family, "Beta")) {
    boundary <- y_num <= 1e-5 | y_num >= 1 - 1e-5
  } else if (identical(fx$family, "binomial") && !is.null(fx$weights)) {
    boundary <- y_num <= 0 | y_num >= fx$weights
  } else if (identical(fx$family, "ordinal_probit")) {
    boundary <- y_num <= min(y_num, na.rm = TRUE) | y_num >= max(y_num, na.rm = TRUE)
  }
  x_cor <- NA_real_
  if (length(fx$slope_cols) >= 2L) {
    X <- fx$df[!duplicated(fx$df[c("species", "rep")]), fx$slope_cols, drop = FALSE]
    cm <- stats::cor(X)
    x_cor <- max(abs(cm[upper.tri(cm)]), na.rm = TRUE)
  }
  list(
    eta_min = min(fx$eta, na.rm = TRUE),
    eta_max = max(fx$eta, na.rm = TRUE),
    eta_sd = stats::sd(fx$eta, na.rm = TRUE),
    x_abs_cor_max = x_cor,
    response_mean = mean(y_num, na.rm = TRUE),
    response_min = min(y_num, na.rm = TRUE),
    response_max = max(y_num, na.rm = TRUE),
    response_zero_frac = mean(y_num == 0, na.rm = TRUE),
    response_boundary_frac = mean(boundary, na.rm = TRUE)
  )
}

.recovery_reason <- function(conv, pdHess, ratio_min, ratio_max,
                             lo = 0.5, hi = 2) {
  if (is.na(conv) || is.na(pdHess)) return("not_fit")
  if (!identical(as.integer(conv), 0L) || !isTRUE(pdHess)) return("nonPD/nonconv")
  if (is.na(ratio_min) || is.na(ratio_max)) return("missing_ratio")
  if (ratio_min < lo) return("low_ratio")
  if (ratio_max > hi) return("high_ratio")
  "pass"
}

.report_family_param <- function(report, fam) {
  candidates <- switch(fam,
    nbinom2 = c("phi_nbinom2", "theta_nbinom2"),
    Gamma = c("phi_gamma", "phi_Gamma", "phi"),
    Beta = c("phi_beta", "phi_Beta", "phi"),
    ordinal_probit = c("tau", "cutpoints", "tau_ord", "tau_ordinal"),
    character()
  )
  vals <- NULL
  for (nm in candidates) {
    if (!is.null(report[[nm]])) {
      vals <- as.numeric(report[[nm]])
      break
    }
  }
  if (is.null(vals) || !length(vals)) return(c(NA_real_, NA_real_))
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(c(NA_real_, NA_real_))
  c(min(vals), max(vals))
}

## Binomial trials per row. Default 12 (multi-trial, matching test-matrix-
## slope-binomial-logit.R) routed through the `weights = n_trials` engine API;
## set GLLVMTMB_BINOM_TRIALS=1 for the low-information Bernoulli case.
BINOM_TRIALS <- as.integer(Sys.getenv("GLLVMTMB_BINOM_TRIALS", "12"))

## Per-family link-scale intercepts (modest so non-Gaussian means stay in the
## family's stable range), the family object, and dispersion truth. Borrowed
## from the validated per-family slope tests (test-matrix-slope-*.R).
.fam_spec <- function(fam) {
  switch(fam,
    gaussian = list(obj = gaussian(),                 mu = c(1.0, -0.5), disp = NA,  ord = FALSE),
    poisson  = list(obj = poisson(link = "log"),      mu = c(1.0,  0.7), disp = NA,  ord = FALSE),
    nbinom2  = list(obj = gllvmTMB::nbinom2(),         mu = c(0.7,  0.7), disp = 2,   ord = FALSE),
    Gamma    = list(obj = Gamma(link = "log"),         mu = c(1.0,  0.5), disp = 2,   ord = FALSE),
    Beta     = list(obj = gllvmTMB::Beta(),            mu = c(0.3, -0.3), disp = 5,   ord = FALSE),
    binomial = list(obj = binomial(link = "logit"),    mu = c(0.2, -0.2), disp = NA,  ord = FALSE),
    ordinal_probit = list(obj = ordinal_probit(),      mu = c(0.0,  0.0), disp = NA,  ord = TRUE,
                          taus = c(0, 0.7, 1.4)),      # K = 4 (3 cutpoints), latent residual sd = 1
    stop("unsupported family ", fam)
  )
}

## Draw the augmented effects + response on the link scale, then apply the
## family. Returns the long data frame + tree.
.make_fixture <- function(fam, n_sp, n_rep, seed, n_slope = 1L,
                          x_sd = 1, slope_scale = 1) {
  set.seed(seed)
  sp <- .fam_spec(fam)
  n_slope <- as.integer(n_slope)
  x_sd <- as.numeric(x_sd)
  if (!is.finite(x_sd) || x_sd <= 0) stop("x_sd must be finite and positive")
  stride <- 1L + n_slope
  C <- stride * T_tr
  Sigma_b_true <- .Sigma_b_true(n_slope, slope_scale = slope_scale)
  slope_cols <- .slope_col_names(n_slope)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- LA %*% matrix(rnorm(n_sp * C), n_sp, C) %*% chol(Sigma_b_true)   # interleaved (a_t, b_t)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(species = factor(tree$tip.label, levels = tree$tip.label),
                    rep = seq_len(n_rep))
  for (col in slope_cols) sr[[col]] <- rnorm(nrow(sr), sd = x_sd)
  if (!"x" %in% slope_cols) sr$x <- sr[[slope_cols[1L]]]  # scaffold alias
  trait_levels <- paste0("t", seq_len(T_tr))
  df <- merge(sr, data.frame(trait = factor(trait_levels, levels = trait_levels)), all = TRUE)
  df <- df[order(df$species, df$rep, df$trait), ]
  ti <- as.integer(df$trait)
  si <- match(as.character(df$species), tree$tip.label)
  eta <- sp$mu[ti] + B[cbind(si, stride * (ti - 1L) + 1L)]
  for (j in seq_len(n_slope)) {
    eta <- eta + B[cbind(si, stride * (ti - 1L) + 1L + j)] * df[[slope_cols[j]]]
  }

  wts <- NULL
  df$value <- switch(fam,
    gaussian = eta + rnorm(nrow(df), sd = 0.3),
    poisson  = rpois(nrow(df), exp(eta)),
    nbinom2  = rnbinom(nrow(df), mu = exp(eta), size = sp$disp),
    Gamma    = rgamma(nrow(df), shape = sp$disp, scale = exp(eta) / sp$disp),
    Beta     = {                                                              # clamp exact 0/1 (Beta support is open)
      mu <- plogis(eta)
      pmin(pmax(rbeta(nrow(df), mu * sp$disp, (1 - mu) * sp$disp), 1e-6), 1 - 1e-6)
    },
    binomial = {                                                             # multi-trial via weights = n_trials API
      wts <- rep(BINOM_TRIALS, nrow(df))
      rbinom(nrow(df), size = BINOM_TRIALS, prob = plogis(eta))
    },
    ordinal_probit = {
      z <- eta + rnorm(nrow(df))                                              # latent, residual sd = 1
      ordered(findInterval(z, sp$taus) + 1L, levels = seq_len(length(sp$taus) + 1L))
    },
    stop("add DGP for family ", fam)
  )
  list(df = df, tree = tree, fam_obj = sp$obj, weights = wts,
       n_slope = n_slope, C = C, Sigma_b_true = Sigma_b_true,
       slope_cols = slope_cols, family = fam, eta = eta, x_sd = x_sd,
       slope_scale = as.numeric(slope_scale), n_rep = as.integer(n_rep))
}

.fail_row <- function(fam, n_sp, seed, n_slope, n_rep = NA_integer_,
                      x_sd = NA_real_, slope_scale = NA_real_,
                      note, diag = .blank_diagnostics()) {
  data.frame(family = fam, n_slope = n_slope, n_sp = n_sp, n_rep = n_rep,
             seed = seed, x_sd = x_sd, slope_scale = slope_scale,
             conv = NA_integer_, pdHess = NA,
             max_sigma_diff = NA_real_, slope_var_ratio_1 = NA_real_,
             slope_var_ratio_2 = NA_real_, slope_var_ratio_3 = NA_real_,
             slope_var_ratio_4 = NA_real_, slope_var_ratio_min = NA_real_,
             slope_var_ratio_max = NA_real_, slope_var_ratios = NA_character_,
             sigma_eigen_min = NA_real_, sigma_eigen_max = NA_real_,
             sigma_condition = NA_real_, truth_condition = NA_real_,
             fit_objective = NA_real_, fit_iterations = NA_integer_,
             family_param_min = NA_real_, family_param_max = NA_real_,
             eta_min = diag$eta_min, eta_max = diag$eta_max,
             eta_sd = diag$eta_sd, x_abs_cor_max = diag$x_abs_cor_max,
             response_mean = diag$response_mean,
             response_min = diag$response_min,
             response_max = diag$response_max,
             response_zero_frac = diag$response_zero_frac,
             response_boundary_frac = diag$response_boundary_frac,
             strict_recovered = FALSE, loose_recovered = FALSE,
             failure_reason = .recovery_reason(NA_integer_, NA, NA_real_, NA_real_),
             note = note, stringsAsFactors = FALSE)
}

## Fit ONE dep-slope cell: scaffold under the target family, override to dep,
## refit, sdreport. Returns a one-row result. Every stage is wrapped so one
## bad cell yields a noted row, never a crash, and the sweep continues.
run_cell <- function(fam, n_sp, n_rep = 10L, seed = 1L, n_slope = 1L,
                     x_sd = 1, slope_scale = 1) {
  fx <- tryCatch(.make_fixture(fam, n_sp, n_rep, seed, n_slope = n_slope,
                               x_sd = x_sd, slope_scale = slope_scale),
                 error = function(e) e)
  if (inherits(fx, "error")) {
    return(.fail_row(fam, n_sp, seed, n_slope, n_rep, x_sd, slope_scale,
                     paste("fixture:", conditionMessage(fx))))
  }
  dgp_diag <- .fixture_diagnostics(fx)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  base <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(1 + x | species),
      data = fx$df, phylo_tree = fx$tree, unit = "species",
      family = fx$fam_obj, weights = fx$weights, control = ctl))),
    error = function(e) e)
  if (inherits(base, "error")) {
    return(.fail_row(fam, n_sp, seed, n_slope, n_rep, x_sd, slope_scale,
                     paste("scaffold:", conditionMessage(base)), dgp_diag))
  }

  dat <- base$tmb_data; par <- base$tmb_params; map <- base$tmb_map
  n_aug <- dat$n_aug_phy; n_obs <- length(dat$y)

  ## Override harvested scaffold to the DEP path (full unstructured C x C).
  dat$use_phylo_dep_slope <- 1L
  dat$n_lhs_cols <- fx$C
  trid <- dat$trait_id
  Z <- array(0.0, dim = c(n_obs, fx$C, 1L))
  stride <- 1L + fx$n_slope
  for (o in seq_len(n_obs)) {
    t0 <- trid[o]
    base <- stride * t0
    Z[o, base + 1L, 1L] <- 1.0
    for (j in seq_len(fx$n_slope)) {
      Z[o, base + 1L + j, 1L] <- fx$df[[fx$slope_cols[j]]][o]
    }
  }
  dat$Z_phy_aug <- Z
  par$b_phy_aug <- array(0.0, dim = c(n_aug, fx$C, 1L))
  par$theta_dep_chol <- numeric(fx$C * (fx$C + 1L) / 2L)
  par$theta_dep_chol[seq_len(fx$C)] <- log(0.5)
  map$b_phy_aug <- NULL
  map$log_sd_b  <- factor(rep(NA, length(par$log_sd_b)))
  if (length(par$atanh_cor_b) > 0) map$atanh_cor_b <- factor(rep(NA, length(par$atanh_cor_b)))
  map$theta_dep_chol <- NULL

  obj <- tryCatch(TMB::MakeADFun(data = dat, parameters = par, map = map,
                                 random = "b_phy_aug", DLL = "gllvmTMB", silent = TRUE),
                  error = function(e) e)
  if (inherits(obj, "error")) {
    return(.fail_row(fam, n_sp, seed, fx$n_slope, n_rep, x_sd, slope_scale,
                     paste("MakeADFun:", conditionMessage(obj)), dgp_diag))
  }

  fit <- tryCatch(nlminb(obj$par, obj$fn, obj$gr, control = list(iter.max = 3000, eval.max = 4000)),
                  error = function(e) e)
  if (inherits(fit, "error")) {
    return(.fail_row(fam, n_sp, seed, fx$n_slope, n_rep, x_sd, slope_scale,
                     paste("nlminb:", conditionMessage(fit)), dgp_diag))
  }

  sdr <- tryCatch(TMB::sdreport(obj), error = function(e) e)
  pdHess <- if (inherits(sdr, "error")) NA else isTRUE(sdr$pdHess)
  report <- tryCatch(obj$report(), error = function(e) NULL)
  Sigma_hat <- if (is.null(report)) NULL else report$Sigma_b_dep
  if (is.null(Sigma_hat)) {
    return(.fail_row(fam, n_sp, seed, fx$n_slope, n_rep, x_sd, slope_scale,
                     "report() lacked Sigma_b_dep", dgp_diag))
  }
  slope_var_idx <- .slope_var_idx(fx$n_slope)
  ratios <- diag(Sigma_hat)[slope_var_idx] / diag(fx$Sigma_b_true)[slope_var_idx]
  ratio_out <- round(ratios, 3)
  ev_hat <- eigen(Sigma_hat, symmetric = TRUE, only.values = TRUE)$values
  ev_truth <- eigen(fx$Sigma_b_true, symmetric = TRUE, only.values = TRUE)$values
  fam_param <- .report_family_param(report, fam)
  strict <- isTRUE(fit$convergence == 0 && isTRUE(pdHess) &&
                     min(ratios, na.rm = TRUE) >= 0.5 &&
                     max(ratios, na.rm = TRUE) <= 2)
  loose <- isTRUE(fit$convergence == 0 && isTRUE(pdHess) &&
                    min(ratios, na.rm = TRUE) >= 0.4 &&
                    max(ratios, na.rm = TRUE) <= 2.5)
  reason <- .recovery_reason(fit$convergence, pdHess,
                             min(ratios, na.rm = TRUE),
                             max(ratios, na.rm = TRUE))

  data.frame(family = fam, n_slope = fx$n_slope, n_sp = n_sp, n_rep = n_rep,
             seed = seed, x_sd = x_sd, slope_scale = slope_scale,
             conv = fit$convergence, pdHess = pdHess,
             max_sigma_diff = round(max(abs(Sigma_hat - fx$Sigma_b_true)), 4),
             slope_var_ratio_1 = ratio_out[1L],
             slope_var_ratio_2 = if (length(ratio_out) >= 2L) ratio_out[2L] else NA_real_,
             slope_var_ratio_3 = if (length(ratio_out) >= 3L) ratio_out[3L] else NA_real_,
             slope_var_ratio_4 = if (length(ratio_out) >= 4L) ratio_out[4L] else NA_real_,
             slope_var_ratio_min = round(min(ratios, na.rm = TRUE), 3),
             slope_var_ratio_max = round(max(ratios, na.rm = TRUE), 3),
             slope_var_ratios = paste(ratio_out, collapse = ";"),
             sigma_eigen_min = round(min(ev_hat, na.rm = TRUE), 5),
             sigma_eigen_max = round(max(ev_hat, na.rm = TRUE), 5),
             sigma_condition = round(max(ev_hat, na.rm = TRUE) / min(ev_hat, na.rm = TRUE), 3),
             truth_condition = round(max(ev_truth, na.rm = TRUE) / min(ev_truth, na.rm = TRUE), 3),
             fit_objective = round(fit$objective, 3),
             fit_iterations = fit$iterations,
             family_param_min = fam_param[1L],
             family_param_max = fam_param[2L],
             eta_min = round(dgp_diag$eta_min, 3),
             eta_max = round(dgp_diag$eta_max, 3),
             eta_sd = round(dgp_diag$eta_sd, 3),
             x_abs_cor_max = round(dgp_diag$x_abs_cor_max, 3),
             response_mean = round(dgp_diag$response_mean, 5),
             response_min = round(dgp_diag$response_min, 5),
             response_max = round(dgp_diag$response_max, 5),
             response_zero_frac = round(dgp_diag$response_zero_frac, 3),
             response_boundary_frac = round(dgp_diag$response_boundary_frac, 3),
             strict_recovered = strict,
             loose_recovered = loose,
             failure_reason = reason,
             note = if (inherits(sdr, "error")) "sdreport failed" else "", stringsAsFactors = FALSE)
}

## ----- configurable grid -------------------------------------------------
.env_list <- function(key, default) {
  v <- Sys.getenv(key, "")
  if (!nzchar(v)) return(default)
  trimws(strsplit(v, ",")[[1]])
}
families <- .env_list("GLLVMTMB_SWEEP_FAMILIES",
                      c("gaussian", "poisson", "nbinom2", "Gamma", "Beta", "binomial", "ordinal_probit"))
s_grid   <- as.integer(.env_list("GLLVMTMB_SWEEP_SGRID", c("1")))
if (any(!s_grid %in% c(1L, 2L))) {
  stop("GLLVMTMB_SWEEP_SGRID currently supports only 1 and 2.")
}
n_grid   <- as.integer(.env_list("GLLVMTMB_SWEEP_NGRID", c("80", "150", "300", "600", "1200")))
seeds    <- as.integer(.env_list("GLLVMTMB_SWEEP_SEEDS", c("101", "202", "303")))
n_rep_grid <- as.integer(.env_list("GLLVMTMB_SWEEP_NREP", c("10")))
x_sd_grid <- as.numeric(.env_list("GLLVMTMB_SWEEP_X_SD_GRID", c("1")))
slope_scale_grid <- as.numeric(.env_list("GLLVMTMB_SWEEP_SLOPE_SCALE_GRID", c("1")))
if (any(!is.finite(x_sd_grid) | x_sd_grid <= 0)) {
  stop("GLLVMTMB_SWEEP_X_SD_GRID values must be finite and positive.")
}
if (any(!is.finite(slope_scale_grid) | slope_scale_grid <= 0)) {
  stop("GLLVMTMB_SWEEP_SLOPE_SCALE_GRID values must be finite and positive.")
}
out_csv  <- Sys.getenv("GLLVMTMB_SWEEP_OUT", "dep-identifiability-sweep-results.csv")

## gaussian is the CONTROL: it should pass (conv 0 + pdHess) at every N. If it
## does NOT, the harness itself is broken, not the identifiability question.
## A "covered" verdict for a non-Gaussian family at some N = conv 0 + pdHess +
## slope-var ratios within roughly [1/2, 2] (the validated Gaussian band).
grid <- expand.grid(family = families, n_slope = s_grid, n_sp = n_grid,
                    n_rep = n_rep_grid, seed = seeds, x_sd = x_sd_grid,
                    slope_scale = slope_scale_grid, stringsAsFactors = FALSE)
cat(sprintf("Running %d cells (%d families x %d s-grid x %d N x %d n_rep x %d seeds x %d x_sd x %d slope_scale).\n",
            nrow(grid), length(families), length(s_grid), length(n_grid),
            length(n_rep_grid), length(seeds), length(x_sd_grid),
            length(slope_scale_grid)))
for (s in s_grid) {
  for (sc in slope_scale_grid) {
    truth <- .Sigma_b_true(s, slope_scale = sc)
    chol_ok <- tryCatch({
      chol(truth)
      TRUE
    }, error = function(e) FALSE)
    if (!isTRUE(chol_ok)) {
      stop("Non-positive-definite truth covariance for s = ", s,
           ", slope_scale = ", sc, ".")
    }
    cat(sprintf("True slope variances (s=%d, slope_scale=%g): %s\n", s, sc,
              paste(round(diag(truth)[.slope_var_idx(s)], 3), collapse = ", ")))
  }
}
cat("\n")

results <- do.call(rbind, Map(function(f, ss, n, nr, seed, xsd, sc) {
  cat(sprintf("  [%-14s s=%d n_sp=%5d n_rep=%d seed=%d x_sd=%g slope_scale=%g] ...\n",
              f, ss, n, nr, seed, xsd, sc))
  r <- run_cell(f, n_sp = n, n_rep = nr, seed = seed, n_slope = ss,
                x_sd = xsd, slope_scale = sc)
  cat(sprintf("      -> conv=%s pdHess=%s reason=%s maxdiff=%s ratios=%s %s\n",
              r$conv, r$pdHess, r$failure_reason, r$max_sigma_diff,
              r$slope_var_ratios,
              if (nzchar(r$note)) paste0("[", r$note, "]") else ""))
  r
}, grid$family, grid$n_slope, grid$n_sp, grid$n_rep, grid$seed,
grid$x_sd, grid$slope_scale))

cat("\n===== IDENTIFIABILITY SWEEP RESULTS (this run's fresh seeds) =====\n")
print(results, row.names = FALSE)

## Accumulation: when a durable store is supplied (GLLVMTMB_SWEEP_STORE), prepend
## the prior rows so the written CSV + aggregate are CUMULATIVE across the
## campaign's runs. The workflow derives FRESH seeds from the run number each
## run, so rows never collide and the per-cell seed count grows through the week
## -- tightening the seed-sensitive cells (nbinom2 / ordinal_probit).
store <- Sys.getenv("GLLVMTMB_SWEEP_STORE", "")
if (nzchar(store) && file.exists(store)) {
  prev <- tryCatch(utils::read.csv(store, stringsAsFactors = FALSE), error = function(e) NULL)
  if (!is.null(prev) && nrow(prev) > 0L) {
    if (!"n_slope" %in% names(prev)) prev$n_slope <- 1L
    if (!"n_rep" %in% names(prev)) prev$n_rep <- 10L
    if (!"x_sd" %in% names(prev)) prev$x_sd <- 1
    if (!"slope_scale" %in% names(prev)) prev$slope_scale <- 1
    if (!"slope_var_ratio_min" %in% names(prev) ||
        !"slope_var_ratio_max" %in% names(prev)) {
      ratio_cols <- intersect(
        c("slope_var_ratio_1", "slope_var_ratio_2",
          "slope_var_ratio_3", "slope_var_ratio_4"),
        names(prev)
      )
      ratio_mat <- as.matrix(prev[, ratio_cols, drop = FALSE])
      prev$slope_var_ratio_min <- apply(ratio_mat, 1L, function(z) {
        if (all(is.na(z))) NA_real_ else min(z, na.rm = TRUE)
      })
      prev$slope_var_ratio_max <- apply(ratio_mat, 1L, function(z) {
        if (all(is.na(z))) NA_real_ else max(z, na.rm = TRUE)
      })
    }
    if (!"slope_var_ratios" %in% names(prev)) {
      prev$slope_var_ratios <- apply(
        prev[, intersect(c("slope_var_ratio_1", "slope_var_ratio_2",
                           "slope_var_ratio_3", "slope_var_ratio_4"),
                         names(prev)), drop = FALSE],
        1L,
        function(z) paste(z[!is.na(z)], collapse = ";")
      )
    }
    if (!"strict_recovered" %in% names(prev)) {
      prev$strict_recovered <- with(
        prev,
        conv == 0 & pdHess == TRUE &
          slope_var_ratio_min >= 0.5 & slope_var_ratio_max <= 2
      )
    }
    if (!"loose_recovered" %in% names(prev)) {
      prev$loose_recovered <- with(
        prev,
        conv == 0 & pdHess == TRUE &
          slope_var_ratio_min >= 0.4 & slope_var_ratio_max <= 2.5
      )
    }
    if (!"failure_reason" %in% names(prev)) {
      prev$failure_reason <- mapply(
        .recovery_reason, prev$conv, prev$pdHess,
        prev$slope_var_ratio_min, prev$slope_var_ratio_max,
        USE.NAMES = FALSE
      )
    }
    for (nm in setdiff(names(results), names(prev))) prev[[nm]] <- NA
    results <- rbind(prev[, names(results), drop = FALSE], results)
    cat(sprintf("Accumulated with %d prior rows from %s -> %d total rows.\n",
                nrow(prev), store, nrow(results)))
  }
}
write.csv(results, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s (%d rows)\n", out_csv, nrow(results)))

## Per-(family, s, N) verdict over ALL accumulated seeds: PD-fraction,
## recovery-within-band fraction, and seed count.
res2 <- transform(
  results,
  pd = as.integer(conv == 0 & pdHess == TRUE),
  recovered = as.integer(strict_recovered),
  loose = as.integer(loose_recovered)
)
agg_by <- c("family", "n_slope", "n_sp", "n_rep", "x_sd", "slope_scale")
agg_f <- aggregate(stats::as.formula(paste("pd ~", paste(agg_by, collapse = " + "))), res2,
                   FUN = function(z) round(mean(z, na.rm = TRUE), 3), na.action = stats::na.pass)
agg_r <- aggregate(stats::as.formula(paste("recovered ~", paste(agg_by, collapse = " + "))), res2,
                   FUN = function(z) round(mean(z, na.rm = TRUE), 3), na.action = stats::na.pass)
agg_l <- aggregate(stats::as.formula(paste("loose ~", paste(agg_by, collapse = " + "))), res2,
                   FUN = function(z) round(mean(z, na.rm = TRUE), 3), na.action = stats::na.pass)
agg_n <- aggregate(stats::as.formula(paste("pd ~", paste(agg_by, collapse = " + "))), res2,
                   FUN = function(z) sum(!is.na(z)), na.action = stats::na.pass)
agg <- Reduce(function(x, y) merge(x, y, by = agg_by),
              list(agg_f, agg_r, agg_l, agg_n))
names(agg)[length(agg_by) + seq_len(4)] <- c("pd_frac", "recovery_frac",
                                             "loose_recovery_frac", "n_seeds")
cat("\n===== CUMULATIVE FRACTION conv==0 & pdHess + strict/loose recovery (accumulated seed count) =====\n")
print(agg[do.call(order, agg[agg_by]), ], row.names = FALSE)
cat("\nIDENTIFIABILITY_SWEEP_DONE\n")
