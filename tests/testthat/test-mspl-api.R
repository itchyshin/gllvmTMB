.mspl_fixture <- function(
  link = "logit",
  q = 1L,
  n_site = 24L,
  direction = c("base", "reflected")
) {
  direction <- match.arg(direction)
  set.seed(
    8808 +
      match(link, c("logit", "probit", "cloglog")) +
      q +
      if (direction == "reflected") 100L else 0L
  )
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- matrix(stats::rnorm(n_site * q), n_site, q)
  Lambda <- if (q == 1L) {
    matrix(c(0.8, -0.55, 0.35), n_trait, 1L)
  } else {
    matrix(c(0.8, -0.55, 0.35, 0, 0.45, -0.3), n_trait, 2L)
  }
  beta <- c(-0.5, 0.1, 0.55)
  eta <- beta[as.integer(trait)] + rowSums(
    z[as.integer(site), , drop = FALSE] * Lambda[as.integer(trait), , drop = FALSE]
  )
  if (direction == "reflected") eta <- -eta
  mu <- switch(
    link,
    logit = stats::plogis(eta),
    probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta))
  )
  data.frame(site = site, trait = trait, y = stats::rbinom(length(mu), 1L, mu))
}

.mspl_fit <- function(
  link = "logit",
  q = 1L,
  unique = FALSE,
  direction = c("base", "reflected"),
  ...
) {
  direction <- match.arg(direction)
  dat <- .mspl_fixture(link, q, direction = direction)
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = %s)",
    q, if (unique) "TRUE" else "FALSE"
  ))
  gllvmTMB(
    form,
    data = dat,
    family = stats::binomial(link = link),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    ),
    ...
  )
}

.mspl_spatial_fixture <- function() {
  sites <- expand.grid(lon = seq(0, 1, length.out = 6L),
                       lat = seq(0, 1, length.out = 5L))
  sites$site <- factor(seq_len(nrow(sites)))
  dat <- merge(
    sites,
    data.frame(trait = factor(paste0("sp", 1:3))),
    all = TRUE
  )
  site_id <- as.integer(dat$site)
  trait_id <- as.integer(dat$trait)
  dat$y <- as.integer((site_id + 2L * trait_id) %% 7L < (2L + trait_id))
  dat
}

.mspl_spatial_fit <- function(link, structure = c("indep", "latent"), q = 1L) {
  structure <- match.arg(structure)
  dat <- .mspl_spatial_fixture()
  mesh <- make_mesh(dat, c("lon", "lat"), cutoff = 0.18)
  form <- if (structure == "indep") {
    y ~ 0 + trait + spatial_indep(0 + trait | site, mesh = mesh)
  } else {
    stats::as.formula(sprintf(
      "y ~ 0 + trait + spatial_latent(0 + trait | site, d = %d, mesh = mesh)",
      as.integer(q)
    ))
  }
  fit <- suppressWarnings(gllvmTMB(
    form, dat, family = binomial(link = link), mesh = mesh,
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  ))
  list(fit = fit, mesh = mesh)
}

.mspl_logsumexp <- function(x) {
  m <- max(x)
  m + log(sum(exp(x - m)))
}

.mspl_cauchy_binet_logdet <- function(X, logw) {
  p <- ncol(X)
  bases <- utils::combn(nrow(X), p)
  terms <- apply(bases, 2L, function(idx) {
    d <- determinant(X[idx, , drop = FALSE], logarithm = TRUE)
    if (d$sign == 0) return(-Inf)
    sum(logw[idx]) + 2 * as.numeric(d$modulus)
  })
  .mspl_logsumexp(terms)
}

test_that("resolved MSPL fixed design follows TMB map and tie semantics", {
  X <- cbind(a = 1, b = c(-1, 0, 1, 2), c = c(2, 1, 1, -1))
  resolved <- gllvmTMB:::.gllvmTMB_mspl_fixed_design(
    X,
    factor(c(1L, 2L, 2L))
  )
  expect_equal(resolved$X, unname(cbind(X[, 1], X[, 2] + X[, 3])))
  expect_equal(resolved$p_beta, 2L)
  expect_equal(resolved$rank, 2L)

  pinned <- gllvmTMB:::.gllvmTMB_mspl_fixed_design(
    X,
    factor(c(1L, 2L, NA_integer_))
  )
  expect_equal(pinned$X, unname(X[, 1:2, drop = FALSE]))
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_fixed_design(cbind(1, c(1, 1, 1)), NULL),
    class = "gllvmTMB_mspl_rank_deficient"
  )
})

test_that("ML remains the default and explicit ml is numerically identical", {
  dat <- .mspl_fixture("logit", 1L)
  form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
  ctrl <- gllvmTMBcontrol(
    n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
  )
  implicit <- gllvmTMB(form, dat, family = binomial(), control = ctrl)
  explicit <- gllvmTMB(form, dat, family = binomial(), control = ctrl,
                       estimator = "ml")
  expect_identical(implicit$estimator, "ML")
  expect_identical(explicit$estimator, "ML")
  expect_equal(explicit$opt$par, implicit$opt$par, tolerance = 1e-10)
  expect_equal(explicit$opt$objective, implicit$opt$objective, tolerance = 1e-10)
  expect_identical(implicit$tmb_data$estimator_id, 0L)
  expect_identical(implicit$estimator_provenance$estimator_id, 0L)
  expect_identical(explicit$estimator_provenance$criterion_id, "la_ml")
})

test_that("LA-MSPL returns labelled finite point estimates for all binary links", {
  for (link in c("logit", "probit", "cloglog")) {
    for (q in 1:2) {
      fit <- .mspl_fit(link, q = q)
      expect_identical(
        fit$mspl$registry_cell,
        paste("binomial", link, "ordinary", paste0("q", q), sep = ":")
      )
      expect_identical(fit$mspl$registry_status, "admitted")
      expect_identical(fit$mspl$registry_evidence, "partial_b2_incomplete")
      expect_s3_class(fit, "gllvmTMB_mspl")
      expect_s3_class(fit, "gllvmTMB_multi")
      expect_identical(fit$estimator, "MSPL")
      expect_identical(fit$tmb_data$estimator_id, 1L)
      expect_true(is.finite(fit$opt$objective))
      expect_true(all(is.finite(fit$opt$par)))
      expect_true(is.finite(fit$mspl$unpenalized_loglik_at_estimate))
      expect_equal(fit$mspl$p_free, length(fit$opt$par))
      expect_null(fit$sd_report)
      expect_false(fit$mspl$inference$calibrated)
      expect_equal(fit$mspl$atom_status, 0L)
      expect_equal(fit$mspl$cloglog_tail_extension$total, 0L)

      expect_error(logLik(fit), class = "gllvmTMB_mspl_likelihood_unsupported")
    }
  }
})

test_that("LA-MSPL closes the stable cloglog objective under fixed-effect separation", {
  n_paper <- 36L
  set.seed(70808)
  papers <- data.frame(
    paper = factor(seq_len(n_paper)),
    design_score = seq(-2, 2, length.out = n_paper)
  )
  papers$item_supports <- stats::rbinom(
    n_paper, 1L, stats::plogis(-0.2 - 0.8 * papers$design_score)
  )
  papers$item_harm <- stats::rbinom(
    n_paper, 1L, stats::plogis(0.1 + 0.7 * papers$design_score)
  )
  papers$rare_escalation <- as.integer(
    seq_len(n_paper) %in% c(n_paper - 1L, n_paper)
  )
  dat <- data.frame(
    paper = rep(papers$paper, times = 3L),
    item = factor(rep(c("item_supports", "item_harm", "rare_escalation"),
                      each = n_paper)),
    design_score = rep(papers$design_score, times = 3L),
    value = c(papers$item_supports, papers$item_harm, papers$rare_escalation)
  )
  fit <- gllvmTMB(
    value ~ 0 + item + item:design_score +
      latent(1 | paper, d = 1, unique = FALSE),
    data = dat, unit = "paper", trait = "item",
    family = binomial("cloglog"), estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  )
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_true(is.finite(fit$opt$objective))
  expect_lt(abs(fit$mspl$decomposition_residual),
            1e-7 * (1 + abs(fit$opt$objective)))
  expect_equal(fit$mspl$unpenalized_tmb_obj$env$data$estimator_id, 2)
})

test_that("spatial LA-MSPL returns labelled finite point estimates for all binary links", {
  skip_if_not_installed("fmesher")
  for (link in c("logit", "probit", "cloglog")) {
    indep <- .mspl_spatial_fit(link, "indep")
    expect_s3_class(indep$fit, "gllvmTMB_mspl")
    expect_identical(indep$fit$mspl$structure, "spatial_indep")
    expect_equal(as.integer(indep$fit$report$mspl_structure_id), 2L)
    expect_equal(indep$fit$mspl$tau_representative, 0:2)
    expect_true(is.finite(indep$fit$opt$objective))
    expect_equal(indep$fit$mspl$atom_status, 0L)

    locations <- unique(indep$mesh$loc_xy)
    centred <- sweep(locations, 2L, colMeans(locations), FUN = "-")
    expect_equal(indep$fit$mspl$spde_r0,
                 sqrt(mean(rowSums(centred^2))), tolerance = 1e-14)

    for (q in 1:2) {
      latent <- .mspl_spatial_fit(link, "latent", q)
      expect_s3_class(latent$fit, "gllvmTMB_mspl")
      expect_identical(latent$fit$mspl$structure, "spatial_latent")
      expect_equal(as.integer(latent$fit$report$mspl_structure_id), 3L)
      expect_true(is.finite(latent$fit$opt$objective))
      expect_equal(latent$fit$mspl$atom_status, 0L)
      expect_equal(ncol(latent$fit$mspl$penalty$Lambda_spde_reference), q)
    }
  }
})

test_that("Bernoulli automatic Psi is admitted only when mapped off", {
  fit <- .mspl_fit("logit", unique = TRUE)
  expect_true(all(fit$tmb_data$diag_B_skip == 1L))
  expect_identical(fit$random, "z_B")
})

test_that("reported Jeffreys information matches a positive Cauchy-Binet oracle", {
  for (link in c("logit", "probit", "cloglog")) {
    fit <- .mspl_fit(link)
    X <- fit$mspl$fixed_design$X %||% fit$tmb_data$X_mspl
    b <- fit$tmb_obj$env$parList(fit$opt$par)$b_fix
    eta <- as.numeric(fit$tmb_data$X_fix %*% b + fit$tmb_data$offset_vec)
    logw <- switch(
      link,
      logit = stats::plogis(eta, log.p = TRUE) +
        stats::plogis(-eta, log.p = TRUE),
      probit = 2 * stats::dnorm(eta, log = TRUE) -
        stats::pnorm(eta, log.p = TRUE) -
        stats::pnorm(-eta, log.p = TRUE),
      cloglog = 2 * eta - log(expm1(exp(eta)))
    )
    oracle <- .mspl_cauchy_binet_logdet(X, logw)
    expect_equal(
      as.numeric(fit$report$mspl_logdet_information),
      oracle,
      tolerance = 2e-9
    )
  }
})

test_that("MSPL inference and likelihood-comparison methods fail closed", {
  fit <- .mspl_fit("logit")
  expect_false(.gllvmTMB_is_mspl(1))
  expect_true(.gllvmTMB_is_mspl(structure(
    list(estimator = NULL),
    class = c("gllvmTMB_mspl", "gllvmTMB_multi")
  )))
  expect_true(.gllvmTMB_is_mspl(list(estimator = "MSPL")))
  expect_error(vcov(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(standard_errors(fit), class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(bootstrap_Sigma(fit, n_boot = 40L),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(tidy(fit, conf.int = TRUE),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(predict(fit, se.fit = TRUE),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(getLV(fit, se = TRUE),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(getREsd(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(loading_ci(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(loading_profile(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(extract_communality(fit, ci = TRUE),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(extract_repeatability(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(extract_lv_effects(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(extract_phylo_signal(fit, ci = TRUE),
               class = "gllvmTMB_mspl_inference_unsupported")
  for (method in c("fisher-z", "wald", "bootstrap", "profile")) {
    expect_error(
      extract_correlations(fit, method = method),
      class = "gllvmTMB_mspl_inference_unsupported"
    )
  }
  expect_error(extract_cross_correlations(fit, method = "wald"),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(.proportions_wald_ci(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(.proportions_bootstrap_ci(fit, nsim = 2L),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(tmbprofile_wrapper(fit, name = "b_fix"),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(profile_targets(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(confint_inspect(fit, parm = "b_fix"),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(profile_ci_phylo_signal(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(profile_ci_total_variance(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(profile_phylo_signal(fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(check_identifiability(fit, sim_reps = 2L),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(gllvmTMB_check_consistency(fit, n_sim = 2L),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(plot(fit, boot = list()),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(AIC(fit), class = "gllvmTMB_mspl_model_comparison_unsupported")
  expect_error(BIC(fit), class = "gllvmTMB_mspl_model_comparison_unsupported")
  expect_error(anova(fit), class = "gllvmTMB_mspl_model_comparison_unsupported")

  class_only_fit <- fit
  class_only_fit$estimator <- NULL
  expect_true(.gllvmTMB_is_mspl(class_only_fit))
  expect_error(logLik(class_only_fit),
               class = "gllvmTMB_mspl_likelihood_unsupported")
  expect_error(vcov(class_only_fit),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(bootstrap_Sigma(class_only_fit, n_boot = 40L),
               class = "gllvmTMB_mspl_inference_unsupported")
  expect_error(plot(class_only_fit, boot = list()),
               class = "gllvmTMB_mspl_inference_unsupported")

  expect_s3_class(predict(fit, type = "response"), "data.frame")
  expect_true(is.matrix(getLV(fit, se = FALSE)))
  expect_true(is.numeric(extract_communality(fit, ci = FALSE)))
  expect_s3_class(
    extract_correlations(fit, method = "none", link_residual = "auto"),
    "data.frame"
  )
  expect_true(is.numeric(coef(fit)))
  expect_s3_class(summary(fit), "summary.gllvmTMB_multi")
  expect_s3_class(tidy(fit, conf.int = FALSE), "data.frame")
  expect_s3_class(extract_proportions(fit), "data.frame")
  expect_s3_class(extract_Sigma_table(fit), "data.frame")
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    expect_s3_class(plot(fit, type = "loadings", boot = NULL), "ggplot")
  }

  sanity_text <- capture.output(sanity_multi(fit))
  expect_match(
    paste(sanity_text, collapse = "\n"),
    "WITHHELD (MSPL point estimate)",
    fixed = TRUE
  )
  check <- check_gllvmTMB(fit)
  withheld <- check[check$component %in% c(
    "sdreport", "pd_hessian", "hessian_rank", "max_fixed_se"
  ), , drop = FALSE]
  expect_true(all(withheld$status == "INFO"))
  expect_true(all(withheld$value == "withheld"))
  advice <- paste(c(withheld$action, gllvmTMB_diagnose(fit, verbose = FALSE)$hints),
                  collapse = " ")
  expect_false(grepl("prefer profile|prefer bootstrap|standard_errors", advice))
})

test_that("internal MSPL profile feasibility traces the penalised objective only", {
  fit <- .mspl_fit("logit", q = 1L)
  checkpoint <- gllvmTMB:::.gllvmTMB_profile_tmb_checkpoint(fit$tmb_obj)
  penalty_off <- fit$mspl$unpenalized_tmb_obj
  penalty_off$fn <- function(...) {
    stop("penalty-off objective must not be profiled")
  }
  fit$mspl$unpenalized_tmb_obj <- penalty_off

  probe <- gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
    fit,
    which = 1L,
    step = 0.5,
    max_steps = 3L
  )

  expect_identical(probe$objective_source, "fit$tmb_obj (penalised LA-MSPL)")
  expect_identical(probe$target_name, "b_fix")
  expect_equal(probe$target_index, 1L)
  expect_true(all(probe$trace$finite))
  expect_true(all(probe$trace$convergence == 0L))
  expect_true(all(is.finite(probe$trace$objective)))
  expect_true(all(is.finite(probe$trace$objective_delta)))
  expect_identical(probe$centre_status, "matched")
  expect_identical(probe$lower_status, "crossed")
  expect_identical(probe$upper_status, "crossed")
  expect_true(probe$finite_stable)
  expect_identical(
    gllvmTMB:::.gllvmTMB_profile_tmb_checkpoint(fit$tmb_obj),
    checkpoint
  )

  displaced <- probe$trace[probe$trace$target > probe$mle, , drop = FALSE][1L, ]
  fixed_nuisance <- as.numeric(fit$opt$par)
  fixed_nuisance[[probe$target_index]] <- displaced$target
  fixed_nuisance_objective <- fit$tmb_obj$fn(fixed_nuisance)
  expect_lte(displaced$objective, fixed_nuisance_objective + 1e-8)
  expect_lt(displaced$objective, fixed_nuisance_objective - 1e-6)
  gllvmTMB:::.gllvmTMB_restore_profile_tmb_checkpoint(fit$tmb_obj, checkpoint)

  truncated <- gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
    fit, which = 1L, step = 0.5, max_steps = 1L
  )
  expect_identical(truncated$lower_status, "truncated")
  expect_identical(truncated$upper_status, "truncated")
  expect_false(truncated$finite_stable)
})

test_that("internal MSPL profile feasibility records the q=1 link matrix", {
  cases <- data.frame(
    link = c("logit", "probit", "cloglog", "cloglog"),
    direction = c("base", "base", "base", "reflected"),
    stringsAsFactors = FALSE
  )
  expected <- data.frame(
    centre_status = rep("matched", 12L),
    lower_status = rep("crossed", 12L),
    upper_status = c(
      rep("crossed", 5L),
      "truncated",
      rep("crossed", 6L)
    ),
    stringsAsFactors = FALSE
  )
  expected$finite_stable <-
    expected$centre_status == "matched" &
    expected$lower_status == "crossed" &
    expected$upper_status == "crossed"

  traces <- lapply(seq_len(nrow(cases)), function(case) {
    fit <- .mspl_fit(
      cases$link[[case]],
      q = 1L,
      direction = cases$direction[[case]]
    )
    target_index <- which(names(fit$opt$par) == "b_fix")
    expect_length(target_index, 3L)
    expect_identical(as.integer(fit$tmb_data$estimator_id), 1L)
    lapply(target_index, function(which) {
      probe <- gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
        fit,
        which = which,
        step = 0.5,
        max_steps = 6L
      )
      expect_identical(
        probe$objective_source,
        "fit$tmb_obj (penalised LA-MSPL)"
      )
      expect_true(all(probe$trace$finite))
      expect_true(all(probe$trace$convergence == 0L))
      expect_true(all(is.finite(probe$trace$objective_delta)))
      probe
    })
  })
  observed <- do.call(
    rbind,
    lapply(traces, function(link_traces) {
      do.call(
        rbind,
        lapply(link_traces, function(probe) {
          data.frame(
            centre_status = probe$centre_status,
            lower_status = probe$lower_status,
            upper_status = probe$upper_status,
            finite_stable = probe$finite_stable,
            stringsAsFactors = FALSE
          )
        })
      )
    })
  )

  expect_identical(observed, expected)
})

test_that("unsupported MSPL surfaces stop before optimisation", {
  dat <- .mspl_fixture("logit", 1L)
  dat$known_offset <- 0.25
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 3, unique = FALSE),
      dat, family = binomial(), estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
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
      dat, family = binomial(), weights = rep(2, nrow(dat)), estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      dat, family = binomial(), estimator = "mspl",
      control = gllvmTMBcontrol(aghq_ridge = 2)
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + offset(known_offset) +
        latent(0 + trait | site, d = 1, unique = FALSE),
      dat, family = binomial(), estimator = "mspl"
    ),
    "offsets are supported for count families"
  )
})

test_that("direct TMB callers cannot bypass the MSPL zero-offset fence", {
  fit <- .mspl_fit("logit")
  bad_data <- fit$tmb_data
  bad_data$offset_vec[[1L]] <- 0.25

  expect_error(
    TMB::MakeADFun(
      data = bad_data,
      parameters = fit$tmb_params,
      map = fit$tmb_map,
      random = fit$random,
      DLL = fit$tmb_obj$env$DLL,
      silent = TRUE
    ),
    "all-zero offsets"
  )
})

test_that("REML keeps legacy omission semantics and rejects explicit estimator", {
  dat <- .mspl_fixture("logit", 1L)
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      dat, family = binomial(), REML = TRUE, estimator = "ml"
    ),
    class = "gllvmTMB_estimator_reml_conflict"
  )
})

test_that("loading_ridge is an integration-neutral alias and cannot double-specify", {
  legacy <- gllvmTMBcontrol(aghq_ridge = 2)
  named <- gllvmTMBcontrol(loading_ridge = 2)

  expect_identical(named$aghq_ridge, legacy$aghq_ridge)
  expect_true(named$aghq_ridge_explicit)
  expect_true(named$loading_ridge_explicit)
  expect_identical(named$loading_ridge, legacy$aghq_ridge)

  expect_error(
    gllvmTMBcontrol(aghq_ridge = 2, loading_ridge = 2),
    class = "gllvmTMB_loading_ridge_alias_conflict"
  )
})
