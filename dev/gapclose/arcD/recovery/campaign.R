## Arc O3: multi-seed recovery evidence for the three zero-inflated
## families (zi_poisson, zi_nbinom2, zi_binomial). DGP lifted verbatim
## from tests/testthat/test-zi-recovery.R (rank-1 latent, 6 traits,
## per-trait zero probabilities 0.1-0.4) -- NOT re-invented. Runs one
## (family, n_site, seed) fit per call; writes one RDS with truth,
## estimates, per-trait errors, and fit diagnostics.
##
## Usage: Rscript campaign.R <family> <n_site> <seed> <out_dir> <lib_path>
##   family  : "zi_poisson" | "zi_nbinom2" | "zi_binomial"
##   n_site  : integer cell size
##   seed    : integer RNG seed
##   out_dir : directory to write <family>_n<n_site>_seed<seed>.rds into
##   lib_path: private library holding the pinned gllvmTMB build

args <- commandArgs(trailingOnly = TRUE)
family_name <- args[[1]]
n_site      <- as.integer(args[[2]])
seed        <- as.integer(args[[3]])
out_dir     <- args[[4]]
lib_path    <- args[[5]]

.libPaths(c(lib_path, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

n_trait <- 6L
beta_true   <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)     ## zi_poisson / zi_nbinom2 (log scale)
beta_true_b <- c(0.3, -0.2, 0.5, -0.4, 0.2, 0.1)   ## zi_binomial (logit scale)
lambda_true <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)
pi_true     <- c(0.1, 0.2, 0.3, 0.4, 0.15, 0.25)
phi_true    <- c(4, 5, 3, 6, 4, 5)                 ## zi_nbinom2 only
Nt          <- 10L                                 ## zi_binomial trials

set.seed(seed)

simulate_fit <- function() {
  u <- rnorm(n_site)

  if (family_name == "zi_poisson") {
    eta <- outer(u, lambda_true) + matrix(beta_true, n_site, n_trait, byrow = TRUE)
    mu <- exp(eta)
    z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
    Y <- matrix(rpois(n_site * n_trait, mu), n_site, n_trait) * z
    dat <- data.frame(
      site  = factor(rep(seq_len(n_site), n_trait)),
      trait = factor(rep(seq_len(n_trait), each = n_site)),
      y     = as.vector(Y)
    )
    form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
    fam <- zi_poisson()
    beta_ref <- beta_true
  } else if (family_name == "zi_nbinom2") {
    eta <- outer(u, lambda_true) + matrix(beta_true, n_site, n_trait, byrow = TRUE)
    mu <- exp(eta)
    z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
    Y <- matrix(
      rnbinom(n_site * n_trait, mu = as.vector(mu), size = rep(phi_true, each = n_site)),
      n_site, n_trait
    ) * z
    dat <- data.frame(
      site  = factor(rep(seq_len(n_site), n_trait)),
      trait = factor(rep(seq_len(n_trait), each = n_site)),
      y     = as.vector(Y)
    )
    form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
    fam <- zi_nbinom2()
    beta_ref <- beta_true
  } else if (family_name == "zi_binomial") {
    eta <- outer(u, lambda_true) + matrix(beta_true_b, n_site, n_trait, byrow = TRUE)
    p <- stats::plogis(eta)
    z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
    succ <- matrix(rbinom(n_site * n_trait, Nt, as.vector(p)), n_site, n_trait) * z
    dat <- data.frame(
      site  = factor(rep(seq_len(n_site), n_trait)),
      trait = factor(rep(seq_len(n_trait), each = n_site)),
      succ  = as.vector(succ)
    )
    dat$fail <- Nt - dat$succ
    form <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
    fam <- zi_binomial()
    beta_ref <- beta_true_b
  } else {
    stop("unknown family_name: ", family_name)
  }

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      form, data = dat, family = fam, unit = "site",
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    error = function(e) e
  )
  runtime <- proc.time()[["elapsed"]] - t0

  if (inherits(fit, "error")) {
    return(list(
      family = family_name, n_site = n_site, seed = seed, runtime = runtime,
      error = conditionMessage(fit), convergence = NA_integer_,
      max_gradient = NA_real_, pd_hessian = NA
    ))
  }

  par <- fit$tmb_obj$env$last.par.best
  bfix <- unname(par[names(par) == "b_fix"])
  int_err <- abs(bfix - beta_ref)

  zi_hat <- fit$report$zi
  zi_err <- abs(zi_hat - pi_true)

  L <- tryCatch(extract_ordination(fit, level = "unit")$loadings, error = function(e) NULL)
  rel_frob <- NA_real_
  if (!is.null(L)) {
    proc_c <- compare_loadings(L, matrix(lambda_true, ncol = 1))
    rel_frob <- proc_c$frobenius / sqrt(sum(lambda_true^2))
  }

  phi_hat <- NULL
  phi_relerr <- NULL
  if (family_name == "zi_nbinom2") {
    phi_hat <- fit$report$phi_nbinom2
    phi_relerr <- abs(phi_hat - phi_true) / phi_true
  }

  max_gradient <- fit$fit_health$max_gradient
  pd_hessian <- fit$fit_health$pd_hessian

  list(
    family = family_name, n_site = n_site, seed = seed, runtime = runtime,
    error = NA_character_,
    convergence = fit$opt$convergence,
    max_gradient = max_gradient,
    pd_hessian = pd_hessian,
    beta_true = beta_ref, bfix = bfix, int_err = int_err,
    pi_true = pi_true, zi_hat = zi_hat, zi_err = zi_err,
    lambda_true = lambda_true, rel_frob = rel_frob,
    phi_true = if (family_name == "zi_nbinom2") phi_true else NA,
    phi_hat = phi_hat, phi_relerr = phi_relerr
  )
}

result <- simulate_fit()
out_file <- file.path(out_dir, sprintf("%s_n%d_seed%d.rds", family_name, n_site, seed))
saveRDS(result, out_file)
cat("wrote", out_file, "runtime", result$runtime, "conv", result$convergence, "\n")
