## M2.3 — galamm cross-package light sanity check.
##
## Per maintainer 2026-05-17 cross-package policy: one shared
## fixture per comparator, no replicates, no grid.
##
## API translation:
##   gllvmTMB: stacked-long + `latent(0+trait|site, d=1)` +
##             `lambda_constraint = list(B = item-1-pin matrix)`.
##             Latent factor z ~ N(0, 1) is **fixed** in the
##             parameterisation; loadings are on the original scale.
##   galamm:   stacked-long + `(0 + ability | person)` +
##             `factor = "ability"`, `load_var = "item"`, `lambda`
##             matrix. Latent factor variance is **estimated**;
##             loadings carry the latent-scale factor.
##
## Scale-difference note: even with item-1 = 1 pinned in both
## engines, galamm's lambda entries differ from gllvmTMB's by a
## factor of sqrt(galamm_ability_var). Both engines correctly
## identify the model; they expose loadings on different scales.
## The cross-check therefore compares **sign pattern + rank
## order**, not absolute magnitude.
##
## Fixture: n_items = 5, n_resp = 200. This is the modest "light
## sanity check" size that converges reliably in galamm; larger
## fixtures hit a known boundary pathology where galamm's outer
## optimizer collapses the latent variance to 0 (rank-deficient
## Hessian). Phase 5.5's full cross-package grid will address with
## starting-value strategies.

skip_if_galamm_missing <- function() {
  if (!requireNamespace("galamm", quietly = TRUE)) {
    skip("galamm not installed (Suggests-only package).")
  }
}

# ---- Local helper (shared with M2.3 LAM-03 + mirt cross-check) -----

make_binary_irt_dgp <- function(n_items, d, n_resp, seed,
                                Lam_signal = NULL,
                                link = c("logit", "probit")) {
  link <- match.arg(link)
  set.seed(seed)
  if (is.null(Lam_signal)) {
    Lam <- matrix(0, nrow = n_items, ncol = d)
    diag(Lam) <- 1
    for (k in seq_len(d)) {
      below <- seq(from = k + 1L, to = n_items)
      Lam[below, k] <- 0.7 * sin(seq_along(below) * 1.3)
    }
  } else {
    Lam <- Lam_signal
  }
  alpha <- stats::rnorm(n_items, mean = 0, sd = 0.4)
  z     <- matrix(stats::rnorm(n_resp * d), nrow = n_resp, ncol = d)
  eta   <- sweep(z %*% t(Lam), 2L, alpha, `+`)
  prob  <- if (link == "logit") stats::plogis(eta) else stats::pnorm(eta)
  y     <- matrix(stats::rbinom(length(prob), 1L, prob), nrow = n_resp)
  df <- data.frame(
    site  = factor(rep(seq_len(n_resp), times = n_items)),
    trait = factor(rep(paste0("i", seq_len(n_items)), each = n_resp),
                   levels = paste0("i", seq_len(n_items))),
    value = c(y)
  )
  cnst <- matrix(NA_real_, nrow = n_items, ncol = d)
  for (k in seq_len(d)) {
    cnst[k, k] <- 1
    if (k < d) cnst[k, (k + 1L):d] <- 0
  }
  list(data = df, Lam_true = Lam, alpha_true = alpha,
       constraint = cnst, n_items = n_items, d = d, link = link,
       y_wide = y, n_resp = n_resp)
}

# ---- (1) gllvmTMB and galamm agree on 2PL IRT (sign + rank order) ---

test_that("gllvmTMB and galamm agree on 2PL IRT loadings — sign + rank order (M2.3 / cross-package galamm)", {
  skip_on_cran()
  skip_if_galamm_missing()

  ## n_items = 5 fixture with explicit Lam_signal (small enough for
  ## galamm to converge cleanly; per maintainer "not big tests").
  ## Hand-picked loading magnitudes ensure all 4 free items have
  ## clear signal (|Lam| >= 0.4) so the sign + rank-order test
  ## isn't tripped by near-zero noise items.
  fx <- make_binary_irt_dgp(
    n_items = 5L, d = 1L, n_resp = 200L,
    seed = 42L, link = "logit",
    Lam_signal = matrix(c(1, 0.7, -0.5, 0.6, 0.4), ncol = 1L)
  )

  ## gllvmTMB fit (z ~ N(0, 1) latent variance fixed).
  fit_g <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1L),
    data = fx$data,
    family = stats::binomial(),
    lambda_constraint = list(B = fx$constraint)
  )))
  expect_equal(fit_g$opt$convergence, 0L,
               info = "gllvmTMB 2PL IRT fit did not converge")
  L_g <- suppressMessages(suppressWarnings(
    as.numeric(gllvmTMB::getLoadings(fit_g, level = "B")[, 1L])
  ))

  ## galamm fit (latent variance estimated).
  df_ga <- data.frame(
    person = fx$data$site,
    item   = fx$data$trait,
    y      = fx$data$value
  )
  fit_ga <- suppressMessages(suppressWarnings(galamm::galamm(
    formula  = y ~ item + (0 + ability | person),
    data     = df_ga, family = stats::binomial,
    factor   = "ability",
    load_var = "item",
    lambda   = matrix(c(1, rep(NA_real_, fx$n_items - 1L)), ncol = 1L)
  )))
  L_ga <- as.numeric(summary(fit_ga, parm = "lambda")$Lambda[, "ability"])

  ## Both engines pin item-1 = 1.
  expect_equal(L_g[1L],  1, tolerance = 1e-8,
               label = "gllvmTMB item-1 pin holds exactly")
  expect_equal(L_ga[1L], 1, tolerance = 1e-8,
               label = "galamm item-1 pin holds exactly")

  ## Sign agreement on items with clear signal in both fits
  ## (|loading| > 0.1 on the gllvmTMB scale; items with near-zero
  ## loadings are noisy and may flip sign across packages).
  free_idx <- seq(2L, fx$n_items)
  signal   <- abs(L_g[free_idx]) > 0.1
  if (any(signal)) {
    sg_g  <- sign(L_g[free_idx])[signal]
    sg_ga <- sign(L_ga[free_idx])[signal]
    expect_true(all(sg_g == sg_ga),
                info = sprintf("Sign pattern mismatch on signal items: gllvm=%s, galamm=%s",
                               paste(sg_g, collapse = ","),
                               paste(sg_ga, collapse = ",")))
  }

  ## Rank-order agreement across free items (Pearson — Spearman
  ## is too discrete with n = 4 free items). Pearson correlation
  ## should be high because gllvm and galamm loadings differ only
  ## by a positive scale factor sqrt(ability_var).
  rho <- stats::cor(L_g[free_idx], L_ga[free_idx], method = "pearson")
  expect_gt(rho, 0.85,
            label = sprintf("Pearson correlation (gllvm, galamm) loadings = %.3f",
                            rho))
})
