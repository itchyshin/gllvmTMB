## Tests for confint.gllvmTMB_multi() — bootstrap path for Sigma CIs.

## Build a tiny fit with a between-site (B) covariance structure only.
## n_sites = 30, n_traits = 3, rank-1 loading + diagonal specific variances.
make_tiny_B_fit <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites              = 30L,
    n_species            = 4L,
    n_traits             = 3L,
    mean_species_per_site = 4L,
    Lambda_B             = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B                  = c(0.20, 0.15, 0.10),
    beta                 = matrix(0, 3L, 2L),
    seed                 = seed
  )
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site),
      data = s$data
    )
  ))
}

## ---- Tests ------------------------------------------------------------------

test_that("confint(fit, parm='Sigma_B') returns a well-formed data.frame", {
  skip_on_cran()

  fit <- make_tiny_B_fit()
  t0 <- proc.time()["elapsed"]

  ## Phase K: explicit `method = "bootstrap"` to match the test's intent.
  ## Default is `method = "profile"`, which falls back to bootstrap for
  ## off-diagonals and emits an info message we suppress.
  ci <- suppressMessages(
    confint(fit, parm = "Sigma_B", nsim = 50L, seed = 1L,
            method = "bootstrap")
  )

  elapsed <- proc.time()["elapsed"] - t0
  expect_lt(elapsed, 30)   ## (c) must finish within ~30 s

  ## (a) result is a data.frame with required columns; Phase K added a
  ## `method` column so we check via subset.
  expect_s3_class(ci, "data.frame")
  expect_true(all(c("parameter", "estimate", "lower", "upper") %in% names(ci)))

  ## Number of rows = upper-triangular entries of a 3x3 matrix = 6
  n_traits <- 3L
  expect_equal(nrow(ci), n_traits * (n_traits + 1L) / 2L)

  ## (b) lower < estimate < upper for every row
  expect_true(all(ci$lower < ci$estimate))
  expect_true(all(ci$estimate < ci$upper))

  ## parameter column is character and non-empty
  expect_type(ci$parameter, "character")
  expect_true(all(nchar(ci$parameter) > 0L))
})

test_that("confint(fit, parm='Sigma_B') diagonal entries are non-negative", {
  skip_on_cran()

  fit <- make_tiny_B_fit()
  ci <- suppressMessages(
    confint(fit, parm = "Sigma_B", nsim = 50L, seed = 2L,
            method = "bootstrap")
  )

  ## Diagonal entries are variances -> must be non-negative
  diag_rows <- grepl("\\[(.+),\\1\\]", ci$parameter)
  expect_true(sum(diag_rows) == 3L)
  expect_true(all(ci$estimate[diag_rows] >= 0))
  expect_true(all(ci$lower[diag_rows]    >= 0))
})

test_that("confint(fit) without parm returns a matrix (Wald, fixed effects)", {
  skip_on_cran()

  fit <- make_tiny_B_fit()
  ci_wald <- suppressMessages(confint(fit))

  expect_true(is.matrix(ci_wald))
  expect_equal(ncol(ci_wald), 2L)
  ## Column names contain "%" (e.g. "2.5 %", "97.5 %")
  expect_true(all(grepl("%", colnames(ci_wald))))
  ## All lower < upper
  expect_true(all(ci_wald[, 1L] < ci_wald[, 2L]))
})

test_that("confint(fit, parm='Sigma_B') errors for a gllvmTMB_multi fit without Sigma_B", {
  skip_on_cran()

  ## Fit with only a within-site (W) covariance structure — no B tier.
  set.seed(7L)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 25L, n_species = 4L, n_traits = 2L,
    mean_species_per_site = 4L,
    Lambda_W = matrix(c(0.5, -0.3), 2L, 1L),
    psi_W = c(0.10, 0.08),
    beta = matrix(0, 2L, 2L), seed = 7L
  )
  fit_W_only <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | site_species, d = 1) +
        unique(0 + trait | site_species),
      data = s$data
    )
  ))

  ## Requesting Sigma_B when only W is present should error.
  expect_error(
    suppressMessages(confint(fit_W_only, parm = "Sigma_B", nsim = 10L,
                             method = "bootstrap")),
    regexp = NULL   ## any error is acceptable
  )
})
