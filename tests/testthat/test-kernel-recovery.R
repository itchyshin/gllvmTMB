## Recovery-vs-truth for the standalone kernel_indep / kernel_dep modes.
## kernel_*() is phylo-equivalent for a dense K (Design 65 C1); these fits
## generate a known between-unit kernel K coupled with a known trait covariance
## Sigma_T (Cov(b) = Sigma_T ⊗ K) and check extract_Sigma(level = name)
## recovers Sigma_T. Flips kernel_indep / kernel_dep from "available" to
## "tested" (Design 79 §7 / capability surface).

make_kernel_fixture <- function(seed, Sigma_T, n_unit = 45L, n_rep = 5L) {
  set.seed(seed)
  unit_levels <- paste0("u", seq_len(n_unit))
  ## AR(1)-style positive-definite kernel among units.
  K <- 0.5^abs(outer(seq_len(n_unit), seq_len(n_unit), "-"))
  rownames(K) <- colnames(K) <- unit_levels
  Tt <- nrow(Sigma_T)
  L_K <- t(chol(K + diag(1e-8, n_unit)))
  L_S <- t(chol(Sigma_T))
  ## B[unit, trait] ~ N(0, Sigma_T ⊗ K)  via  L_K Z L_S^T.
  B <- L_K %*% matrix(stats::rnorm(n_unit * Tt), n_unit, Tt) %*% t(L_S)
  rows <- expand.grid(
    unit_id = unit_levels, rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)
  rows$row_id <- factor(seq_len(nrow(rows)))
  for (t in seq_len(Tt)) {
    rows[[paste0("y", t)]] <-
      B[as.integer(rows$unit_id), t] + stats::rnorm(nrow(rows), sd = 0.3)
  }
  list(data = rows, K = K, Sigma_T = Sigma_T)
}

fit_kernel <- function(marker, fx) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(
      sprintf("traits(y1, y2, y3) ~ 1 + %s(unit_id, K = fx$K, name = \"known\")",
              marker)
    ),
    data = fx$data, unit = "row_id", cluster = "unit_id",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("kernel_indep recovers per-trait variances on a dense K", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  Sigma_T <- diag(c(0.8, 0.5, 1.1))
  fx <- make_kernel_fixture(101, Sigma_T)
  fit <- fit_kernel("kernel_indep", fx)
  expect_equal(fit$opt$convergence, 0L)
  S <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "known", part = "total")$Sigma
  )
  ## Per-trait variances recovered; off-diagonals held at zero (indep).
  expect_equal(diag(S), diag(Sigma_T), tolerance = 0.3, ignore_attr = TRUE)
  expect_lt(max(abs(S[upper.tri(S)])), 1e-6)
})

test_that("kernel_dep recovers a full cross-trait covariance on a dense K", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  Sigma_T <- matrix(
    c(1.0, 0.4, -0.3,
      0.4, 0.8,  0.2,
      -0.3, 0.2, 0.9), 3, 3
  )
  fx <- make_kernel_fixture(202, Sigma_T)
  fit <- fit_kernel("kernel_dep", fx)
  expect_equal(fit$opt$convergence, 0L)
  S <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "known", part = "total")$Sigma
  )
  ## Full unstructured covariance recovered, including signed off-diagonals.
  expect_equal(S, Sigma_T, tolerance = 0.35, ignore_attr = TRUE)
})

test_that("kernel_scalar desugars to the diagonal kernel path with scalar mode", {
  txt <- paste(deparse(gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + kernel_scalar(site, K = K, name = "k")
  )), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, ".phylo_unique = TRUE", fixed = TRUE)
  expect_match(txt, ".kernel_mode = \"scalar\"", fixed = TRUE)
})

test_that("kernel_scalar fits ONE shared variance across traits on a dense K", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  sigma2 <- 0.7
  fx <- make_kernel_fixture(707, diag(sigma2, 3))  # scalar truth: sigma^2 I_3
  fit <- fit_kernel("kernel_scalar", fx)
  expect_equal(fit$opt$convergence, 0L)
  ## The tie collapses the per-trait diagonal to ONE free parameter.
  fit_indep <- fit_kernel("kernel_indep", fx)
  expect_equal(sum(names(fit$opt$par) == "theta_rr_phy"), 1L)
  expect_lt(
    sum(names(fit$opt$par) == "theta_rr_phy"),
    sum(names(fit_indep$opt$par) == "theta_rr_phy")
  )
  S <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "known", part = "total")$Sigma
  )
  ## One shared variance: all trait variances identical, off-diagonals zero,
  ## recovered near the scalar truth.
  expect_lt(max(abs(diag(S) - diag(S)[1L])), 1e-8)
  expect_lt(max(abs(S[upper.tri(S)])), 1e-6)
  expect_equal(diag(S)[1L], sigma2, tolerance = 0.25, ignore_attr = TRUE)
})
