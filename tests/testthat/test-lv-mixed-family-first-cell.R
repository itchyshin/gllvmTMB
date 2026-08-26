make_mixed_lv_first_cell_data <- function() {
  units <- paste0("u", seq_len(6L))
  traits <- c("g", "b")
  dat <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        x = rep(seq(-1, 1, length.out = length(units))[[i]], 2L),
        value = c(0.1 * i, i %% 3L),
        stringsAsFactors = FALSE
      )
    })
  )
  dat$unit <- factor(dat$unit, levels = units)
  dat$trait <- factor(dat$trait, levels = traits)
  dat
}

make_mixed_lv_first_cell_fit_data <- function(n_units = 60L, seed = 73101L) {
  set.seed(seed)
  x <- stats::rnorm(n_units)
  score <- 0.60 * x + stats::rnorm(n_units)
  eta_g <- 0.15 + 0.70 * score
  eta_b <- -0.20 - 0.55 * score
  data.frame(
    unit = factor(rep(sprintf("u%03d", seq_len(n_units)), each = 2L)),
    trait = factor(
      rep(c("gaussian_trait", "binomial_trait"), n_units),
      levels = c("gaussian_trait", "binomial_trait")
    ),
    family = factor(
      rep(c("continuous", "presence"), n_units),
      levels = c("continuous", "presence")
    ),
    x = rep(x, each = 2L),
    value = as.vector(rbind(
      stats::rnorm(n_units, eta_g, 0.30),
      stats::rbinom(n_units, size = 20L, prob = stats::plogis(eta_b))
    ))
  )
}

make_mixed_lv_wide_gaussian_poisson <- function(n_units = 60L, seed = 73102L) {
  set.seed(seed)
  x <- stats::rnorm(n_units)
  score <- 0.60 * x + stats::rnorm(n_units)
  data.frame(
    unit = factor(sprintf("u%03d", seq_len(n_units))),
    x = x,
    gaussian = stats::rnorm(n_units, 0.15 + 0.70 * score, 0.30),
    poisson = stats::rpois(n_units, exp(log(4) - 0.55 * score))
  )
}

fit_mixed_lv_wide_gaussian_poisson <- function(dat, families) {
  suppressWarnings(suppressMessages(gllvmTMB(
    traits(gaussian, poisson) ~ 1 +
      latent(1 | unit, d = 1, unique = FALSE, lv = ~x),
    data = dat,
    unit = "unit",
    family = families,
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

mixed_lv_first_cell_preflight <- function(
  formula,
  data = make_mixed_lv_first_cell_data(),
  family_id_vec = rep(c(0L, 1L), times = nrow(data) / 2L),
  link_id_vec = rep(0L, nrow(data))
) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(formula)
  )
  gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = parsed,
    data = data,
    trait = "trait",
    site = "unit",
    family_id_vec = family_id_vec,
    link_id_vec = link_id_vec,
    REML = FALSE
  )
}

test_that("the named Gaussian plus binomial-logit loadings-only cell is admitted", {
  setup <- mixed_lv_first_cell_preflight(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x)
  )

  expect_true(isTRUE(setup$enabled))
  expect_equal(setup$X_lv_B_names, "x")
  expect_equal(nrow(setup$X_lv_B), 6L)
})

test_that("the mixed first cell keeps default Psi and K greater than one gated", {
  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
    ),
    regexp = "unique = FALSE|loadings-only"
  )

  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 2, unique = FALSE, lv = ~x)
    ),
    regexp = "d = 1|rank one"
  )
})

test_that("the family-wide programme rejects explicit unit-tier diagonal companions", {
  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x) +
        unique(0 + trait | unit)
    ),
    regexp = "loadings-only|diagonal Psi|indep\\(\\)|unique\\(\\)"
  )

  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x) +
        indep(0 + trait | unit)
    ),
    regexp = "loadings-only|diagonal Psi|indep\\(\\)|unique\\(\\)"
  )
})

test_that("the mixed programme keeps unregistered links and pairings gated", {
  dat <- make_mixed_lv_first_cell_data()
  family_ids <- rep(c(0L, 1L), times = nrow(dat) / 2L)
  unsupported_links <- ifelse(family_ids == 1L, 3L, 0L)

  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = dat,
      family_id_vec = family_ids,
      link_id_vec = unsupported_links
    ),
    regexp = "canonical admitted link|logit.*probit.*cloglog"
  )

  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = dat,
      family_id_vec = rep(c(4L, 5L), times = nrow(dat) / 2L)
    ),
    regexp = "programme cells|Arbitrary mixed-family"
  )

  mixed_binomial_links <- rep(c(0L, 0L, 1L), times = nrow(dat) / 3L)
  mixed_binomial_ids <- rep(c(0L, 1L, 1L), times = nrow(dat) / 3L)
  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = dat,
      family_id_vec = mixed_binomial_ids,
      link_id_vec = mixed_binomial_links
    ),
    regexp = "one binomial link|named.*link|canonical admitted link"
  )
})

test_that("a pure-binomial predictor-informed fit keeps one exact link", {
  dat <- make_mixed_lv_first_cell_data()

  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = dat,
      family_id_vec = rep(1L, nrow(dat)),
      link_id_vec = rep(c(0L, 1L), length.out = nrow(dat))
    ),
    regexp = "one binomial link|one exact named family.*link cell"
  )
})

test_that("the family-wide programme keeps the one numeric predictor contract exact", {
  dat <- make_mixed_lv_first_cell_data()
  dat$x2 <- dat$x^2
  dat$x_factor <- factor(ifelse(dat$x < 0, "low", "high"))
  dat$x_matrix <- I(cbind(dat$x, dat$x^2))

  for (formula in list(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x + x2),
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~I(x^2)),
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x_factor),
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x_matrix)
  )) {
    expect_error(
      mixed_lv_first_cell_preflight(formula, data = dat),
      regexp = "one untransformed numeric|lv = ~ x|single numeric"
    )
  }
})

test_that("the family-wide programme rejects every extra covariance tier", {
  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x) +
        latent(0 + trait | trait, d = 1, unique = FALSE)
    ),
    regexp = "only covariance term|extra covariance|source.*tier"
  )
})

test_that("the mixed first cell requires a complete response", {
  dat <- make_mixed_lv_first_cell_data()
  dat$value[[4L]] <- NA_real_

  expect_error(
    mixed_lv_first_cell_preflight(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = dat
    ),
    regexp = "complete response|missing response"
  )
})

test_that("the named mixed first cell constructs and reports its invariants", {
  skip_on_cran()
  dat <- make_mixed_lv_first_cell_fit_data()
  families <- list(
    continuous = stats::gaussian(),
    presence = stats::binomial(link = "logit")
  )
  attr(families, "family_var") <- "family"

  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = dat,
    unit = "unit",
    trait = "trait",
    family = families,
    weights = rep(c(1L, 20L), nrow(dat) / 2L),
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  par_list <- fit$tmb_obj$env$parList(fit$opt$par)

  expect_identical(fit$opt$convergence, 0L)
  expect_equal(sort(unique(fit$tmb_data$family_id_vec)), c(0L, 1L))
  expect_true(all(fit$tmb_data$link_id_vec == 0L))
  expect_true(all(is.finite(fit$report$B_lv_unit)))
  expect_true(all(is.finite(fit$report$Lambda_B %*% t(fit$report$Lambda_B))))
  expect_false(isTRUE(fit$use$diag_B))
  expect_equal(
    fit$report$U_B_total,
    fit$report$U_lv_mean_B + t(par_list$z_B),
    tolerance = 1e-8
  )
})

test_that("the family-wide programme admits only its frozen pure and mixed cells", {
  dat <- make_mixed_lv_first_cell_data()
  formula <- value ~ 0 + trait +
    latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x)

  for (family_id in 2:16) {
    setup <- mixed_lv_first_cell_preflight(
      formula,
      data = dat,
      family_id_vec = rep(family_id, nrow(dat)),
      link_id_vec = rep(0L, nrow(dat))
    )
    expect_true(isTRUE(setup$enabled), info = paste("pure family", family_id))
  }

  gaussian_anchor_candidates <- c(1L, 2L, 4:16)
  for (family_id in gaussian_anchor_candidates) {
    ids <- rep(c(0L, family_id), length.out = nrow(dat))
    setup <- mixed_lv_first_cell_preflight(
      formula,
      data = dat,
      family_id_vec = ids,
      link_id_vec = rep(0L, nrow(dat))
    )
    expect_true(
      isTRUE(setup$enabled),
      info = paste("Gaussian anchor family", family_id)
    )
  }

  for (link_id in 1:2) {
    ids <- rep(c(0L, 1L), length.out = nrow(dat))
    links <- ifelse(ids == 1L, link_id, 0L)
    setup <- mixed_lv_first_cell_preflight(
      formula,
      data = dat,
      family_id_vec = ids,
      link_id_vec = links
    )
    expect_true(isTRUE(setup$enabled), info = paste("binomial link", link_id))
  }

  expect_true(isTRUE(mixed_lv_first_cell_preflight(
    formula,
    data = dat,
    family_id_vec = rep(c(2L, 3L), length.out = nrow(dat)),
    link_id_vec = rep(0L, nrow(dat))
  )$enabled))
  expect_true(isTRUE(mixed_lv_first_cell_preflight(
    formula,
    data = dat,
    family_id_vec = rep(c(2L, 4L, 7L), length.out = nrow(dat)),
    link_id_vec = rep(0L, nrow(dat))
  )$enabled))

  for (ids in list(c(0L, 3L), c(0L, 1L, 2L), c(4L, 5L))) {
    expect_error(
      mixed_lv_first_cell_preflight(
        formula,
        data = dat,
        family_id_vec = rep(ids, length.out = nrow(dat)),
        link_id_vec = rep(0L, nrow(dat))
      ),
      regexp = "named|programme|gated"
    )
  }
})

test_that("traits wide data maps a named family list to the mixed LV traits", {
  skip_on_cran()
  dat <- make_mixed_lv_wide_gaussian_poisson()
  families <- list(
    gaussian = stats::gaussian(),
    poisson = stats::poisson()
  )

  fit <- fit_mixed_lv_wide_gaussian_poisson(dat, families)
  long <- data.frame(
    unit = factor(rep(dat$unit, each = 2L), levels = levels(dat$unit)),
    trait = factor(
      rep(c("gaussian", "poisson"), nrow(dat)),
      levels = c("gaussian", "poisson")
    ),
    family = factor(
      rep(c("gaussian", "poisson"), nrow(dat)),
      levels = c("gaussian", "poisson")
    ),
    x = rep(dat$x, each = 2L),
    value = as.vector(t(as.matrix(dat[c("gaussian", "poisson")]))),
    stringsAsFactors = FALSE
  )
  families_long <- families
  attr(families_long, "family_var") <- "family"
  fit_long <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = long,
    unit = "unit",
    trait = "trait",
    family = families_long,
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))

  effects <- extract_lv_effects(fit, type = "trait_effect")
  effects_long <- extract_lv_effects(fit_long, type = "trait_effect")
  expect_identical(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$family_id_vec, fit_long$tmb_data$family_id_vec)
  expect_equal(as.character(effects$trait), c("gaussian", "poisson"))
  expect_identical(as.character(effects$trait), as.character(effects_long$trait))
  expect_equal(effects$estimate, effects_long$estimate, tolerance = 1e-8)
  expect_true(all(is.finite(effects$estimate)))
})

test_that("traits auto-mapping ignores an unrelated wide family column", {
  skip_on_cran()
  dat <- make_mixed_lv_wide_gaussian_poisson()
  dat$family <- "unrelated_metadata"
  families <- list(
    gaussian = stats::gaussian(),
    poisson = stats::poisson()
  )

  fit <- fit_mixed_lv_wide_gaussian_poisson(dat, families)
  expect_equal(sort(unique(fit$tmb_data$family_id_vec)), c(0L, 2L))
})

test_that("traits preserves an explicit missing family selector error", {
  dat <- make_mixed_lv_wide_gaussian_poisson()
  families <- list(
    gaussian = stats::gaussian(),
    poisson = stats::poisson()
  )
  attr(families, "family_var") <- "misspelled_selector"

  expect_error(
    fit_mixed_lv_wide_gaussian_poisson(dat, families),
    regexp = "misspelled_selector|Mixed-family fit needs"
  )
})
