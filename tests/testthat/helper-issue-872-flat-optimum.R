## Issue #872 oracle helpers — two-tier gaussian flat-likelihood probe.
## The k = 1 converged optimum maps to a valid lower objective at scale k under
## y -> k * y (loadings and fixed effects x k, log-sds + log k).

.issue_872_two_tier_fixture <- function() {
  set.seed(7)
  ntr <- 4L
  base <- gllvmTMB::simulate_site_trait(
    n_sites = 150L, n_species = 3L, n_traits = ntr,
    mean_species_per_site = 2L,
    Lambda_B = matrix(c(0.9, 0.6, -0.5, 0.4), ntr, 1L),
    psi_B = rep(0.3, ntr), psi_W = rep(0.3, ntr),
    beta = matrix(0, ntr, 2L), seed = 7L
  )
  list(
    data = base$data,
    formula = value ~ 0 + trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site_species)
  )
}

.issue_872_scale_par_to_k <- function(par, k) {
  out <- as.numeric(par)
  nm <- names(par)
  for (i in seq_along(out)) {
    if (nm[i] %in% c("b_fix", "theta_rr_B")) out[i] <- out[i] * k
    else if (nm[i] %in% c("theta_diag_B", "theta_diag_W")) out[i] <- out[i] + log(k)
  }
  names(out) <- nm
  out
}

.issue_872_rel_par_dist <- function(a, b) {
  a <- as.numeric(a)
  b <- as.numeric(b)
  sqrt(sum((a - b)^2)) / sqrt(sum(a^2))
}

.issue_872_oracle_probe <- function(k = 5000) {
  fx <- .issue_872_two_tier_fixture()
  ctl <- gllvmTMBcontrol(se = FALSE)
  fit_k1 <- suppressMessages(suppressWarnings(
    gllvmTMB(fx$formula, data = fx$data, family = gaussian(),
             silent = TRUE, control = ctl)
  ))
  d_k <- fx$data
  d_k$value <- d_k$value * k
  fit_k <- suppressMessages(suppressWarnings(
    gllvmTMB(fx$formula, data = d_k, family = gaussian(),
             silent = TRUE, control = ctl)
  ))
  par_oracle <- .issue_872_scale_par_to_k(fit_k1$opt$par, k)
  obj_reached <- fit_k$opt$objective
  obj_oracle <- fit_k$tmb_obj$fn(par_oracle)
  grad_oracle <- max(abs(fit_k$tmb_obj$gr(par_oracle)))
  list(
    k = k,
    convergence_k1 = fit_k1$opt$convergence,
    convergence_k = fit_k$opt$convergence,
    nll_gap = obj_reached - obj_oracle,
    rel_par_dist = .issue_872_rel_par_dist(fit_k$opt$par, par_oracle),
    max_grad_oracle = grad_oracle,
    max_grad_reported = fit_k$fit_health$max_gradient
  )
}