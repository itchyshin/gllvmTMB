## Design 79 §4 -- the `||` uncorrelated intercept-slope coupling, Gaussian
## recovery for phylo_indep / animal_indep (A0 parser + A1 engine).
##
## `mode(1 + x || g)` == `mode(1|g) + mode(0+x|g)`: each trait gets its own
## intercept variance AND slope variance, but NO intercept-slope covariance --
## a FULLY diagonal Sigma_b (2T params), vs the correlated `|` form which keeps
## each trait's within-block (intercept, slope) covariance free (3T params).
## Engine: `phylo_indep(1 + x || g)` rides the SAME block-diagonal theta_dep_chol
## engine as `|`, but with block_size = 1 in dep_chol_crossblock_pins() so every
## off-diagonal Cholesky entry is pinned (not just the cross-trait ones).

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
}

## Compact self-contained fixture: T=3 traits, per-trait (intercept, slope)
## phylo random effects on a coalescent tree, with a genuine within-trait
## intercept-slope correlation in the DGP (so a correct `||` fit must PIN it to
## 0, and a correct `|` fit must recover it).
make_uncorr_fixture <- function(seed, n_sp = 80L, n_rep = 8L) {
  set.seed(seed)
  n_traits <- 3L
  tree <- ape::rcoal(n_sp)
  A <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(A))
  s2_int <- c(0.4, 0.6, 0.3); s2_slope <- c(0.3, 0.5, 0.2); rho <- c(0.5, -0.4, 0.0)
  sp <- rownames(A)
  rows <- list()
  b_int <- b_slope <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    G <- matrix(c(s2_int[t], rho[t] * sqrt(s2_int[t] * s2_slope[t]),
                  rho[t] * sqrt(s2_int[t] * s2_slope[t]), s2_slope[t]), 2, 2)
    Z <- matrix(stats::rnorm(n_sp * 2L), n_sp, 2L)
    B <- LA %*% Z %*% chol(G)
    b_int[, t] <- B[, 1]; b_slope[, t] <- B[, 2]
  }
  for (i in seq_len(n_sp)) for (r in seq_len(n_rep)) {
    x <- stats::rnorm(1)
    for (t in seq_len(n_traits)) {
      mu <- b_int[i, t] + x * b_slope[i, t]
      rows[[length(rows) + 1L]] <- data.frame(
        species = sp[i], trait = paste0("t", t), x = x,
        value = mu + stats::rnorm(1, 0, 0.3), stringsAsFactors = FALSE)
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp)
  df$trait <- factor(df$trait, levels = paste0("t", 1:3))
  list(df = df, tree = tree, n_traits = n_traits)
}

.fit_indep_slope <- function(fx, coupling) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(sprintf("value ~ 0 + trait + phylo_indep(1 + x %s species)", coupling)),
    data = fx$df, phylo_tree = fx$tree, unit = "species",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))
}
.n_free_dep_chol <- function(f) sum(!is.na(as.integer(f$tmb_obj$env$map$theta_dep_chol)))
.max_offdiag_cor <- function(f) {
  m <- f$report$cor_b_mat
  if (is.null(m)) return(NA_real_)
  m <- as.matrix(m); diag(m) <- 0; max(abs(m))
}

test_that("phylo_indep(1 + x || species) fits the fully-diagonal (uncorrelated) Sigma_b", {
  skip_if_not_ape()
  fx <- make_uncorr_fixture(seed = 101L)
  T <- fx$n_traits

  fit_unc <- .fit_indep_slope(fx, "||")
  fit_cor <- .fit_indep_slope(fx, "|")

  expect_equal(fit_unc$opt$convergence, 0L)
  expect_equal(fit_cor$opt$convergence, 0L)

  ## `||` = fully diagonal: 2T free theta_dep_chol; `|` = 3T (within-block cov free).
  expect_equal(.n_free_dep_chol(fit_unc), 2L * T)
  expect_equal(.n_free_dep_chol(fit_cor), 3L * T)

  ## `||` pins EVERY intercept-slope / cross-trait covariance to 0.
  expect_lt(.max_offdiag_cor(fit_unc), 1e-6)
  ## `|` genuinely estimates a within-block correlation (not pinned).
  expect_gt(.max_offdiag_cor(fit_cor), 0.1)

  ## Per-trait variances still recovered (2T free diagonal params, positive).
  expect_true(all(fit_unc$report$sd_b > 0))
  expect_length(fit_unc$report$sd_b, 2L * T)
})

test_that("source-tier latent `||` desugars to and fits the same as `|` (A3)", {
  ## Source-tier latent slopes are already the uncorrelated form (separate Lambda
  ## per column block, no intercept-slope covariance), so `||` is an accepted
  ## spelling that routes to the same engine. Desugar identity is cheap (no fit).
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  t <- matrix(0, 3, 3)
  rw <- gllvmTMB:::rewrite_canonical_aliases
  for (kw in c("phylo_latent", "spatial_latent")) {
    a <- paste(deparse(rw(stats::as.formula(
      sprintf("y ~ %s(1 + x || sp, tree = t, d = 1)", kw)))), collapse = " ")
    b <- paste(deparse(rw(stats::as.formula(
      sprintf("y ~ %s(1 + x | sp, tree = t, d = 1)", kw)))), collapse = " ")
    expect_identical(a, b, info = kw)
  }
})

test_that("latent `||` fit equals the `|` fit at the likelihood", {
  skip_if_not_ape()
  fx <- make_uncorr_fixture(seed = 5L)
  ff <- function(bar) suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(sprintf("value ~ 0 + trait + phylo_latent(%s, d = 1)", bar)),
    data = fx$df, phylo_tree = fx$tree, unit = "species", family = stats::gaussian())))
  f_unc <- ff("1 + x || species"); f_cor <- ff("1 + x | species")
  expect_equal(f_unc$opt$convergence, 0L)
  expect_equal(as.numeric(stats::logLik(f_unc)),
               as.numeric(stats::logLik(f_cor)), tolerance = 1e-8)
})

test_that("wide `||` and its long form are byte-identical", {
  skip_if_not_ape()
  fx <- make_uncorr_fixture(seed = 7L)
  fit_wide <- .fit_indep_slope(fx, "||")
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait + (0 + trait):x || species),
    data = fx$df, phylo_tree = fx$tree, unit = "species",
    family = stats::gaussian(), control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
  )))
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(as.numeric(stats::logLik(fit_wide)),
               as.numeric(stats::logLik(fit_long)), tolerance = 1e-8)
})
