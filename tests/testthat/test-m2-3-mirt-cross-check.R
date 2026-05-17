## M2.3 — mirt cross-package light sanity check.
##
## Per maintainer 2026-05-17 cross-package policy
## (docs/design/41-binary-completeness.md §3): one shared fixture
## per comparator, no replicates, no grid. Phase 5.5 owns the
## full cross-package empirical-agreement grid.
##
## Shared fixture: binary 2PL IRT, n_items = 20, d = 1, n_resp = 500.
##   gllvmTMB: stacked-long data + `latent(0+trait|site, d=1)` +
##             `lambda_constraint = list(B = diag-pin matrix)`
##   mirt:     wide-data matrix + `itemtype = "2PL"` (logit link)
##
## Comparison: discrimination (slope) loadings after scale-aligning
## both fits to a common reference (item 1's loading). gllvmTMB
## pins Lambda[1, 1] = 1 via lambda_constraint; we rescale mirt's
## a1 entries by a1[1] so both report the same identification scale.
##
## Tolerances: binary IRT at n = 500 has meaningful information.
## Both packages share the Laplace + autodiff lineage (gllvmTMB via
## TMB; mirt via marginal ML + adaptive Gauss-Hermite). Maximum
## absolute deviation < 0.4 on rescaled loadings is the gross-
## disagreement bound; Spearman rank correlation > 0.8 catches
## sign flips.

skip_if_mirt_missing <- function() {
  if (!requireNamespace("mirt", quietly = TRUE)) {
    skip("mirt not installed (Suggests-only package).")
  }
}

# ---- Re-declare DGP helper (shared with M2.3 LAM-03 test file) -----

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

# ---- (1) gllvmTMB and mirt agree on 2PL loadings (relative scale) ---

test_that("gllvmTMB and mirt agree on 2PL IRT loadings (M2.3 / cross-package mirt)", {
  skip_on_cran()
  skip_if_mirt_missing()

  fx <- make_binary_irt_dgp(n_items = 20L, d = 1L, n_resp = 500L,
                            seed = 20260604L, link = "logit")

  ## gllvmTMB fit.
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

  ## mirt fit on the wide y matrix.
  wide <- as.data.frame(fx$y_wide)
  colnames(wide) <- paste0("i", seq_len(fx$n_items))
  fit_m <- suppressMessages(suppressWarnings(mirt::mirt(
    wide, model = 1L, itemtype = "2PL", verbose = FALSE,
    technical = list(NCYCLES = 1000L)
  )))
  expect_true(mirt::extract.mirt(fit_m, "converged"),
              info = "mirt 2PL fit did not converge")
  a_m <- mirt::coef(fit_m, simplify = TRUE)$items[, "a1"]

  ## Rescale both to the item-1 reference (gllvmTMB pinned Lambda[1] = 1).
  a_m_scaled <- a_m / a_m[1L]

  ## Pairwise absolute deviation across items.
  abs_err <- max(abs(L_g - a_m_scaled))
  expect_lt(abs_err, 0.4,
            label = sprintf("max abs err on rescaled loadings = %.3f",
                            abs_err))

  ## Rank-order agreement (sign flips would tank this).
  rho <- stats::cor(L_g, a_m_scaled, method = "spearman")
  expect_gt(rho, 0.8,
            label = sprintf("Spearman rank correlation = %.3f", rho))
})
