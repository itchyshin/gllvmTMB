## Driver: launches the full O3 recovery grid (9 cells x 50 seeds = 450
## fits) via parallel::mclapply, one persistent R session (package loaded
## once, forked workers share the loaded DLL). Run under nohup on Totoro.
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
  expand.grid(family = "zi_poisson",  n_site = c(150L, 200L, 400L), stringsAsFactors = FALSE),
  expand.grid(family = "zi_nbinom2",  n_site = c(200L, 400L, 800L), stringsAsFactors = FALSE),
  expand.grid(family = "zi_binomial", n_site = c(150L, 250L, 500L), stringsAsFactors = FALSE)
)
seeds <- 1:50

jobs <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  data.frame(family = cells$family[i], n_site = cells$n_site[i], seed = seeds)
}))
cat("total jobs:", nrow(jobs), "\n")

script_dir <- dirname(sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)))
campaign_script <- file.path(script_dir, "campaign.R")

run_one <- function(i) {
  fam <- jobs$family[i]; n <- jobs$n_site[i]; sd <- jobs$seed[i]
  out_file <- file.path(out_dir, sprintf("%s_n%d_seed%d.rds", fam, n, sd))
  if (file.exists(out_file)) return(invisible(NULL))
  source_env <- new.env()
  assign("commandArgs", function(trailingOnly = TRUE) c(fam, as.character(n), as.character(sd), out_dir, lib_path), envir = source_env)
  ## Run campaign.R's body in a fresh environment reusing the already-loaded
  ## gllvmTMB session (fork), rather than re-spawning Rscript per job.
  local({
    args <- c(fam, as.character(n), as.character(sd), out_dir, lib_path)
    family_name <- args[[1]]; n_site <- as.integer(args[[2]]); seed <- as.integer(args[[3]])
    out_dir_l <- args[[4]]
    dir.create(out_dir_l, recursive = TRUE, showWarnings = FALSE)

    n_trait <- 6L
    beta_true   <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)
    beta_true_b <- c(0.3, -0.2, 0.5, -0.4, 0.2, 0.1)
    lambda_true <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)
    pi_true     <- c(0.1, 0.2, 0.3, 0.4, 0.15, 0.25)
    phi_true    <- c(4, 5, 3, 6, 4, 5)
    Nt          <- 10L

    set.seed(seed)
    u <- rnorm(n_site)

    if (family_name == "zi_poisson") {
      eta <- outer(u, lambda_true) + matrix(beta_true, n_site, n_trait, byrow = TRUE)
      mu <- exp(eta)
      z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
      Y <- matrix(rpois(n_site * n_trait, mu), n_site, n_trait) * z
      dat <- data.frame(site = factor(rep(seq_len(n_site), n_trait)),
                         trait = factor(rep(seq_len(n_trait), each = n_site)), y = as.vector(Y))
      form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
      fam_obj <- zi_poisson(); beta_ref <- beta_true
    } else if (family_name == "zi_nbinom2") {
      eta <- outer(u, lambda_true) + matrix(beta_true, n_site, n_trait, byrow = TRUE)
      mu <- exp(eta)
      z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
      Y <- matrix(rnbinom(n_site * n_trait, mu = as.vector(mu), size = rep(phi_true, each = n_site)),
                  n_site, n_trait) * z
      dat <- data.frame(site = factor(rep(seq_len(n_site), n_trait)),
                         trait = factor(rep(seq_len(n_trait), each = n_site)), y = as.vector(Y))
      form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
      fam_obj <- zi_nbinom2(); beta_ref <- beta_true
    } else if (family_name == "zi_binomial") {
      eta <- outer(u, lambda_true) + matrix(beta_true_b, n_site, n_trait, byrow = TRUE)
      p <- stats::plogis(eta)
      z <- matrix(rbinom(n_site * n_trait, 1, rep(1 - pi_true, each = n_site)), n_site, n_trait)
      succ <- matrix(rbinom(n_site * n_trait, Nt, as.vector(p)), n_site, n_trait) * z
      dat <- data.frame(site = factor(rep(seq_len(n_site), n_trait)),
                         trait = factor(rep(seq_len(n_trait), each = n_site)), succ = as.vector(succ))
      dat$fail <- Nt - dat$succ
      form <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
      fam_obj <- zi_binomial(); beta_ref <- beta_true_b
    }

    t0 <- proc.time()[["elapsed"]]
    fit <- tryCatch(
      suppressMessages(suppressWarnings(gllvmTMB(
        form, data = dat, family = fam_obj, unit = "site",
        control = gllvmTMBcontrol(se = FALSE)
      ))), error = function(e) e)
    runtime <- proc.time()[["elapsed"]] - t0

    if (inherits(fit, "error")) {
      result <- list(family = family_name, n_site = n_site, seed = seed, runtime = runtime,
                      error = conditionMessage(fit), convergence = NA_integer_,
                      max_gradient = NA_real_, pd_hessian = NA)
    } else {
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
      phi_hat <- NULL; phi_relerr <- NULL
      if (family_name == "zi_nbinom2") {
        phi_hat <- fit$report$phi_nbinom2
        phi_relerr <- abs(phi_hat - phi_true) / phi_true
      }
      max_gradient <- fit$fit_health$max_gradient
      pd_hessian <- fit$fit_health$pd_hessian
      result <- list(family = family_name, n_site = n_site, seed = seed, runtime = runtime,
                      error = NA_character_, convergence = fit$opt$convergence,
                      max_gradient = max_gradient, pd_hessian = pd_hessian,
                      beta_true = beta_ref, bfix = bfix, int_err = int_err,
                      pi_true = pi_true, zi_hat = zi_hat, zi_err = zi_err,
                      lambda_true = lambda_true, rel_frob = rel_frob,
                      phi_true = if (family_name == "zi_nbinom2") phi_true else NA,
                      phi_hat = phi_hat, phi_relerr = phi_relerr)
    }
    saveRDS(result, out_file)
  })
  invisible(NULL)
}

res <- parallel::mclapply(seq_len(nrow(jobs)), run_one, mc.cores = mc_cores, mc.preschedule = FALSE)
cat("DONE\n")
