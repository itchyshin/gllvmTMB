## M1.6 — extract_repeatability() mixed-family formula fix + tests.
##
## Walks register row MIX-06 from `partial` to `covered`. The
## M1.1 audit (docs/dev-log/audits/2026-05-17-m1-1-mixed-family-extractor-audit.md)
## identified that extract_repeatability's vW formula at
## R/extract-repeatability.R:127 omitted the per-family link
## residual sigma2_d, biasing R upward (toward 1) on non-Gaussian
## fits. The M1.6 fix (in this PR) adds link_residual_per_trait(fit)
## to vW so R = vB / (vB + sd_W^2 + sigma2_d).
##
## Tests:
##   (1) backward-compat: on a pure-Gaussian fit, R is unchanged
##       (sigma2_d = 0 for Gaussian → no behavioural difference);
##   (2) post-fix: on a mixed-family fit, R for non-Gaussian traits
##       is strictly SMALLER than the pre-fix formula
##       (Rule-1: would have failed before the fix);
##   (3) R is in [0, 1] on both Gaussian and mixed-family fits.

# ---- Helpers --------------------------------------------------------

## Pre-fix formula (vW without sigma2_d) for the Rule-1 test.
.repeatability_prefix <- function(fit) {
  rep <- fit$report
  T <- length(levels(fit$data[[fit$trait_col]]))
  Lambda_B <- if (is.null(rep$Lambda_B)) matrix(0, T, 0) else rep$Lambda_B
  Lambda_W <- if (is.null(rep$Lambda_W)) matrix(0, T, 0) else rep$Lambda_W
  sd_B     <- if (is.null(rep$sd_B))     rep(0, T)       else rep$sd_B
  sd_W     <- if (is.null(rep$sd_W))     rep(0, T)       else rep$sd_W
  vB <- diag(Lambda_B %*% t(Lambda_B)) + sd_B^2
  vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2     # NO sigma2_d
  vB / (vB + vW)
}

make_tiny_BW_mixed_fit <- function(seed = 20260517L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 40L, n_species = 4L, n_traits = 3L,
    mean_species_per_site = 3L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B    = c(0.40, 0.30, 0.50),
    psi_W    = c(0.30, 0.40, 0.30),
    beta     = matrix(0, 3L, 2L),
    seed     = seed
  )
  df <- s$data
  trait_lookup <- c("trait_1" = "gaussian",
                    "trait_2" = "binomial",
                    "trait_3" = "poisson")
  df$family <- factor(trait_lookup[as.character(df$trait)],
                      levels = c("gaussian", "binomial", "poisson"))
  ## Cast value per family (group-wise centring; same as M1.2 fixture).
  for (fam in levels(df$family)) {
    idx <- which(df$family == fam)
    v <- df$value[idx]
    df$value[idx] <- switch(fam,
      "gaussian" = v,
      "binomial" = as.integer((v - mean(v)) > 0),
      "poisson"  = pmax(0L, as.integer(round(v - mean(v) + 2))))
  }
  family_list <- list(gaussian(), binomial(), poisson())
  attr(family_list, "family_var") <- "family"
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = df,
      family = family_list,
      silent = TRUE
    )
  ))
}

# ---- (1) backward-compat on pure Gaussian fit ------------------------

test_that("extract_repeatability on Gaussian fit is unchanged after M1.6 fix", {
  skip_on_cran()
  ## Pure Gaussian fit; sigma2_d = 0 → fix is a no-op.
  set.seed(20260517L)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 40L, n_species = 4L, n_traits = 3L,
    mean_species_per_site = 3L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B    = c(0.40, 0.30, 0.50),
    psi_W    = c(0.30, 0.40, 0.30),
    beta     = matrix(0, 3L, 2L),
    seed     = 20260517L
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site) +
      unique(0 + trait | site_species),
    data = s$data,
    silent = TRUE
  )))
  R_extract <- suppressMessages(extract_repeatability(
    fit, level = 0.95, method = "wald"
  ))$R
  R_manual  <- .repeatability_prefix(fit)
  ## For Gaussian, the M1.6 fix is a no-op: link_residual = 0.
  expect_equal(unname(R_extract), unname(R_manual), tolerance = 1e-6,
               label = "Gaussian backward-compat: R should match pre-fix formula")
})

# ---- (2) post-fix mixed-family: non-Gaussian traits get smaller R ---

test_that("extract_repeatability on mixed-family fit shrinks R on non-Gaussian (M1.6 / MIX-06)", {
  skip_on_cran()
  fit <- make_tiny_BW_mixed_fit()
  R_extract <- suppressMessages(extract_repeatability(
    fit, level = 0.95, method = "wald"
  ))$R
  R_prefix  <- unname(.repeatability_prefix(fit))

  ## All R in [0, 1].
  expect_true(all(R_extract >= 0 - 1e-8 & R_extract <= 1 + 1e-8))

  ## trait_1 = gaussian → R_extract == R_prefix.
  expect_equal(R_extract[1], R_prefix[1], tolerance = 1e-6,
               label = "trait_1 (Gaussian): R unchanged by fix")

  ## trait_2 = binomial-logit: link_residual = pi^2/3 ≈ 3.29 added to vW
  ## → R_extract < R_prefix.
  expect_lt(R_extract[2], R_prefix[2] - 1e-3,
            label = "trait_2 (binomial): R should shrink under M1.6 fix")

  ## trait_3 = Poisson-log: link_residual = log(1 + 1/mu) > 0
  ## → R_extract < R_prefix.
  expect_lt(R_extract[3], R_prefix[3] - 1e-4,
            label = "trait_3 (Poisson): R should shrink under M1.6 fix")
})

# ---- (3) sanity: bracket + R-extract method labels ------------------

test_that("extract_repeatability output shape + bracket on mixed-family (M1.6)", {
  skip_on_cran()
  fit <- make_tiny_BW_mixed_fit()
  R <- suppressMessages(extract_repeatability(
    fit, level = 0.95, method = "wald"
  ))
  expect_s3_class(R, "data.frame")
  expect_named(R, c("trait", "R", "lower", "upper", "method"))
  expect_equal(nrow(R), 3L)
  expect_true(all(R$method == "wald"))
  ## R in [0, 1].
  expect_true(all(R$R >= 0 - 1e-8 & R$R <= 1 + 1e-8))
  ## CI brackets the point estimate (where finite).
  has_lo <- is.finite(R$lower)
  has_hi <- is.finite(R$upper)
  expect_true(all(R$lower[has_lo] <= R$R[has_lo] + 1e-6))
  expect_true(all(R$upper[has_hi] >= R$R[has_hi] - 1e-6))
})
