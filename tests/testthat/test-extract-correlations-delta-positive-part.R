## Design 02 (2026-07-05 resolution, docs/design/02-family-registry.md
## "Hurdle / delta families"): for a delta/hurdle trait, the latent
## structure attaches only to the positive-continuous submodel (the
## occurrence submodel is fixed-effects-only), so the trait contributes one
## defensible latent scale -- the positive-part residual (sigma^2 for
## delta_lognormal; trigamma(shape) for delta_gamma) -- to
## extract_correlations()'s diagonal, NOT the total-variance
## sigma^2 + pi^2/3 that link_residual_per_trait() reports for its own
## repeatability purpose. The resulting correlation is conditional on
## occurrence, not an unconditional response correlation, and is flagged
## interval_status = "conditional_on_occurrence".
##
## DGP mirrors test-delta-lognormal-recovery.R (already-validated 6/6-seed
## convergence for latent(0 + trait | unit, d = 1) + delta_lognormal(), see
## data-raw/diagnostics/2026-07-05-fam17-delta-latent-boundary-repro*.R and
## docs/design/35-validation-debt-register.md FAM-17), with a latent(0+trait
## | unit, d = 1) term added so a "unit" tier exists for extract_correlations().

test_that("extract_correlations() reports the positive-part residual with the conditional_on_occurrence label for a single-family delta_lognormal fit", {
  skip_if_not_heavy()
  skip_on_cran()
  set.seed(2025)
  n_ind <- 800
  Tn <- 3
  trait_names <- letters[seq_len(Tn)]
  mu_true <- c(1.0, 1.5, 2.0)
  sigma_true <- 0.7

  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    eta_t <- mu_true[t]
    p_t <- 1 / (1 + exp(-eta_t))
    pres <- stats::rbinom(n_ind, 1, p_t)
    pos <- stats::rlnorm(n_ind, meanlog = eta_t, sdlog = sigma_true)
    y[, t] <- pres * pos
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    trait = "trait",
    unit = "individual",
    family = delta_lognormal()
  )))

  expect_stationary_for_recovery_test(fit)
  expect_true(all(fit$tmb_data$family_id_vec == 12L))

  cors <- suppressMessages(extract_correlations(
    fit,
    tier = "unit",
    link_residual = "auto"
  ))

  ## All pairs are between delta_lognormal traits -> all flagged.
  expect_equal(nrow(cors), choose(Tn, 2))
  expect_true(all(cors$interval_status == "conditional_on_occurrence"))
  ## Not silently folded into the ordinary unconditional-correlation tokens.
  expect_false(any(
    cors$interval_status %in%
      c("none", "heuristic_unvalidated", "target_specific_uncalibrated")
  ))

  ## Numerically: the reported correlation must match the positive-part-only
  ## construction (Sigma_base + diag(sigma_lognormal_delta^2)), and must
  ## differ from the total-variance construction
  ## (Sigma_base + diag(sigma_lognormal_delta^2 + pi^2/3)) that
  ## extract_Sigma(..., link_residual = "auto") still reports on its own
  ## (unchanged) contract.
  sig_base <- extract_Sigma(
    fit,
    level = "unit",
    part = "total",
    link_residual = "none"
  )
  sigma_hat <- as.numeric(fit$report$sigma_lognormal_delta)
  expect_equal(length(sigma_hat), Tn)

  Sigma_pos_only <- sig_base$Sigma
  diag(Sigma_pos_only) <- diag(Sigma_pos_only) + sigma_hat^2
  R_pos_only <- stats::cov2cor(Sigma_pos_only)

  Sigma_total_var <- sig_base$Sigma
  diag(Sigma_total_var) <- diag(Sigma_total_var) + sigma_hat^2 + pi^2 / 3
  R_total_var <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "total",
    link_residual = "auto"
  )$R)

  for (m in seq_len(nrow(cors))) {
    i <- match(cors$trait_i[m], trait_names)
    j <- match(cors$trait_j[m], trait_names)
    expect_equal(cors$correlation[m], R_pos_only[i, j], tolerance = 1e-8)
    ## The total-variance (old) construction is a genuinely different
    ## number, confirming the fix is not a no-op.
    expect_false(isTRUE(all.equal(
      cors$correlation[m], R_total_var[i, j],
      tolerance = 1e-6
    )))
  }

  ## extract_Sigma()'s own "auto" contract is untouched by this change (it
  ## still reports the total-variance residual for its repeatability
  ## purpose).
  expect_equal(
    unname(gllvmTMB:::link_residual_per_trait(fit)),
    unname(sigma_hat^2 + pi^2 / 3),
    tolerance = 1e-8
  )
  expect_equal(
    unname(gllvmTMB:::delta_positive_part_residual_per_trait(fit)),
    unname(sigma_hat^2),
    tolerance = 1e-8
  )
})
