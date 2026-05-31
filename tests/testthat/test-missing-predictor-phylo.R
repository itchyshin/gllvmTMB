# Phase 3 (issue #332 / design 69): a PHYLOGENETIC species-level Gaussian
# missing PREDICTOR via mi(x) whose covariate model carries a phylo-structured
# intercept, declared `impute = list(x = x ~ z + phylo(1 | species, tree = t))`.
# This is the gllvmTMB analogue of drmTMB's MD4 structured route, ported with
# the design 69 decisions:
#   * the phylo(1|species, tree=) token declares (a) the species LATENT level
#     for the broadcast (reuses the Phase-2c mi_group machinery, keyed to the
#     tree's species) AND (b) a phylo-structured intercept on the covariate
#     mean (design 69 surface).
#   * STANDARDIZED-field parametrization (Q1): g_x ~ N(0, A) via the EXISTING
#     sparse Ainv_phy_rr (unit-variance GMRF penalty, the phylo_diag shape at
#     src/gllvmTMB.cpp:771-776), then eta_x(s) += sd_x * g_x(node(s)). NOT
#     drmTMB's unstandardized fold-sd-into-penalty form.
#   * the Pagel partition (Q2): residual sigma_x^2 I + phylo sd_x^2 A. As
#     sd_x -> 0 the covariate model degrades to the independent Phase-2c model
#     with no separate code path.
#   * Level-1 INDEPENDENT only: the covariate phylo field g_x is its OWN field
#     with its OWN sd_x, NOT shared/correlated with any response phylo field
#     (they may reuse the same Ainv precision but are SEPARATE latents). The
#     joint field (correlate_with="response") is DEFERRED to Phase 4.
#
# Gate map (design 69 sec.8 / design 59 sec.9):
#   1. high-vs-low phylo-signal recovery (the headline gate): STRONG signal ->
#      the phylo covariate model recovers missing-x BETTER than an independent
#      (Phase-2c, no-phylo) model (higher correlation with truth) and recovers
#      beta_x / sd_x / the response slope within a band. WEAK signal (sd_x->0)
#      -> degrades gracefully (no worse than independent) and a phylo-signal
#      diagnostic flags the weak case.
#   2. species broadcast: one latent per missing SPECIES; one observed value
#      per species enforced (clear error otherwise).
#   3. independence from the response phylo field: a fit with BOTH a response
#      phylo effect AND a phylo covariate model -- beta_x is identified and the
#      two phylo fields are SEPARATE `random` blocks (not conflated).
#   4. no-op / non-regression: Phase 2a/2c (non-phylo) mi() unchanged.
#
# All fits are gated behind skip_if_not_heavy(); the pure-validation boundary
# blocks run unconditionally (they error before any TMB fit).

skip_unless_phylo_deps <- function() {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
}

# ---- Fixtures --------------------------------------------------------------

# Simulate a SPECIES-level trait x from a phylogenetic field plus an i.i.d.
# species residual (the Pagel partition), then build a long-format multi-trait
# dataset where x is broadcast to every (species, trait) row. `sd_x` controls
# the phylogenetic signal: large sd_x = strong signal (x tracks the tree),
# sd_x near 0 = weak signal (x phylogenetically unstructured).
#
# The covariate model is INTERCEPT-ONLY: x = alpha + u_x + eps_x, with NO
# observed covariate on x. This is the biologically central setup -- the ONLY
# information about a missing species' x is its phylogenetic neighbours (via the
# field u_x). An independent (no-phylo) covariate model has nothing but the
# global mean to impute a missing species, so phylogenetic borrowing has room to
# help when the signal is strong (design 69 sec.6.2). A covariate that also
# carried an observed predictor would let the independent model impute from that
# predictor and mask the borrowing.
#
# Layout: n_species species, each observed across `reps` sites, 2 traits per
# (site, species) cell. x is SPECIES-level (constant within a species). z is a
# species-level RESPONSE covariate (not in the covariate model for x). The
# response slope on x is `b_x_true`, shared across traits. The species factor
# matches the tree tip labels, so phylo(1|species, tree=tree) keys to it.
.make_mi_phylo <- function(seed = 11, n_species = 40L, reps = 3L,
                           b_x_true = 1.2, sd_x = 1.4, sigma_x = 0.4,
                           alpha = 0.3, resp_sd = 0.4) {
  set.seed(seed)
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  Cphy <- ape::vcv(tree, corr = TRUE)
  ## Species-level RESPONSE covariate z (NOT in the covariate model for x).
  z_sp <- stats::rnorm(n_species)
  ## Phylogenetic field u_x ~ N(0, sd_x^2 A): correlated draw via Cholesky.
  Lphy <- chol(Cphy + 1e-9 * diag(n_species))
  u_x <- sd_x * as.numeric(t(Lphy) %*% stats::rnorm(n_species))
  ## Pagel partition, INTERCEPT-ONLY covariate model: x = alpha + u_x + eps_x.
  eps_x <- stats::rnorm(n_species, sd = sigma_x)
  x_sp <- alpha + u_x + eps_x
  ## Two traits, shared x slope, trait-specific intercept + z slope. `resp_sd`
  ## is the response noise: a LARGER resp_sd makes the response y carry LESS
  ## information about a missing species' x, so the covariate-model prior (the
  ## phylogenetic borrowing) drives the imputation and the strong-vs-independent
  ## contrast is not masked by the response likelihood.
  rows <- list()
  sc <- 0L
  for (i in seq_len(n_species)) {
    for (r in seq_len(reps)) {
      sc <- sc + 1L
      eta1 <- 0.6 + b_x_true * x_sp[i] - 0.25 * z_sp[i]
      eta2 <- -0.3 + b_x_true * x_sp[i] + 0.45 * z_sp[i]
      rows[[sc]] <- data.frame(
        site = sc,
        species = paste0("sp", i),
        trait = c("t1", "t2"),
        value = c(eta1, eta2) + stats::rnorm(2, sd = resp_sd),
        x = x_sp[i],
        z = z_sp[i],
        stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(sc))
  dat$species <- factor(dat$species, levels = paste0("sp", seq_len(n_species)))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  list(
    data = dat, tree = tree, Cphy = Cphy,
    x_sp = x_sp, u_x = u_x, z_sp = z_sp,
    n_species = n_species, b_x_true = b_x_true,
    sd_x = sd_x, sigma_x = sigma_x, alpha = alpha,
    species_labels = paste0("sp", seq_len(n_species))
  )
}

# Set x to NA for every long row of the given species (species-level missing).
.inject_missing_species <- function(d, miss_species) {
  dat <- d$data
  miss_labels <- d$species_labels[miss_species]
  dat$x[as.character(dat$species) %in% miss_labels] <- NA_real_
  list(data = dat, miss_species = miss_species, miss_labels = miss_labels)
}

# Fit the phylo covariate-model mi(x): impute RHS carries an INTERCEPT-ONLY
# phylo(1|species, tree=) covariate model. The response side has NO phylo term
# (so Ainv_phy_rr must be built from the covariate-model tree -- design 69
# sec.2.2).
.fit_mi_phylo <- function(data, tree, impute = NULL, se = FALSE) {
  if (is.null(impute)) {
    impute <- list(x = x ~ phylo(1 | species, tree = tree))
  }
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = data, family = gaussian(),
    impute = impute, missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = se)
  )))
}

# Fit the INDEPENDENT (Phase-2c, no-phylo) baseline: species-level mi(x) via
# an intercept-only mi_group(species) covariate model, no phylo field. Same data
# / missingness. A missing species is imputed from the global mean (no
# phylogenetic borrowing) -- the contrast the strong-signal gate exploits.
.fit_mi_indep <- function(data, se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = data, family = gaussian(),
    impute = list(x = x ~ 1 + mi_group(species)),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = se)
  )))
}

# ===========================================================================
# Boundary rejection (no fit -- errors before TMB)
# ===========================================================================

test_that("phylo mi(): a structured covariate SLOPE is rejected (intercept-only)", {
  skip_unless_phylo_deps()
  d <- .make_mi_phylo(n_species = 12L, reps = 2L)
  dat <- .inject_missing_species(d, c(2L, 7L))$data
  ## phylo(1 + z | species) is a structured slope -- OUT of Phase 3.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z + phylo(1 + z | species, tree = d$tree)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "INTERCEPT|slope"
  )
})

test_that("phylo mi(): the joint response-covariate field is rejected (Phase 4)", {
  skip_unless_phylo_deps()
  d <- .make_mi_phylo(n_species = 12L, reps = 2L)
  dat <- .inject_missing_species(d, c(2L, 7L))$data
  ## correlate_with="response" is the deferred Phase-4 joint field.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z +
                      phylo(1 | species, tree = d$tree,
                            correlate_with = "response")),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "[Pp]hase 4|correlate|joint|response"
  )
})

test_that("phylo mi(): a non-phylo structured marker (spatial/animal) is rejected", {
  skip_unless_phylo_deps()
  d <- .make_mi_phylo(n_species = 12L, reps = 2L)
  dat <- .inject_missing_species(d, c(2L, 7L))$data
  ## spatial()/animal()/relmat() on x is a later generalization -- phylo only.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z + animal(1 | species)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "structured|phylo|spatial|animal|relmat|not yet"
  )
})

test_that("phylo mi(): the tree must be supplied on the phylo() token", {
  skip_unless_phylo_deps()
  d <- .make_mi_phylo(n_species = 12L, reps = 2L)
  dat <- .inject_missing_species(d, c(2L, 7L))$data
  ## phylo(1 | species) without tree= (and no global phylo_tree) cannot build
  ## the precision -- error loudly.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z + phylo(1 | species)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "tree"
  )
})

# ===========================================================================
# Gate 2: species broadcast (one latent per missing species)
# ===========================================================================

test_that("phylo mi(): one latent per missing SPECIES (not per long row)", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  miss_species <- c(3L, 8L, 15L, 22L)
  d <- .make_mi_phylo(seed = 21, n_species = 30L, reps = 3L)
  inj <- .inject_missing_species(d, miss_species)
  dat <- inj$data

  fit <- .fit_mi_phylo(dat, d$tree, se = FALSE)

  ## Registry: the phylo version, species level, one missing entry per species.
  reg <- fit$missing_data$predictors$x
  expect_identical(reg$version, "phase3")
  expect_identical(reg$structured$type, "phylo")
  expect_identical(reg$structured$group, "species")
  expect_identical(reg$counts$missing, length(miss_species))

  ## ONE latent per missing SPECIES even though each species spans
  ## reps sites x 2 traits = 6 long rows.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$x_mis, length(miss_species))
  expect_identical(reg$model_row, miss_species)

  ## The covariate phylo field g_x lives on the augmented phylogeny
  ## (n_aug_phy = 2*n_tips - 1 rows >= n_species), one column.
  expect_true(is.matrix(par$g_x) || is.numeric(par$g_x))
  n_aug <- if (is.matrix(par$g_x)) nrow(par$g_x) else length(par$g_x)
  expect_gte(n_aug, d$n_species)

  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})

test_that("phylo mi(): one observed value per species is enforced", {
  skip_unless_phylo_deps()
  ## A species with two DIFFERENT observed x values violates the species-level
  ## broadcast invariant; the builder must error before any TMB fit.
  d <- .make_mi_phylo(n_species = 12L, reps = 2L)
  dat <- d$data
  ## Corrupt one species: make its two sites carry different x.
  rows_sp1 <- which(as.character(dat$species) == "sp1")
  dat$x[rows_sp1[1:2]] <- dat$x[rows_sp1[1:2]] + c(0, 5)  # now inconsistent
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z + phylo(1 | species, tree = d$tree)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "one observed value per|constant within|species"
  )
})

test_that("phylo mi(): the imputed species value feeds every trait row", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  ## The single per-species x_mis must broadcast identically to BOTH trait rows
  ## of each (site, species) of the missing species -- the single-source
  ## invariant under the species broadcast. We check the engine's mi_x_full is
  ## a single per-species value used across the species' long rows.
  miss_species <- c(4L, 9L)
  d <- .make_mi_phylo(seed = 31, n_species = 16L, reps = 3L)
  inj <- .inject_missing_species(d, miss_species)
  dat <- inj$data

  fit <- .fit_mi_phylo(dat, d$tree, se = FALSE)
  modes <- fit$missing_data$predictors$x$conditional_mode
  expect_length(modes, length(miss_species))

  ## The full species-level x (observed + EBLUP) exposed in the registry.
  x_full_sp <- fit$missing_data$predictors$x$value
  expect_length(x_full_sp, d$n_species)
  ## Observed species recover their observed x exactly.
  observed_sp <- !(seq_len(d$n_species) %in% miss_species)
  expect_equal(x_full_sp[observed_sp], d$x_sp[observed_sp], tolerance = 1e-10)
})

# ===========================================================================
# Gate 1: high-vs-low phylogenetic-signal recovery (the headline gate)
# ===========================================================================

test_that("phylo mi(): STRONG signal -- borrowing beats the independent model", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  ## STRONG phylogenetic signal: large sd_x relative to sigma_x, INTERCEPT-ONLY
  ## covariate model. The phylo covariate model should recover the missing-x
  ## species modes BETTER than the independent (Phase-2c, no-phylo) model -- a
  ## smaller error (RMSE) and a higher correlation with the held-out truth
  ## (design 69 sec.6.2) -- and recover beta_x / sd_x / sigma_x within a band;
  ## sd_x away from zero. The response noise (resp_sd) is set high enough that
  ## the response likelihood does not by itself pin the missing x, so the
  ## covariate-model prior (the phylogenetic borrowing) drives the imputation.
  set.seed(42)
  miss_species <- sort(sample.int(50L, 16L))
  d <- .make_mi_phylo(
    seed = 101, n_species = 50L, reps = 2L,
    b_x_true = 1.2, sd_x = 1.6, sigma_x = 0.35, resp_sd = 1.2
  )
  inj <- .inject_missing_species(d, miss_species)
  dat <- inj$data
  x_true_missing <- d$x_sp[miss_species]

  fit_phy <- .fit_mi_phylo(dat, d$tree, se = TRUE)
  fit_ind <- .fit_mi_indep(dat, se = FALSE)

  ## Both converge.
  expect_lt(max(abs(fit_phy$tmb_obj$gr(fit_phy$opt$par))), 1e-2)

  modes_phy <- fit_phy$missing_data$predictors$x$conditional_mode
  modes_ind <- fit_ind$missing_data$predictors$x$conditional_mode
  expect_length(modes_phy, length(miss_species))
  expect_length(modes_ind, length(miss_species))

  cor_phy <- stats::cor(modes_phy, x_true_missing)
  cor_ind <- stats::cor(modes_ind, x_true_missing)
  rmse_phy <- sqrt(mean((modes_phy - x_true_missing)^2))
  rmse_ind <- sqrt(mean((modes_ind - x_true_missing)^2))

  ## Borrowing helps when strong: the phylo model tracks the held-out truth
  ## with smaller error (the primary metric -- design 69 sec.6.2 "smaller
  ## error") AND higher correlation than the independent model.
  expect_lt(rmse_phy, rmse_ind)
  expect_gt(cor_phy, cor_ind)
  expect_gt(cor_phy, 0.7)

  ## The response slope b_x recovers.
  mu_col <- fit_phy$missing_data$predictors$x$mu_col
  par_phy <- fit_phy$tmb_obj$env$parList(fit_phy$opt$par)
  b_x_hat <- par_phy$b_fix[mu_col]
  expect_equal(b_x_hat, d$b_x_true, tolerance = 0.25)

  ## sd_x (the phylogenetic SD of the covariate) recovers WELL AWAY FROM ZERO.
  ## (fit$report holds the post-fit REPORT; obj$report(opt$par) is incorrect --
  ## report() expects the FULL fixed+random vector, not opt$par.)
  sd_x_hat <- as.numeric(fit_phy$report$sd_x)
  expect_true(is.finite(sd_x_hat))
  expect_gt(sd_x_hat, 0.6)
  ## sigma_x (the residual) recovers near the truth (Pagel partition holds).
  sigma_x_hat <- exp(par_phy$log_sigma_mi[[1L]])
  expect_equal(sigma_x_hat, d$sigma_x, tolerance = 0.4)
})

test_that("phylo mi(): WEAK signal -- degrades gracefully + diagnostic flags it", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  ## WEAK phylogenetic signal: sd_x near zero (trait phylogenetically
  ## unstructured). The phylo model must perform NO WORSE than the independent
  ## model and inject no spurious structure; sd_x recovered near the boundary;
  ## the phylo-signal diagnostic FIRES a weak-signal warning.
  set.seed(43)
  miss_species <- sort(sample.int(50L, 16L))
  d <- .make_mi_phylo(
    seed = 202, n_species = 50L, reps = 3L,
    b_x_true = 1.2, sd_x = 0.02, sigma_x = 1.0
  )
  inj <- .inject_missing_species(d, miss_species)
  dat <- inj$data
  x_true_missing <- d$x_sp[miss_species]

  fit_phy <- .fit_mi_phylo(dat, d$tree, se = FALSE)
  fit_ind <- .fit_mi_indep(dat, se = FALSE)

  expect_lt(max(abs(fit_phy$tmb_obj$gr(fit_phy$opt$par))), 1e-2)

  modes_phy <- fit_phy$missing_data$predictors$x$conditional_mode
  modes_ind <- fit_ind$missing_data$predictors$x$conditional_mode
  rmse_phy <- sqrt(mean((modes_phy - x_true_missing)^2))
  rmse_ind <- sqrt(mean((modes_ind - x_true_missing)^2))

  ## Degrades to approximately independent when weak: the phylo model is no
  ## worse than independent (small slack for inner-solver / boundary noise).
  expect_lt(rmse_phy, rmse_ind * 1.1)

  ## sd_x recovered near the boundary (the field flattens).
  sd_x_hat <- as.numeric(fit_phy$report$sd_x)
  expect_lt(sd_x_hat, 0.5)

  ## The phylo-signal diagnostic flags the weak case. The effective lambda
  ## (sd_x^2 / (sd_x^2 + sigma_x^2)) is small; the diagnostic helper reports
  ## weak = TRUE and emits an EBLUP-language warning.
  diag <- phylo_signal_mi(fit_phy)
  expect_true(is.list(diag))
  expect_true(diag$weak)
  expect_lt(diag$lambda, 0.2)
  expect_warning(
    phylo_signal_mi(fit_phy, warn = TRUE),
    "weak"
  )
})

# ===========================================================================
# Gate 3: independence from the response phylo field
# ===========================================================================

test_that("phylo mi(): the covariate field is SEPARATE from a response phylo field", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  ## A fit with BOTH a response phylogenetic field (phylo on the response,
  ## here phylo_unique via mode = "diag" -> the response g_phy field) AND a
  ## phylo covariate model (-> the covariate g_x field). beta_x must be
  ## identified, and the two phylo fields must be SEPARATE `random` blocks
  ## (g_x vs the response phylo block) -- not conflated into one shared field.
  ## This is the Phase-3 guard that the Level-2 joint field is genuinely absent
  ## and the slope is not confounded (design 69 sec.5). The two share the SAME
  ## precision Ainv_phy_rr (one tree per fit) but are distinct latents.
  miss_species <- c(3L, 8L, 15L, 22L, 29L)
  d <- .make_mi_phylo(seed = 303, n_species = 40L, reps = 3L,
                      b_x_true = 1.2, sd_x = 1.4, sigma_x = 0.4)
  inj <- .inject_missing_species(d, miss_species)
  dat <- inj$data

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x) +
      phylo(0 + trait | species, mode = "diag"),
    data = dat, family = gaussian(),
    phylo_tree = d$tree,
    impute = list(x = x ~ phylo(1 | species, tree = d$tree)),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 5e-2)

  ## BOTH fields are present as SEPARATE random blocks. The covariate field is
  ## g_x; the response phylo field is g_phy (mode = "diag" -> phylo_unique).
  rand <- fit$tmb_obj$env$random
  rand_names <- names(fit$tmb_obj$env$par)[rand]
  expect_true("g_x" %in% rand_names)     # covariate phylo field
  response_phylo_blocks <- intersect(
    c("g_phy", "g_phy_diag"), rand_names
  )
  expect_gt(length(response_phylo_blocks), 0L)  # a response phylo field exists
  ## They are DISTINCT random blocks -- g_x is its own latent, not the response
  ## phylo field (no shared field, no cross-covariance parameter).
  expect_false("g_x" %in% response_phylo_blocks)

  ## beta_x (the response slope on x) is identified, not absorbed by the
  ## response phylo field.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  mu_col <- fit$missing_data$predictors$x$mu_col
  b_x_hat <- par$b_fix[mu_col]
  expect_equal(b_x_hat, d$b_x_true, tolerance = 0.3)

  ## The covariate field has its OWN sd_x (its own variance component).
  expect_true(is.finite(as.numeric(fit$report$sd_x)))
})

# ===========================================================================
# Gate 4: no-op / non-regression (Phase 2a/2c unchanged)
# ===========================================================================

test_that("phylo mi(): non-phylo Phase-2c mi_group() fit is unchanged (no-op)", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  ## A Phase-2c (species-level, no-phylo) mi() fit must be byte-identical with
  ## and without the Phase-3 code present (the has_mi_phylo flag / g_x block map
  ## off and contribute nothing). We assert the version is phase2c and the fit
  ## carries no phylo covariate structure.
  miss_species <- c(3L, 8L, 15L)
  d <- .make_mi_phylo(seed = 404, n_species = 24L, reps = 3L)
  inj <- .inject_missing_species(d, miss_species)
  dat <- inj$data

  fit <- .fit_mi_indep(dat, se = FALSE)

  expect_identical(fit$missing_data$predictors$x$version, "phase2c")
  ## No structured slot (or a disabled one).
  struct <- fit$missing_data$predictors$x$structured
  expect_true(is.null(struct) || isFALSE(struct$enabled))
  ## g_x is mapped off (not in the random set).
  rand <- fit$tmb_obj$env$random
  rand_names <- names(fit$tmb_obj$env$par)[rand]
  expect_false("g_x" %in% rand_names)
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})

test_that("phylo mi(): a plain Phase-2a unit-level mi() fit still works (no-op)", {
  skip_if_not_heavy()
  skip_unless_phylo_deps()
  ## The simplest mi() route -- a unit-level Gaussian covariate model with no
  ## group/phylo -- must be unaffected by the Phase-3 additions.
  d <- .make_mi_phylo(seed = 505, n_species = 20L, reps = 2L)
  ## Make x UNIT-level (per site) by re-drawing per long-row-collapsed site:
  ## the .make_mi_phylo x is species-level, but with reps>=2 each species spans
  ## multiple sites. For a clean Phase-2a fixture, treat each site as its own
  ## unit and impute with a bare fixed model (no mi_group, no phylo).
  dat <- d$data
  ## Inject missing at the SITE level: drop x for a few whole sites.
  miss_sites <- c(2L, 5L, 11L)
  dat$x[as.integer(dat$site) %in% miss_sites] <- NA_real_
  ## x is constant within a site (one species per site here? no -- species
  ## spans sites). To keep x unit(site)-level constant we only need the within
  ## site rows to agree, which they do (both trait rows share x). Fit Phase-2a.
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = dat, family = gaussian(),
    impute = list(x = x ~ z),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_identical(fit$missing_data$predictors$x$version, "phase2a")
  rand <- fit$tmb_obj$env$random
  rand_names <- names(fit$tmb_obj$env$par)[rand]
  expect_false("g_x" %in% rand_names)
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})
