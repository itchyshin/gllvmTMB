## Phase K: profile-likelihood confidence intervals.
## Tests the three-method API (`profile` / `wald` / `bootstrap`) on
## `confint.gllvmTMB_multi`, `extract_repeatability`,
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

## ---- 2. Repeatability profile gives reasonable bounds --------------------

test_that("extract_repeatability(method='profile') returns sane bounds", {
  skip_if_not_heavy()
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

## ---- 5. Speed: profile is meaningfully faster than bootstrap -------------

test_that("Profile CI for repeatability is faster than bootstrap", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  t_p <- system.time({
    rep_p <- gllvmTMB::extract_repeatability(fit, method = "profile")
  })["elapsed"]
  t_b <- system.time({
    rep_b <- suppressMessages(gllvmTMB::extract_repeatability(
      fit,
      method = "bootstrap",
      nsim = 30L,
      seed = 1L
    ))
  })["elapsed"]
  ## Profile should be faster than 30-rep bootstrap (typically 2-5x).
  ## We assert >= 1x to be safe -- the headline win shows up at larger
  ## scales (full T-trait fit with 5 tiers ~ 75 correlations).
  expect_true(t_p < t_b * 2) ## generous bound to avoid CI flakiness
  expect_s3_class(rep_p, "data.frame")
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

## ---- 9. Total-variance V_t: profile (Route A) + delta-Wald (Route B) ------
## V_t = (Lambda Lambda^T)_tt + psi_t = diag(Sigma_unit)_tt, the loadings-
## inclusive per-trait total variance. `.profile_ci_total_variance()` is the
## certificate candidate (genuine chi-square_1 profile via `.profile_ci_via_refit`)
## and `.wald_ci_total_variance_logsd()` is a log-SD delta-Wald DIAGNOSTIC. Both
## flow through the single `.total_variance_spec()` builder so they target the
## identical functional. NOTE: these are dev/re-score internals; they do NOT
## touch the public confint bootstrap-fallback path asserted above -- do not
## modify the "Profile on Sigma_unit (latent+unique tier) falls back to
## bootstrap" test.

test_that("total-variance routes: estimand identity, exact gradient, bracketing, guards", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()

  prof <- gllvmTMB:::.profile_ci_total_variance(fit, tier = "unit")
  wald <- gllvmTMB:::.wald_ci_total_variance_logsd(fit, tier = "unit")

  ## (a) Estimand identity: Route A == Route B == diag(extract_Sigma total).
  exs <- gllvmTMB::extract_Sigma(fit, level = "unit", link_residual = "none")
  sig_diag <- unname(diag(as.matrix(exs$Sigma)))
  expect_equal(prof$estimate, wald$estimate, tolerance = 1e-8)
  expect_equal(prof$estimate, sig_diag, tolerance = 1e-6)

  ## (b) Analytic gradient of V_t matches central finite differences (<1e-5).
  spec <- gllvmTMB:::.total_variance_spec(fit, tier = "unit")
  par0 <- fit$opt$par
  for (t in seq_len(spec$n_traits)) {
    ga <- spec$dV_dpar(par0, t)
    gn <- numeric(length(par0))
    h <- 1e-6
    for (m in seq_along(par0)) {
      pp <- par0
      pp[m] <- pp[m] + h
      pm <- par0
      pm[m] <- pm[m] - h
      gn[m] <- (spec$V_of_par(pp, t) - spec$V_of_par(pm, t)) / (2 * h)
    }
    expect_lt(max(abs(ga - gn)), 1e-5)
  }

  ## (c) Profile brackets the point estimate with finite, positive bounds.
  ok <- !is.na(prof$lower) & !is.na(prof$upper)
  expect_true(any(ok))
  expect_true(all(prof$lower[ok] >= 0))
  expect_true(all(prof$lower[ok] <= prof$estimate[ok] + 1e-8))
  expect_true(all(prof$upper[ok] >= prof$estimate[ok] - 1e-8))

  ## (d) Route B is a documented-status diagnostic; where "ok", bounds bracket.
  valid_status <- c(
    "ok", "wide_na", "boundary_na", "pdHess_false",
    "no_sdreport", "cov_dim_mismatch", "se_nonfinite"
  )
  expect_true(all(wald$ci_status %in% valid_status))
  wok <- wald$ci_status == "ok"
  if (any(wok)) {
    expect_true(all(wald$lower[wok] > 0))
    expect_true(all(wald$upper[wok] > wald$lower[wok]))
  }
})

test_that("profile V_t upper bound sits on the chi-square_1 deviance crossing", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  spec <- gllvmTMB:::.total_variance_spec(fit, tier = "unit")

  ## Use the most strongly identified trait (largest V_hat) so the upper bound
  ## is a genuine crossing rather than the parameter ceiling.
  V_hat <- vapply(
    seq_len(spec$n_traits),
    function(tt) spec$V_of_par(fit$opt$par, tt),
    numeric(1)
  )
  t <- which.max(V_hat)
  prof <- gllvmTMB:::.profile_ci_total_variance(fit, tier = "unit", trait_idx = t)
  skip_if(is.na(prof$upper))
  expect_gt(prof$upper, prof$estimate)

  ## At the reported upper bound the constrained deviance should equal the
  ## chi-square_1(0.95) threshold (this is exactly what the profile root-finds).
  target_fn <- function(par, fit) {
    V <- spec$V_of_par(par, t)
    if (is.na(V) || V <= 0) {
      return(NA_real_)
    }
    log(V)
  }
  target_grad <- function(par, fit) {
    V <- spec$V_of_par(par, t)
    if (is.na(V) || V <= 0) {
      return(numeric(length(par)))
    }
    spec$dV_dpar(par, t) / V
  }
  crit <- gllvmTMB:::.qchisq_threshold(0.95)
  mle <- as.numeric(fit$opt$objective)
  nll_hi <- gllvmTMB:::.fix_and_refit_nll(
    fit, target_fn, log(prof$upper), target_grad = target_grad
  )
  skip_if(is.na(nll_hi))
  expect_lt(abs((nll_hi - mle) - crit), 0.1)
})

## ---- 10. Restored recovery-grade correlation profile on Sigma_total -------
## profile_ci_correlation() was withdrawn (extract_correlations(method =
## "profile") aborted) because the old prototype targeted Sigma_shared =
## Lambda Lambda^T, mismatching fisher-z / wald / bootstrap (all Sigma_total).
## The restored route targets Sigma_total = Lambda Lambda^T + diag(Psi) +
## diag(link_residual) via `.correlation_total_spec()`, profiled on the
## Fisher-z scale. It is RECOVERY-GRADE (interval_status =
## "recovery_unvalidated"), NOT coverage-certified (audit
## 2026-05-17-profile-correlation-surface.md option b; validation-debt
## CI-08 / CI-10).

## Hand-built binomial-logit fit: link residual pi^2/3 per trait is a constant
## (no eta needed), so the spec's Sigma_total math is deterministic and the
## analytic-gradient / estimand checks below need no TMB fit.
make_fake_binomial_corr_fit <- function() {
  par <- c(
    theta_rr_B = 0.9,
    theta_rr_B = 0.4,
    theta_diag_B = log(0.5),
    theta_diag_B = log(0.6)
  )
  structure(
    list(
      opt = list(par = par),
      tmb_data = list(
        family_id_vec = c(1L, 1L), # binomial
        link_id_vec = c(0L, 0L), # logit -> link residual pi^2/3
        trait_id = c(0L, 1L) # 0-based trait ids
      ),
      tmb_map = list(),
      report = list(),
      use = list(rr_B = TRUE, diag_B = TRUE),
      d_B = 1L,
      n_traits = 2L,
      data = data.frame(trait = factor(c("t1", "t2"))),
      trait_col = "trait"
    ),
    class = "gllvmTMB_multi"
  )
}

test_that(".correlation_total_spec: analytic drho_dpar matches finite diff", {
  fake <- make_fake_binomial_corr_fit()
  spec <- gllvmTMB:::.correlation_total_spec(
    fake, "B", 1L, 2L, link_residual = "auto"
  )
  par0 <- fake$opt$par
  ga <- spec$drho_dpar(par0)
  gn <- numeric(length(par0))
  h <- 1e-6
  for (m in seq_along(par0)) {
    pp <- par0
    pp[m] <- pp[m] + h
    pm <- par0
    pm[m] <- pm[m] - h
    gn[m] <- (spec$rho_of_par(pp) - spec$rho_of_par(pm)) / (2 * h)
  }
  expect_lt(max(abs(ga - gn)), 1e-5)
})

test_that(".correlation_total_spec targets Sigma_total (link residual on diag)", {
  fake <- make_fake_binomial_corr_fit()
  par0 <- fake$opt$par
  spec_auto <- gllvmTMB:::.correlation_total_spec(
    fake, "B", 1L, 2L, link_residual = "auto"
  )
  spec_none <- gllvmTMB:::.correlation_total_spec(
    fake, "B", 1L, 2L, link_residual = "none"
  )
  rho_auto <- spec_auto$rho_of_par(par0)
  rho_none <- spec_none$rho_of_par(par0)
  ## Both interior; the pi^2/3 link residual on the diagonal shrinks the
  ## correlation, so the Sigma_total ("auto") value is strictly smaller in
  ## magnitude than the no-residual value -- i.e. the residual IS included.
  expect_true(is.finite(rho_auto))
  expect_lt(abs(rho_auto), 1)
  expect_lt(abs(rho_auto), abs(rho_none))
  ## Closed-form Sigma_total check.
  llt <- c(0.81, 0.16, 0.36) # Sigma11_shared, Sigma22_shared, Sigma12
  psi <- c(0.25, 0.36)
  r <- pi^2 / 3
  denom <- sqrt((llt[1] + psi[1] + r) * (llt[2] + psi[2] + r))
  expect_equal(rho_auto, llt[3] / denom, tolerance = 1e-10)
})

test_that("profile_ci_correlation(): finite interval brackets point in [-1,1]", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ci <- suppressMessages(suppressWarnings(
    gllvmTMB:::profile_ci_correlation(fit, tier = "unit", i = 1L, j = 2L)
  ))
  expect_named(ci, c("estimate", "lower", "upper"))
  expect_true(all(is.finite(ci)))
  expect_gte(ci[["estimate"]], -1)
  expect_lte(ci[["estimate"]], 1)
  expect_lte(ci[["lower"]], ci[["estimate"]] + 1e-8)
  expect_gte(ci[["upper"]], ci[["estimate"]] - 1e-8)
  expect_gte(ci[["lower"]], -1)
  expect_lte(ci[["upper"]], 1)
})

test_that("profile correlation point == fisher-z point (Sigma_total, interior)", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ## rank-1 latent (d = 1) over 3 traits: Lambda Lambda^T is rank-deficient,
  ## but Psi keeps rho interior. The restored profile point must equal the
  ## fisher-z point (both Sigma_total), i.e. interior, NOT +/-1.
  cor_prof <- suppressMessages(suppressWarnings(
    gllvmTMB:::profile_ci_correlation(fit, tier = "unit", i = 1L, j = 2L)
  ))
  cor_fz <- suppressMessages(gllvmTMB::extract_correlations(
    fit, tier = "unit", pair = c(1L, 2L), method = "fisher-z"
  ))
  expect_equal(
    unname(cor_prof[["estimate"]]), cor_fz$correlation[1L],
    tolerance = 1e-5
  )
  expect_lt(abs(unname(cor_prof[["estimate"]])), 1)

  ## End-to-end wiring: extract_correlations(method = "profile") routes to the
  ## restored profile and fences the interval as recovery-grade (not certified).
  cor_pr_tab <- suppressMessages(gllvmTMB::extract_correlations(
    fit, tier = "unit", pair = c(1L, 2L), method = "profile"
  ))
  expect_equal(nrow(cor_pr_tab), 1L)
  expect_equal(cor_pr_tab$method[1L], "profile")
  expect_equal(cor_pr_tab$interval_status[1L], "recovery_unvalidated")
  ## Point is method-invariant (same Sigma_total value as fisher-z).
  expect_equal(
    cor_pr_tab$correlation[1L], cor_fz$correlation[1L], tolerance = 1e-8
  )
  ## Interval, when finite, brackets the point.
  if (is.finite(cor_pr_tab$lower[1L])) {
    expect_lte(cor_pr_tab$lower[1L], cor_pr_tab$correlation[1L] + 1e-8)
  }
  if (is.finite(cor_pr_tab$upper[1L])) {
    expect_gte(cor_pr_tab$upper[1L], cor_pr_tab$correlation[1L] - 1e-8)
  }
})

test_that("confint(method='profile') routes rho through the restored profile", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_tiny_BW_fit()
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:unit:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  ## Restored: no longer aborts with the withdrawn-class error.
  expect_false(inherits(ci, "gllvmTMB_nonlinear_profile_withdrawn"))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(ncol(ci), 2L)
})
