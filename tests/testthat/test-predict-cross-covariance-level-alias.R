## #1578: extract_Gamma() and extract_Sigma() accept level = "phy" on a
## single-tier kernel fit (the tier's internal level); predict_cross_covariance()
## must accept the same alias and return the same result as the tier name.

test_that("predict_cross_covariance() accepts level = 'phy' as an alias for the single kernel tier (#1578)", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")

  set.seed(1578L)
  n_H <- 10L
  n_P <- 10L
  mk_corr <- function(n, prefix) {
    X <- matrix(stats::rnorm(n * 4L), n, 4L)
    A <- stats::cov2cor(tcrossprod(X) + diag(n))
    dimnames(A) <- list(paste0(prefix, seq_len(n)), paste0(prefix, seq_len(n)))
    A
  }
  A_H <- mk_corr(n_H, "H")
  A_P <- mk_corr(n_P, "P")
  W <- matrix(0.5, n_H, n_P, dimnames = list(rownames(A_H), rownames(A_P)))
  K <- gllvmTMB::make_cross_kernel(A_H, A_P, W, rho = 0.6)

  species <- rownames(K)
  n_total <- n_H + n_P
  n_rep <- 3L
  g <- t(chol(K + diag(1e-8, n_total))) %*% stats::rnorm(n_total)
  lambda <- c(1, 0.6, 0.7, -0.5)
  rows <- lapply(seq_len(n_total), function(i) {
    do.call(rbind, lapply(seq_len(n_rep), function(r) {
      y <- lambda * g[i] + stats::rnorm(4L, 0, 0.3)
      host <- i <= n_H
      data.frame(
        row_id = paste0("o", i, "_", r),
        species = species[i],
        h_size = if (host) y[1L] else NA_real_,
        h_defence = if (host) y[2L] else NA_real_,
        p_size = if (!host) y[3L] else NA_real_,
        p_attack = if (!host) y[4L] else NA_real_
      )
    }))
  })
  df <- do.call(rbind, rows)
  df$row_id <- factor(df$row_id)
  df$species <- factor(df$species, levels = species)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = K, d = 1, name = "cross", unique = TRUE),
    data = df,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian()
  )))

  args <- list(
    row_levels = c("H1", "H2"),
    col_levels = c("P1", "P2"),
    row_traits = c("h_size", "h_defence"),
    col_traits = c("p_size", "p_attack")
  )
  by_tier <- do.call(
    gllvmTMB::predict_cross_covariance,
    c(list(fit, level = "cross"), args)
  )
  by_alias <- do.call(
    gllvmTMB::predict_cross_covariance,
    c(list(fit, level = "phy"), args)
  )
  expect_equal(by_alias, by_tier)

  ## Unrelated names still error and name the available tier.
  expect_error(
    do.call(
      gllvmTMB::predict_cross_covariance,
      c(list(fit, level = "nonexistent"), args)
    ),
    "kernel"
  )
})
