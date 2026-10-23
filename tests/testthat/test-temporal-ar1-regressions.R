## A clean compatibility fixture for the temporal acceptance runner.  It uses
## small, deterministic Gaussian fits and deliberately avoids optional skips:
## `verify.R regression` rejects a skip or warning as missing evidence.

test_that("ordinary latent, wide rewriting, scores, and simulation remain available", {
  set.seed(260908L)
  long <- expand.grid(
    site = paste0("s", 1:8), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  long$value <- stats::rnorm(nrow(long))

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_long <- suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = long, unit = "site", family = stats::gaussian(), control = ctl,
    silent = TRUE
  ))
  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(dim(gllvmTMB::getLV(fit_long)), c(8L, 1L))
  expect_equal(dim(stats::simulate(fit_long, nsim = 2L, seed = 260909L)), c(nrow(long), 2L))

  wide <- data.frame(site = paste0("s", 1:8))
  for (tr in paste0("t", 1:3)) {
    wide[[tr]] <- long$value[long$trait == tr]
  }
  fit_wide <- suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + latent(1 | site, d = 1),
    data = wide, unit = "site", family = stats::gaussian(), control = ctl,
    silent = TRUE
  ))
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_true(is.call(fit_wide$call_wide))
  expect_equal(dim(gllvmTMB::getLV(fit_wide)), c(8L, 1L))
})

test_that("dense kernel and phylogenetic loadings-only paths remain equivalent", {
  set.seed(260910L)
  units <- paste0("u", 1:6)
  A <- matrix(0.25, 6L, 6L, dimnames = list(units, units))
  diag(A) <- 1
  rows <- expand.grid(
    unit_id = units, rep_id = 1:3,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = units)
  latent_score <- as.numeric(t(chol(A + diag(1e-8, 6L))) %*% stats::rnorm(6L))
  for (j in seq_len(3L)) {
    rows[[paste0("y", j)]] <-
      c(0.7, 0.35, -0.45)[j] * latent_score[as.integer(rows$unit_id)] +
      stats::rnorm(nrow(rows), sd = 0.3)
  }
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_phy <- suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~ 1 + phylo_latent(unit_id, d = 1, vcv = A, unique = FALSE),
    data = rows, unit = "row_id", cluster = "unit_id", family = stats::gaussian(),
    control = ctl, silent = TRUE
  ))
  fit_kernel <- suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      kernel_latent(unit_id, K = A, d = 1, name = "known", unique = FALSE),
    data = rows, unit = "row_id", cluster = "unit_id", family = stats::gaussian(),
    control = ctl, silent = TRUE
  ))
  expect_equal(fit_phy$opt$convergence, 0L)
  expect_equal(fit_kernel$opt$convergence, 0L)
  expect_equal(as.numeric(stats::logLik(fit_kernel)), as.numeric(stats::logLik(fit_phy)), tolerance = 1e-6)
})

test_that("spatial latent companion is still emitted by the covariance parser", {
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1, coords = c("lon", "lat"), unique = TRUE)
  )
  text <- paste(deparse(f), collapse = " ")
  expect_match(text, ".spatial_latent = TRUE", fixed = TRUE)
  expect_match(text, ".spatial_unique_diag = TRUE", fixed = TRUE)
})
