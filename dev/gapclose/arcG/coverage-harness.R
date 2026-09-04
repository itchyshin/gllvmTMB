## Shared helpers for arcG ordination_uncertainty() coverage campaign.
## Scores via extract_latent_scores() ONLY; uncertainty via ordination_uncertainty().
## Design: dev/gapclose/arcG/coverage-design.md

## ---- grid constants (Section 4) ----
Lambda_B_K1_4 <- matrix(c(0.9, 0.6, -0.4, 0.5), nrow = 4, ncol = 1)
Lambda_B_K2_4 <- matrix(c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2), nrow = 4, ncol = 2)

## n_traits = 8 cell: one fixed draw appended to K2 loadings (Section 4).
set.seed(99001)
extra4 <- matrix(runif(8, 0.3, 1.0) * sample(c(-1, 1), 8, replace = TRUE), nrow = 4, ncol = 2)
Lambda_B_K2_8 <- rbind(Lambda_B_K2_4, extra4)

arcG_grid <- function() {
  cells <- list(
    list(id = 1L, label = "cell01_d1_n40_t4",  n_sites = 40L,  n_traits = 4L, d = 1L),
    list(id = 2L, label = "cell02_d1_n80_t4",  n_sites = 80L,  n_traits = 4L, d = 1L),
    list(id = 3L, label = "cell03_d1_n160_t4", n_sites = 160L, n_traits = 4L, d = 1L),
    list(id = 4L, label = "cell04_d1_n320_t4", n_sites = 320L, n_traits = 4L, d = 1L),
    list(id = 5L, label = "cell05_d2_n40_t4",  n_sites = 40L,  n_traits = 4L, d = 2L),
    list(id = 6L, label = "cell06_d2_n80_t4",  n_sites = 80L,  n_traits = 4L, d = 2L),
    list(id = 7L, label = "cell07_d2_n160_t4", n_sites = 160L, n_traits = 4L, d = 2L),
    list(id = 8L, label = "cell08_d2_n320_t4", n_sites = 320L, n_traits = 4L, d = 2L),
    list(id = 9L, label = "cell09_d2_n80_t8",  n_sites = 80L,  n_traits = 8L, d = 2L)
  )
  cells
}

arcG_get_lambda <- function(n_traits, d) {
  if (n_traits == 4L && d == 1L) return(Lambda_B_K1_4)
  if (n_traits == 4L && d == 2L) return(Lambda_B_K2_4)
  if (n_traits == 8L && d == 2L) return(Lambda_B_K2_8)
  stop("unhandled cell: n_traits=", n_traits, ", d=", d)
}

## Global per-axis sign alignment (coverage-design.md Section 3).
arcG_sign_align <- function(z_hat, u_true) {
  stopifnot(identical(dim(z_hat), dim(u_true)))
  d <- ncol(z_hat)
  signs <- rep(1, d)
  rho <- rep(NA_real_, d)
  for (k in seq_len(d)) {
    rho[k] <- stats::cor(z_hat[, k], u_true[, k])
    signs[k] <- if (isTRUE(all.equal(rho[k], 0))) 1 else sign(rho[k])
    z_hat[, k] <- z_hat[, k] * signs[k]
  }
  list(z_hat = z_hat, u_true = u_true, signs = signs, rho = rho)
}

## Univariate Wald coverage for one converged fit (one seed).
arcG_coverage_one_fit <- function(fit, sim, nominal = c(0.90, 0.95)) {
  z_hat <- extract_latent_scores(fit, level = "unit")
  u_true <- extract_latent_scores(sim, level = "unit")
  if (is.null(z_hat) || is.null(u_true)) {
    return(list(status = "no_scores", coverage = NULL))
  }
  ordu <- tryCatch(
    ordination_uncertainty(fit, level = "unit"),
    error = function(e) e
  )
  if (inherits(ordu, "error") || is.null(ordu)) {
    return(list(
      status = if (inherits(ordu, "error")) paste("ordu_error:", conditionMessage(ordu)) else "ordu_null",
      coverage = NULL,
      z_dims = dim(z_hat),
      u_dims = dim(u_true)
    ))
  }
  aligned <- arcG_sign_align(z_hat, u_true)
  z_hat <- aligned$z_hat
  u_true <- aligned$u_true
  se <- ordu$se
  stopifnot(identical(dim(z_hat), dim(se)))
  n <- nrow(z_hat)
  d <- ncol(z_hat)
  cov_out <- lapply(nominal, function(alpha) {
    zcrit <- stats::qnorm(1 - (1 - alpha) / 2)
    lo <- z_hat - zcrit * se
    hi <- z_hat + zcrit * se
    inside <- (u_true >= lo) & (u_true <= hi)
    list(
      nominal = alpha,
      coverage = mean(inside),
      n_pairs = length(inside),
      n_inside = sum(inside)
    )
  })
  names(cov_out) <- paste0("nominal_", nominal)
  list(
    status = "ok",
    coverage = cov_out,
    z_dims = dim(z_hat),
    u_dims = dim(u_true),
    se_dims = dim(se),
    rho = aligned$rho,
    converged = fit$opt$convergence,
    pdHess = isTRUE(fit$sd_report$pdHess),
    runtime = NA_real_
  )
}

## One (cell, seed) replicate: simulate, fit, return diagnostics + coverage.
arcG_run_one_seed <- function(cell, seed, verbose = TRUE) {
  Lambda_B <- arcG_get_lambda(cell$n_traits, cell$d)
  psi_B <- rep(0.3, cell$n_traits)
  sim <- simulate_site_trait(
    n_sites = cell$n_sites,
    n_species = 12L,
    n_traits = cell$n_traits,
    mean_species_per_site = 6L,
    Lambda_B = Lambda_B,
    psi_B = psi_B,
    seed = seed
  )
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = cell$d),
      data = sim$data
    ))),
    error = function(e) e
  )
  runtime <- proc.time()[["elapsed"]] - t0
  base <- list(
    cell = cell$label,
    cell_id = cell$id,
    n_sites = cell$n_sites,
    n_traits = cell$n_traits,
    d = cell$d,
    seed = seed,
    runtime = runtime
  )
  if (inherits(fit, "error")) {
    return(c(base, list(status = "fit_error", error = conditionMessage(fit))))
  }
  conv <- fit$opt$convergence
  pd <- isTRUE(fit$sd_report$pdHess)
  cov <- arcG_coverage_one_fit(fit, sim)
  cov$runtime <- runtime
  cov$converged <- conv
  cov$pdHess <- pd
  if (verbose) {
    cat(sprintf(
      "  seed %d: conv=%s pdHess=%s runtime=%.2fs status=%s",
      seed, conv, pd, runtime, cov$status
    ))
    if (cov$status == "ok") {
      cat(sprintf(" z=%dx%d", cov$z_dims[1], cov$z_dims[2]))
      for (nm in names(cov$coverage)) {
        cat(sprintf(" %s=%.3f", nm, cov$coverage[[nm]]$coverage))
      }
    }
    cat("\n")
  }
  c(base, cov)
}
