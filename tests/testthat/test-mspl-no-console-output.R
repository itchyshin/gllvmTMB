## Compiled code must not write to the console on the default path (#1378).
## The atomic Jeffreys weight used to Rprintf a "V8CERT ..." certification
## line, once per process, for any MSPL fit with n >= 2000 rows.

test_that("MSPL fit with n >= 2000 rows prints nothing from compiled code", {
  skip_on_cran()
  set.seed(1378)
  n_site <- 700L
  n_trait <- 3L # 2100 rows >= the old n >= 2000 trigger
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = stats::rpois(n_site * n_trait, 2)
  )
  out <- utils::capture.output(
    fit <- gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      unit = "site",
      family = stats::poisson(),
      estimator = "mspl",
      control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
    )
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_false(any(grepl("V8CERT", out, fixed = TRUE)))
  expect_identical(length(out), 0L)
})

test_that("src/ has no Rprintf/Rcout/std::cout console output", {
  src <- testthat::test_path("..", "..", "src")
  skip_if_not(dir.exists(src), "package sources not available")
  files <- list.files(src, pattern = "\\.(cpp|h|hpp)$", full.names = TRUE)
  hits <- unlist(lapply(files, function(f) {
    x <- readLines(f, warn = FALSE)
    x <- x[!grepl("^\\s*//", x)]
    basename(f)[any(grepl("\\b(Rprintf|Rcout|std::cout)\\b", x))]
  }))
  expect_identical(as.character(hits), character(0))
})
