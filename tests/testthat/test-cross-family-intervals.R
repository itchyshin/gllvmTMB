## Slices 2-4 (cross-family intervals arc): calibrated intervals on
## extract_cross_correlations() for BOTH estimands.
##   - multiple_r (aggregate Sigma-block functional) -> parametric bootstrap
##     via bootstrap_Sigma(what = "cross_corr").
##   - contrast_r (pairwise rho_ij)                  -> wired profile via
##     profile_ci_correlation(), on the AUTO scale (Option b: constant link
##     residual added to the i, j diagonals) so the profiled estimate matches
##     the AUTO-scale point estimate + the analytic truth.
##
## Intervals are interval_status = "target_specific_uncalibrated": coverage is
## NOT yet certified (register CI-11 pending). These tests exercise plumbing,
## estimand-identity, guards, and the reconstruction self-check -- NOT coverage.

# --- self-contained cross-family (gaussian + multinomial, shared latent) ------
.sim_xfam_ci <- function(seed = 1L, N = 200L, reps = 5L,
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
.xfam_fam_ci <- function() {
  fam <- list(g = gaussian(), m = multinomial()); attr(fam, "family_var") <- "family"; fam
}
.fit_xfam_ci <- function(seed = 1L, N = 200L, reps = 5L, unique = TRUE) {
  dat <- .sim_xfam_ci(seed, N, reps)
  term <- if (unique) "latent(0 + trait | unit, d = 2, unique = TRUE)" else "indep(0 + trait | unit)"
  fm <- stats::as.formula(paste("value ~ 0 + trait +", term))
  suppressWarnings(suppressMessages(gllvmTMB(
    fm, data = dat, family = .xfam_fam_ci(), trait = "trait", unit = "unit")))
}

# Memoised default fixture (built once per file run, after skip gates).
.xfam_cache <- new.env(parent = emptyenv())
.get_xfam_ci <- function() {
  if (is.null(.xfam_cache$fit)) .xfam_cache$fit <- .fit_xfam_ci(seed = 1L, N = 200L, reps = 5L)
  .xfam_cache$fit
}
# Partner index + nominal-block indices from a fitted cross-family Sigma.
.xfam_pb <- function(fit) {
  S  <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total", link_residual = "auto"))
  tn <- rownames(S$Sigma); mnK <- fit$tmb_data$multinom_K_per_trait
  is_mn <- mnK > 0L; base <- sub(":[^:]*$", "", tn)
  list(tn = tn, p = which(!is_mn)[1L], blk = which(is_mn & base == unique(base[is_mn])[1L]))
}

test_that("profiled contrast_r estimate equals the AUTO-scale point estimate (estimand-identity)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  cc <- suppressMessages(extract_cross_correlations(
    fit, level = "unit", contrasts = TRUE, link_residual = "auto"))
  pt <- cc$contrast_r[[1L]]                       # AUTO-scale point contrast_r
  pb <- .xfam_pb(fit); lr <- suppressWarnings(link_residual_per_trait(fit))
  for (k in seq_along(pb$blk)) {
    ij  <- sort(c(pb$p, pb$blk[k]))
    res <- suppressMessages(profile_ci_correlation(
      fit, tier = "unit", i = ij[1L], j = ij[2L], level = 0.95,
      diag_resid = as.numeric(lr[ij])))
    ## The profiled point estimate is the AUTO-scale quantity -> identical to the
    ## extract_cross_correlations() AUTO point estimate (exercises the mapped-off
    ## contrast Psi through target_fn + the reconstruction self-check).
    expect_equal(unname(res[["estimate"]]), unname(pt[k]), tolerance = 1e-6)
    expect_true(res[["lower"]] <= res[["estimate"]] && res[["estimate"]] <= res[["upper"]])
  }
})

test_that("profile contrast_r interval brackets its estimate across seeds (N ~ 200)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  for (sd in c(1L, 2L)) {
    fit <- .fit_xfam_ci(seed = sd, N = 200L, reps = 4L)
    skip_if_not(isTRUE(fit$opt$convergence == 0L), "N=200 fixture did not converge")
    pb <- .xfam_pb(fit); lr <- suppressWarnings(link_residual_per_trait(fit))
    ij  <- sort(c(pb$p, pb$blk[1L]))
    res <- suppressMessages(profile_ci_correlation(
      fit, tier = "unit", i = ij[1L], j = ij[2L], level = 0.95,
      diag_resid = as.numeric(lr[ij])))
    expect_true(all(is.finite(res)))
    expect_true(res[["lower"]] <= res[["estimate"]] && res[["estimate"]] <= res[["upper"]])
  }
})

test_that("the unit_slope Gaussian canary stays silent on a cross-family unit-tier profile", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  ## A legit cross-family unit-tier profile must NOT trip the B_slope Gaussian-
  ## only canary (that guard lives on tier "unit_slope", not "unit").
  cc <- suppressMessages(extract_cross_correlations(
    fit, level = "unit", contrasts = TRUE, method = "profile", conf = 0.95))
  expect_true("contrast_r_lower" %in% names(cc))
  expect_true(all(cc$contrast_r_method == "profile"))
  expect_true(all(cc$contrast_r_interval_status == "target_specific_uncalibrated"))
})

test_that("multiple_r + method = 'profile' fails loud (block functional is not profileable)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  expect_error(
    extract_cross_correlations(fit, level = "unit", contrasts = FALSE, method = "profile"),
    class = "gllvmTMB_multiple_r_profile_undefined"
  )
})

test_that("reconstruction self-check fires on a corrupted diagonal map (negative control)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  pb <- .xfam_pb(fit); lr <- suppressWarnings(link_residual_per_trait(fit))
  n_traits <- length(pb$tn)
  ## Corrupt theta_diag_B's map so .expand_mapped_diag() mis-assembles Psi; the
  ## extract_Sigma-based rho_hat is unaffected, so target_fn(theta_hat) diverges
  ## from rho_hat and the self-check must abort rather than emit a corrupt CI.
  fit_bad <- fit
  fit_bad$tmb_map$theta_diag_B <- factor(rep(1L, n_traits))
  ij <- sort(c(pb$p, pb$blk[1L]))
  expect_error(
    profile_ci_correlation(fit_bad, tier = "unit", i = ij[1L], j = ij[2L],
                           level = 0.95, diag_resid = as.numeric(lr[ij])),
    class = "gllvmTMB_profile_reconstruction_mismatch"
  )
})

test_that("profile guards: contrasts, tier, and latent-term fences all fire", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  ## (a) contrasts = FALSE -> undefined block profile.
  expect_error(
    extract_cross_correlations(fit, contrasts = FALSE, method = "profile"),
    class = "gllvmTMB_multiple_r_profile_undefined"
  )
  ## (b) structured tier out of scope.
  expect_error(
    extract_cross_correlations(fit, level = "phy", contrasts = TRUE, method = "profile"),
    class = "gllvmTMB_cross_profile_tier_unsupported"
  )
  ## (c) diagonal-only (no shared latent) -> nothing to profile.
  fit_diag <- fit
  fit_diag$use$rr_B <- FALSE
  expect_error(
    extract_cross_correlations(fit_diag, contrasts = TRUE, method = "profile"),
    class = "gllvmTMB_cross_profile_no_latent"
  )
})

test_that("bootstrap path populates multiple_r interval columns with interval_status", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  set.seed(202)
  cc <- suppressWarnings(suppressMessages(extract_cross_correlations(
    fit, level = "unit", contrasts = FALSE, method = "bootstrap",
    conf = 0.95, nsim = 20L, seed = 202)))
  expect_true(all(c("multiple_r_lower", "multiple_r_upper",
                    "multiple_r_method", "multiple_r_interval_status") %in% names(cc)))
  expect_true(all(cc$multiple_r_method == "bootstrap"))
  expect_true(all(cc$multiple_r_interval_status == "target_specific_uncalibrated"))
  ok <- is.finite(cc$multiple_r_lower) & is.finite(cc$multiple_r_upper)
  expect_true(any(ok))
  expect_true(all(cc$multiple_r_lower[ok] <= cc$multiple_r[ok] &
                  cc$multiple_r[ok] <= cc$multiple_r_upper[ok]))
})

test_that("wald populates BOTH estimands (Fisher-z; heuristic_unvalidated; brackets the point est)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  cc <- suppressWarnings(suppressMessages(extract_cross_correlations(
    fit, level = "unit", contrasts = TRUE, method = "wald", conf = 0.95)))
  ## multiple_r Wald columns
  expect_true(all(c("multiple_r_lower", "multiple_r_upper", "multiple_r_method",
                    "multiple_r_interval_status") %in% names(cc)))
  expect_true(all(cc$multiple_r_method == "wald"))
  expect_true(all(cc$multiple_r_interval_status == "heuristic_unvalidated"))
  ## contrast_r Wald columns (list-cols)
  expect_true(all(c("contrast_r_lower", "contrast_r_upper", "contrast_r_method",
                    "contrast_r_interval_status") %in% names(cc)))
  expect_true(all(cc$contrast_r_method == "wald"))
  ## bounds sane: multiple_r lower >= 0 (it is a non-negative multiple correlation)
  ## and the interval brackets the point estimate.
  mr_ok <- is.finite(cc$multiple_r_lower) & is.finite(cc$multiple_r_upper)
  expect_true(any(mr_ok))
  expect_true(all(cc$multiple_r_lower[mr_ok] >= 0))
  expect_true(all(cc$multiple_r_lower[mr_ok] <= cc$multiple_r[mr_ok] &
                  cc$multiple_r[mr_ok] <= cc$multiple_r_upper[mr_ok]))
  ## contrast_r brackets its point estimate (first pair).
  lo1 <- cc$contrast_r_lower[[1L]]; hi1 <- cc$contrast_r_upper[[1L]]; pt1 <- cc$contrast_r[[1L]]
  fin <- is.finite(lo1) & is.finite(hi1)
  expect_true(all(lo1[fin] <= pt1[fin] & pt1[fin] <= hi1[fin]))
})

test_that("wald works with contrasts = FALSE (multiple_r only, no partner-family fence)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  fit <- .get_xfam_ci()
  skip_if_not(isTRUE(fit$opt$convergence == 0L), "fixture did not converge")
  cc <- suppressWarnings(suppressMessages(extract_cross_correlations(
    fit, level = "unit", contrasts = FALSE, method = "wald")))
  expect_true(all(c("multiple_r_lower", "multiple_r_upper") %in% names(cc)))
  expect_false("contrast_r_lower" %in% names(cc))
  expect_true(all(cc$multiple_r_method == "wald"))
})
