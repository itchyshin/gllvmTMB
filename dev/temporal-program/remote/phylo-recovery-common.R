## Retained local recovery campaign: replicated AR1 temporal_indep + phylo_indep.
## Direct DGP only; it never calls production temporal simulation.
## Frozen redesign after the retained 80-series initial fixture: 160 series,
## exact same dense covariance construction rule, 16 occasions, two measures,
## three traits, unchanged truths/thresholds/optimizer, and 10 fresh seeds/cell.
root <- normalizePath(".", mustWork = TRUE)

# Loading source through pkgload in every array worker races compilation and can
# fail before the task wrapper has a chance to retain a one-row receipt.  The
# local verifier keeps that route; an allocated DRAC preflight installs the
# exact source once and workers then use the installed-package route.
load_temporal_program_package <- function(root) {
  mode <- Sys.getenv("GLLVMTMB_TEMPORAL_LOAD", "pkgload")
  if (identical(mode, "pkgload")) {
    pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  } else if (identical(mode, "installed")) {
    if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
      stop("GLLVMTMB_TEMPORAL_LOAD=installed requires gllvmTMB in R_LIBS_USER.", call. = FALSE)
    }
    suppressPackageStartupMessages(library(gllvmTMB))
    # The formula is constructed in this sourced script.  Bind provider
    # helpers here rather than depending on a search-path lookup from inside
    # the formula evaluator used by an installed package.
    for (name in c("temporal_indep", "phylo_indep")) {
      assign(name, getExportedValue("gllvmTMB", name), envir = globalenv())
    }
  } else {
    stop("GLLVMTMB_TEMPORAL_LOAD must be 'pkgload' or 'installed'.", call. = FALSE)
  }
  invisible(mode)
}

truth <- list(beta = c(.2, -.3, .1), temporal = c(.55, .42, .63)^2,
  phylo = c(.35, .28, .40)^2, residual = .30)
n_series <- 160L; n_time <- 16L; n_replicate <- 2L
series <- paste0("sp", seq_len(n_series)); traits <- paste0("t", 1:3)
Cphy <- matrix(.18, n_series, n_series)
diag(Cphy) <- 1
Cphy[abs(row(Cphy) - col(Cphy)) == 1L] <- .48
Cphy[abs(row(Cphy) - col(Cphy)) == 2L] <- .28
Cphy <- (Cphy + t(Cphy)) / 2; diag(Cphy) <- 1
dimnames(Cphy) <- list(series, series)
stopifnot(all(eigen(Cphy, symmetric = TRUE, only.values = TRUE)$values > 0))

phylo_recovery_error <- function(phi, seed, message) {
  data.frame(phi = phi, seed = seed, terminal = "error",
    convergence = NA_integer_, pass_1_convergence = NA_integer_, pass_2_convergence = NA_integer_,
    pass_2_accepted = NA, max_gradient = NA_real_, objective = NA_real_, phi_estimate = NA_real_,
    temporal_1 = NA_real_, temporal_2 = NA_real_, temporal_3 = NA_real_, phylo_1 = NA_real_,
    phylo_2 = NA_real_, phylo_3 = NA_real_, beta_1 = NA_real_, beta_2 = NA_real_, beta_3 = NA_real_,
    error_message = message, stringsAsFactors = FALSE)
}

simulate_fixture <- function(phi, seed) {
  set.seed(seed)
  U <- t(chol(Cphy)) %*% sweep(matrix(rnorm(n_series * 3L), n_series, 3L), 2L,
    sqrt(truth$phylo), "*")
  Z <- array(0, c(n_series, n_time, 3L))
  for (j in 1:3) for (g in seq_len(n_series)) {
    Z[g, 1L, j] <- rnorm(1L, sd = sqrt(truth$temporal[j]))
    for (tt in 2:n_time) Z[g, tt, j] <- phi * Z[g, tt - 1L, j] +
      sqrt(1 - phi^2) * rnorm(1L, sd = sqrt(truth$temporal[j]))
  }
  data <- expand.grid(series = series, occasion = seq_len(n_time), trait = traits,
    stringsAsFactors = FALSE)
  g <- match(data$series, series); tt <- data$occasion; j <- match(data$trait, traits)
  data$mean_value <- truth$beta[j] + Z[cbind(g, tt, j)] + U[cbind(g, j)]
  data <- data[rep(seq_len(nrow(data)), each = n_replicate), , drop = FALSE]
  data$measurement <- rep(c("m1", "m2"), times = nrow(data) / n_replicate)
  data$value <- data$mean_value + rnorm(nrow(data), sd = truth$residual)
  data$mean_value <- NULL
  data
}

fit_one <- function(phi, seed) {
  started <- proc.time()[["elapsed"]]
  d <- simulate_fixture(phi, seed)
  out <- tryCatch({
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait +
        temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
        phylo_indep(0 + trait | series, vcv = Cphy),
      data = d, unit = "series", cluster = "series", family = gaussian(), silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 3000, reltol = 1e-14)),
        optimizer_passes = 2L)
    ))
    h <- fit$optimizer_pass_history
    if (!is.data.frame(h) || nrow(h) != 2L || !all(h$pass == 1:2))
      stop("The requested two-pass optimizer history was not retained.", call. = FALSE)
    temporal <- extract_temporal(fit); beta <- unname(fit$opt$par[names(fit$opt$par) == "b_fix"])
    p <- fit$tmb_obj$env$parList(fit$opt$par)
    data.frame(phi = phi, seed = seed, terminal = "success", convergence = fit$opt$convergence,
      pass_1_convergence = h$convergence[[1L]], pass_2_convergence = h$convergence[[2L]],
      pass_2_accepted = h$accepted[[2L]], max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))),
      objective = fit$opt$objective, phi_estimate = temporal$time$value[[1L]],
      temporal_1 = temporal$variance$value[[1L]], temporal_2 = temporal$variance$value[[2L]], temporal_3 = temporal$variance$value[[3L]],
      phylo_1 = p$theta_rr_phy[1L]^2, phylo_2 = p$theta_rr_phy[2L]^2, phylo_3 = p$theta_rr_phy[3L]^2,
      beta_1 = beta[[1L]], beta_2 = beta[[2L]], beta_3 = beta[[3L]],
      error_message = NA_character_, stringsAsFactors = FALSE)
  }, error = function(e) phylo_recovery_error(phi, seed, conditionMessage(e)))
  out$elapsed_seconds <- proc.time()[["elapsed"]] - started; out
}
