## Driver: launches the full Arc F recovery grid (2 families x 3 sizes x
## 50 seeds = 300 fits) via parallel::mclapply, one persistent R session
## (package loaded once, forked workers share the loaded DLL). Run under
## nohup on Totoro.
##
## Usage: Rscript run_grid.R <out_dir> <lib_path> <mc_cores>

args <- commandArgs(trailingOnly = TRUE)
out_dir  <- args[[1]]
lib_path <- args[[2]]
mc_cores <- as.integer(args[[3]])

.libPaths(c(lib_path, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

cells <- rbind(
  expand.grid(family = "ordinal_logit",    size = c(300L, 600L, 1200L), stringsAsFactors = FALSE),
  expand.grid(family = "censored_poisson", size = c(200L, 400L, 800L),  stringsAsFactors = FALSE)
)
seeds <- 1:50

jobs <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  data.frame(family = cells$family[i], size = cells$size[i], seed = seeds)
}))
cat("total jobs:", nrow(jobs), "\n")

## ---- DGP constants (verbatim from the shipped tests -- see campaign.R
## for the source-of-truth comment) ----
.ordlogit_taus        <- c(0, 0.7, 1.4)
.ordlogit_n_traits    <- 4L
.ordlogit_n_rep       <- 2L
.ordlogit_trait_names <- paste0("t", seq_len(.ordlogit_n_traits))
.ordlogit_alpha       <- c(0.2, -0.1, 0.15, 0.0)
.ordlogit_lambda      <- c(1.6, 1.3, -1.2, 1.1)
.ordlogit_bar_median_rel_loading <- 0.25
.ordlogit_bar_max_rel_loading    <- 0.40
.ordlogit_bar_max_abs_cutpoint   <- 0.30

.cpois_n_trait     <- 6L
.cpois_beta_true   <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)
.cpois_lambda_true <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)
.cpois_C           <- 6
.cpois_bar_max_int_err <- 0.15
.cpois_bar_rel_frob    <- 0.25

.ordlogit_ordinalise <- function(ystar) {
  1L + (ystar > .ordlogit_taus[1L]) + (ystar > .ordlogit_taus[2L]) +
    (ystar > .ordlogit_taus[3L])
}

run_one <- function(i) {
  fam <- jobs$family[i]; sz <- jobs$size[i]; sd <- jobs$seed[i]
  out_file <- file.path(out_dir, sprintf("%s_n%d_seed%d.rds", fam, sz, sd))
  if (file.exists(out_file)) return(invisible(NULL))

  if (fam == "ordinal_logit") {
    set.seed(sd)
    n_unit <- sz
    f <- stats::rnorm(n_unit, 0, 1)
    rows <- vector("list", n_unit * .ordlogit_n_traits * .ordlogit_n_rep)
    k <- 1L
    for (i2 in seq_len(n_unit)) {
      for (t in seq_len(.ordlogit_n_traits)) {
        for (r in seq_len(.ordlogit_n_rep)) {
          ystar <- .ordlogit_alpha[t] + .ordlogit_lambda[t] * f[i2] +
            stats::rlogis(1L, 0, 1)
          rows[[k]] <- data.frame(
            unit = i2, trait = .ordlogit_trait_names[t],
            value = .ordlogit_ordinalise(ystar)
          )
          k <- k + 1L
        }
      }
    }
    df <- do.call(rbind, rows)
    df$unit <- factor(df$unit, levels = seq_len(n_unit))
    df$trait <- factor(df$trait, levels = .ordlogit_trait_names)

    t0 <- proc.time()[["elapsed"]]
    fit <- tryCatch(
      suppressMessages(suppressWarnings(gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | unit, d = 1), df,
        unit = "unit", family = ordinal_logit()
      ))),
      error = function(e) e
    )
    runtime <- proc.time()[["elapsed"]] - t0
    base <- list(family = fam, size = sz, seed = sd, runtime = runtime)

    if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
      result <- c(base, list(
        error = if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB_multi return",
        convergence = NA_integer_, max_gradient = NA_real_, pd_hessian = NA
      ))
    } else {
      Lhat <- as.numeric(fit$report$Lambda_B)
      rel_err <- abs(abs(Lhat) - abs(.ordlogit_lambda)) / abs(.ordlogit_lambda)
      cuts <- extract_cutpoints(fit)
      true_free <- rep(.ordlogit_taus[-1L], .ordlogit_n_traits)
      abs_cut_err <- abs(cuts$tau_estimate - true_free)
      result <- c(base, list(
        error = NA_character_,
        convergence = fit$opt$convergence,
        max_gradient = fit$fit_health$max_gradient,
        pd_hessian = fit$fit_health$pd_hessian,
        median_rel_loading = stats::median(rel_err),
        max_rel_loading = max(rel_err),
        max_abs_cutpoint = max(abs_cut_err),
        bar_median_rel_loading = .ordlogit_bar_median_rel_loading,
        bar_max_rel_loading = .ordlogit_bar_max_rel_loading,
        bar_max_abs_cutpoint = .ordlogit_bar_max_abs_cutpoint
      ))
    }
  } else if (fam == "censored_poisson") {
    set.seed(sd)
    n_site <- sz
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
      ))), error = function(e) e)
    runtime <- proc.time()[["elapsed"]] - t0
    base <- list(family = fam, size = sz, seed = sd, runtime = runtime, frac_censored = frac_cens)

    if (inherits(fit, "error")) {
      result <- c(base, list(
        error = conditionMessage(fit), convergence = NA_integer_,
        max_gradient = NA_real_, pd_hessian = NA
      ))
    } else {
      par <- fit$tmb_obj$env$last.par.best
      bfix <- unname(par[names(par) == "b_fix"])
      int_err <- abs(bfix - .cpois_beta_true)
      L <- tryCatch(extract_ordination(fit, level = "unit")$loadings, error = function(e) NULL)
      rel_frob <- NA_real_
      if (!is.null(L)) {
        proc_c <- compare_loadings(L, matrix(.cpois_lambda_true, ncol = 1))
        rel_frob <- proc_c$frobenius / sqrt(sum(.cpois_lambda_true^2))
      }
      result <- c(base, list(
        error = NA_character_,
        convergence = fit$opt$convergence,
        max_gradient = fit$fit_health$max_gradient,
        pd_hessian = fit$fit_health$pd_hessian,
        beta_true = .cpois_beta_true, bfix = bfix, int_err = int_err,
        max_int_err = max(int_err),
        lambda_true = .cpois_lambda_true, rel_frob = rel_frob,
        bar_max_int_err = .cpois_bar_max_int_err,
        bar_rel_frob = .cpois_bar_rel_frob
      ))
    }
  } else {
    stop("unknown family: ", fam)
  }

  saveRDS(result, out_file)
  invisible(NULL)
}

res <- parallel::mclapply(seq_len(nrow(jobs)), run_one, mc.cores = mc_cores, mc.preschedule = FALSE)
cat("DONE\n")
