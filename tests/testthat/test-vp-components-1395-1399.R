# VP() and extract_proportions() must count every active variance component
# they can compute, and must say which ones they leave out (#1395, #1399).
#
# #1399: extract_proportions() left out the Gaussian residual sigma_eps^2, so
#   a fit whose variance was 70-84% residual reported shared_unit = 1.
# #1395: VP() read only the rr/diag/phylo/propto tiers plus the Gaussian
#   residual, silently dropped `(1 | group)` intercepts (and the spatial,
#   kernel, cluster2, temporal and slope tiers), then renormalised.

# ---- fixtures -------------------------------------------------------------

## The #1399 data: three Gaussian traits, one latent axis, residual-dominated.
make_vp_1399_fit <- function() {
  set.seed(3)
  n <- 40
  d <- expand.grid(
    trait = factor(c("a", "b", "c")),
    unit = factor(sprintf("u%02d", seq_len(n))),
    rep = 1:3
  )
  z <- stats::rnorm(n)
  d$value <- c(0.8, 0.5, -0.6)[as.integer(d$trait)] * z[as.integer(d$unit)] +
    stats::rnorm(nrow(d))
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, unit = "unit", trait = "trait", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(n_init = 1, se = FALSE)
  )))
}

## The #1395 data: the same design plus an 8-level `(1 | study)` intercept
## with SD 2, the largest single variance component.
make_vp_1395_fit <- function() {
  set.seed(3)
  n <- 30
  ns <- 8
  d <- expand.grid(
    trait = factor(c("a", "b", "c")),
    unit = factor(sprintf("u%02d", seq_len(n))),
    rep = 1:2
  )
  d$study <- factor(sample(seq_len(ns), nrow(d), replace = TRUE))
  z <- stats::rnorm(n)
  u <- stats::rnorm(ns, 0, 2)
  d$value <- c(0.8, 0.5, -0.6)[as.integer(d$trait)] * z[as.integer(d$unit)] +
    u[d$study] + stats::rnorm(nrow(d), sd = 0.5)
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1) + (1 | study),
    data = d, unit = "unit", trait = "trait", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(n_init = 1, se = FALSE)
  )))
}

## Plain-list VP() fixture in the style of test-ordiplot-VP.R.
make_fake_vp_fit_1395 <- function(use_extra = list(), report_extra = list(),
                                  extra = list()) {
  trait_levels <- c("t1", "t2")
  fit <- list(
    use = utils::modifyList(
      list(
        rr_B = FALSE, diag_B = TRUE, rr_W = FALSE, diag_W = FALSE,
        diag_species = FALSE, phylo_rr = FALSE, phylo_diag = FALSE,
        propto = FALSE
      ),
      use_extra
    ),
    report = utils::modifyList(
      list(sd_B = c(1, 1), sigma_eps = 1),
      report_extra
    ),
    n_traits = 2L,
    data = data.frame(
      trait = factor(rep(trait_levels, each = 2L), levels = trait_levels)
    ),
    trait_col = "trait",
    tmb_data = list(
      family_id_vec = rep(0L, 4L),
      link_id_vec = rep(0L, 4L),
      trait_id = rep(0:1, each = 2L)
    )
  )
  utils::modifyList(fit, extra)
}

# ---- #1399: the Gaussian residual in extract_proportions() ----------------

test_that("extract_proportions() counts the Gaussian residual sigma_eps^2 (#1399)", {
  skip_on_cran()
  fit <- make_vp_1399_fit()
  s2 <- as.numeric(fit$report$sigma_eps)^2
  expect_length(s2, 1L)

  p <- extract_proportions(fit, format = "wide")
  expect_true("residual" %in% names(p))
  ## The residual enters as the absolute sigma_eps^2 of every Gaussian trait.
  expect_equal(unname(p$residual * p$total_variance), rep(s2, 3L),
               tolerance = 1e-8)
  ## The issue's symptom: the shared share was reported as 1 for a fit whose
  ## variance is 70-84% residual.
  expect_true(all(p$shared_unit < 0.5))
  share_cols <- setdiff(names(p), c("trait", "total_variance"))
  expect_equal(unname(rowSums(as.matrix(p[, share_cols]))), rep(1, 3L),
               tolerance = 1e-8)

  ## sigma_eps is an estimated parameter, not a link-implied constant, so
  ## link_residual = "none" keeps it.
  p_none <- extract_proportions(fit, link_residual = "none", format = "wide")
  expect_equal(p_none$residual, p$residual)

  long <- extract_proportions(fit, format = "long")
  expect_true("residual" %in% as.character(long$component))

  ## The two variance-share functions now agree on the same fit.
  vp <- VP(fit)
  expect_equal(unname(p$shared_unit), unname(vp[, "rr_B"]), tolerance = 1e-8)
  expect_equal(unname(p$unique_unit), unname(vp[, "diag_B"]), tolerance = 1e-8)
  expect_equal(unname(p$residual), unname(vp[, "residual"]), tolerance = 1e-8)
})

test_that("proportion intervals rebuild the same residual-inclusive shares (#1399)", {
  skip_on_cran()
  fit <- make_vp_1399_fit()
  p <- extract_proportions(fit, format = "wide")

  ## confint(parm = "proportion:residual") must be a recognised token.
  parsed <- gllvmTMB:::.parse_proportion_parm(
    "proportion:residual",
    trait_names = c("a", "b", "c")
  )
  expect_equal(parsed$components, "residual")

  ## The Wald path rebuilds numerator and denominator from report(); at the
  ## MLE it must reproduce the extractor's shares, residual included.
  comps <- gllvmTMB:::.proportions_components_present(fit)
  expect_true("residual" %in% comps)
  base <- gllvmTMB:::.proportions_components_at(
    fit, fit$tmb_obj$env$last.par.best, comps, 3L
  )
  p_hat <- base$num / base$den
  expect_equal(unname(p_hat[, "residual"]), unname(p$residual),
               tolerance = 1e-8)
  expect_equal(unname(p_hat[, "shared_unit"]), unname(p$shared_unit),
               tolerance = 1e-8)

  ## The profile target function floats sigma_eps in the denominator.
  for (cc in c("residual", "shared_unit")) {
    target <- gllvmTMB:::.proportion_target_fn(fit, cc, trait_idx = 2L)
    expect_false(is.null(target))
    expect_equal(target(fit$opt$par, fit), unname(p[[cc]][2L]),
                 tolerance = 1e-8)
  }
})

test_that("plot(type = 'variance') labels and colours the residual (#1399)", {
  skip_on_cran()
  skip_if_not_installed("ggplot2")
  fit <- make_vp_1399_fit()
  p <- suppressMessages(plot(fit, type = "variance"))
  expect_true("Residual" %in% levels(p$data$component_label))
  ## A level missing from the manual palette would be drawn in the scale's
  ## grey50 fallback, not NA, so check for the residual's own colour.
  built <- ggplot2::ggplot_build(p)
  expect_true(
    gllvmTMB:::.gtmb_plot_palette[["grey"]] %in% built$data[[1]]$fill
  )
})

test_that("a sigma_eps fixed by the engine is still counted (#1399)", {
  skip_on_cran()
  ## One observation per unit and trait: the default latent() Psi is then
  ## per-row, so the engine fixes sigma_eps at sd(all responses) / 1000
  ## instead of estimating it. With one trait on a 1000-fold larger scale,
  ## that fixed value is a large part of the unit-scale traits' variance.
  set.seed(6)
  n <- 150
  d <- expand.grid(
    trait = factor(c("mass_g", "ratio", "score")),
    unit = factor(sprintf("u%03d", seq_len(n)))
  )
  z <- stats::rnorm(n)
  ti <- as.integer(d$trait)
  d$value <- c(1000, 1, 1)[ti] *
    (c(0.8, 0.5, -0.6)[ti] * z[as.integer(d$unit)] +
       stats::rnorm(nrow(d), sd = 0.6))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, unit = "unit", trait = "trait", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(n_init = 1, se = FALSE)
  )))
  expect_true(gllvmTMB:::.gllvmTMB_sigma_eps_mapped_off(fit))
  s2 <- as.numeric(fit$report$sigma_eps)^2

  vp <- VP(fit)
  p <- extract_proportions(fit, format = "wide")
  expect_true("residual" %in% colnames(vp))
  expect_true("residual" %in% names(p))
  expect_equal(unname(p$residual * p$total_variance), rep(s2, 3L),
               tolerance = 1e-8)
  expect_equal(unname(p$residual), unname(vp[, "residual"]), tolerance = 1e-8)
  expect_equal(unname(p$shared_unit), unname(vp[, "rr_B"]), tolerance = 1e-8)
  expect_true(all(p$residual[2:3] > 0.1))

  ## A fixed sigma_eps is a constant offset in the profile denominator; its
  ## own proportion has no profile target, as for the link residual.
  expect_null(gllvmTMB:::.proportion_target_fn(fit, "residual", 2L))
  target <- gllvmTMB:::.proportion_target_fn(fit, "shared_unit", 2L)
  expect_equal(target(fit$opt$par, fit), unname(p$shared_unit[2L]),
               tolerance = 1e-8)
})

test_that("profile targets refuse partly fixed per-trait blocks instead of misreading them", {
  skip_on_cran()
  ## Gaussian and binomial traits under one latent(): the engine fixes the
  ## binomial traits' Psi, so theta_diag_B has fewer free values than traits.
  set.seed(7)
  n <- 40
  d <- expand.grid(
    trait = factor(c("a", "b", "c", "d")),
    unit = factor(sprintf("u%02d", seq_len(n))),
    rep = 1:3
  )
  fam <- c(a = "b", b = "g", c = "b", d = "g")
  d$family <- factor(fam[as.character(d$trait)], levels = c("g", "b"))
  eta <- c(0.9, 0.8, 1.0, -0.6)[as.integer(d$trait)] *
    stats::rnorm(n)[as.integer(d$unit)]
  d$value <- ifelse(d$family == "b", stats::rbinom(nrow(d), 1, stats::plogis(eta)),
                    eta + stats::rnorm(nrow(d)))
  families <- list(g = stats::gaussian(), b = stats::binomial())
  attr(families, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, unit = "unit", trait = "trait", family = families,
    silent = TRUE, control = gllvmTMBcontrol(n_init = 1, se = FALSE)
  )))
  expect_true(anyNA(fit$tmb_obj$env$map$theta_diag_B))
  expect_null(gllvmTMB:::.proportion_target_fn(fit, "residual", 2L))
  expect_null(gllvmTMB:::.proportion_target_fn(fit, "shared_unit", 2L))

  ## The report-based Wald reconstruction is unaffected and still matches.
  p <- extract_proportions(fit, format = "wide")
  expect_equal(unname(p$residual[c(1L, 3L)]), c(0, 0))
  comps <- gllvmTMB:::.proportions_components_present(fit)
  base <- gllvmTMB:::.proportions_components_at(
    fit, fit$tmb_obj$env$last.par.best, comps, 4L
  )
  expect_equal(unname((base$num / base$den)[, "residual"]),
               unname(p$residual), tolerance = 1e-8)
})

# ---- #1395: components VP() used to drop ----------------------------------

test_that("VP() includes the (1 | group) random-intercept variance (#1395)", {
  skip_on_cran()
  fit <- make_vp_1395_fit()
  s2_study <- exp(2 * as.numeric(fit$report$log_sigma_re_int))
  s2_eps <- as.numeric(fit$report$sigma_eps)^2
  L <- as.matrix(fit$report$Lambda_B)
  v_rr <- rowSums(L^2)
  v_diag <- as.numeric(fit$report$sd_B)^2
  total <- v_rr + v_diag + s2_study + s2_eps

  expect_no_warning(VP(fit))
  vp <- VP(fit)
  expect_true("re_int_study" %in% colnames(vp))
  expect_equal(unname(vp[, "re_int_study"]), unname(s2_study / total),
               tolerance = 1e-8)
  expect_equal(unname(vp[, "rr_B"]), unname(v_rr / total), tolerance = 1e-8)
  expect_equal(unname(vp[, "residual"]), unname(s2_eps / total),
               tolerance = 1e-8)
  expect_equal(unname(rowSums(vp)), rep(1, 3L), tolerance = 1e-8)
})

test_that("extract_proportions() names the (1 | group) term it leaves out (#1395)", {
  skip_on_cran()
  fit <- make_vp_1395_fit()
  expect_warning(
    extract_proportions(fit, format = "wide"),
    regexp = "study",
    class = "gllvmTMB_proportions_component_omitted"
  )
  p <- suppressWarnings(extract_proportions(fit, format = "wide"))
  expect_true("(1 | study)" %in% attr(p, "omitted_components"))
  expect_false("re_int_study" %in% names(p))

  ## The interval machinery re-calls extract_proportions(); the user sees the
  ## omission once per request, not once per internal call.
  n_warn <- 0L
  withCallingHandlers(
    gllvmTMB:::.proportions_validate_inputs(fit, NULL, NULL, 0.95),
    gllvmTMB_proportions_component_omitted = function(cnd) {
      n_warn <<- n_warn + 1L
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(n_warn, 1L)
})

test_that("VP() warns, by name, about random slopes it cannot partition (#1395)", {
  skip_on_cran()
  set.seed(5)
  n <- 40
  d <- expand.grid(
    trait = factor(c("a", "b", "c")),
    unit = factor(sprintf("u%02d", seq_len(n))),
    rep = 1:3
  )
  d$x <- stats::rnorm(nrow(d))
  b0 <- stats::rnorm(n)
  b1 <- stats::rnorm(n, sd = 0.5)
  d$value <- c(0.8, 0.5, -0.6)[as.integer(d$trait)] *
    (b0[as.integer(d$unit)] + b1[as.integer(d$unit)] * d$x) +
    stats::rnorm(nrow(d), sd = 0.5)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):x +
      latent(0 + trait + (0 + trait):x | unit, d = 1),
    data = d, unit = "unit", trait = "trait", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(n_init = 1, se = FALSE)
  )))
  expect_true(isTRUE(fit$use$rr_B_slope))
  ## The whole unit-level term (its intercepts and slopes) has no single
  ## per-trait variance. Before the fix VP() dropped it without a warning and
  ## returned residual = 1 for every trait, although that term carries most of
  ## the variance.
  expect_warning(VP(fit), regexp = "intercepts and slopes",
                 class = "gllvmTMB_vp_component_omitted")
  vp <- suppressWarnings(VP(fit))
  expect_equal(attr(vp, "omitted_components"),
               "unit-level random intercepts and slopes")
})

test_that("VP() adds cluster2 and names each tier it omits (#1395)", {
  fit <- make_fake_vp_fit_1395(
    use_extra = list(diag_cluster2 = TRUE, spde = TRUE, equalto = TRUE),
    report_extra = list(sd_c2 = c(1, 2)),
    extra = list(temporal = list(active = TRUE))
  )
  w <- NULL
  M <- withCallingHandlers(
    VP(fit),
    gllvmTMB_vp_component_omitted = function(cnd) {
      w <<- conditionMessage(cnd)
      invokeRestart("muffleWarning")
    }
  )
  expect_false(is.null(w))
  expect_match(w, "spatial_*() field", fixed = TRUE)
  expect_match(w, "temporal_*() state", fixed = TRUE)
  expect_match(w, "meta_V() known sampling variance", fixed = TRUE)
  expect_equal(length(attr(M, "omitted_components")), 3L)

  ## diag_B = 1, cluster2 = c(1, 4), residual = 1.
  expect_true("diag_cluster2" %in% colnames(M))
  expect_equal(unname(M["t1", ]), c(1, 1, 1) / 3)
  expect_equal(unname(M["t2", c("diag_B", "diag_cluster2", "residual")]),
               c(1, 4, 1) / 6)
})

test_that("VP() stays silent and unchanged on fits it fully partitions", {
  fit <- make_fake_vp_fit_1395()
  expect_no_warning(M <- VP(fit))
  expect_null(attr(M, "omitted_components"))
  expect_equal(colnames(M), c("diag_B", "residual"))
  expect_equal(unname(M[, "diag_B"]), c(0.5, 0.5))
})

test_that("VP() gives one column per (1 | group) term, propto and kernel tier (#1395)", {
  fit <- make_fake_vp_fit_1395(
    use_extra = list(re_int = TRUE, propto = TRUE, kernel = TRUE),
    report_extra = list(
      log_sigma_re_int = log(c(1, 2)),
      lam_phy = 3,
      ## T x rank x tier: kernel k1 loadings (1, 2), k2 loadings (3, 1).
      Lambda_kernel = array(c(1, 2, 3, 1), dim = c(2L, 1L, 2L))
    ),
    extra = list(
      re_int = list(groups = c("study", "site")),
      kernel_levels = data.frame(
        name = c("k1", "k2"), internal_level = "kernel", index = 1:2,
        rank = 1L, stringsAsFactors = FALSE
      )
    )
  )
  expect_no_warning(M <- VP(fit))
  expect_equal(
    colnames(M),
    c("diag_B", "propto", "kernel_k1", "kernel_k2", "re_int_study",
      "re_int_site", "residual")
  )
  ## t1: 1 + 3 + 1 + 9 + 1 + 4 + 1 = 20; t2: 1 + 3 + 4 + 1 + 1 + 4 + 1 = 15.
  expect_equal(unname(M["t1", ]), c(1, 3, 1, 9, 1, 4, 1) / 20)
  expect_equal(unname(M["t2", ]), c(1, 3, 4, 1, 1, 4, 1) / 15)
})

test_that("VP() reads the Gaussian and lognormal sigma_eps slots separately", {
  fit <- make_fake_vp_fit_1395(
    report_extra = list(sigma_eps = c(1, 2)),
    extra = list(tmb_data = list(family_id_vec = c(0L, 0L, 3L, 3L)))
  )
  M <- VP(fit)
  ## diag_B = 1; residual = 1^2 for the Gaussian trait, 2^2 for the lognormal.
  expect_equal(unname(M["t1", ]), c(1, 1) / 2)
  expect_equal(unname(M["t2", ]), c(1, 4) / 5)
})

test_that("VP() names one response-column slope term once", {
  fit <- make_fake_vp_fit_1395(
    use_extra = list(phylo_dep_slope = TRUE, phylo_column_slope = TRUE),
    extra = list(tmb_data = list(
      use_phylo_slope = 1L,
      use_phylo_slope_correlated = 1L
    ))
  )
  expect_warning(M <- VP(fit), class = "gllvmTMB_vp_component_omitted")
  expect_equal(attr(M, "omitted_components"),
               "response-column slope or coefficient term")
})

test_that("VP() refuses a Julia bridge fit instead of returning an empty matrix", {
  fake <- structure(
    list(trait_col = "trait", trait_levels = c("a", "b"),
         use = list(lv_B = TRUE)),
    class = c("gllvmTMB_julia", "list")
  )
  expect_error(VP(fake), class = "gllvmTMB_julia_gate")
})
