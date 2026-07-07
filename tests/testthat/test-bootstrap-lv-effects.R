## Parametric bootstrap CIs for B_lv, and the unconditional-simulate redraw of the
## Model A tiers (lv_B / phylo_rr / diag_species) it depends on. A conditional
## simulate (REs fixed) would give absurdly narrow, non-covering intervals; the
## redraw is what makes the bootstrap honest.

make_modelA_fit <- function(S = 40L, T = 4L, seed = 20260706L, reml = TRUE) {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(seed)
  tree <- ape::rcoal(S); tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE); LA <- t(chol(A))
  LambdaB <- matrix(c(1.0, 0.8, -0.6, 0.5)[seq_len(T)], T, 1)
  alpha <- 0.9
  LambdaPhy <- matrix(c(0.7, -0.5, 0.4, 0.6)[seq_len(T)], T, 1)
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
    data = df, unit = "species", trait = "trait", family = gaussian(), REML = reml,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, optimizer = "optim",
                                        optArgs = list(method = "BFGS"))
  ))
  list(fit = fit, truth = as.numeric(LambdaB) * alpha)
}

test_that("bootstrap_ci_lv_effects errors without a predictor-informed latent term", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 20L
  df <- expand.grid(unit = factor(paste0("u", seq_len(n))), trait = factor(paste0("t", 1:3)))
  df$value <- stats::rnorm(nrow(df))
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
  expect_error(bootstrap_ci_lv_effects(fit, n_boot = 5), regexp = "predictor-informed latent")
})

test_that("unconditional simulate() redraws the Model A tiers (no conditional fallback)", {
  skip_if_not_heavy()
  skip_on_cran()
  obj <- make_modelA_fit(S = 30L, T = 4L)
  ## No 'does not yet redraw' fallback warning: all Model A tiers are handled.
  warns <- character(0)
  Y <- withCallingHandlers(
    simulate(obj$fit, nsim = 6, seed = 7),
    warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") }
  )
  expect_false(any(grepl("does not yet redraw", warns)))
  expect_equal(ncol(Y), 6L)
  ## Unconditional draws vary across replicates (RE tiers redrawn, not fixed).
  col_sds <- apply(Y, 1, stats::sd)
  expect_true(mean(col_sds) > 0.1)
})

test_that("bootstrap_ci_lv_effects gives wide, covering B_lv intervals (heavy)", {
  skip_if_not_heavy()
  skip_on_cran()
  obj <- make_modelA_fit(S = 40L, T = 4L)
  res <- bootstrap_ci_lv_effects(obj$fit, n_boot = 40, conf = 0.95, seed = 42, n_cores = 2)
  expect_s3_class(res, "data.frame")
  expect_identical(unique(res$method), "bootstrap")
  expect_true(all(is.finite(res$lower) & is.finite(res$upper)))
  ## Honest (not the ~0-width conditional-simulate bug): widths are substantial.
  expect_true(mean(res$upper - res$lower) > 0.2)
  ## Covers the known B_lv on this fixed-seed fixture.
  expect_true(all(obj$truth >= res$lower & obj$truth <= res$upper))
})
