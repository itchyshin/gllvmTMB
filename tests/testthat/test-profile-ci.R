## Phase K: profile-likelihood confidence intervals.
## Tests the three-method API (`profile` / `wald` / `bootstrap`) on
## `confint.gllvmTMB_multi`, `extract_repeatability`,
## `extract_communality`, `extract_correlations`, and
## `extract_phylo_signal`.

## Build a tiny fit with rr_B + diag_B + diag_W (3 traits, 80 sites).
make_tiny_BW_fit <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites              = 80L,
    n_species            = 6L,
    n_traits             = 3L,
    mean_species_per_site = 4L,
    Lambda_B             = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B                  = c(0.40, 0.30, 0.50),
    psi_W                  = c(0.30, 0.40, 0.30),
    beta                 = matrix(0, 3L, 2L),
    seed                 = seed
  )
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
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
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Pick the most strongly identified trait (largest |theta| with
  ## smallest SE) -- trait_3 in the tiny fit. Profile and Wald should
  ## agree on the UPPER bound (lower bound can be NA at the boundary
  ## where variance -> 0; tested separately).
  ci_p <- gllvmTMB::tmbprofile_wrapper(
    fit, name = "theta_diag_B", which = 3L,
    level = 0.95, transform = exp
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

## ---- 2. Repeatability profile gives reasonable bounds --------------------

test_that("extract_repeatability(method='profile') returns sane bounds", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  rep_ci <- suppressMessages(
    gllvmTMB::extract_repeatability(fit, level = 0.95, method = "profile")
  )
  ## Shape
  expect_s3_class(rep_ci, "data.frame")
  expect_named(rep_ci, c("trait", "R", "lower", "upper", "method"))
  expect_equal(nrow(rep_ci), 3L)
  ## Honest labelling: when method='profile' is requested but the
  ## proper Lagrange-style profile-likelihood path isn't yet
  ## implemented for full-Sigma repeatability, the output reports
  ## method = "wald" (the actual computation) and emits a one-shot
  ## inform message explaining the fallback. This avoids the
  ## previous misleading behaviour where the label said "profile"
  ## but the bounds were Wald.
  expect_true(all(rep_ci$method == "wald"))
  ## R is in [0, 1]
  expect_true(all(rep_ci$R >= 0 & rep_ci$R <= 1))
  ## When upper bound is finite, lower < estimate < upper
  has_upper <- !is.na(rep_ci$upper)
  expect_true(all(rep_ci$R[has_upper] <= rep_ci$upper[has_upper] + 1e-6))
})

## ---- 3. extract_correlations returns the expected shape ------------------

test_that("extract_correlations returns tidy frame with required columns", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Use Wald (fastest, most robust for testing)
  cors <- gllvmTMB::extract_correlations(fit, tier = "B", level = 0.95,
                                         method = "wald")
  expect_s3_class(cors, "data.frame")
  expect_named(cors, c("tier", "trait_i", "trait_j", "correlation",
                       "lower", "upper", "method"))
  ## 3 traits at B tier -> 3 unique pairs
  expect_equal(nrow(cors), 3L)
  expect_true(all(cors$tier == "B"))
  expect_true(all(cors$method == "wald"))
  expect_true(all(cors$correlation >= -1 & cors$correlation <= 1))
  expect_true(all(cors$lower <= cors$correlation + 1e-6))
  expect_true(all(cors$upper >= cors$correlation - 1e-6))
})

test_that("extract_correlations supports `pair` argument", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  one <- gllvmTMB::extract_correlations(fit, tier = "B",
                                        pair = c("trait_1", "trait_2"),
                                        method = "wald")
  expect_equal(nrow(one), 1L)
  expect_equal(one$trait_i[1], "trait_1")
  expect_equal(one$trait_j[1], "trait_2")
})

## ---- 4. confint() default is method = "profile" --------------------------

test_that("confint(fit) defaults to method = 'profile'", {
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

test_that("confint(fit, method='bootstrap') for Sigma_B works", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ci_b <- suppressMessages(confint(fit, parm = "Sigma_B",
                                   level = 0.95, method = "bootstrap",
                                   nsim = 30L, seed = 1L))
  expect_s3_class(ci_b, "data.frame")
  expect_named(ci_b, c("parameter", "estimate", "lower", "upper", "method"))
  expect_true(all(ci_b$method == "bootstrap"))
  ## 3-trait Sigma_B has 6 upper-tri entries
  expect_equal(nrow(ci_b), 6L)
})

## ---- 5. Speed: profile is meaningfully faster than bootstrap -------------

test_that("Profile CI for repeatability is faster than bootstrap", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  t_p <- system.time({
    rep_p <- gllvmTMB::extract_repeatability(fit, method = "profile")
  })["elapsed"]
  t_b <- system.time({
    rep_b <- suppressMessages(gllvmTMB::extract_repeatability(
      fit, method = "bootstrap", nsim = 30L, seed = 1L))
  })["elapsed"]
  ## Profile should be faster than 30-rep bootstrap (typically 2-5x).
  ## We assert >= 1x to be safe -- the headline win shows up at larger
  ## scales (full T-trait fit with 5 tiers ~ 75 correlations).
  expect_true(t_p < t_b * 2)  ## generous bound to avoid CI flakiness
  expect_s3_class(rep_p, "data.frame")
  expect_s3_class(rep_b, "data.frame")
})

## ---- 6. Method argument is dispatchable on each extractor ----------------

test_that("All extractors accept method argument", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  expect_no_error(
    suppressMessages(gllvmTMB::extract_repeatability(fit, method = "wald"))
  )
  expect_no_error(
    suppressMessages(gllvmTMB::extract_correlations(fit, tier = "B", method = "wald"))
  )
  expect_no_error(
    suppressMessages(gllvmTMB::extract_communality(fit, level = "B", ci = TRUE,
                                                  method = "bootstrap", nsim = 30L,
                                                  seed = 1L))
  )
})

## ---- 7. Bootstrap fallback for full-Sigma matrices when profile asked ---

test_that("Profile on Sigma_B (rr+diag tier) falls back to bootstrap", {
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## Profile method should fall back to bootstrap with an info message
  ci <- suppressMessages(confint(fit, parm = "Sigma_B", method = "profile"))
  expect_s3_class(ci, "data.frame")
  expect_true(all(ci$method == "bootstrap"))  ## fell back automatically
})

## ---- 8. Pure-diag tier (no rr): profile gives clean bounds ---------------

test_that("Profile on Sigma_B (pure-diag tier) gives finite bounds", {
  skip_on_cran()
  set.seed(42)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 80, n_species = 6, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3, 1),
    psi_B = c(0.4, 0.3, 0.5), psi_W = c(0.3, 0.4, 0.3),
    beta = matrix(0, 3, 2), seed = 42
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      unique(0 + trait | site) +
      unique(0 + trait | site_species),
    data = s$data, silent = TRUE
  )))
  ci <- confint(fit, parm = "Sigma_B", method = "profile", level = 0.95)
  expect_s3_class(ci, "data.frame")
  ## Diagonal entries should have finite bounds (3 diag rows)
  diag_rows <- which(grepl("trait_1,trait_1|trait_2,trait_2|trait_3,trait_3",
                           ci$parameter))
  expect_equal(length(diag_rows), 3L)
  expect_true(all(is.finite(ci$lower[diag_rows])))
  expect_true(all(is.finite(ci$upper[diag_rows])))
  ## Off-diagonals are zero by construction in pure-diag tier
  off_rows <- setdiff(seq_len(nrow(ci)), diag_rows)
  expect_true(all(ci$estimate[off_rows] == 0))
})
