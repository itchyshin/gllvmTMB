kernel_bridge_make_long <- function(n_unit = 10L,
                                    traits = c("t1", "t2", "t3"),
                                    seed = 1L) {
  set.seed(seed)
  out <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = factor(traits),
    KEEP.OUT.ATTRS = FALSE
  )
  out$value <- stats::rnorm(nrow(out))
  out
}

kernel_bridge_skip_if_no_julia <- function() {
  testthat::skip_if_not_installed("JuliaCall")
  jl <- getOption("gllvmTMB.GLLVM.jl.path", Sys.getenv("GLLVM_JL_PATH", ""))
  if (!nzchar(jl)) {
    testthat::skip(
      "GLLVM.jl path not configured (set GLLVM_JL_PATH / options(gllvmTMB.GLLVM.jl.path=))."
    )
  }
}

test_that("dense-kernel source extractor returns B, not residual-inclusive Sigma", {
  B <- matrix(c(1.5, 0.4, 0.4, 1.1), nrow = 2,
              dimnames = list(c("t1", "t2"), c("t1", "t2")))
  fit <- structure(
    list(
      family = "gaussian",
      families = "gaussian",
      n_traits = 2L,
      n_units = 6L,
      trait_names = c("t1", "t2"),
      unit_names = paste0("u", 1:6),
      loadings = matrix(c(0.8, 0.2), nrow = 2),
      Sigma = B + diag(0.7, 2),
      source_names = "cross",
      source_covariance = B,
      source_unique = TRUE,
      correlation = stats::cov2cor(B + diag(0.7, 2))
    ),
    class = c("gllvmTMB_julia", "list")
  )
  out <- suppressMessages(extract_Sigma(fit, level = "cross"))
  expect_equal(out$Sigma, B)
  expect_equal(out$R, stats::cov2cor(B))
  expect_false(isTRUE(all.equal(out$Sigma, fit$Sigma)))
  expect_match(out$note, "B = Lambda Lambda' \\+ Psi")
})

test_that("kernel Julia bridge rejects the bounded-cell exclusions", {
  df <- kernel_bridge_make_long(n_unit = 6L, traits = c("t1", "t2"))
  df$group <- factor(rep(1:3, each = 4))
  K <- diag(3)
  dimnames(K) <- list(levels(df$group), levels(df$group))

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + kernel_unique(group, K = K),
      data = df, unit = "unit", trait = "trait",
      family = gaussian(), engine = "julia", ci_method = "none"
    ),
    "GJL-GATE-STRUCTURED-TERMS"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait +
        kernel_latent(group, K = K, d = 1, unique = TRUE) +
        kernel_latent(group, K = K, d = 1, unique = FALSE),
      data = df, unit = "unit", trait = "trait",
      family = gaussian(), engine = "julia", ci_method = "none"
    ),
    "GJL-GATE-STRUCTURED-TERMS"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + kernel_latent(group, K = K, d = 1, unique = TRUE),
      data = df, unit = "unit", trait = "trait",
      family = poisson(), engine = "julia", ci_method = "none"
    ),
    "GJL-GATE-STRUCTURED-TERMS"
  )
})

test_that("one Gaussian dense-kernel cell agrees between TMB and Julia", {
  kernel_bridge_skip_if_no_julia()
  set.seed(220)
  n_unit <- 12L
  df <- data.frame(obs = factor(paste0("o", seq_len(n_unit))))
  z <- matrix(rnorm(n_unit * 2), n_unit, 2)
  K <- tcrossprod(z) / 2 + diag(0.8, n_unit)
  dimnames(K) <- list(levels(df$obs), levels(df$obs))
  df$t1 <- rnorm(n_unit)
  df$t2 <- rnorm(n_unit)

  fml <- traits(t1, t2) ~ 1 +
    kernel_latent(obs, K = K, d = 1, unique = TRUE)
  Y <- t(as.matrix(df[c("t1", "t2")]))
  rownames(Y) <- c("t1", "t2")
  colnames(Y) <- levels(df$obs)
  fit_j <- gllvm_julia_fit(
    Y, family = "gaussian", num.lv = 1,
    sources = list(list(
      name = "kernel", covariance = K, groups = seq_len(n_unit),
      mode = "latent", rank = 1, unique = TRUE, common = FALSE
    ))
  )
  fit_r <- gllvmTMB_wide(Y, d = 1)
  expect_s3_class(fit_j, "gllvmTMB_julia")
  expect_true(is.finite(as.numeric(logLik(fit_j))))
  B_j <- suppressMessages(extract_Sigma(fit_j, level = "kernel"))
  expect_equal(unname(B_j$Sigma), unname(fit_j$source_covariance),
               tolerance = 1e-10)
  expect_equal(B_j$R, stats::cov2cor(B_j$Sigma), tolerance = 1e-10)
  expect_true(is.finite(as.numeric(logLik(fit_r))))
  expect_equal(dim(B_j$Sigma), c(2L, 2L))
})
