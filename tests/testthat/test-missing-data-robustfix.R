# Robustness fixes for the missing-data layer (issue #399). Eight findings from
# an adversarial 5-lens sweep of the shipped missing-data layer (Phases
# 1/2a/2b/2c/3), each with its own regression block here. The numbering matches
# the issue: BUGs 1-4 (silent-wrong / silent-NaN), GAPs 5-7 (loud-but-opaque /
# silent misreport), NIT 8 (doc clarity).
#
# Pure-validation blocks (the precise-error guards: BUG-3, BUG-4, GAP-5, GAP-6)
# run unconditionally -- they error before any TMB fit. Blocks that need a fit
# (BUG-1 rank-deficient abort, BUG-2 mixed-family response link, GAP-7 wide-mask
# preservation) are gated behind skip_if_not_heavy().

# ---- Shared fixtures (mirror test-missing-predictor-gaussian.R) ------------

# Two-trait LONG-format dataset; x and z are UNIT-level (constant within a
# site). The response slope on x is b_x_true, shared across traits.
.rf_make_mi_uni <- function(seed = 202, n_sites = 40, b_x_true = 1.3,
                            miss_idx = c(4L, 12L, 23L, 31L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  x <- 0.25 + 0.8 * z - 0.4 * w + stats::rnorm(n_sites, sd = 0.5)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eta1 <- 0.7 + b_x_true * x[s] - 0.3 * z[s]
    eta2 <- -0.2 + b_x_true * x[s] + 0.5 * z[s]
    rows[[s]] <- data.frame(
      site  = s,
      trait = c("t1", "t2"),
      value = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
      x     = x[s],
      z     = z[s],
      w     = w[s],
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site    <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait   <- factor(dat$trait, levels = c("t1", "t2"))
  dat$species <- factor(rep(1L, nrow(dat)))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  list(data = dat, x_true = x, missing_site = miss_idx, b_x_true = b_x_true)
}

.rf_inject_missing_x <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dat$x[miss_rows] <- NA_real_
  dat
}

# ===========================================================================
# BUG-1: rank-deficient impute design must ABORT (not silently NaN the SEs)
# ===========================================================================

test_that("BUG-1 rank-deficient mi() impute design is rejected cleanly", {
  skip_if_not_heavy()
  dat <- .rf_inject_missing_x(.rf_make_mi_uni())
  ## impute = x ~ z + I(2*z): the two RHS columns are exactly collinear, so the
  ## observed-unit design X_x is rank-deficient (rank 2 < ncol 3 with the
  ## intercept). The count guard (sum(observed) > ncol) passes; only a rank
  ## check catches this. Must abort with a collinearity message, NOT fit to a
  ## NaN fixed-effect SE block.
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data    = dat,
      family  = gaussian(),
      impute  = list(x = x ~ z + I(2 * z)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = TRUE)
    ))),
    "rank|collinear|redundant"
  )
})

# ===========================================================================
# BUG-2: predict(type = "response") must use the PER-ROW inverse link on a
# mixed-family fit (not the first trait's link for every cell).
# ===========================================================================

# A 3-trait mixed-family fit: trait_1 gaussian (identity), trait_2 binomial
# (logit), trait_3 poisson (log). The first family is gaussian, so the OLD code
# applied the identity link to every cell -> binomial/poisson cells were left on
# the link scale (silent wrong).
.rf_make_mixed_family_fit <- function() {
  set.seed(11)
  sim <- simulate_site_trait(
    n_sites = 20, n_species = 3, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
    seed = 11
  )
  sim$data$value[sim$data$trait == "trait_2"] <-
    as.numeric(stats::rbinom(sum(sim$data$trait == "trait_2"), 1, 0.4))
  sim$data$value[sim$data$trait == "trait_3"] <-
    as.numeric(stats::rpois(sum(sim$data$trait == "trait_3"), 2))
  sim$data$family <- factor(
    c("gaussian", "binomial", "poisson")[as.integer(sim$data$trait)],
    levels = c("gaussian", "binomial", "poisson")
  )
  fams <- list(gaussian(), binomial(), poisson())
  attr(fams, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + unique(0 + trait | site),
    data   = sim$data,
    family = fams
  )))
  list(fit = fit, data = sim$data)
}

test_that("per-row inverse link returns lognormal conditional mean, not median", {
  eta <- c(log(2), log(3))
  out <- gllvmTMB:::.apply_linkinv_per_row(
    eta,
    family_id = c(3L, 2L),
    link_id = c(0L, 0L),
    sigma_eps = 0.8
  )
  expect_equal(out[1], exp(eta[1] + 0.5 * 0.8^2))
  expect_equal(out[2], exp(eta[2]))
})

test_that("newdata family/link lookup uses modal ids, not median-truncated ids", {
  expect_equal(gllvmTMB:::.modal_integer_id(c(2L, 4L)), 2L)
  expect_equal(gllvmTMB:::.modal_integer_id(c(4L, 2L)), 4L)
  expect_equal(gllvmTMB:::.modal_integer_id(c(2L, 4L, 4L)), 4L)
  expect_equal(gllvmTMB:::.modal_integer_id(integer(), fallback = 5L), 5L)
  expect_false(identical(
    gllvmTMB:::.modal_integer_id(c(2L, 4L)),
    as.integer(stats::median(c(2L, 4L)))
  ))
})

test_that("BUG-2 predict(type='response') uses per-row inverse link (mixed family)", {
  skip_if_not_heavy()
  mm <- .rf_make_mixed_family_fit()
  fit <- mm$fit

  link <- predict(fit, type = "link")
  resp <- suppressMessages(predict(fit, type = "response"))
  expect_equal(nrow(link), nrow(resp))

  tr <- as.character(link[[fit$trait_col]])
  eta <- link$est
  ## Per-row expected inverse link: identity / plogis / exp.
  expected <- eta
  expected[tr == "trait_2"] <- stats::plogis(eta[tr == "trait_2"])
  expected[tr == "trait_3"] <- exp(eta[tr == "trait_3"])
  expect_equal(resp$est, expected, tolerance = 1e-8)

  ## Sharper: the binomial (logit) cells must be probabilities in (0, 1) and
  ## must DIFFER from the identity-link passthrough the old code produced.
  bin <- tr == "trait_2"
  expect_true(all(resp$est[bin] > 0 & resp$est[bin] < 1))
  expect_false(isTRUE(all.equal(resp$est[bin], eta[bin])))
  ## Poisson (log) cells must be non-negative on the response scale.
  pois <- tr == "trait_3"
  expect_true(all(resp$est[pois] >= 0))
})

# ===========================================================================
# BUG-3: a covariate-model RHS predictor (z) that VARIES within the latent
# level must be rejected (not silently collapsed to the level's first row).
# ===========================================================================

test_that("BUG-3 non-constant covariate-model RHS within a latent level errors", {
  ## Phase 2c mi_group(species) makes the latent level COARSER than the unit:
  ## the covariate model is fit at the species level, so an impute RHS variable
  ## that varies WITHIN a species (here `z`, which is per (site, species)) has
  ## no single species-level value. The old code silently used the species'
  ## first row; the guard must abort.
  set.seed(7)
  n_species <- 6L
  reps <- 3L
  rows <- list()
  sc <- 0L
  for (i in seq_len(n_species)) {
    x_sp <- stats::rnorm(1)
    for (r in seq_len(reps)) {
      sc <- sc + 1L
      ## z varies WITHIN the species (per site_species), violating the
      ## species-level constancy the covariate model requires.
      z_val <- stats::rnorm(1)
      rows[[sc]] <- data.frame(
        site    = sc,
        species = paste0("sp", i),
        trait   = c("t1", "t2"),
        value   = c(0.6 + x_sp, -0.3 + x_sp) + stats::rnorm(2, sd = 0.3),
        x       = x_sp,
        z       = z_val,
        stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  dat$site    <- factor(dat$site, levels = seq_len(sc))
  dat$species <- factor(dat$species, levels = paste0("sp", seq_len(n_species)))
  dat$trait   <- factor(dat$trait, levels = c("t1", "t2"))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  ## Make species 2 + 4 fully missing in x (species-level missingness).
  dat$x[as.character(dat$species) %in% c("sp2", "sp4")] <- NA_real_

  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data    = dat,
      family  = gaussian(),
      impute  = list(x = x ~ z + mi_group(species)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    "constant|vary|varies|one value"
  )
})

# ===========================================================================
# BUG-4: mi(x) reused as a structured random-slope covariate must be rejected
# (the structured term would read raw NA x -> NaN eta).
# ===========================================================================

test_that("BUG-4 mi(x) + phylo_slope(x | species) on the same var is rejected", {
  testthat::skip_if_not_installed("ape")
  set.seed(13)
  n_species <- 8L
  reps <- 2L
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  rows <- list()
  sc <- 0L
  for (i in seq_len(n_species)) {
    x_sp <- stats::rnorm(1)
    for (r in seq_len(reps)) {
      sc <- sc + 1L
      rows[[sc]] <- data.frame(
        site    = sc,
        species = paste0("sp", i),
        trait   = c("t1", "t2"),
        value   = c(0.6 + x_sp, -0.3 + x_sp) + stats::rnorm(2, sd = 0.3),
        x       = x_sp,
        z       = stats::rnorm(1),
        stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  dat$site    <- factor(dat$site, levels = seq_len(sc))
  dat$species <- factor(dat$species, levels = paste0("sp", seq_len(n_species)))
  dat$trait   <- factor(dat$trait, levels = c("t1", "t2"))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  ## x missing for species 3 (only the broadcast fixed column is imputed; the
  ## phylo_slope reads raw x -> NA leak).
  dat$x[as.character(dat$species) == "sp3"] <- NA_real_

  ## mi(x) AND phylo_slope(x | species) reference the SAME variable x.
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + mi(x) + phylo_slope(x | species),
      data       = dat,
      family     = gaussian(),
      phylo_tree = tree,
      impute     = list(x = x ~ z),
      missing    = miss_control(predictor = "model"),
      control    = gllvmTMBcontrol(se = FALSE)
    ))),
    "structured|random.slope|random slope|slope"
  )
})

# ===========================================================================
# GAP-5: a parenthesized additive mi() -- y ~ 0 + trait + (mi(x)) -- must be
# unwrapped, not crash with "could not find function 'mi'".
# ===========================================================================

test_that("GAP-5 parenthesized mi() is unwrapped (no 'could not find function mi')", {
  ## The old RHS walk left the mi() wrapper inside the parens, so the bare `x`
  ## was never stripped and model.matrix raised "could not find function 'mi'".
  ## The parser is a pure function; assert that the parenthesized form is
  ## unwrapped to the SAME parse as the unparenthesized form: mi_vars = "x" and
  ## the fixed RHS carries the bare `x` term (not a literal mi(x) call).
  p_paren <- gllvmTMB:::parse_multi_formula(value ~ 0 + trait + (mi(x)))
  p_plain <- gllvmTMB:::parse_multi_formula(value ~ 0 + trait + mi(x))
  expect_equal(p_paren$mi_vars, "x")
  ## The fixed RHS term labels must include the bare `x` and NOT a mi() call.
  paren_terms <- attr(stats::terms(p_paren$fixed), "term.labels")
  expect_true("x" %in% paren_terms)
  expect_false(any(grepl("mi(", paren_terms, fixed = TRUE)))
  ## Parenthesized parse matches the unparenthesized parse (mi metadata).
  expect_equal(p_paren$mi_vars, p_plain$mi_vars)
  expect_equal(
    attr(stats::terms(p_paren$fixed), "term.labels"),
    attr(stats::terms(p_plain$fixed), "term.labels")
  )
})

test_that("GAP-5 parenthesized mi() fits like the unparenthesized form", {
  skip_if_not_heavy()
  dat <- .rf_inject_missing_x(.rf_make_mi_uni())
  ## End-to-end: the parenthesized mi() must NOT raise the opaque
  ## function-not-found error and must reach a fit (parity with bare mi()).
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + (mi(x)),
    data    = dat,
    family  = gaussian(),
    impute  = list(x = x ~ z + w),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(is.list(fit$missing_data$predictors))
  expect_true("x" %in% names(fit$missing_data$predictors))
})

# ===========================================================================
# GAP-6: the bare mi() variable reused in a transform/interaction -- mi(x) +
# I(x^2) -- must give a PRECISE reuse error, not the generic "NA in design
# matrix" misattribution.
# ===========================================================================

test_that("GAP-6 mi(x) reused in I(x^2) gives a precise reuse error", {
  dat <- .rf_inject_missing_x(.rf_make_mi_uni())
  err <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x) + I(x^2),
      data    = dat,
      family  = gaussian(),
      impute  = list(x = x ~ z + w),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    error = function(e) conditionMessage(e)
  )
  expect_false(is.null(err))
  ## Must NOT be the generic NA-in-design misattribution.
  expect_false(grepl("NA in the fixed-effect design matrix", err, fixed = TRUE))
  ## Must name the reuse cause.
  expect_match(err, "transform|interact|reuse|cannot also appear", ignore.case = TRUE)
})

# ===========================================================================
# GAP-7: gllvmTMB_wide() must NOT strip NA cells when missing =
# miss_control(response = "include") -- otherwise the mask is silently defeated.
# ===========================================================================

test_that("GAP-7 gllvmTMB_wide(response='include') preserves the masked cells", {
  skip_if_not_heavy()
  set.seed(5)
  n_sites <- 18L
  n_sp <- 4L
  Y <- matrix(stats::rnorm(n_sites * n_sp), n_sites, n_sp)
  rownames(Y) <- paste0("s", seq_len(n_sites))
  colnames(Y) <- paste0("sp", seq_len(n_sp))
  ## Introduce NA cells.
  na_cells <- cbind(c(2L, 5L, 9L), c(1L, 3L, 2L))
  Y[na_cells] <- NA_real_
  n_na <- nrow(na_cells)

  fit_inc <- suppressMessages(suppressWarnings(gllvmTMB_wide(
    Y, d = 1, family = gaussian(),
    missing = miss_control(response = "include")
  )))
  ## The masked cells must SURVIVE: predict_missing() returns one row per masked
  ## cell, and the long-format observed-response mask carries the NA count.
  pm <- suppressMessages(predict_missing(fit_inc))
  expect_equal(nrow(pm), n_na)
  iyo <- fit_inc$tmb_data$is_y_observed
  expect_false(is.null(iyo))
  expect_equal(sum(iyo == 0L), n_na)

  W <- matrix(1, nrow = n_sites, ncol = n_sp)
  W[na_cells] <- NA_real_
  fit_wgt <- suppressMessages(suppressWarnings(gllvmTMB_wide(
    Y, d = 1, family = gaussian(),
    weights = W,
    missing = miss_control(response = "include")
  )))
  expect_equal(length(fit_wgt$tmb_data$weights_i), n_sites * n_sp)
  expect_true(all(is.finite(fit_wgt$tmb_data$weights_i)))
  expect_equal(sum(fit_wgt$tmb_data$weights_i == 0), n_na)
  expect_equal(sum(fit_wgt$tmb_data$is_y_observed == 0L), n_na)

  ## The default (drop) path is unchanged: NA cells are removed, no masked rows.
  fit_drop <- suppressMessages(suppressWarnings(gllvmTMB_wide(
    Y, d = 1, family = gaussian()
  )))
  pm_drop <- suppressMessages(predict_missing(fit_drop))
  expect_equal(nrow(pm_drop), 0L)
})

# ===========================================================================
# NIT-8: imputed() row semantics doc clarity. Doc-only fix; assert the runtime
# columns still exist (the doc clarification does not change behaviour).
# ===========================================================================

test_that("NIT-8 imputed() still returns the documented columns", {
  skip_if_not_heavy()
  dat <- .rf_inject_missing_x(.rf_make_mi_uni())
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data    = dat,
    family  = gaussian(),
    impute  = list(x = x ~ z + w),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  imp <- imputed(fit)
  expect_true(all(c("variable", "level", "level_id", "original_row", "model_row", "observed",
                    "estimate", "std_error", "source",
                    "uncertainty_status") %in% names(imp)))
})
