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

test_that("a per-row indep() residual is not double counted with pinned sigma_eps", {
  skip_on_cran()
  set.seed(11)
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 5, n_traits = 3, mean_species_per_site = 3,
    psi_B = c(0.3, 0.3, 0.3), psi_W = c(0.3, 0.3, 0.3), seed = 11
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + indep(0 + trait | site_species),
    data = sim$data, control = gllvmTMBcontrol(n_init = 1, se = FALSE)
  )))
  ## The per-row indep() term IS the residual; the package pins sigma_eps at
  ## about sd(y) / 1000 to keep the density defined.
  expect_true(gllvmTMB:::.gllvmTMB_sigma_eps_mapped_off(fit))
  p <- extract_proportions(fit, format = "wide")
  expect_false("residual" %in% names(p))
  expect_false("residual" %in% colnames(VP(fit)))
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
  ## Before the fix VP() returned residual = 1 for every trait, with no
  ## warning, although the unit-level slopes carry most of the variance.
  expect_warning(VP(fit), regexp = "slope",
                 class = "gllvmTMB_vp_component_omitted")
  vp <- suppressWarnings(VP(fit))
  expect_true(length(attr(vp, "omitted_components")) >= 1L)
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
  expect_match(w, "spatial")
  expect_match(w, "temporal")
  expect_match(w, "meta_V")
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
