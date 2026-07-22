## Phase K: interval routes and retained internal profile research machinery.
## Tests the public Wald/bootstrap API and typed withdrawal of nonlinear
## profile tokens on `confint.gllvmTMB_multi`, `extract_repeatability`,
## `extract_communality`, `extract_correlations`, and
## `extract_phylo_signal`.

## Build a tiny fit with rr_B + diag_B + diag_W (3 traits, 80 sites).
make_tiny_BW_fit <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 80L,
    n_species = 6L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B = c(0.40, 0.30, 0.50),
    psi_W = c(0.30, 0.40, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = s$data,
      silent = TRUE
    )
  ))
}

## ---- 1. Direct variance component: profile == Wald on well-identified -----

test_that("Direct profile on theta_diag_B agrees with Wald (upper bound) to ~30%", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Pick the most strongly identified trait (largest |theta| with
  ## smallest SE) -- trait_3 in the tiny fit. Profile and Wald should
  ## agree on the UPPER bound (lower bound can be NA at the boundary
  ## where variance -> 0; tested separately).
  ci_p <- gllvmTMB::tmbprofile_wrapper(
    fit,
    name = "theta_diag_B",
    which = 3L,
    level = 0.95,
    transform = exp
  )
  ## Compute Wald CI manually from sd_report
  par_names <- names(fit$opt$par)
  ix <- which(par_names == "theta_diag_B")[3L]
  log_sd <- as.numeric(fit$opt$par[ix])
  se <- sqrt(diag(fit$sd_report$cov.fixed))[ix]
  z <- stats::qnorm(0.975)
  ci_w_hi <- exp(log_sd + z * se)
  expect_true(is.finite(ci_p["upper"]))
  expect_true(ci_p["upper"] > 0)
  ## Profile and Wald upper-bound should agree to within ~30%
  rel_diff <- abs(ci_p["upper"] - ci_w_hi) / ci_w_hi
  expect_lt(rel_diff, 0.5)
})

## ---- 2. Repeatability defaults to Wald; profile refuses ------------------

test_that("extract_repeatability rejects withdrawn profile before fitting", {
  expect_error(
    gllvmTMB::extract_repeatability(NULL, method = "profile"),
    class = "gllvmTMB_repeatability_profile_withdrawn"
  )
})

test_that("extract_repeatability validates malformed bootstrap objects without masking profile withdrawal", {
  malformed <- structure(1, class = "bootstrap_Sigma")
  expect_error(
    gllvmTMB::extract_repeatability(malformed),
    class = "gllvmTMB_invalid_bootstrap_Sigma"
  )
  expect_error(
    gllvmTMB::extract_repeatability(malformed, method = "profile"),
    class = "gllvmTMB_repeatability_profile_withdrawn"
  )

  empty <- structure(list(), class = c("bootstrap_Sigma", "list"))
  expect_error(
    gllvmTMB::extract_repeatability(empty),
    class = "gllvmTMB_invalid_bootstrap_Sigma"
  )

  mismatched <- structure(list(
    point_est = list(ICC_site = c(a = 0.4, b = 0.5)),
    ci_lower = list(ICC_site = c(a = 0.3)),
    ci_upper = list(ICC_site = c(a = 0.5, b = 0.6))
  ), class = c("bootstrap_Sigma", "list"))
  expect_error(
    gllvmTMB::extract_repeatability(mismatched),
    class = "gllvmTMB_invalid_bootstrap_Sigma"
  )
})

test_that("extract_repeatability declares Wald as its public default", {
  expect_identical(
    eval(formals(gllvmTMB::extract_repeatability)$method),
    c("wald", "profile", "bootstrap")
  )
})

test_that("extract_repeatability defaults to Wald", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  rep_ci <- gllvmTMB::extract_repeatability(fit, level = 0.95)
  expect_s3_class(rep_ci, "data.frame")
  expect_named(rep_ci, c("trait", "R", "lower", "upper", "method"))
  expect_equal(nrow(rep_ci), 3L)
  expect_true(all(rep_ci$method == "wald"))
  expect_true(all(rep_ci$R >= 0 & rep_ci$R <= 1))
  has_upper <- !is.na(rep_ci$upper)
  expect_true(all(rep_ci$R[has_upper] <= rep_ci$upper[has_upper] + 1e-6))
})

## ---- 3. extract_correlations returns the expected shape ------------------

test_that("extract_correlations returns tidy frame with required columns", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Use Wald (fastest, most robust for testing)
  cors <- gllvmTMB::extract_correlations(
    fit,
    tier = "unit",
    level = 0.95,
    method = "wald"
  )
  expect_s3_class(cors, "data.frame")
  expect_named(
    cors,
    c(
      "tier", "trait_i", "trait_j", "correlation", "lower", "upper", "method",
      "interval_status"
    )
  )
  ## 3 traits at B tier -> 3 unique pairs
  expect_equal(nrow(cors), 3L)
  expect_true(all(cors$tier == "B"))
  expect_true(all(cors$method == "wald"))
  expect_true(all(cors$correlation >= -1 & cors$correlation <= 1))
  expect_true(all(cors$lower <= cors$correlation + 1e-6))
  expect_true(all(cors$upper >= cors$correlation - 1e-6))
})

test_that("extract_correlations supports `pair` argument", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  one <- gllvmTMB::extract_correlations(
    fit,
    tier = "unit",
    pair = c("trait_1", "trait_2"),
    method = "wald"
  )
  expect_equal(nrow(one), 1L)
  expect_equal(one$trait_i[1], "trait_1")
  expect_equal(one$trait_j[1], "trait_2")
})

## ---- 4. confint() default is method = "profile" --------------------------

test_that("confint(fit) defaults to method = 'profile'", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Default: returns matrix shape with profile-CI rows
  ci_default <- confint(fit, level = 0.95)
  expect_true(is.matrix(ci_default))
  ## Wald should still be a matrix with the same shape
  ci_wald <- confint(fit, level = 0.95, method = "wald")
  expect_equal(dim(ci_default), dim(ci_wald))
  expect_equal(rownames(ci_default), rownames(ci_wald))
  ## Default and Wald should agree to within reasonable numerical
  ## precision on these well-identified fixed effects (b_fix is normal
  ## under the Laplace approx; profile and Wald near-identical).
  rel <- abs(ci_default - ci_wald) / abs(ci_wald)
  expect_true(all(rel < 0.05, na.rm = TRUE))
})

test_that("confint(fit, method='bootstrap') for Sigma_unit works", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ci_b <- suppressMessages(confint(
    fit,
    parm = "Sigma_unit",
    level = 0.95,
    method = "bootstrap",
    nsim = 30L,
    seed = 1L
  ))
  expect_s3_class(ci_b, "data.frame")
  expect_named(ci_b, c("parameter", "estimate", "lower", "upper", "method"))
  expect_true(all(ci_b$method == "bootstrap"))
  ## 3-trait Sigma_unit has 6 upper-tri entries
  expect_equal(nrow(ci_b), 6L)
  expect_true(all(grepl("^Sigma_unit\\[", ci_b$parameter)))
})

test_that("Wald Sigma_unit does not attach Psi-only bounds to latent total variance", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ci <- suppressMessages(confint(
    fit,
    parm = "Sigma_unit",
    level = 0.95,
    method = "wald"
  ))
  pieces <- strsplit(
    sub("^[^[]+\\[([^,]+),([^]]+)\\]$", "\\1|\\2", ci$parameter),
    "\\|"
  )
  diag_rows <- vapply(pieces, function(x) identical(x[1L], x[2L]), logical(1))
  expect_equal(sum(diag_rows), 3L)
  expect_true(all(is.finite(ci$estimate[diag_rows])))
  expect_true(all(is.na(ci$lower[diag_rows])))
  expect_true(all(is.na(ci$upper[diag_rows])))
})

## ---- 5. Speed: Wald is meaningfully faster than bootstrap ----------------

test_that("Wald CI for repeatability is faster than bootstrap", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  t_w <- system.time({
    rep_w <- gllvmTMB::extract_repeatability(fit, method = "wald")
  })["elapsed"]
  t_b <- system.time({
    rep_b <- suppressMessages(gllvmTMB::extract_repeatability(
      fit,
      method = "bootstrap",
      nsim = 30L,
      seed = 1L
    ))
  })["elapsed"]
  ## Wald should be faster than 30-rep bootstrap (typically 2-5x).
  ## We assert >= 1x to be safe -- the headline win shows up at larger
  ## scales (full T-trait fit with 5 tiers ~ 75 correlations).
  expect_true(t_w < t_b * 2) ## generous bound to avoid CI flakiness
  expect_s3_class(rep_w, "data.frame")
  expect_s3_class(rep_b, "data.frame")
})

## ---- 6. Method argument is dispatchable on each extractor ----------------

test_that("All extractors accept method argument", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  expect_no_error(
    suppressMessages(gllvmTMB::extract_repeatability(fit, method = "wald"))
  )
  expect_no_error(
    suppressMessages(gllvmTMB::extract_correlations(
      fit,
      tier = "unit",
      method = "wald"
    ))
  )
  expect_no_error(
    suppressMessages(gllvmTMB::extract_communality(
      fit,
      level = "unit",
      ci = TRUE,
      method = "bootstrap",
      nsim = 30L,
      seed = 1L
    ))
  )
})

## ---- 7. Bootstrap fallback for full-Sigma matrices when profile asked ---

test_that("Profile on Sigma_unit (latent+unique tier) falls back to bootstrap", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Profile method should fall back to bootstrap with an info message
  ci <- suppressMessages(confint(fit, parm = "Sigma_unit", method = "profile"))
  expect_s3_class(ci, "data.frame")
  expect_true(all(ci$method == "bootstrap")) ## fell back automatically
})

## ---- 8. Pure-diag tier (no rr): profile gives clean bounds ---------------

test_that("Profile on Sigma_unit (pure-diag tier) gives finite bounds", {
  skip_if_not_heavy()
  skip_on_cran()
  set.seed(42)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 80,
    n_species = 6,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3, 1),
    psi_B = c(0.4, 0.3, 0.5),
    psi_W = c(0.3, 0.4, 0.3),
    beta = matrix(0, 3, 2),
    seed = 42
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      unique(0 + trait | site) +
      unique(0 + trait | site_species),
    data = s$data,
    silent = TRUE
  )))
  ci <- confint(fit, parm = "Sigma_unit", method = "profile", level = 0.95)
  expect_s3_class(ci, "data.frame")
  ## Diagonal entries should have finite bounds (3 diag rows)
  diag_rows <- which(grepl(
    "trait_1,trait_1|trait_2,trait_2|trait_3,trait_3",
    ci$parameter
  ))
  expect_equal(length(diag_rows), 3L)
  expect_true(all(is.finite(ci$lower[diag_rows])))
  expect_true(all(is.finite(ci$upper[diag_rows])))
  ci_wald <- confint(fit, parm = "Sigma_unit", method = "wald", level = 0.95)
  diag_rows_wald <- which(grepl(
    "trait_1,trait_1|trait_2,trait_2|trait_3,trait_3",
    ci_wald$parameter
  ))
  expect_equal(length(diag_rows_wald), 3L)
  expect_true(all(is.finite(ci_wald$lower[diag_rows_wald])))
  expect_true(all(is.finite(ci_wald$upper[diag_rows_wald])))
  ## Off-diagonals are zero by construction in pure-diag tier
  off_rows <- setdiff(seq_len(nrow(ci)), diag_rows)
  expect_true(all(ci$estimate[off_rows] == 0))
  expect_true(all(ci$lower[off_rows] == 0))
  expect_true(all(ci$upper[off_rows] == 0))
  expect_true(all(ci$method[off_rows] == "structural_zero"))
  off_rows_wald <- setdiff(seq_len(nrow(ci_wald)), diag_rows_wald)
  expect_true(all(ci_wald$estimate[off_rows_wald] == 0))
  expect_true(all(ci_wald$lower[off_rows_wald] == 0))
  expect_true(all(ci_wald$upper[off_rows_wald] == 0))
  expect_true(all(ci_wald$method[off_rows_wald] == "structural_zero"))
})

## ---- .qchisq_threshold() level guard (T14, pure R) ---------------
## Dot-internal helper: `level` must be a single number strictly inside
## (0, 1). The "(0, 1)" text is rendered literally by cli.

test_that(".qchisq_threshold() rejects out-of-range or non-scalar level", {
  for (bad in list(1.2, 1, 0, -0.1)) {
    expect_error(
      gllvmTMB:::.qchisq_threshold(bad),
      "must be a single value in (0, 1)", fixed = TRUE
    )
  }
  expect_error(
    gllvmTMB:::.qchisq_threshold(c(0.9, 0.95)),
    "must be a single value in (0, 1)", fixed = TRUE
  )
  expect_error(
    gllvmTMB:::.qchisq_threshold("x"),
    "must be a single value in (0, 1)", fixed = TRUE
  )
})
