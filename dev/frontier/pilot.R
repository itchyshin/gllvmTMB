#!/usr/bin/env Rscript
## Pilot timing run: exercise each arm once at the SMALLEST and LARGEST grid
## cells to estimate per-fit wall-clock before committing to the full 3-seed
## grid. Not part of the recorded frontier.csv.

suppressPackageStartupMessages({ library(stats) })
`%||%` <- function(x, y) if (is.null(x)) y else x
root <- normalizePath("/private/tmp/gllvmtmb-va-wiring-20260726", mustWork = TRUE)
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = FALSE))
source(file.path(root, "dev", "va-eva-comparator.R"), local = .GlobalEnv)
va_eva_source_private_engines(root, envir = .GlobalEnv)

build_fixture <- function(family = c("poisson", "bernoulli"),
                          n_units, n_traits, d = 2L, seed) {
  family <- match.arg(family)
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(n_traits))
  Lambda_true <- matrix(stats::rnorm(n_traits * d, sd = 0.7), n_traits, d)
  alpha_true <- stats::rnorm(n_traits, mean = if (family == "poisson") 0.2 else 0, sd = 0.3)
  Z_true <- matrix(stats::rnorm(n_units * d), n_units, d)
  eta <- matrix(alpha_true, n_units, n_traits, byrow = TRUE) + Z_true %*% t(Lambda_true)
  Y <- switch(family,
    poisson = matrix(stats::rpois(n_units * n_traits, lambda = exp(eta)), n_units, n_traits),
    bernoulli = matrix(stats::rbinom(n_units * n_traits, size = 1, prob = stats::plogis(eta)), n_units, n_traits))
  colnames(Y) <- trait_names
  long <- data.frame(unit = factor(rep(seq_len(n_units), times = n_traits)),
                     trait = factor(rep(trait_names, each = n_units), levels = trait_names),
                     value = as.vector(Y))
  df_wide <- as.data.frame(Y); df_wide$unit <- factor(seq_len(n_units))
  list(Y = Y, long = long, df_wide = df_wide, trait_names = trait_names,
       n_units = n_units, n_traits = n_traits, q = d, family = family, seed = seed)
}

time_it <- function(label, expr) {
  t0 <- proc.time()[["elapsed"]]
  v <- tryCatch(expr, error = function(e) { cat(sprintf("  %s ERROR: %s\n", label, conditionMessage(e))); NULL })
  cat(sprintf("  %-14s %.2fs\n", label, proc.time()[["elapsed"]] - t0))
  v
}

for (cellname in c("small (p=8,n=40)", "large (p=40,n=100)")) {
  p <- if (grepl("small", cellname)) 8L else 40L
  n <- if (grepl("small", cellname)) 40L else 100L
  cat(sprintf("\n=== %s, poisson ===\n", cellname))
  fx <- build_fixture("poisson", n_units = n, n_traits = p, seed = 1L)
  X <- stats::model.matrix(~ 0 + trait, fx$long)
  time_it("GH-VA", .approximation_engine_fit(engine = "va_r3", y = fx$long$value,
           n_trials = rep(1L, nrow(fx$long)), X = X, unit_id = as.integer(fx$long$unit),
           trait_id = as.integer(fx$long$trait), q = fx$q, family = "poisson", link = "log", silent = TRUE))
  fml <- stats::as.formula(sprintf("traits(%s) ~ 1 + latent(1 | unit, d = %d, unique = FALSE)",
                                   paste(fx$trait_names, collapse = ", "), fx$q))
  time_it("Laplace", gllvmTMB::gllvmTMB(fml, data = fx$df_wide, unit = "unit", family = stats::poisson(),
           control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)))
  time_it("gllvm_VA", gllvm::gllvm(y = fx$Y, num.lv = fx$q, family = "poisson", method = "VA",
           seed = 1L, n.init = 1L, sd.errors = FALSE, control = list(max.iter = 2000L, maxit = 2000L)))

  cat(sprintf("\n=== %s, bernoulli ===\n", cellname))
  fx <- build_fixture("bernoulli", n_units = n, n_traits = p, seed = 2L)
  X <- stats::model.matrix(~ 0 + trait, fx$long)
  time_it("GH-VA", .approximation_engine_fit(engine = "va_r3", y = fx$long$value,
           n_trials = rep(1L, nrow(fx$long)), X = X, unit_id = as.integer(fx$long$unit),
           trait_id = as.integer(fx$long$trait), q = fx$q, family = "binomial", link = "logit", silent = TRUE))
  fml <- stats::as.formula(sprintf("traits(%s) ~ 1 + latent(1 | unit, d = %d, unique = FALSE)",
                                   paste(fx$trait_names, collapse = ", "), fx$q))
  time_it("Laplace", gllvmTMB::gllvmTMB(fml, data = fx$df_wide, unit = "unit", family = stats::binomial(),
           control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)))
  time_it("gllvm_JJ", gllvm::gllvm(y = fx$Y, num.lv = fx$q, family = "binomial", link = "logit", method = "VA",
           seed = 1L, n.init = 1L, sd.errors = FALSE, control = list(max.iter = 2000L, maxit = 2000L)))
  time_it("gllvm_EVA", gllvm::gllvm(y = fx$Y, num.lv = fx$q, family = "binomial", link = "logit", method = "EVA",
           seed = 1L, n.init = 1L, sd.errors = FALSE, control = list(max.iter = 2000L, maxit = 2000L)))
}
cat("\nPilot done.\n")
