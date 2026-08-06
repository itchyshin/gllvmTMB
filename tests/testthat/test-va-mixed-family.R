## Design 108 Gate A Stage 2 — VA mixed-family + per-trait Gaussian SD.
##
## Admission plumbing only. No public mixed-family VA certificate; no probit;
## no VA mi(). skip_on_cran() avoids CRAN compile of the parked VA DLL.

.va_mixed_tiny_X <- function() {
  ## Intercept-only avoids Design-85 separation on tiny binomial fixtures.
  matrix(1, nrow = 4L, ncol = 1L)
}

test_that("VA validate_data expands scalar family to a dense code vector", {
  v <- .va_r3_validate_data(
    y = c(1L, 0L, 1L, 0L), n_trials = rep(1L, 4L),
    X = .va_mixed_tiny_X(),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L,
    family = "binomial", link = "logit"
  )
  expect_identical(v$family, rep(1L, 4L))
  expect_length(v$log_sigma_start, 2L)
})

test_that("VA validate_data accepts per-row family_codes (gaussian+binomial)", {
  codes <- c(0L, 1L, 0L, 1L)
  v <- .va_r3_validate_data(
    y = c(0.2, 1L, -0.1, 0L), n_trials = c(1L, 1L, 1L, 1L),
    X = .va_mixed_tiny_X(),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L,
    family_codes = codes,
    link = "logit",
    gaussian_sd = 0.8
  )
  expect_identical(v$family, codes)
  expect_identical(v$family_name, "mixed")
  expect_equal(v$log_sigma_start, rep(log(0.8), 2L), tolerance = 1e-12)
  expect_identical(v$link, c("identity", "logit", "identity", "logit"))
})

test_that("mixed-family eval_method forces GH; JJ refused", {
  codes <- c(0L, 1L, 0L, 1L)
  expect_identical(.va_r3_resolve_eval_method("auto", codes), "gh")
  expect_identical(.va_r3_resolve_eval_method("gh", codes), "gh")
  expect_error(.va_r3_resolve_eval_method("jj", codes), "pure-binomial")
})

test_that("single-family binomial-logit auto uses GH; JJ remains explicit", {
  expect_identical(.va_r3_resolve_eval_method("auto", rep(1L, 4L)), "gh")
  expect_identical(.va_r3_resolve_eval_method("jj", rep(1L, 4L)), "jj")
})

test_that("VA mixed gaussian+binomial smoke recovers a healthy fit", {
  skip_on_cran()
  set.seed(10802L)
  ## Thin prototype smoke (no public fence). N=40 / T=4 / q=1 is in the
  ## measured regime where GH mixed starts clear the health gate.
  N <- 40L; T <- 4L; q <- 1L
  codes <- rep(c(0L, 0L, 1L, 1L), times = N)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  beta <- seq(-0.2, 0.2, length.out = T)
  Lambda <- matrix(seq(0.8, 0.4, length.out = T), T, 1L)
  scores <- matrix(rnorm(N), N, 1L)
  eta <- drop(X %*% beta) + as.numeric(Lambda[trait, ] * scores[unit, ])
  y <- eta
  y[codes == 0L] <- y[codes == 0L] + rnorm(sum(codes == 0L), sd = 0.5)
  y[codes == 1L] <- rbinom(sum(codes == 1L), 1L, plogis(eta[codes == 1L]))

  fit <- .va_r3_fit(
    y = y, n_trials = rep(1L, N * T), X = X,
    unit_id = unit, trait_id = trait, q = q,
    family_codes = codes, link = "logit",
    gaussian_sd = 0.5, H = 15L, n_starts = 4L,
    eval_method = "gh", rebuild = TRUE
  )
  expect_identical(fit$status, "healthy")
  expect_identical(fit$family, "mixed")
  expect_identical(fit$eval_method, "gh")
  expect_true(is.matrix(fit$report$Sigma_B))
  expect_true(all(is.finite(fit$report$Sigma_B)))
  expect_length(fit$report$log_sigma, T)
})

test_that("integration = \"va\" admits mixed binomial+poisson under the fence", {
  skip_on_cran()
  set.seed(1L)
  ## Fence needs n >= 100; keep p/q small so GH mixed clears the health gate.
  n <- 100L; p <- 4L; q <- 1L
  fam_by_trait <- c("b", "b", "p", "p")
  site <- factor(rep(seq_len(n), each = p))
  trait <- factor(rep(paste0("t", seq_len(p)), times = n),
                  levels = paste0("t", seq_len(p)))
  beta <- seq(-0.15, 0.15, length.out = p)
  Lambda <- matrix(seq(0.6, 0.35, length.out = p), p, 1L)
  scores <- matrix(rnorm(n), n, 1L)
  eta <- matrix(beta, n, p, byrow = TRUE) + tcrossprod(scores, Lambda)
  Y <- matrix(NA_real_, n, p)
  for (t in seq_len(p)) {
    if (fam_by_trait[[t]] == "b") {
      Y[, t] <- rbinom(n, 1L, plogis(eta[, t]))
    } else {
      Y[, t] <- rpois(n, exp(pmin(eta[, t], 2.5)))
    }
  }
  df <- data.frame(
    y = as.numeric(t(Y)),
    trait = trait,
    site = site,
    family = factor(rep(fam_by_trait, times = n), levels = c("b", "p"))
  )
  family_list <- list(b = stats::binomial(), p = stats::poisson())
  attr(family_list, "family_var") <- "family"

  fit <- gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
    data = df,
    family = family_list,
    unit = "site",
    control = gllvmTMBcontrol(integration = "va")
  )
  expect_s3_class(fit, "gllvmTMB_va")
  expect_identical(fit$status, "healthy")
  expect_identical(fit$family, "mixed")
  expect_identical(fit$eval_method, "gh")
})

test_that("Laplace-to-VA family id map is the scalar identity 0:15", {
  expect_identical(
    .va_r3_laplace_id_to_code(c(0L, 1L, 2L, 5L), c(0L, 0L, 0L, 0L)),
    c(0L, 1L, 2L, 5L)
  )
  expect_identical(.va_r3_laplace_id_to_code(0:15, rep(0L, 16L)), 0:15)
  expect_error(.va_r3_laplace_id_to_code(16L, 0L), "does not admit")
})
