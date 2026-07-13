## Design 79 §4 -- `dep(1 + x || g)` = Sigma_int (+) Sigma_slope. FULL cross-trait
## covariance among intercepts and (separately) among slopes, but intercept _|_
## slope everywhere. This is the SUBTLE cell: under the interleaved 2T ordering
## (int_1, slope_1, ...) the target is NOT a contiguous block-diagonal; it needs
## a PARITY pin on the Cholesky (pin strictly-lower L(i,j) with parity(i) !=
## parity(j)), giving T(T+1) free params. Getting it wrong silently collapses to
## indep-diag, so the target-matrix structure is asserted directly.

## --- pure-math pin (non-flaky, no fit) --------------------------------------
test_that("dep_chol_parity_pins pins exactly the parity-crossing lower entries", {
  ## C = 4 (T = 2), interleaved (int1, slope1, int2, slope2). Column-major packing:
  ## diag = idx 1-4; lower: (2,1)=5 (3,1)=6 (4,1)=7 (3,2)=8 (4,2)=9 (4,3)=10.
  ## Parity-crossing (odd<->even): (2,1)=5, (4,1)=7, (3,2)=8, (4,3)=10.
  expect_identical(gllvmTMB:::dep_chol_parity_pins(4L), c(5L, 7L, 8L, 10L))
  ## Free = 4 diag + (3,1)=int-int + (4,2)=slope-slope = 6 = T(T+1).
  n_lower <- 4L * 3L / 2L
  expect_equal(4L + n_lower - length(gllvmTMB:::dep_chol_parity_pins(4L)), 2L * 3L)
})

## --- target-matrix recovery (heavy) -----------------------------------------
skip_heavy_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
}

test_that("dep(1 + x || g) fits Sigma_int (+) Sigma_slope (int _|_ slope, cross-trait free)", {
  skip_heavy_ape()
  set.seed(11); n_sp <- 100L; n_rep <- 10L; T <- 3L
  tree <- ape::rcoal(n_sp); A <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(A)); sp <- rownames(A)
  cs <- function(d, r) { m <- matrix(r, T, T); diag(m) <- 1; d * m }
  Bi <- LA %*% matrix(stats::rnorm(n_sp * T), n_sp, T) %*% chol(cs(0.5, 0.5))
  Bs <- LA %*% matrix(stats::rnorm(n_sp * T), n_sp, T) %*% chol(cs(0.4, 0.4))
  rows <- list()
  for (i in seq_len(n_sp)) for (r in seq_len(n_rep)) {
    x <- stats::rnorm(1)
    for (t in seq_len(T)) rows[[length(rows) + 1L]] <- data.frame(
      species = sp[i], trait = paste0("t", t), x = x,
      value = Bi[i, t] + x * Bs[i, t] + stats::rnorm(1, 0, 0.3),
      stringsAsFactors = FALSE)
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp)
  df$trait <- factor(df$trait, levels = paste0("t", 1:3))

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(1 + x || species),
    data = df, phylo_tree = tree, unit = "species", family = stats::gaussian())))
  expect_equal(fit$opt$convergence, 0L)

  ## T(T+1) free theta_dep_chol (two T x T Cholesky blocks).
  expect_equal(sum(!is.na(as.integer(fit$tmb_obj$env$map$theta_dep_chol))), T * (T + 1L))

  ## Reconstruct Sigma_b and split by parity (odd = intercept, even = slope).
  s <- fit$report$sd_b; Sig <- diag(s) %*% as.matrix(fit$report$cor_b_mat) %*% diag(s)
  ij <- subset(expand.grid(i = 1:(2 * T), j = 1:(2 * T)), i < j)
  cross <- ij[(ij$i %% 2) != (ij$j %% 2), ]   # intercept-slope
  same  <- ij[(ij$i %% 2) == (ij$j %% 2), ]   # int-int or slope-slope
  expect_lt(max(abs(mapply(function(i, j) Sig[i, j], cross$i, cross$j))), 1e-6)
  expect_gt(max(abs(mapply(function(i, j) Sig[i, j], same$i, same$j))), 0.05)
})

test_that("dep `||` with multiple slopes fails loud (single-slope only)", {
  skip_heavy_ape()
  set.seed(3); n_sp <- 30L; tree <- ape::rcoal(n_sp); sp <- tree$tip.label
  df <- expand.grid(species = factor(sp, levels = sp), trait = factor(c("t1", "t2")))
  df$x1 <- stats::rnorm(nrow(df)); df$x2 <- stats::rnorm(nrow(df))
  df$value <- stats::rnorm(nrow(df))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait + (0 + trait):x1 + (0 + trait):x2 || species),
      data = df, phylo_tree = tree, unit = "species", family = stats::gaussian()))),
    regexp = "single-slope only"
  )
})
