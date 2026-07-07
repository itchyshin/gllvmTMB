## Profile CIs for predictor-informed latent-score effects B_lv (D-12 hero
## method), with the small-sample t reference. The heavy case builds the Model A
## composition (ordinary predictor-informed latent + a separate phylo term),
## fits it REML (unbiased variance components), and checks the profile interval
## closes, covers a known B_lv, and is wider under the t reference than chi-square.

test_that("profile_ci_lv_effects errors without a predictor-informed latent term", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 20L
  df <- expand.grid(
    unit = factor(paste0("u", seq_len(n))),
    trait = factor(paste0("t", 1:3))
  )
  df$value <- stats::rnorm(nrow(df))
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
  expect_error(profile_ci_lv_effects(fit), regexp = "predictor-informed latent")
})

test_that("profile_ci_lv_effects closes, covers B_lv, and t is wider than chisq (heavy)", {
  skip_if_not_heavy()
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(20260706)
  S <- 30L; T <- 5L
  tree <- ape::rcoal(S); tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE); LA <- t(chol(A))
  LambdaB <- matrix(c(1.0, 0.8, -0.6, 0.5, 0.3), T, 1)
  alpha <- 0.9
  LambdaPhy <- matrix(c(0.7, -0.5, 0.4, 0.6, 0.2), T, 1)
  beta <- stats::rnorm(T, 0, 0.5); x <- stats::rnorm(S)
  zB <- matrix(x, S, 1) * alpha + matrix(stats::rnorm(S), S, 1)
  gphy <- LA %*% matrix(stats::rnorm(S), S, 1)
  eta <- matrix(beta, S, T, byrow = TRUE) + zB %*% t(LambdaB) + gphy %*% t(LambdaPhy)
  y <- eta + matrix(stats::rnorm(S * T, 0, 0.5), S, T)
  df <- data.frame(
    species = factor(rep(tree$tip.label, times = T), levels = tree$tip.label),
    trait = factor(rep(paste0("t", seq_len(T)), each = S)),
    value = as.vector(y), x = rep(x, times = T)
  )
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | species, d = 1, lv = ~x) +
      phylo_latent(0 + trait | species, d = 1, tree = tree),
    data = df, unit = "species", trait = "trait", family = gaussian(), REML = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE, optimizer = "optim",
                                        optArgs = list(method = "BFGS"))
  ))
  expect_equal(fit$opt$convergence, 0L)

  res_t <- profile_ci_lv_effects(fit, trait = 1, predictor = 1, reference = "t")
  res_c <- profile_ci_lv_effects(fit, trait = 1, predictor = 1, reference = "chisq")
  truth <- LambdaB[1, 1] * alpha

  expect_s3_class(res_t, "data.frame")
  expect_identical(res_t$method, "profile")
  expect_identical(res_t$reference, "t")
  expect_equal(res_t$df, S - 1L - 1L)                    # n_units - d - 1
  expect_true(is.finite(res_t$lower) && is.finite(res_t$upper))
  expect_true(res_t$lower < res_t$estimate && res_t$estimate < res_t$upper)
  expect_true(truth >= res_t$lower && truth <= res_t$upper)   # covers the known B_lv
  ## t reference (df = 28) is wider than the chi-square reference.
  expect_gt(res_t$upper - res_t$lower, res_c$upper - res_c$lower)
})
