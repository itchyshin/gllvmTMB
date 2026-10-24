## gllvmTMB_diagnose() reports correlations on the same scale as the
## communalities and the extract_Sigma() defaults (link residual included).
## Issue #1586.

make_rank1_binary_fit <- function() {
  set.seed(3)
  n <- 200
  Tn <- 5
  lam <- c(1.5, 1, -1, 0.8, 1.2)
  u <- rnorm(n)
  Y <- matrix(rbinom(n * Tn, 1, plogis(outer(u, lam))), n, Tn)
  df <- data.frame(
    site = factor(rep(seq_len(n), each = Tn)),
    trait = factor(rep(paste0("t", seq_len(Tn)), n)),
    value = as.vector(t(Y))
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = df,
    family = binomial(),
    unit = "site"
  )))
}

test_that("diagnose correlations match extract_Sigma() defaults (#1586)", {
  skip_on_cran()
  fit <- make_rank1_binary_fit()
  dx <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  ref <- suppressMessages(extract_Sigma(fit, level = "unit"))
  expect_equal(dx$Sigma_B$R_B[1, 2], ref$R[1, 2], tolerance = 1e-6)
  expect_lt(abs(dx$Sigma_B$R_B[1, 2]), 0.99)
})

test_that("verbose = FALSE is silent (#1586)", {
  skip_on_cran()
  fit <- make_rank1_binary_fit()
  expect_silent(gllvmTMB_diagnose(fit, verbose = FALSE))
})

test_that("report uses public tier names and says how many pairs are shown (#1586)", {
  skip_on_cran()
  fit <- make_rank1_binary_fit()
  out <- paste(
    capture.output(
      suppressMessages(gllvmTMB_diagnose(fit, big_corr_thresh = 0.1)),
      type = "output"
    ),
    collapse = "\n"
  )
  expect_match(out, "showing 8 of 10", fixed = TRUE)
  expect_match(out, "link residual included", fixed = TRUE)
  expect_no_match(out, "d=B", fixed = TRUE)
})
