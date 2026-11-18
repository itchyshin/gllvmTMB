# Synthetic extractor fixtures only; no external data or Julia runtime.
.full_cor_fits <- new.env(parent = emptyenv())
.full_cor_ordinal_fit <- function() {
  if (exists("ordinal", .full_cor_fits, inherits = FALSE)) return(.full_cor_fits$ordinal)
  set.seed(1469)
  items <- c("zeta", "beta", "omega", "alpha")
  n <- 40L
  u <- rnorm(n)
  dat <- data.frame(unit = factor(rep(seq_len(n), times = length(items))),
    item = factor(rep(items, each = n), levels = items),
    value = ordered(as.integer(cut(rep(u, times = length(items)) +
      rnorm(n * length(items)), breaks = c(-Inf, -.6, .4, Inf), labels = FALSE))))
  .full_cor_fits$ordinal <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + item + latent(0 + item | unit, d = 1, unique = FALSE),
    data = dat, trait = "item", unit = "unit", family = ordinal_probit(),
    control = gllvmTMBcontrol(se = FALSE))))
  .full_cor_fits$ordinal
}

.full_cor_expect_layout <- function(all, unique, items) {
  k <- length(items)
  expect_equal(nrow(all), k^2)
  expect_setequal(all$trait_i, items)
  expect_setequal(all$trait_j, items)
  key <- paste(all$trait_i, all$trait_j, sep = "|")
  expect_false(anyDuplicated(key) > 0L)
  diagonal <- all$trait_i == all$trait_j
  expect_equal(all$correlation[diagonal], rep(1, k))
  expect_true(all(is.na(all$lower[diagonal])))
  expect_true(all(is.na(all$upper[diagonal])))
  expect_equal(all$method[diagonal], rep("fixed", k))
  expect_equal(all$interval_status[diagonal], rep("none", k))
  for (r in seq_len(nrow(unique))) {
    direct <- match(paste(unique$trait_i[r], unique$trait_j[r], sep = "|"), key)
    mirror <- match(paste(unique$trait_j[r], unique$trait_i[r], sep = "|"), key)
    expect_equal(all$correlation[c(direct, mirror)], rep(unique$correlation[r], 2L))
    for (col in c("lower", "upper", "method", "interval_status")) {
      expect_equal(all[[col]][c(direct, mirror)], rep(unique[[col]][r], 2L))
    }
  }
}

test_that("unique preserves the existing correlation output exactly", {
  fit <- .full_cor_ordinal_fit()
  default <- suppressMessages(extract_correlations(fit, tier = "unit", link_residual = "auto"))
  explicit <- suppressMessages(extract_correlations(fit, tier = "unit", link_residual = "auto", entries = "unique"))
  expect_identical(explicit, default)
})

test_that("all and offdiag retain ordinal item order and mirrored interval payloads", {
  fit <- .full_cor_ordinal_fit()
  items <- c("zeta", "beta", "omega", "alpha")
  unique <- suppressMessages(extract_correlations(fit, tier = "unit", link_residual = "auto", method = "fisher-z", n_eff = 40L))
  all <- suppressMessages(extract_correlations(fit, tier = "unit", link_residual = "auto", method = "fisher-z", n_eff = 40L, entries = "all"))
  offdiag <- suppressMessages(extract_correlations(fit, tier = "unit", link_residual = "auto", method = "fisher-z", n_eff = 40L, entries = "offdiag"))
  .full_cor_expect_layout(all, unique, items)
  expect_equal(nrow(offdiag), length(items) * (length(items) - 1L))
  expect_false(any(offdiag$trait_i == offdiag$trait_j))
  expect_setequal(offdiag$trait_i, items)
  expect_setequal(offdiag$trait_j, items)
  expected <- all[all$trait_i != all$trait_j, , drop = FALSE]
  rownames(expected) <- rownames(offdiag) <- NULL
  expect_equal(offdiag, expected)
  matrix_table <- suppressMessages(extract_Sigma_table(fit, level = "unit",
    measure = "correlation", entries = "all", link_residual = "auto"))
  keys <- paste(all$trait_i, all$trait_j, sep = "|")
  idx <- match(keys, paste(matrix_table$trait_i, matrix_table$trait_j, sep = "|"))
  expect_equal(all$correlation, matrix_table$estimate[idx])
  expect_s3_class(all, "gllvmTMB_reportable_table")
  expect_output(print(all), "zeta")
})

test_that("non-unique correlation entries reject pair requests clearly", {
  fit <- .full_cor_ordinal_fit()
  for (entries in c("all", "offdiag")) {
    expect_error(extract_correlations(fit, tier = "unit", link_residual = "auto", pair = c("zeta", "beta"),
      entries = entries), "pair.*unique|unique.*pair")
  }
  expect_error(extract_correlations(fit, entries = "invalid"), "entries|arg")
})

test_that("full correlation tables remain compatible with full heatmaps", {
  skip_if_not_installed("ggplot2")
  fit <- .full_cor_ordinal_fit()
  for (entries in c("all", "offdiag")) {
    table <- suppressMessages(extract_correlations(fit, tier = "unit", link_residual = "auto", entries = entries))
    plot <- plot_correlations(table, style = "heatmap", triangle = "full")
    expect_s3_class(plot, "ggplot")
    tiles <- ggplot2::ggplot_build(plot)$data[[1L]]
    expect_equal(nrow(tiles), 16L)
    expect_false(anyDuplicated(paste(tiles$x, tiles$y)) > 0L)
  }
})

test_that("full correlation entry expansion occurs separately within each tier", {
  set.seed(1470)
  s <- simulate_site_trait(n_sites = 20L, n_species = 6L, n_traits = 3L,
    mean_species_per_site = 4L, Lambda_B = matrix(c(.9, .4, -.3), 3L, 1L),
    psi_B = c(.4, .3, .5), psi_W = c(.3, .4, .3), beta = matrix(0, 3L, 2L), seed = 1470)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site_species),
    data = s$data, unit = "site", unit_obs = "site_species", control = gllvmTMBcontrol(se = FALSE))))
  unique <- extract_correlations(fit, tier = c("unit", "unit_obs"))
  all <- extract_correlations(fit, tier = c("unit", "unit_obs"), entries = "all")
  expect_setequal(all$tier, unique$tier)
  for (tier in unique(all$tier)) {
    .full_cor_expect_layout(all[all$tier == tier, ], unique[unique$tier == tier, ], levels(fit$data$trait))
  }
})

test_that("point-only Julia bridge correlation tables expand without a Julia process", {
  items <- c("zeta", "beta", "omega", "alpha")
  Lambda <- matrix(c(.7, -.4, .5, .3), ncol = 1L)
  Sigma <- tcrossprod(Lambda) + diag(.2, length(items))
  fit <- structure(list(family = "gaussian", model = "gaussian_rr", d = 1L,
    n_traits = length(items), n_units = 6L, trait_names = items,
    unit_names = paste0("u", 1:6), alpha = rep(0, length(items)),
    loadings = Lambda, scores = matrix(0, 6L, 1L), Sigma = Sigma,
    correlation = cov2cor(Sigma), loglik = -22, df = 9L, nobs = 24L,
    converged = TRUE), class = c("gllvmTMB_julia", "list"))
  unique <- extract_correlations(fit, tier = "unit", link_residual = "auto")
  all <- extract_correlations(fit, tier = "unit", link_residual = "auto", entries = "all")
  .full_cor_expect_layout(all, unique, items)
  expect_true(all(is.na(all$lower)))
  expect_true(all(is.na(all$upper)))
  off <- extract_correlations(fit, tier = "unit", link_residual = "auto", entries = "offdiag")
  expect_equal(nrow(off), 12L)
  expect_true(all(off$method == "none"))
})
