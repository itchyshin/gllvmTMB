## Arc F: multi-seed recovery evidence for two newly-admitted families,
## ordinal_logit (FAM-24) and censored_poisson (FAM-25). DGPs lifted
## VERBATIM from tests/testthat/test-ordinal-logit.R (the .ordlogit_*
## block) and tests/testthat/test-censored-poisson.R (the known-DGP
## recovery block) -- NOT re-invented. Runs one (family, size, seed) fit
## per call; writes one RDS with truth, estimates, per-metric errors, and
## fit diagnostics.
##
## Usage: Rscript campaign.R <family> <size> <seed> <out_dir> <lib_path>
##   family  : "ordinal_logit" | "censored_poisson"
##   size    : integer cell size (n_unit for ordinal_logit, n_site for
##             censored_poisson)
##   seed    : integer RNG seed
##   out_dir : directory to write <family>_n<size>_seed<seed>.rds into
##   lib_path: private library holding the pinned gllvmTMB build
##
## Deliberate deviation from the shipped censored_poisson test: that test
## fits with control = gllvmTMBcontrol(se = FALSE) (skips the Hessian, so
## PD-ness cannot be reported). This campaign uses the package DEFAULT
## (se = TRUE, gllvmTMBcontrol()'s own default) for BOTH families, so
## pd_hessian can be reported for both. Point estimates are unaffected by
## se; only whether sdreport() runs.

args <- commandArgs(trailingOnly = TRUE)
family_name <- args[[1]]
size        <- as.integer(args[[2]])
seed        <- as.integer(args[[3]])
out_dir     <- args[[4]]
lib_path    <- args[[5]]

.libPaths(c(lib_path, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## ---- ordinal_logit DGP constants (tests/testthat/test-ordinal-logit.R,
## the .ordlogit_* block) ----
.ordlogit_taus        <- c(0, 0.7, 1.4)
.ordlogit_n_traits    <- 4L
.ordlogit_n_rep       <- 2L
.ordlogit_trait_names <- paste0("t", seq_len(.ordlogit_n_traits))
.ordlogit_alpha       <- c(0.2, -0.1, 0.15, 0.0)
.ordlogit_lambda      <- c(1.6, 1.3, -1.2, 1.1)
.ordlogit_bar_median_rel_loading <- 0.25
.ordlogit_bar_max_rel_loading    <- 0.40
.ordlogit_bar_max_abs_cutpoint   <- 0.30

.ordlogit_ordinalise <- function(ystar) {
  1L + (ystar > .ordlogit_taus[1L]) + (ystar > .ordlogit_taus[2L]) +
    (ystar > .ordlogit_taus[3L])
}

.ordlogit_sim <- function(n_unit, seed) {
  set.seed(seed)
  f <- stats::rnorm(n_unit, 0, 1)
  rows <- vector("list", n_unit * .ordlogit_n_traits * .ordlogit_n_rep)
  k <- 1L
  for (i in seq_len(n_unit)) {
    for (t in seq_len(.ordlogit_n_traits)) {
      for (r in seq_len(.ordlogit_n_rep)) {
        ystar <- .ordlogit_alpha[t] + .ordlogit_lambda[t] * f[i] +
          stats::rlogis(1L, 0, 1)
        rows[[k]] <- data.frame(
          unit = i, trait = .ordlogit_trait_names[t],
          value = .ordlogit_ordinalise(ystar)
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$unit <- factor(df$unit, levels = seq_len(n_unit))
  df$trait <- factor(df$trait, levels = .ordlogit_trait_names)
  df
}

## ---- censored_poisson DGP constants
## (tests/testthat/test-censored-poisson.R, known-DGP recovery block) ----
.cpois_n_trait    <- 6L
.cpois_beta_true  <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)
.cpois_lambda_true <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)
.cpois_C          <- 6
.cpois_bar_max_int_err <- 0.15
.cpois_bar_rel_frob    <- 0.25

run_ordinal_logit <- function(n_unit, seed) {
  df <- .ordlogit_sim(n_unit, seed)
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1), df,
      unit = "unit", family = ordinal_logit()
    ))),
    error = function(e) e
  )
  runtime <- proc.time()[["elapsed"]] - t0

  base <- list(family = "ordinal_logit", size = n_unit, seed = seed, runtime = runtime)

  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    return(c(base, list(
      error = if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB_multi return",
      convergence = NA_integer_, max_gradient = NA_real_, pd_hessian = NA
    )))
  }

  Lhat <- as.numeric(fit$report$Lambda_B)
  rel_err <- abs(abs(Lhat) - abs(.ordlogit_lambda)) / abs(.ordlogit_lambda)
  cuts <- extract_cutpoints(fit)
  true_free <- rep(.ordlogit_taus[-1L], .ordlogit_n_traits)
  abs_cut_err <- abs(cuts$tau_estimate - true_free)

  max_gradient <- fit$fit_health$max_gradient
  pd_hessian <- fit$fit_health$pd_hessian

  c(base, list(
    error = NA_character_,
    convergence = fit$opt$convergence,
    max_gradient = max_gradient,
    pd_hessian = pd_hessian,
    median_rel_loading = stats::median(rel_err),
    max_rel_loading = max(rel_err),
    max_abs_cutpoint = max(abs_cut_err),
    bar_median_rel_loading = .ordlogit_bar_median_rel_loading,
    bar_max_rel_loading = .ordlogit_bar_max_rel_loading,
    bar_max_abs_cutpoint = .ordlogit_bar_max_abs_cutpoint
  ))
}

run_censored_poisson <- function(n_site, seed) {
  set.seed(seed)
  u <- rnorm(n_site)
  eta <- outer(u, .cpois_lambda_true) + matrix(.cpois_beta_true, n_site, .cpois_n_trait, byrow = TRUE)
  mu <- exp(eta)
  Y_true <- matrix(stats::rpois(n_site * .cpois_n_trait, mu), n_site, .cpois_n_trait)
  censored <- Y_true >= .cpois_C
  Y_obs <- ifelse(censored, .cpois_C, Y_true)

  dat <- data.frame(
    site     = factor(rep(seq_len(n_site), .cpois_n_trait)),
    trait    = factor(rep(seq_len(.cpois_n_trait), each = n_site)),
    y        = as.vector(Y_obs),
    censored = as.integer(as.vector(censored))
  )
  frac_cens <- mean(dat$censored)

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      cbind(y, censored) ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat, family = censored_poisson(), unit = "site"
      ## control = gllvmTMBcontrol() default (se = TRUE) -- deliberate
      ## deviation from the shipped test's se = FALSE, so pd_hessian can
      ## be reported. Point estimates unaffected.
    ))),
    error = function(e) e
  )
  runtime <- proc.time()[["elapsed"]] - t0

  base <- list(family = "censored_poisson", size = n_site, seed = seed, runtime = runtime,
               frac_censored = frac_cens)

  if (inherits(fit, "error")) {
    return(c(base, list(
      error = conditionMessage(fit), convergence = NA_integer_,
      max_gradient = NA_real_, pd_hessian = NA
    )))
  }

  par <- fit$tmb_obj$env$last.par.best
  bfix <- unname(par[names(par) == "b_fix"])
  int_err <- abs(bfix - .cpois_beta_true)

  L <- tryCatch(extract_ordination(fit, level = "unit")$loadings, error = function(e) NULL)
  rel_frob <- NA_real_
  if (!is.null(L)) {
    proc_c <- compare_loadings(L, matrix(.cpois_lambda_true, ncol = 1))
    rel_frob <- proc_c$frobenius / sqrt(sum(.cpois_lambda_true^2))
  }

  max_gradient <- fit$fit_health$max_gradient
  pd_hessian <- fit$fit_health$pd_hessian

  c(base, list(
    error = NA_character_,
    convergence = fit$opt$convergence,
    max_gradient = max_gradient,
    pd_hessian = pd_hessian,
    beta_true = .cpois_beta_true, bfix = bfix, int_err = int_err,
    max_int_err = max(int_err),
    lambda_true = .cpois_lambda_true, rel_frob = rel_frob,
    bar_max_int_err = .cpois_bar_max_int_err,
    bar_rel_frob = .cpois_bar_rel_frob
  ))
}

result <- if (family_name == "ordinal_logit") {
  run_ordinal_logit(size, seed)
} else if (family_name == "censored_poisson") {
  run_censored_poisson(size, seed)
} else {
  stop("unknown family_name: ", family_name)
}

out_file <- file.path(out_dir, sprintf("%s_n%d_seed%d.rds", family_name, size, seed))
saveRDS(result, out_file)
cat("wrote", out_file, "runtime", result$runtime, "conv", result$convergence, "\n")
