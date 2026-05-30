## ANI-06 — animal_slope(x | id) recovery + byte-equivalence.
##
## `animal_slope(x | id)` is the additive-genetic random-SLOPE keyword:
##   eta += beta_a(i) * x_io,   beta_a ~ N(0, sigma2_slope * A)
## i.e. ONE shared slope variance, slopes correlated by the pedigree A
## (the documented contract; see ?animal_slope -- "Mathematical parallel
## to phylo_slope()"). It desugars in R/brms-sugar.R to
##   phylo_slope(x | id, vcv = A)            [A = ...]   /
##   phylo_slope(x | id, vcv = pedigree_to_Ainv_sparse(ped))  [pedigree = ...]
## and rides the legacy slope-only engine path (b_phy_slope /
## log_sigma_slope in src/gllvmTMB.cpp). This is NOT the augmented
## intercept+slope random regression (sigma2_alpha, sigma2_beta, rho) of
## phylo_unique(1 + x | sp); that augmented form is reached via the
## `.phylo_unique_augmented` marker, which animal_slope does not set.
##
## These cells pin (i) sigma_slope recovery, (ii) byte-equivalence with
## phylo_slope(x | id, vcv = A) per Design 14 §5, and (iii) the fail-loud
## guard against the `animal_unique(1 + x | id)` slope-drop trap.

# ---- Shared slope-only fixture: pedigree -> A, beta_i ~ N(0, s2*A) ----

make_animal_slope_fixture <- function(seed = 202L) {
  set.seed(seed)
  ## 12 founders + 38 offspring, parents drawn from the founders only
  ## (topologically sorted: parents always precede offspring).
  n_found <- 12L
  n_off <- 38L
  founders <- paste0("F", seq_len(n_found))
  ids <- c(founders, paste0("O", seq_len(n_off)))
  sire <- c(rep(NA_character_, n_found), character(n_off))
  dam <- c(rep(NA_character_, n_found), character(n_off))
  for (k in seq_len(n_off)) {
    sire[n_found + k] <- sample(founders, 1L)
    dam[n_found + k] <- sample(founders, 1L)
  }
  ped <- data.frame(id = ids, sire = sire, dam = dam,
                    stringsAsFactors = FALSE)
  A <- gllvmTMB::pedigree_to_A(ped)
  n_id <- nrow(A)

  ## Slope-only truth: beta_i ~ N(0, sigma2_slope * A).
  sigma2_slope <- 0.5
  LA <- t(chol(A + diag(1e-8, n_id)))
  beta <- as.numeric(LA %*% rnorm(n_id, sd = sqrt(sigma2_slope)))
  names(beta) <- rownames(A)

  n_traits <- 3L
  n_rep <- 5L
  df <- expand.grid(
    species = factor(rownames(A), levels = rownames(A)),
    trait = factor(paste0("t", seq_len(n_traits)),
                   levels = paste0("t", seq_len(n_traits))),
    rep = seq_len(n_rep)
  )
  df$x <- rnorm(nrow(df))
  mu_t <- c(1.5, 0.5, -0.5)[as.integer(df$trait)]
  df$value <- mu_t + beta[as.character(df$species)] * df$x +
    rnorm(nrow(df), sd = 0.4)

  list(data = df, A = A, ped = ped,
       sigma2_slope = sigma2_slope, beta = beta)
}

# Robust "reached a genuine optimum" gate. `nlminb`'s integer convergence
# code is platform-sensitive on this flat slope-only likelihood (it returns
# code 0 / "relative convergence (4)" under the macOS arm64 BLAS but code 1
# / "false convergence (8)" under the CI Linux/Windows BLAS, even though the
# fit lands on the same optimum to TMB tolerance — recovery and the
# phylo_slope byte-equivalence below still hold). So we assert the
# build-independent optimum-quality signals (finite objective + a
# positive-definite Hessian + a successful sdreport) rather than the literal
# code, matching the gate used in test-relmat-unique-slope-gaussian.R.
expect_reached_optimum <- function(fit) {
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_true(isTRUE(fit$fit_health$sdreport_ok))
}

# ---- (1) Recovery: sigma_slope (dense A= path; base R only) -----------

test_that("animal_slope(x | id, A = A) recovers sigma_slope (ANI-06)", {
  skip_on_cran()
  fx <- make_animal_slope_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_slope(x | species, A = fx$A),
    data = fx$data, unit = "species", cluster = "species"
  )))
  expect_reached_optimum(fit)

  ## Slope-only engine path: exactly one log_sigma_slope, no intercept
  ## variance / correlation parameters (would be log_sd_b / atanh_cor_b).
  pn <- names(fit$opt$par)
  expect_true(any(grepl("log_sigma_slope", pn)))
  expect_false(any(grepl("log_sd_b|atanh_cor_b", pn)),
    info = "animal_slope is slope-only; it must NOT fit the augmented
            intercept+slope (sigma_alpha, sigma_beta, rho) block.")

  sigma_slope_hat <- exp(fit$opt$par[grepl("log_sigma_slope", pn)])
  expect_equal(unname(sigma_slope_hat), sqrt(fx$sigma2_slope),
               tolerance = 0.15,
               label = "animal_slope sigma_slope recovery")
})

# ---- (2) Byte-equivalence: animal_slope(A=) == phylo_slope(vcv=) ------

test_that(
  "animal_slope(x | id, A = A) is byte-equivalent with phylo_slope(x | id, vcv = A) (ANI-06 / Design 14 §5)", {
  skip_on_cran()
  fx <- make_animal_slope_fixture()
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_slope(x | species, A = fx$A),
    data = fx$data, unit = "species", cluster = "species"
  )))
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | species, vcv = fx$A),
    data = fx$data, unit = "species", cluster = "species"
  )))
  expect_reached_optimum(fit_a)
  expect_reached_optimum(fit_p)

  ## Same parameter vector and same logLik: animal_slope is a pure
  ## rewrite layer onto phylo_slope(vcv = A), no new TMB likelihood.
  expect_equal(length(fit_a$opt$par), length(fit_p$opt$par))
  expect_equal(unname(fit_a$opt$par), unname(fit_p$opt$par),
               tolerance = 1e-5,
               label = "animal_slope(A=) vs phylo_slope(vcv=A) parameters")
  expect_equal(as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
               tolerance = 1e-6,
               label = "animal_slope(A=) vs phylo_slope(vcv=A) logLik")
})

# ---- (3) Sparse Ainv route: animal_slope(pedigree = ) recovers -------

test_that("animal_slope(x | id, pedigree = ped) recovers sigma_slope via sparse Ainv (ANI-06 / ANI-08)", {
  skip_on_cran()
  ## animal_slope(pedigree=) auto-routes through pedigree_to_Ainv_sparse(),
  ## which wraps MCMCglmm::inverseA() (Design 47 §10).
  skip_if_not_installed("MCMCglmm")
  fx <- make_animal_slope_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_slope(x | species, pedigree = fx$ped),
    data = fx$data, unit = "species", cluster = "species"
  )))
  expect_reached_optimum(fit)
  sigma_slope_hat <- exp(
    fit$opt$par[grepl("log_sigma_slope", names(fit$opt$par))])
  expect_equal(unname(sigma_slope_hat), sqrt(fx$sigma2_slope),
               tolerance = 0.2,
               label = "animal_slope(pedigree=) sigma_slope recovery")
})

# ---- (4) UX guard: animal_unique(1 + x | id) fails loud --------------
#
# `animal_unique` fits per-trait additive-genetic random INTERCEPTS only
# (a bare `id` column; see ?animal_unique). Before the R/brms-sugar.R
# guard, `animal_unique(1 + x | id)` passed the slope-bearing bar verbatim
# to phylo_rr, which SILENTLY DROPPED the slope and fit an intercept-only
# model (byte-identical to `animal_unique(id)`). The slope entry point is
# `animal_slope(x | id)`. The augmented intercept+slope random regression
# (sigma2_alpha, sigma2_beta, rho) via `animal_unique(1 + x | id)` is
# deferred to Design 56 Stage 3 (see test-animal-unique-slope-gaussian.R,
# gated skip_until_stage3()); until then this form must fail loud, not
# silently collapse.

test_that("animal_unique(1 + x | id) fails loud and points to animal_slope (UX trap guard)", {
  fx_A <- diag(4)
  rownames(fx_A) <- colnames(fx_A) <- paste0("i", 1:4)
  df <- data.frame(
    species = factor(rep(rownames(fx_A), each = 2L), levels = rownames(fx_A)),
    trait = factor(rep(c("t1", "t2"), times = 4L)),
    x = rnorm(8L),
    value = rnorm(8L)
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_unique(1 + x | species, A = fx_A),
      data = df, unit = "species", cluster = "species"
    ))),
    regexp = "does not take a random slope|animal_slope",
    info = "Augmented-slope bar in animal_unique() must fail loud, not silently drop the slope."
  )
  ## Long-form augmented LHS is guarded too.
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_unique(0 + trait + (0 + trait):x | species, A = fx_A),
      data = df, unit = "species", cluster = "species"
    ))),
    regexp = "does not take a random slope|animal_slope"
  )
})
