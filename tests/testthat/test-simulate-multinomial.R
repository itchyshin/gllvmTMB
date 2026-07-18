## Slice 1 (cross-family intervals arc): simulate.gllvmTMB_multi now draws the
## multinomial (family_id 16) softmax response, unblocking the parametric
## bootstrap. Removes the gllvmTMB_simulate_multinomial_unsupported fence.
##
## The draw is a grouped pass: the K-1 contrast pseudo-rows of one observation
## share multinom_group_id, baseline pinned at eta = 0; one categorical draw per
## group writes a single 1 into a contrast row (baseline -> all L rows 0), the
## one-hot the TMB softmax likelihood + expand_multinomial_response() use.

# Softmax DGP with a predictor (for fit + round-trip).
.sim_mn_data <- function(seed = 1L, n = 300L, K = 3L,
                         b0 = c(0.5, -0.4), b1 = c(1.0, -0.8)) {
  set.seed(seed)
  x   <- stats::rnorm(n)
  eta <- cbind(0, matrix(b0, n, K - 1L, byrow = TRUE) + outer(x, b1))
  P   <- exp(eta - apply(eta, 1L, max)); P <- P / rowSums(P)
  y   <- vapply(seq_len(n), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))
  data.frame(unit = factor(seq_len(n)), trait = factor("morph"),
             value = factor(y), x = x)
}

# Intercept-only DGP: b1 = 0 so EVERY observation shares one KNOWN softmax, giving
# a closed-form true category distribution independent of the fit and the draw.
.sim_mn_intercept <- function(seed = 1L, n = 3000L, b0 = c(0.7, -0.5)) {
  set.seed(seed)
  p <- exp(c(0, b0)); p <- p / sum(p)
  y <- sample.int(length(p), n, replace = TRUE, prob = p)
  list(df = data.frame(unit = factor(seq_len(n)), trait = factor("morph"),
                       value = factor(y, levels = seq_along(p))),
       p_true = p)
}

# Decode a simulated one-hot response vector back to category codes, per group.
.decode_mn <- function(yvec, mn_rows, mgid) {
  grps <- split(mn_rows, mgid[mn_rows])
  vapply(grps, function(g) {
    w <- which(yvec[g] == 1)
    if (length(w) == 0L) 1L else which(g == g[w][1L]) + 1L   # baseline = 1; contrast k -> cat k+1
  }, integer(1))
}

.fit_mn <- function(df, formula = value ~ 0 + trait + (0 + trait):x) {
  suppressWarnings(suppressMessages(gllvmTMB(
    formula, data = df, family = multinomial(), trait = "trait", unit = "unit")))
}

# Self-contained cross-family (gaussian + multinomial sharing a latent factor)
# builder — the shared-latent fixtures live in another test file (per-file scope).
.sim_xfam_local <- function(seed = 1L, N = 200L, reps = 5L,
                            Lam = matrix(c(1.3, 0.4, 1.0, 0.6, -0.6, 0.9), 3, byrow = TRUE)) {
  d <- ncol(Lam); set.seed(seed)
  Z <- matrix(stats::rnorm(N * d), N, d); u <- Z %*% t(Lam)
  rows <- list()
  for (i in seq_len(N)) for (r in seq_len(reps)) {
    yg <- u[i, 1] + stats::rnorm(1, sd = 0.25)
    p  <- c(1, exp(u[i, 2]), exp(u[i, 3])); p <- p / sum(p)
    yc <- sample.int(3L, 1L, prob = p)
    rows[[length(rows) + 1L]] <- data.frame(unit = i, trait = "cat", family = "m", value = yc)
    rows[[length(rows) + 1L]] <- data.frame(unit = i, trait = "g",   family = "g", value = yg)
  }
  dat <- do.call(rbind, rows)
  dat$unit <- factor(dat$unit, levels = seq_len(N))
  dat$trait <- factor(dat$trait); dat$family <- factor(dat$family)
  dat
}
.xfam_fam_local <- function() {
  fam <- list(g = gaussian(), m = multinomial()); attr(fam, "family_var") <- "family"; fam
}

test_that("simulate() draws a valid multinomial response — fence gone, per-group one-hot", {
  skip_on_cran()
  fit <- .fit_mn(.sim_mn_data(seed = 1L, n = 200L))
  expect_equal(fit$opt$convergence, 0L)
  ## The old fence must be gone.
  expect_error(simulate(fit, nsim = 1L, seed = 42L), NA)
  Y    <- simulate(fit, nsim = 1L, seed = 42L)
  fids <- fit$tmb_data$family_id_vec
  mgid <- fit$tmb_data$multinom_group_id
  mn   <- which(fids == 16L)
  expect_gt(length(mn), 0L)
  ## one-hot values, and each observation-group sums to 0 (baseline) or 1.
  expect_true(all(Y[mn, 1L] %in% c(0, 1)))
  sums <- tapply(Y[mn, 1L], mgid[mn], sum)
  expect_true(all(sums %in% c(0, 1)))
  ## the OLD fence class must NOT be reachable any more.
  expect_no_condition(simulate(fit, nsim = 1L, seed = 1L),
                      class = "gllvmTMB_simulate_multinomial_unsupported")
})

test_that("simulate() is reproducible under a fixed seed", {
  skip_on_cran()
  fit <- .fit_mn(.sim_mn_data(seed = 3L, n = 150L))
  expect_identical(simulate(fit, nsim = 2L, seed = 11L),
                   simulate(fit, nsim = 2L, seed = 11L))
})

test_that("intercept-only large-n simulate matches the KNOWN softmax probs (independent GOF)", {
  skip_on_cran()
  s   <- .sim_mn_intercept(seed = 5L, n = 4000L, b0 = c(0.7, -0.5))
  fit <- .fit_mn(s$df, formula = value ~ 0 + trait)   # intercept-only: one shared softmax
  expect_equal(fit$opt$convergence, 0L)
  Y    <- simulate(fit, nsim = 1L, seed = 99L)
  fids <- fit$tmb_data$family_id_vec
  mgid <- fit$tmb_data$multinom_group_id
  mn   <- which(fids == 16L)
  cats <- .decode_mn(Y[, 1L], mn, mgid)
  obs  <- as.numeric(table(factor(cats, levels = seq_along(s$p_true))))
  ## Expected probs are the KNOWN DGP softmax (NOT recomputed from the draw's
  ## own formula) -> a genuine falsification of a wrong baseline / off-by-one.
  gof  <- suppressWarnings(stats::chisq.test(obs, p = s$p_true))
  expect_gt(gof$p.value, 0.01)
})

test_that("cross-family (gaussian + multinomial) simulate is column-coherent", {
  skip_on_cran(); skip_if_not_installed("MASS")
  dat <- .sim_xfam_local(1L, N = 200L, reps = 5L)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = dat, family = .xfam_fam_local(), trait = "trait", unit = "unit")))
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "cross-family fixture did not converge")
  Y    <- simulate(fit, nsim = 1L, seed = 7L)
  fids <- fit$tmb_data$family_id_vec
  mgid <- fit$tmb_data$multinom_group_id
  gauss <- which(fids == 0L)
  mn    <- which(fids == 16L)
  expect_true(all(is.finite(Y[gauss, 1L])))        # gaussian rows continuous, finite
  expect_true(all(Y[mn, 1L] %in% c(0, 1)))          # multinomial rows one-hot
  sums <- tapply(Y[mn, 1L], mgid[mn], sum)
  expect_true(all(sums %in% c(0, 1)))
})
