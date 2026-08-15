## Arc 1A: internal estimator provenance. These tests must FAIL if the
## adapter changes accepted calls, TMB integers, or numeric objectives.

.prov_ml_fixture <- function() {
  set.seed(8808)
  n_site <- 24L
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  Lambda <- c(0.8, -0.55, 0.35)
  beta <- c(-0.5, 0.1, 0.55)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * Lambda[as.integer(trait)]
  data.frame(
    site = site,
    trait = trait,
    y = stats::rbinom(length(eta), 1L, stats::plogis(eta))
  )
}

.prov_ctrl <- function(...) {
  gllvmTMBcontrol(
    n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE, ...
  )
}

test_that("compatibility table covers the locked adapter contract", {
  tbl <- gllvmTMB:::.gllvmTMB_estimator_compatibility_table()
  expect_true(all(c(
    "criterion_id", "numeric_kernel_id", "penalty_eval_id",
    "integration", "estimator_id", "public_label"
  ) %in% names(tbl)))
  expect_identical(
    sort(unique(tbl$criterion_id)),
    c("la_ml", "la_mspl", "reml", "va_elbo")
  )
  expect_identical(
    sort(unique(tbl$numeric_kernel_id)),
    c("audited_stable_mspl", "legacy_ml", "va")
  )
  expect_identical(
    sort(unique(tbl$penalty_eval_id)),
    c("off", "on", "provenance_off")
  )
  expect_identical(
    sort(unique(tbl$estimator_id[!is.na(tbl$estimator_id)])),
    c(0L, 1L, 2L)
  )
  expect_true(any(is.na(tbl$estimator_id)))
  expect_true(all(tbl$accepted))
})

test_that("resolver derives existing TMB integers and records VA+ml", {
  ml <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", integration = "laplace"
  )
  expect_identical(ml$estimator_id, 0L)
  expect_identical(ml$criterion_id, "la_ml")
  expect_identical(ml$numeric_kernel_id, "legacy_ml")
  expect_identical(ml$penalty_eval_id, "off")
  expect_identical(ml$public_estimator, "ML")
  expect_false(ml$public_estimator_is_coarse)
  expect_identical(gllvmTMB:::.gllvmTMB_estimator_id_for_tape(ml), 0L)

  mspl <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "mspl", integration = "laplace"
  )
  expect_identical(mspl$estimator_id, 1L)
  expect_identical(mspl$criterion_id, "la_mspl")
  expect_identical(mspl$numeric_kernel_id, "audited_stable_mspl")
  expect_identical(mspl$penalty_eval_id, "on")
  expect_identical(mspl$penalty_off_tape$estimator_id, 2L)
  expect_identical(mspl$penalty_off_tape$penalty_eval_id, "provenance_off")
  expect_identical(gllvmTMB:::.gllvmTMB_estimator_id_for_tape(mspl), 1L)

  off <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "mspl", integration = "laplace",
    tape_role = "penalty_off_provenance"
  )
  expect_identical(gllvmTMB:::.gllvmTMB_estimator_id_for_tape(off), 2L)
  expect_match(off$notes, "not public ML", all = FALSE)

  va_ml <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", integration = "va"
  )
  expect_true(va_ml$accepted)
  expect_identical(va_ml$integration, "va")
  expect_identical(va_ml$criterion_id, "va_elbo")
  expect_identical(va_ml$public_estimator, "ML")
  expect_true(va_ml$public_estimator_is_coarse)
  expect_true(is.na(va_ml$estimator_id))
  expect_error(
    gllvmTMB:::.gllvmTMB_estimator_id_for_tape(va_ml),
    "no TMB estimator_id"
  )

  reml <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", reml = TRUE, integration = "laplace"
  )
  expect_identical(reml$criterion_id, "reml")
  expect_identical(reml$public_estimator, "REML")
  expect_identical(reml$estimator_id, 0L)
})

test_that("implicit and explicit Laplace ML keep numeric parity and provenance", {
  dat <- .prov_ml_fixture()
  form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
  implicit <- gllvmTMB(form, dat, family = binomial(), control = .prov_ctrl())
  explicit <- gllvmTMB(
    form, dat, family = binomial(), control = .prov_ctrl(), estimator = "ml"
  )
  expect_identical(implicit$estimator, "ML")
  expect_identical(explicit$estimator, "ML")
  expect_equal(explicit$opt$par, implicit$opt$par, tolerance = 1e-10)
  expect_equal(explicit$opt$objective, implicit$opt$objective, tolerance = 1e-10)
  expect_identical(implicit$tmb_data$estimator_id, 0L)
  expect_identical(explicit$tmb_data$estimator_id, 0L)
  for (fit in list(implicit, explicit)) {
    prov <- fit$estimator_provenance
    expect_type(prov, "list")
    expect_identical(prov$estimator_id, 0L)
    expect_identical(prov$criterion_id, "la_ml")
    expect_identical(prov$integration, "laplace")
    expect_identical(prov$penalty_eval_id, "off")
    expect_false(prov$public_estimator_is_coarse)
  }
  printed <- paste(capture.output(print(implicit)), collapse = "\n")
  expect_false(grepl("estimator_provenance|criterion_id|la_ml", printed))
})

test_that("Laplace MSPL keeps tape integers 1 and 2 and attaches provenance", {
  dat <- .prov_ml_fixture()
  fit <- gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    dat, family = binomial(), estimator = "mspl", control = .prov_ctrl()
  )
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$estimator, "MSPL")
  expect_identical(fit$tmb_data$estimator_id, 1L)
  expect_equal(fit$mspl$unpenalized_tmb_obj$env$data$estimator_id, 2)
  expect_true(is.finite(fit$opt$objective))
  expect_true(all(is.finite(fit$opt$par)))
  prov <- fit$estimator_provenance
  expect_identical(prov$estimator_id, 1L)
  expect_identical(prov$criterion_id, "la_mspl")
  expect_identical(prov$numeric_kernel_id, "audited_stable_mspl")
  expect_identical(prov$penalty_eval_id, "on")
  expect_identical(prov$penalty_off_tape$estimator_id, 2L)
  expect_identical(prov$penalty_off_tape$penalty_eval_id, "provenance_off")
})

test_that("accepted VA+ml is still accepted and records coarse ML", {
  skip_on_cran()
  set.seed(20260814L)
  n <- 100L
  p <- 3L
  site <- factor(rep(sprintf("s%03d", seq_len(n)), each = p))
  trait <- factor(rep(sprintf("t%d", seq_len(p)), n), levels = sprintf("t%d", seq_len(p)))
  dat <- data.frame(
    site = site,
    trait = trait,
    y = stats::rbinom(n * p, 1L, 0.5)
  )
  fit <- gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    dat,
    family = binomial(),
    estimator = "ml",
    control = gllvmTMBcontrol(integration = "va", se = FALSE, warn_runaway = FALSE)
  )
  expect_s3_class(fit, "gllvmTMB_va")
  expect_identical(fit$integration, "va")
  prov <- fit$estimator_provenance
  expect_identical(prov$integration, "va")
  expect_identical(prov$criterion_id, "va_elbo")
  expect_identical(prov$public_estimator, "ML")
  expect_true(prov$public_estimator_is_coarse)
  expect_true(prov$accepted)
  expect_true(is.na(prov$estimator_id))
})

test_that("existing MSPL and REML aborts keep their classes", {
  dat <- .prov_ml_fixture()
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      dat, family = poisson(), estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      dat, family = binomial(), estimator = "mspl",
      control = gllvmTMBcontrol(integration = "va")
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      dat, family = binomial(), REML = TRUE, estimator = "ml"
    ),
    class = "gllvmTMB_estimator_reml_conflict"
  )
})
