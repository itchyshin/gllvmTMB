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

test_that("#1713 the svd cut-off is the check_gllvmTMB() loading_runaway_thresh default", {
  thr <- gllvmTMB:::.gllvmTMB_runaway_thresh_default()
  expect_identical(thr, eval(formals(gllvmTMB::check_gllvmTMB)$loading_runaway_thresh))
  expect_identical(
    thr,
    eval(formals(gllvmTMB:::.gllvmTMB_binomial_prevalence_loading_row)$loading_runaway_thresh)
  )
})

test_that("#1713 the svd guard blocks at 2x the runaway threshold, not at 0.5x", {
  thr <- gllvmTMB:::.gllvmTMB_runaway_thresh_default()
  ## 4 traits, rank 2: the last entry is trait 4's loading, the others are 1,
  ## so the relative loading equals that entry.
  theta_with <- function(x) c(1, 1, 1, 1, 1, 1, x)
  ok <- theta_with(1)
  blk <- function(new, old = ok)
    gllvmTMB:::.gllvmTMB_svd_runaway_blocked(new, old, n_traits = 4L, rank = 2L)

  below <- blk(theta_with(0.5 * thr))
  expect_equal(below$rel_new, 0.5 * thr)
  expect_false(below$blocked)
  above <- blk(theta_with(2 * thr))
  expect_equal(above$rel_new, 2 * thr)
  expect_true(above$blocked)
  ## Not blocked when the earlier fit had already run away (nothing to protect).
  expect_false(blk(theta_with(2 * thr), old = theta_with(2 * thr))$blocked)
  ## Not blocked when only the earlier fit ran away.
  expect_false(blk(ok, old = theta_with(2 * thr))$blocked)
})

test_that("#1713 a theta_rr_B of the wrong length leaves the svd guard a silent no-op", {
  thr <- gllvmTMB:::.gllvmTMB_runaway_thresh_default()
  runaway <- c(1, 1, 1, 1, 1, 1, 2 * thr)
  ## Premise: the right length does block.
  expect_true(gllvmTMB:::.gllvmTMB_svd_runaway_blocked(
    runaway, rep(1, 7), n_traits = 4L, rank = 2L)$blocked)
  ## Wrong length (6, not 7): the relative loading is NA and nothing blocks.
  expect_true(is.na(gllvmTMB:::.gllvmTMB_theta_relative_loading(runaway[-7], 4L, 2L)))
  short <- gllvmTMB:::.gllvmTMB_svd_runaway_blocked(
    runaway[-7], rep(1, 7), n_traits = 4L, rank = 2L)
  expect_true(is.na(short$rel_new))
  expect_false(short$blocked)
  ## Asymmetry, pinned as current behaviour: an unreadable EARLIER fit counts as
  ## "has not run away", so a runaway svd fit is still blocked there.
  expect_true(gllvmTMB:::.gllvmTMB_svd_runaway_blocked(
    runaway, rep(1, 6), n_traits = 4L, rank = 2L)$blocked)
  ## A missing parameter (zero length) on the new fit is the same silent no-op.
  expect_false(gllvmTMB:::.gllvmTMB_svd_runaway_blocked(
    numeric(0), rep(1, 7), n_traits = 4L, rank = 2L)$blocked)
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
    data = long, trait = "trait", unit = "unit", family = fam,
    control = gllvmTMBcontrol(n_init = 1L)
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
