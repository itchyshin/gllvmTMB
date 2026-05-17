## M2.3 — lambda_constraint binary IRT recovery.
##
## Walks LAM-03 (lambda_constraint on binary IRT) from `partial` to
## `covered` per docs/design/41-binary-completeness.md. The existing
## test-lambda-constraint.R covers the Gaussian path (LAM-01 + LAM-02);
## M2.3 adds the binary-IRT recovery surface.
##
## DGP (2PL IRT, probit link):
##   eta_ij = alpha_j + Lambda_j' * z_i
##   y_ij   = rbinom(1, pnorm(eta_ij))   for respondent i, item j
##   z_i    ~ N(0, I_d)
##
## Identification: lambda_constraint pins entries that would
## otherwise be unidentified under rotation. We use the canonical
## "lower-triangle echelon" pattern:
##   Lambda[t, k] is FREE if t > k or (t = k and t > d)
##   Lambda[t, k] is PINNED to 1 if t = k and t <= d (diagonal)
##   Lambda[t, k] is PINNED to 0 if t < k                 (upper triangle)
##
## Recovery target: the free entries Lambda[t, k] (t > k) and
## per-item intercepts alpha.

# ---- Shared helpers ------------------------------------------------

make_binary_irt_dgp <- function(n_items, d, n_resp, seed,
                                Lam_signal = NULL,
                                link = c("probit", "logit")) {
  link <- match.arg(link)
  set.seed(seed)
  ## Build a known Lambda_B with lower-triangle echelon structure.
  if (is.null(Lam_signal)) {
    Lam <- matrix(0, nrow = n_items, ncol = d)
    diag(Lam) <- 1
    for (k in seq_len(d)) {
      below <- seq(from = k + 1L, to = n_items)
      ## Mix of moderate-magnitude loadings (alternating signs).
      Lam[below, k] <- 0.7 * sin(seq_along(below) * 1.3)
    }
  } else {
    Lam <- Lam_signal
  }
  alpha <- stats::rnorm(n_items, mean = 0, sd = 0.4)
  z     <- matrix(stats::rnorm(n_resp * d), nrow = n_resp, ncol = d)
  eta   <- sweep(z %*% t(Lam), 2L, alpha, `+`)   # n_resp x n_items
  prob  <- if (link == "logit") stats::plogis(eta) else stats::pnorm(eta)
  y     <- matrix(stats::rbinom(length(prob), 1L, prob), nrow = n_resp)

  ## Long-format data for gllvmTMB
  df <- data.frame(
    site  = factor(rep(seq_len(n_resp), times = n_items)),
    trait = factor(rep(paste0("i", seq_len(n_items)), each = n_resp),
                   levels = paste0("i", seq_len(n_items))),
    value = c(y)
  )

  ## Constraint matrix: diagonal = 1, upper triangle = 0, lower free.
  cnst <- matrix(NA_real_, nrow = n_items, ncol = d)
  for (k in seq_len(d)) {
    cnst[k, k] <- 1
    if (k < d) cnst[k, (k + 1L):d] <- 0
  }

  list(data = df, Lam_true = Lam, alpha_true = alpha,
       constraint = cnst, n_items = n_items, d = d, link = link,
       y_wide = y, n_resp = n_resp)
}

# ---- (1) LAM-03 recovery at d = 1, n_items = 20 --------------------

test_that("lambda_constraint binary IRT recovery at d=1, n_items=20 (LAM-03 / M2.3)", {
  skip_on_cran()
  fx <- make_binary_irt_dgp(n_items = 20L, d = 1L, n_resp = 400L,
                            seed = 20260601L, link = "probit")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1L),
    data = fx$data,
    family = stats::binomial(link = "probit"),
    lambda_constraint = list(B = fx$constraint)
  )))
  expect_equal(fit$opt$convergence, 0L,
               info = "binary IRT d=1 fit did not converge")

  ## Recover Lambda. Diagonal is pinned at 1; free entries are
  ## Lam[2:n_items, 1].
  L_hat <- gllvmTMB::getLoadings(fit, level = "B")
  expect_equal(L_hat[1L, 1L], 1, tolerance = 1e-8,
               label = "diagonal pin Lambda[1,1] == 1")

  ## Compare free entries' max abs error against truth.
  free_idx <- seq(2L, fx$n_items)
  err <- max(abs(L_hat[free_idx, 1L] - fx$Lam_true[free_idx, 1L]))
  expect_lt(err, 0.4,
            label = sprintf("d=1 max abs err on free Lambda entries = %.3f",
                            err))
})

# ---- (2) LAM-03 recovery at d = 2, n_items = 20 --------------------

test_that("lambda_constraint binary IRT recovery at d=2, n_items=20 (LAM-03 / M2.3)", {
  skip_on_cran()
  fx <- make_binary_irt_dgp(n_items = 20L, d = 2L, n_resp = 500L,
                            seed = 20260602L, link = "probit")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data = fx$data,
    family = stats::binomial(link = "probit"),
    lambda_constraint = list(B = fx$constraint)
  )))
  expect_equal(fit$opt$convergence, 0L,
               info = "binary IRT d=2 fit did not converge")

  L_hat <- gllvmTMB::getLoadings(fit, level = "B")

  ## Diagonal pins hold exactly.
  expect_equal(L_hat[1L, 1L], 1, tolerance = 1e-8)
  expect_equal(L_hat[2L, 2L], 1, tolerance = 1e-8)
  ## Upper-triangle zero pin holds exactly.
  expect_equal(L_hat[1L, 2L], 0, tolerance = 1e-8)

  ## Free entries (lower triangle + below-diagonal):
  ## Lambda[t, k] for t > k. Compare element-wise.
  free_mask <- lower.tri(matrix(0, fx$n_items, fx$d), diag = FALSE)
  err <- max(abs(L_hat[free_mask] - fx$Lam_true[free_mask]))
  expect_lt(err, 0.6,
            label = sprintf("d=2 max abs err on free Lambda entries = %.3f",
                            err))
})

# ---- (3) LAM-03 recovery at d = 1, n_items = 50 --------------------

test_that("lambda_constraint binary IRT recovery at d=1, n_items=50 (LAM-03 / M2.3)", {
  skip_on_cran()
  fx <- make_binary_irt_dgp(n_items = 50L, d = 1L, n_resp = 500L,
                            seed = 20260603L, link = "probit")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1L),
    data = fx$data,
    family = stats::binomial(link = "probit"),
    lambda_constraint = list(B = fx$constraint)
  )))
  expect_equal(fit$opt$convergence, 0L)

  L_hat <- gllvmTMB::getLoadings(fit, level = "B")
  expect_equal(L_hat[1L, 1L], 1, tolerance = 1e-8)

  free_idx <- seq(2L, fx$n_items)
  err <- max(abs(L_hat[free_idx, 1L] - fx$Lam_true[free_idx, 1L]))
  expect_lt(err, 0.4,
            label = sprintf("d=1 n=50 max abs err on free Lambda entries = %.3f",
                            err))
})
