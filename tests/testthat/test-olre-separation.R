## Tests for extract_residual_split() — OLRE sigma^2_e / sigma^2_d separation.
##
## Simulation design: Poisson + per-trait OLRE (observation-level random
## effect). Each (site, trait) observation has its own random effect
## e_it ~ N(0, sigma^2_e[t]). With 200 sites x 4 traits we have 800 rows;
## the per-trait OLRE variance should be recoverable within ~0.2 of truth.
##
## Column naming: use the default gllvmTMB column names — "site" for the
## between-unit grouping and "site_species" for the within-unit (obs-level)
## grouping — to match both the installed package API and the canonical
## internal tmb_data field names.

test_that("extract_residual_split() recovers OLRE sigma^2_e in a Poisson simulation", {
  skip_on_cran()
  skip_if_not_installed("gllvmTMB")

  n_traits <- 4L
  n_sites  <- 200L
  true_sigma2_e <- c(0.5, 0.3, 0.8, 0.4)   # per-trait OLRE variances
  true_alpha    <- c(2.0, 1.5, 1.0, 0.5)    # per-trait intercepts

  set.seed(123)
  df <- expand.grid(site = seq_len(n_sites), trait_idx = seq_len(n_traits))
  ## One obs per (site, trait) — use "site_species" as the obs-level column
  ## to match the default unit_obs = "site_species" in gllvmTMB().
  df$site_species <- factor(seq_len(nrow(df)))
  df$trait <- factor(paste0("t", df$trait_idx),
                     levels = paste0("t", seq_len(n_traits)))
  e_it  <- rnorm(nrow(df), sd = sqrt(true_sigma2_e[df$trait_idx]))
  eta   <- true_alpha[df$trait_idx] + e_it
  df$value <- rpois(nrow(df), exp(eta))

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | site_species),
      data = df,
      family = poisson()
    )
  ))

  ## --- extract_residual_split() output -----------------------------------
  split <- extract_residual_split(fit)

  ## Structure checks
  expect_s3_class(split, "data.frame")
  expect_named(split, c("trait", "sigma2_d", "sigma2_e", "sigma2_total"))
  expect_equal(nrow(split), n_traits)
  expect_s3_class(split$trait, "factor")
  expect_equal(levels(split$trait), paste0("t", seq_len(n_traits)))

  ## sigma2_total = sigma2_d + sigma2_e (by construction)
  expect_equal(split$sigma2_total, split$sigma2_d + split$sigma2_e,
               tolerance = 1e-12)

  ## sigma2_d > 0 for Poisson log (lognormal-Poisson approx log(1 + 1/mu))
  ## The fitted mean mu_t is the marginal mean E[Y_it] = exp(alpha_t + sigma2_e_t/2)
  ## (Jensen's inequality for lognormal-Poisson), so sigma2_d is based on the
  ## marginal fitted mu rather than exp(alpha_t) alone.
  expected_marginal_mu <- exp(true_alpha + true_sigma2_e / 2)
  expected_sigma2_d    <- log(1 + 1 / expected_marginal_mu)
  ## Tolerance 0.10 absolute — 200 sites gives tight mu estimates
  for (t in seq_len(n_traits)) {
    expect_equal(split$sigma2_d[t], expected_sigma2_d[t],
                 tolerance = 0.10,
                 label = paste0("sigma2_d[", t, "]"))
  }

  ## sigma2_e within 0.2 of truth (200 sites provides reasonable recovery)
  for (t in seq_len(n_traits)) {
    expect_equal(split$sigma2_e[t], true_sigma2_e[t],
                 tolerance = 0.2,
                 label = paste0("sigma2_e[", t, "]"))
  }
})

test_that("extract_residual_split() returns zero sigma2_e when no OLRE term", {
  skip_on_cran()
  skip_if_not_installed("gllvmTMB")

  ## Fit WITHOUT a per-obs unique() — only a site-level unique() term.
  ## sigma2_e should be zero; sigma2_d should be non-zero for Poisson.
  set.seed(42)
  n_sites <- 50L; n_traits <- 3L
  df <- expand.grid(site = factor(seq_len(n_sites)),
                    trait = factor(paste0("t", seq_len(n_traits)),
                                   levels = paste0("t", seq_len(n_traits))))
  df$value <- rpois(nrow(df), 5)

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | site),
      data = df,
      family = poisson()
    )
  ))

  split <- extract_residual_split(fit)

  ## The unique() here is at the site level, NOT at the obs level, so the
  ## cell-uniqueness check fails (n_traits rows per site) and sigma2_e = 0.
  expect_equal(unname(split$sigma2_e), rep(0, n_traits))
  ## sigma2_d should still be non-zero for Poisson
  expect_true(all(split$sigma2_d > 0))
  expect_equal(split$sigma2_total, split$sigma2_d + split$sigma2_e,
               tolerance = 1e-12)
})

test_that("extract_Omega() includes residual_split when link_residual = 'auto'", {
  skip_on_cran()
  skip_if_not_installed("gllvmTMB")

  ## Lightweight fit: binomial, no OLRE.  Just check the list slot is present.
  set.seed(7)
  n <- 40L; Tn <- 3L
  Lambda_B <- matrix(c(0.8, 0.5, -0.3), Tn, 1)
  u <- rnorm(n)
  eta <- outer(u, Lambda_B[, 1])
  p   <- plogis(eta)
  df  <- data.frame(
    site  = factor(rep(seq_len(n), each = Tn)),
    trait = factor(rep(paste0("t", seq_len(Tn)), n),
                   levels = paste0("t", seq_len(Tn))),
    value = as.integer(rbinom(n * Tn, 1, as.vector(t(p))))
  )
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = df,
      family = binomial(link = "logit")
    )
  ))

  om <- suppressMessages(extract_Omega(fit, link_residual = "auto"))
  expect_true("residual_split" %in% names(om))
  expect_s3_class(om$residual_split, "data.frame")
  expect_named(om$residual_split, c("trait", "sigma2_d", "sigma2_e", "sigma2_total"))
  ## Binomial logit: sigma2_d = pi^2/3 for all traits
  expect_equal(om$residual_split$sigma2_d, rep(pi^2 / 3, Tn),
               tolerance = 1e-6)
  ## No OLRE in this fit → sigma2_e = 0
  expect_equal(om$residual_split$sigma2_e, rep(0, Tn))
})

test_that("extract_Omega() does NOT include residual_split when link_residual = 'none'", {
  ## Structural test — no need for a real model; use a minimal fake fit stub.
  fit_stub <- structure(
    list(
      use    = list(rr_B = TRUE, diag_B = FALSE,
                    rr_W = FALSE, diag_W = FALSE,
                    phylo_rr = FALSE),
      n_traits = 2L,
      data     = data.frame(trait = factor(c("a", "b"))),
      trait_col = "trait",
      unit_col  = "site",
      tmb_data  = list(family_id_vec = c(0L, 0L),
                       link_id_vec   = c(0L, 0L),
                       trait_id      = c(0L, 1L)),
      report   = list(Lambda_B = matrix(c(1, 0.5), 2, 1),
                      eta      = c(0, 0),
                      sigma_eps = 1)
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
  om <- suppressMessages(extract_Omega(fit_stub, link_residual = "none"))
  expect_false("residual_split" %in% names(om))
})
