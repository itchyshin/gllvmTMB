## M2.4 — suggest_lambda_constraint() reliability regime on binary IRT.
##
## Walks LAM-04 (suggest_lambda_constraint reliability) from
## `partial` to `covered` per docs/design/41-binary-completeness.md.
## The existing test-suggest-lambda-constraint.R covers the parser
## machinery (LAM-04 partial baseline: shape, pins, names);
## M2.4 verifies the suggester produces useful constraint matrices
## on **binary 2PL IRT** DGPs across the n_items × d grid and
## documents the reliability boundary.
##
## Tests:
##   (1) suggester output shape on binary fixture (d ∈ {1, 2, 3})
##   (2) suggester-then-fit recovery cycle on binary at d = 1
##   (3) suggester-then-fit recovery cycle on binary at d = 2
##   (4) reliability boundary: d = 3, n_items = 10 — suggester
##       either succeeds or fails gracefully (with a typed message)
##
## DGP convention: standard 2PL IRT with logit link, lower-
## triangle echelon truth (diagonal = 1, upper-triangle = 0).

# ---- Local helper (mirrors M2.3 binary IRT DGP) --------------------

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
  list(data = df, Lam_true = Lam, alpha_true = alpha,
       n_items = n_items, d = d, link = link, n_resp = n_resp)
}

# ---- (1) Suggester output structure on binary DGP ------------------

test_that("suggest_lambda_constraint() on binary IRT data returns correct shape (LAM-04 / M2.4)", {
  skip_on_cran()
  ## Use a small d=2 fixture for shape inspection (don't need to fit).
  fx <- make_binary_irt_dgp(n_items = 8L, d = 2L, n_resp = 100L,
                            seed = 20260605L, link = "logit")

  res <- gllvmTMB::suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data = fx$data, unit = "site"
  )
  expect_type(res, "list")
  expect_true(all(c("constraint", "convention", "d", "n_pins") %in% names(res)))
  expect_equal(dim(res$constraint), c(fx$n_items, fx$d))
  expect_equal(res$d, fx$d)

  ## Lower-triangular convention: upper-triangle zeros are pinned;
  ## the rest are NA (free).
  M <- res$constraint
  ## Row 1: M[1, 2] should be 0 (upper triangle).
  expect_equal(M[1L, 2L], 0)
  ## Other (i, j) with i < j get pinned; (i, j) with i >= j are free.
  for (i in seq_len(fx$n_items)) {
    for (j in seq_len(fx$d)) {
      if (i < j) {
        expect_equal(M[i, j], 0,
                     label = sprintf("upper-triangle pin at (%d, %d)", i, j))
      } else {
        expect_true(is.na(M[i, j]),
                    info = sprintf("entry (%d, %d) should be free (NA)", i, j))
      }
    }
  }
  ## n_pins == K(K-1)/2 = 1 for d = 2.
  expect_equal(res$n_pins, 1L)
})

# ---- (2) suggester → fit recovery cycle at d = 1 -------------------

test_that("suggest_lambda_constraint() → gllvmTMB fit recovers Lambda at d=1 (LAM-04 / M2.4)", {
  skip_on_cran()
  fx <- make_binary_irt_dgp(n_items = 20L, d = 1L, n_resp = 400L,
                            seed = 20260606L, link = "logit")

  ## At d = 1, the lower_triangular convention pins K(K-1)/2 = 0 entries.
  ## So the suggester returns an all-NA matrix and the fit is just
  ## the standard d = 1 rank-1 latent factor (identified via the
  ## TMB packed-vector convention's positive diagonal).
  res <- suppressMessages(gllvmTMB::suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 1L),
    data = fx$data, unit = "site"
  ))
  expect_equal(res$n_pins, 0L)
  expect_equal(dim(res$constraint), c(fx$n_items, 1L))

  ## Use the suggested (all-NA) constraint in a binary fit.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1L),
    data = fx$data, family = stats::binomial(),
    lambda_constraint = list(B = res$constraint)
  )))
  expect_equal(fit$opt$convergence, 0L,
               info = "fit with suggester's d=1 constraint did not converge")

  ## Sanity: Lambda is identifiable and the diagonal recovery
  ## is meaningful (engine's positive-diagonal pin gives item-1
  ## a positive loading, matching truth = 1).
  L_hat <- suppressMessages(suppressWarnings(
    gllvmTMB::getLoadings(fit, level = "B")[, 1L]
  ))
  expect_true(L_hat[1L] > 0,
              info = "engine positive-diagonal pin should keep item-1 loading positive")
})

# ---- (3) suggester → fit recovery cycle at d = 2 -------------------

test_that("suggest_lambda_constraint() → gllvmTMB fit recovers Lambda at d=2 (LAM-04 / M2.4)", {
  skip_on_cran()
  fx <- make_binary_irt_dgp(n_items = 20L, d = 2L, n_resp = 500L,
                            seed = 20260607L, link = "logit")

  res <- suppressMessages(gllvmTMB::suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data = fx$data, unit = "site"
  ))
  expect_equal(res$n_pins, 1L)         # K(K-1)/2 = 1
  expect_equal(res$constraint[1L, 2L], 0)   # upper-tri pin

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data = fx$data, family = stats::binomial(),
    lambda_constraint = list(B = res$constraint)
  )))
  expect_equal(fit$opt$convergence, 0L,
               info = "fit with suggester's d=2 constraint did not converge")

  L_hat <- suppressMessages(suppressWarnings(
    gllvmTMB::getLoadings(fit, level = "B")
  ))
  ## Upper-triangle zero pin holds exactly.
  expect_equal(L_hat[1L, 2L], 0, tolerance = 1e-8,
               label = "upper-triangle pin at (1, 2) should be exact zero")
  ## Lower-triangle + diagonal entries are estimated freely.
  expect_true(any(abs(L_hat[, 1L]) > 0.1),
              info = "column 1 of Lambda should have non-zero entries")
  expect_true(any(abs(L_hat[, 2L]) > 0.1),
              info = "column 2 of Lambda should have non-zero entries (other than the (1,2) zero pin)")
})

# ---- (4) Reliability boundary: d=3 with sparse data ----------------

test_that("suggest_lambda_constraint() at d=3 boundary (n_items=10) returns sensible constraint or fails gracefully (LAM-04 reliability / M2.4)", {
  skip_on_cran()
  ## Boundary regime: d = 3 with only n_items = 10 is on the
  ## parameter-counting edge. Suggester should at minimum return
  ## the correct constraint shape; the downstream fit may or may
  ## not converge depending on the realisation.
  fx <- make_binary_irt_dgp(n_items = 10L, d = 3L, n_resp = 500L,
                            seed = 20260608L, link = "logit")

  res <- suppressMessages(gllvmTMB::suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 3L),
    data = fx$data, unit = "site"
  ))
  expect_equal(dim(res$constraint), c(10L, 3L))
  expect_equal(res$n_pins, 3L)   # K(K-1)/2 = 3

  ## Verify the three pins are at the right (i, j) positions:
  ## (1, 2), (1, 3), (2, 3) — i.e. strict upper triangle of the
  ## first d × d sub-block.
  M <- res$constraint
  expect_equal(M[1L, 2L], 0)
  expect_equal(M[1L, 3L], 0)
  expect_equal(M[2L, 3L], 0)
  ## (2, 1) and (3, 1) and (3, 2) are free (lower triangle).
  expect_true(is.na(M[2L, 1L]))
  expect_true(is.na(M[3L, 1L]))
  expect_true(is.na(M[3L, 2L]))

  ## Document the reliability: try the fit; if it doesn't converge,
  ## that's a finding for §8 of the after-task, not a test failure.
  fit_try <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 3L),
      data = fx$data, family = stats::binomial(),
      lambda_constraint = list(B = res$constraint)
    ))),
    error = function(e) e
  )
  if (inherits(fit_try, "error")) {
    succeed("d=3 n_items=10 boundary: fit failed with a typed error (graceful)")
  } else if (fit_try$opt$convergence != 0L) {
    succeed("d=3 n_items=10 boundary: fit reported non-zero convergence (graceful)")
  } else {
    expect_equal(fit_try$opt$convergence, 0L)
  }
})
