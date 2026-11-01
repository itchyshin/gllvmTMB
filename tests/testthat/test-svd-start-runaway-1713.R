## Issue #1713: the #1331 "svd" restart was selected on a lower Laplace
## objective even when that objective was an artefact. On psych::sat.act
## (mixed Gaussian / probit / ordinal probit, d = 2) it reached an ordinal
## loading of 25.4 and a logLik 325 units above the quadrature value
## (678 above the exact integral), where the default start's fit had
## optimism -0.06. The data are stored in fixtures/sat-act-1713.rds
## (psych::sat.act, GPL-2+, columns used by the issue's repro).

test_that("#1713 relative loading is read from the packed theta", {
  ## 4 traits, rank 2: diagonal (2), then col 1 below diag (3), col 2 (2).
  theta <- c(1, 1, 1, 1, 1, 1, 30)
  rel <- gllvmTMB:::.gllvmTMB_theta_relative_loading(theta, n_traits = 4L, rank = 2L)
  ## per-trait maxima: 1, 1, 1, 30 -> median 1, mad 0 -> 30 / 1
  expect_equal(rel, 30)
  ## scale-free under Lambda -> c * Lambda
  expect_equal(
    gllvmTMB:::.gllvmTMB_theta_relative_loading(7 * theta, 4L, 2L), rel
  )
  expect_true(is.na(gllvmTMB:::.gllvmTMB_theta_relative_loading(theta[-1], 4L, 2L)))
  expect_true(is.na(gllvmTMB:::.gllvmTMB_theta_relative_loading(c(theta[-1], NA), 4L, 2L)))
})

test_that("#1713 the svd start does not displace a fit with a runaway loading", {
  skip_on_cran()
  sa <- readRDS(testthat::test_path("fixtures", "sat-act-1713.rds"))
  n <- nrow(sa)
  W <- data.frame(
    ACT = as.numeric(scale(sa$ACT)), SATV = as.numeric(scale(sa$SATV)),
    SATQ = as.numeric(scale(sa$SATQ)), gender = as.integer(sa$gender == 2),
    education = as.integer(sa$education) + 1L
  )
  fam_of <- c(ACT = "continuous", SATV = "continuous", SATQ = "continuous",
              gender = "binary", education = "ordinal")
  long <- do.call(rbind, lapply(names(W), function(r) {
    data.frame(unit = factor(seq_len(n)), trait = r, family = fam_of[[r]],
               value = W[[r]])
  }))
  long$trait <- factor(long$trait, levels = names(W))
  long$family <- factor(long$family, levels = c("continuous", "binary", "ordinal"))
  long <- long[!is.na(long$value), ]
  fam <- list(continuous = gaussian(), binary = binomial(link = "probit"),
              ordinal = ordinal_probit())
  attr(fam, "family_var") <- "family"

  set.seed(20261003)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = long, trait = "trait", unit = "unit", family = fam
  )))

  rh <- fit$restart_history
  expect_identical(rh$start_label, c("initial", "svd"))
  ## The svd restart finds a LOWER objective, at a runaway ...
  expect_lt(rh$objective[2L], rh$objective[1L])
  expect_match(rh$message[2L], "a loading ran away")
  ## ... and is not selected.
  expect_identical(rh$selected, c(TRUE, FALSE))
  expect_equal(as.numeric(logLik(fit)), -4130.444, tolerance = 1e-3)
  L <- as.matrix(extract_loadings(fit, level = "unit"))
  expect_lt(max(abs(L)), 5)
  ## The reported logLik is not above the quadrature value.
  la <- gllvmTMB:::.gllvmTMB_laplace_accuracy(fit)
  expect_true(la$evaluated)
  expect_lt(la$optimism, 2)
})
