.cov1125x3_ordinal_fit <- function(se = TRUE) {
  set.seed(112531)
  n_site <- 12L
  dat <- expand.grid(
    site = factor(seq_len(n_site)),
    trait = factor(rep(c("ord_a", "ord_b"), length.out = 2L * n_site))
  )
  dat$value <- sample(1:3, nrow(dat), replace = TRUE)
  gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = dat,
    trait = "trait",
    unit = "site",
    family = ordinal_probit(),
    control = gllvmTMBcontrol(
      n_init = 1L,
      se = se,
      warn_runaway = FALSE
    )
  )
}

test_that("extract_cutpoints() returns empty frame without ordinal traits", {
  set.seed(1)
  n <- 10L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rpois(n, 1)
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE)
  )
  out <- extract_cutpoints(fit)
  expect_equal(nrow(out), 0L)
  expect_true(all(c("trait", "tau_estimate", "tau_se") %in% names(out)))
})

test_that("extract_cutpoints() returns rows for ordinal_probit fit", {
  fit <- .cov1125x3_ordinal_fit(se = FALSE)
  cp <- extract_cutpoints(fit, quiet = TRUE)
  expect_gt(nrow(cp), 0L)
  expect_true(all(cp$cutpoint_index >= 2L))
})

test_that("extract_cutpoints() informs when sd_report is missing", {
  fit <- .cov1125x3_ordinal_fit(se = FALSE)
  expect_message(
    extract_cutpoints(fit),
    "tau_se"
  )
  expect_silent(extract_cutpoints(fit, quiet = TRUE))
})

test_that("extract_cutpoints() refuses non-multi input", {
  expect_error(extract_cutpoints(data.frame()), "gllvmTMB")
})