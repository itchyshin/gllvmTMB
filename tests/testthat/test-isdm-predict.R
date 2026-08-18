## predict() on isdm_sources() fits (class c("gllvmTMB_multi", "gllvmTMB")):
## the defensible core established by dev/isdm-predict-probe/probe.R (Part A,
## non-spatial). Spatial newdata behaviour (the field is silently dropped)
## is a known bug tracked separately and is deliberately NOT certified here.

.isdm_predict_fixture <- function() {
  set.seed(7)
  n_cell <- 30L
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2")
  x <- as.numeric(scale(runif(n_cell)))
  alpha <- c(-0.1, 0.2); beta <- c(0.4, -0.3)
  ## a REAL shared latent field, so random-effect re-add paths are testable
  u_cell <- rnorm(n_cell, sd = 0.8)
  lam_tr <- c(0.9, 0.6)
  mk <- function(src, kind, support) {
    d <- expand.grid(cell_id = cells, trait = species, stringsAsFactors = FALSE)
    ci <- match(d$cell_id, cells); si <- match(d$trait, species)
    eta <- alpha[si] + x[ci] * beta[si] + u_cell[ci] * lam_tr[si]
    d$isdm_source <- src
    d$support <- support
    d$value <- if (kind == "count") rpois(nrow(d), support * exp(eta))
               else rbinom(nrow(d), 1, -expm1(-support * exp(eta)))
    d
  }
  dat <- rbind(mk("gbif", "count", 1.5), mk("survey", "pa", 0.9))
  dat$trait <- factor(dat$trait)
  dat$cell_id <- factor(dat$cell_id)
  dat$isdm_source <- factor(dat$isdm_source, levels = c("gbif", "survey"))
  dat$log_support <- log(dat$support)
  dat$env <- x[match(as.character(dat$cell_id), cells)]
  dat$src_gbif <- as.integer(dat$isdm_source == "gbif")
  dat
}

.isdm_predict_fit <- function() {
  dat <- .isdm_predict_fixture()
  fam <- isdm_sources(gbif = poisson(), survey = binomial(link = "cloglog"))
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + trait:src_gbif + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam, silent = TRUE
  ))
  list(fit = fit, dat = dat)
}

## Fit once, reuse across test_that blocks (fixture is small; still an
## expensive TMB fit worth not repeating six times).
.isdm_pred_fx <- if (requireNamespace("TMB", quietly = TRUE)) {
  .isdm_predict_fit()
} else {
  NULL
}

test_that("in-sample predict() matches report$eta exactly (link scale)", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  out <- predict(fit)
  expect_s3_class(out, "data.frame")
  expect_identical(nrow(out), nrow(dat))
  expect_true(all(c("est") %in% names(out)))
  expect_identical(out$est, as.numeric(fit$report$eta))
})

test_that("type = 'response' applies each row's own arm inverse link", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  link_out <- predict(fit)
  resp_out <- predict(fit, type = "response")

  i_count <- dat$isdm_source == "gbif"
  i_pa <- dat$isdm_source == "survey"

  expect_equal(resp_out$est[i_count], exp(link_out$est[i_count]))
  expect_equal(resp_out$est[i_pa], -expm1(-exp(link_out$est[i_pa])))
  expect_true(all(resp_out$est[i_pa] >= 0 & resp_out$est[i_pa] <= 1))
  expect_true(all(resp_out$est[i_count] > 0))
})

test_that("predict(newdata = training data) equals in-sample predictions on a non-spatial fit", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  in_sample <- predict(fit)
  newdata_pred <- suppressMessages(predict(fit, newdata = dat))
  expect_equal(newdata_pred$est, in_sample$est)
})

test_that("re_form = ~0 on newdata is exactly fixed effects + offset", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  with_re <- suppressMessages(predict(fit, newdata = dat, re_form = ~.))
  fixed_only <- suppressMessages(predict(fit, newdata = dat, re_form = ~0))
  ## the fixture's latent field is non-degenerate, so ~. must differ from ~0
  expect_gt(sd(with_re$est - fixed_only$est), 0)
  ## and ~0 must equal the fixed linear predictor plus the re-evaluated
  ## offset EXACTLY (the same construction the newdata path uses)
  eta_fixed <- .gllvmTMB_predict_fixed_eta(
    fit, stats::model.matrix(fit$formula, dat)
  ) + .gllvmTMB_offset_newdata(fit, dat)
  expect_equal(fixed_only$est, as.numeric(eta_fixed))
})

test_that("se.fit = TRUE works in-sample and is refused with newdata", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  out <- predict(fit, se.fit = TRUE)
  expect_true("se.fit" %in% names(out))
  expect_true(all(is.finite(out$se.fit)))
  expect_true(all(out$se.fit > 0))

  err <- tryCatch(
    predict(fit, newdata = dat, se.fit = TRUE),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_predict_se_newdata_unsupported")
})

test_that("newdata with an unseen unit level falls back to the fixed-only prediction", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  nd_new <- dat[dat$cell_id == levels(dat$cell_id)[1], ]
  nd_new$cell_id <- factor("cNEW")
  nd_new$env <- 0.25

  unseen_pred <- suppressMessages(predict(fit, newdata = nd_new))
  fixed_only_pred <- suppressMessages(predict(fit, newdata = nd_new, re_form = ~0))
  expect_equal(unseen_pred$est, fixed_only_pred$est)
})

## ---------------------------------------------------------------------------
## #1132 regression tests. Three defects in predict.gllvmTMB_multi's newdata
## path, each measured in Design 126 section 3. Defects 2 and 3 reuse the
## fixture above at no extra fitting cost; defect 1 needs a spatial fit and
## builds one lazily, inside the block, so an SPDE fit never enters a routine
## CRAN run (the file-level fixture above is NOT skip_on_cran()-protected).
## ---------------------------------------------------------------------------

test_that("#1132 defect 3: newdata response uses each ROW's own arm, not the trait's modal family", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat
  i_pa <- which(dat$isdm_source == "survey")

  in_sample <- suppressMessages(predict(fit, type = "response"))
  on_newdata <- suppressMessages(predict(fit, newdata = dat, type = "response"))

  ## The in-sample response is the certified baseline (block 2 above). At
  ## newdata == training data the two must agree exactly. Before the fix the
  ## per-trait modal reduction gave max|diff| = 1.42.
  expect_equal(on_newdata$est, in_sample$est)

  ## The measured symptom: the cloglog detection arm was pushed through the
  ## Poisson arm's exp(), returning "probabilities" in [0.253, 2.32].
  expect_true(all(on_newdata$est[i_pa] >= 0 & on_newdata$est[i_pa] <= 1))

  ## And it is the RIGHT inverse link, not merely an in-range one.
  link_out <- suppressMessages(predict(fit, newdata = dat, type = "link"))
  expect_equal(
    on_newdata$est[i_pa],
    -expm1(-exp(link_out$est[i_pa]))
  )
})

test_that("#1132 defect 2: re_form is honoured in-sample, and for NA / numeric 0", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit

  ## The reference: fixed effects + offset on the training rows.
  eta_fixed <- .gllvmTMB_predict_fixed_eta(fit, .gllvmTMB_training_X_fix(fit)) +
    .gllvmTMB_offset_vec(fit)

  default <- suppressMessages(predict(fit))
  zero <- suppressMessages(predict(fit, re_form = ~0))

  ## Before the fix the in-sample branch never read re_form: this returned
  ## report$eta, i.e. the full conditional predictor, on the package's
  ## DEFAULT calling convention.
  expect_equal(zero$est, as.numeric(eta_fixed))
  expect_gt(sd(default$est - zero$est), 0)

  ## NA is a documented form; numeric 0 is the obvious slip. Both were
  ## silently ignored on BOTH paths.
  expect_equal(suppressMessages(predict(fit, re_form = NA))$est, zero$est)
  expect_equal(suppressMessages(predict(fit, re_form = 0))$est, zero$est)

  ## fitted() forwards ... to the same in-sample path (Ayumi #25, PR #1114),
  ## so its roxygen claim that re_form "works here too" is now true.
  expect_equal(
    suppressMessages(fitted(fit, type = "link", re_form = ~0))$est,
    zero$est
  )

  ## An unsupported form must be loud, not silently full-RE (how ~1 passed).
  expect_warning(
    suppressMessages(predict(fit, re_form = ~1)),
    class = "gllvmTMB_predict_re_form_unsupported"
  )
})

test_that("#1132 defect 1: a spatial fit's SPDE field survives the newdata path", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  ## Cheap gaussian spatial fixture, matching the shape used across the suite
  ## (test-spatial-mode-dispatch.R) and the configuration the adversarial
  ## verification used to reproduce this defect on a NON-isdm fit.
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4),
    seed = 1
  )
  df <- sim$data
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1),
    error = function(e) NULL
  )
  skip_if(is.null(mesh), "mesh build failed")

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$spde))

  in_sample <- suppressMessages(predict(fit))
  on_newdata <- suppressMessages(predict(fit, newdata = df))

  ## The strong identity (verify-report.md VER[D4]): at training rows the
  ## rebuilt predictor must reproduce report$eta EXACTLY. Before the fix the
  ## field was absent, giving a dropped piece of sd 0.516 against eta sd
  ## 0.786 -- and newdata ~. equalled ~0, because nothing was re-added.
  expect_equal(on_newdata$est, in_sample$est)

  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))
  expect_gt(sd(on_newdata$est - fixed_only$est), 0)

  ## This fit's ONLY random tier is the field, so the difference from the
  ## fixed-only prediction is the whole random-effect contribution.
  expect_equal(
    on_newdata$est - fixed_only$est,
    in_sample$est - fixed_only$est
  )
})

test_that("#1132 defect 1: a tier that cannot be re-added is named, not dropped in silence", {
  skip_on_cran()
  skip_if_not_installed("TMB")

  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1, seed = 1
  )
  df <- sim$data
  df$grp <- factor(rep(letters[1:5], length.out = nrow(df)))

  ## re_int is an active eta tier this path cannot reconstruct.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + (1 | grp),
    data = df, silent = TRUE
  )))
  expect_true(isTRUE(as.integer(fit$tmb_data$use_re_int) == 1L))

  expect_warning(
    suppressMessages(predict(fit, newdata = df)),
    class = "gllvmTMB_predict_newdata_re_dropped"
  )

  ## re_form = ~0 makes no such claim, so it must stay quiet.
  expect_no_warning(suppressMessages(predict(fit, newdata = df, re_form = ~0)))
})

test_that("#1132: a fully-handled fit does not raise a false alarm", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  ## fit$use carries MODE DESCRIPTORS (spatial_scalar) alongside the engine
  ## flag (spde) that actually adds the term. Warning on those would flag a
  ## prediction that is exactly right -- worse than useless, because it
  ## teaches the reader to ignore the warning.
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4), seed = 1
  )
  df <- sim$data
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1),
    error = function(e) NULL
  )
  skip_if(is.null(mesh), "mesh build failed")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE
  )))
  expect_true(isTRUE(fit$use$spatial_scalar))
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
})

test_that("#1132: coordinates outside the mesh hull warn instead of returning a silent zero field", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  ## Found by the adversarial verification of the SPDE re-add. fmesher returns
  ## an all-zero basis row outside the hull, so the field reads as exactly 0 --
  ## a blank patch of map indistinguishable from a cold one. make_mesh()
  ## rejects such rows at FIT time, so predict() must not be quietly more
  ## permissive than the fit was.
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4), seed = 1
  )
  df <- sim$data
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1),
    error = function(e) NULL
  )
  skip_if(is.null(mesh), "mesh build failed")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE
  )))

  far <- df
  far$lon <- df$lon + 500
  far$lat <- df$lat + 500
  expect_warning(
    suppressMessages(predict(fit, newdata = far)),
    class = "gllvmTMB_predict_newdata_outside_mesh"
  )

  ## In-domain rows must stay quiet -- a warning that fires on good input is
  ## the failure mode this whole block exists to avoid.
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
})

## ---------------------------------------------------------------------------
## #1138: the random-effect tiers whose reshape convention is reconstructible
## for newdata. Each is pinned by the SAME acceptance criterion the SPDE tier
## had to meet -- predict(newdata = training rows) == report$eta EXACTLY --
## because a non-zero contribution proves nothing about a transposed reshape.
##
## Deliberately still NOT re-added, and still warned about: `equalto` (indexed
## by observation, so it has no meaning for arbitrary new rows), `re_int` (its
## group mapping is not a top-level field on the fit), `diag_cluster2` / the
## `*_slope` and phylo-diagonal blocks (no established reshape convention --
## see getREsd()'s roxygen). See #1138.
## ---------------------------------------------------------------------------

.pred_tier_df <- function(seed = 4L) {
  set.seed(seed)
  gllvmTMB::simulate_site_trait(
    n_sites = 25, n_species = 3, n_traits = 2,
    mean_species_per_site = 3, seed = seed
  )$data
}

test_that("#1138: diag_species is re-added on newdata, exactly", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- .pred_tier_df()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | species),
    data = df, silent = TRUE
  )))
  expect_true(isTRUE(as.integer(fit$tmb_data$use_diag_species) == 1L))

  ## q_sp is indexed (trait, species) -- the TRANSPOSE of p_phy. A swapped
  ## index would still produce a plausible non-zero contribution, so the
  ## exact identity is what actually tests it.
  expect_equal(
    suppressMessages(predict(fit, newdata = df))$est,
    suppressMessages(predict(fit))$est
  )
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
})

test_that("#1138: the site-species tiers (rr_W, diag_W) are re-added exactly", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- .pred_tier_df()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site_species, d = 1),
    data = df, silent = TRUE
  )))
  expect_true(isTRUE(as.integer(fit$tmb_data$use_rr_W) == 1L))

  expect_equal(
    suppressMessages(predict(fit, newdata = df))$est,
    suppressMessages(predict(fit))$est
  )

  ## These tiers are keyed on the unit-observation column. If newdata does
  ## not carry it they cannot be reconstructed, and that must be reported
  ## rather than silently omitted.
  nd_drop <- df[, setdiff(names(df), fit$unit_obs_col), drop = FALSE]
  expect_warning(
    suppressMessages(predict(fit, newdata = nd_drop)),
    class = "gllvmTMB_predict_newdata_re_dropped"
  )
})

test_that("#1132/#1138: propto is guarded per row, not on row 1 alone", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- .pred_tier_df()
  sp <- levels(factor(df$species))
  V <- diag(length(sp))
  dimnames(V) <- list(sp, sp)
  V[1, 2] <- V[2, 1] <- 0.4
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + propto(0 + trait | species),
    data = df, phylo_vcv = V, silent = TRUE
  )))

  expect_equal(
    suppressMessages(predict(fit, newdata = df))$est,
    suppressMessages(predict(fit))$est
  )

  ## The old guard was `!is.na(sp_id[1])` -- row ONE only -- so an unseen
  ## species in the first row silently dropped the tier for EVERY row.
  nd <- df
  nd$species <- as.character(nd$species)
  nd$species[1] <- "GHOST"
  with_re <- suppressWarnings(suppressMessages(predict(fit, newdata = nd)))
  fixed_only <- suppressWarnings(suppressMessages(
    predict(fit, newdata = nd, re_form = ~0)
  ))
  rest <- seq(2L, nrow(nd))
  expect_gt(sd(with_re$est[rest] - fixed_only$est[rest]), 0)
  ## and the unseen row itself still falls back, as documented.
  expect_equal(with_re$est[1], fixed_only$est[1])
})

## ---------------------------------------------------------------------------
## #1133 items 2 and 3 (Design 127 sections 4-5): arm attribution and scale
## semantics. Item 1 (off-mesh projection) largely landed with #1132's
## fm_basis() route; item 4 (RE-aware map uncertainty) is deliberately out of
## scope and se.fit stays refused on newdata.
## ---------------------------------------------------------------------------

test_that("#1133 item 3: the in-sample path carries the arm/source column", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat
  fam_var <- attr(fit$family_input, "family_var")
  expect_identical(fam_var, "isdm_source")

  out <- suppressMessages(predict(fit))
  ## Without this column `est` mixes scales -- Poisson expected counts beside
  ## cloglog detection probabilities -- with nothing to tell them apart. The
  ## newdata path always returned it (it returns all of newdata); the
  ## in-sample path, which is the DEFAULT and what fitted() wraps, did not.
  expect_true(fam_var %in% names(out))
  expect_identical(as.character(out[[fam_var]]), as.character(dat[[fam_var]]))

  ## `est` stays the last column and its values are untouched.
  expect_identical(names(out)[ncol(out)], "est")
  expect_identical(out$est, as.numeric(fit$report$eta))

  ## fitted() wraps the same path, so it inherits the label.
  expect_true(fam_var %in% names(suppressMessages(fitted(fit, type = "link"))))
})

test_that("#1133 item 3: a single-family fit's output shape is unchanged", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  ## The column is added only where the ambiguity exists. A fit with no
  ## family_var column must return exactly what it always did -- this is the
  ## backward-compatibility half of the change.
  set.seed(2)
  df <- gllvmTMB::simulate_site_trait(
    n_sites = 20, n_species = 1, n_traits = 2,
    mean_species_per_site = 1, seed = 2
  )$data
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = df, silent = TRUE
  )))
  expect_identical(
    names(suppressMessages(predict(fit))),
    c("site", "species", "trait", "est")
  )
})

test_that("#1133 item 2: zeroing the offset gives the effort-free scale, exactly", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  ## type = "response" includes the row's offset, so it is an expected count
  ## AT THAT EFFORT. A map wants relative intensity; the documented idiom is
  ## to zero the offset in newdata. The offset is re-evaluated against
  ## newdata, so this is exact rather than approximate -- which is what makes
  ## it documentable instead of needing a new `type =`.
  nd0 <- dat
  nd0$log_support <- 0
  with_effort <- suppressMessages(predict(fit, newdata = dat, type = "link"))
  no_effort <- suppressMessages(predict(fit, newdata = nd0, type = "link"))

  ## On the link scale the difference is exactly the offset that was removed.
  expect_equal(with_effort$est - no_effort$est, log(dat$support))
})

test_that("#1154: predict(newdata=) works without the response column", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  ## A prediction grid has no response by construction -- that is the point
  ## of predicting on one. `model.matrix()` on a two-sided formula builds a
  ## model.frame() first, which evaluates the LHS, so this used to fail with
  ## `object 'value' not found` and force a dummy-column workaround that was
  ## undiscoverable from the error.
  nd <- dat
  nd$value <- NULL
  expect_false("value" %in% names(nd))

  out <- suppressMessages(predict(fit, newdata = nd))
  ## and it must agree exactly with the with-response result, so the fix is
  ## a relaxation of an input requirement and not a change of answer.
  expect_equal(out$est, suppressMessages(predict(fit, newdata = dat))$est)
  expect_equal(out$est, suppressMessages(predict(fit))$est)

  ## response scale too -- that path re-reads the family column, not the LHS.
  expect_equal(
    suppressMessages(predict(fit, newdata = nd, type = "response"))$est,
    suppressMessages(predict(fit, type = "response"))$est
  )
})
