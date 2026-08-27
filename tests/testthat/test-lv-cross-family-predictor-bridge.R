make_lv_cross_family_bridge_data <- function(n_units = 8L) {
  units <- sprintf("u%02d", seq_len(n_units))
  traits <- c("gaussian_trait", "binomial_trait", "poisson_trait")
  x <- seq(-1, 1, length.out = n_units)
  dat <- do.call(rbind, lapply(seq_len(n_units), function(i) {
    data.frame(
      unit = units[[i]],
      trait = traits,
      family = c("g", "b", "p"),
      x = rep(x[[i]], length(traits)),
      value = c(0.2 + x[[i]], as.numeric(x[[i]] > 0), 2 + (i %% 3L)),
      stringsAsFactors = FALSE
    )
  }))
  dat$unit <- factor(dat$unit, levels = units)
  dat$trait <- factor(dat$trait, levels = traits)
  dat$family <- factor(dat$family, levels = c("g", "b", "p"))
  dat
}

prepare_lv_cross_family_bridge <- function(
    formula,
    data = make_lv_cross_family_bridge_data(),
    family_id_vec = NULL,
    link_id_vec = NULL,
    weights = NULL) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(formula)
  )
  if (is.null(family_id_vec)) {
    family_id <- c(g = 0L, b = 1L, p = 2L)
    family_id_vec <- unname(family_id[as.character(data$family)])
  }
  if (is.null(link_id_vec)) {
    link_id_vec <- rep(0L, nrow(data))
  }
  gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = parsed,
    data = data,
    trait = "trait",
    site = "unit",
    family_id_vec = family_id_vec,
    link_id_vec = link_id_vec,
    weights = weights,
    n_missing_response = 0L,
    REML = FALSE
  )
}

make_lv_registered_family_contract_data <- function(
    family_ids,
    n_units = 4L) {
  stopifnot(length(family_ids) >= 1L)
  units <- sprintf("u%02d", seq_len(n_units))
  traits <- sprintf("trait_%02d", seq_along(family_ids))
  data <- expand.grid(
    unit = units,
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  data$unit <- factor(data$unit, levels = units)
  data$trait <- factor(data$trait, levels = traits)
  x_by_unit <- setNames(seq(-1, 1, length.out = n_units), units)
  data$x <- unname(x_by_unit[as.character(data$unit)])
  data$value <- 1
  family_by_trait <- setNames(as.integer(family_ids), traits)
  list(
    data = data,
    family_id_vec = unname(family_by_trait[as.character(data$trait)])
  )
}

test_that("the existing core cross-family block admits a rank-two LV predictor", {
  setup <- prepare_lv_cross_family_bridge(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 2, unique = FALSE, lv = ~x)
  )

  expect_true(isTRUE(setup$enabled))
  expect_equal(setup$X_lv_B_names, "x")
  expect_equal(dim(setup$X_lv_B), c(8L, 1L))
})

test_that("automatic Psi rejects a rank that underidentifies the covariance decomposition", {
  expect_error(
    prepare_lv_cross_family_bridge(
      value ~ 0 + trait + latent(0 + trait | unit, d = 3, lv = ~x)
    ),
    regexp = "automatic.*Psi|identif|unique = FALSE|logical responses"
  )
})

test_that("automatic Psi admits a conservative rank-two five-response block", {
  contract <- make_lv_registered_family_contract_data(0:4)
  setup <- prepare_lv_cross_family_bridge(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, lv = ~x),
    data = contract$data,
    family_id_vec = contract$family_id_vec
  )

  expect_true(isTRUE(setup$enabled))
})

test_that("automatic Psi counts multi-trial binomial diagonal slots from weights", {
  contract <- make_lv_registered_family_contract_data(c(0L, 1L))

  expect_no_error(prepare_lv_cross_family_bridge(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
    data = contract$data,
    family_id_vec = contract$family_id_vec
  ))
  expect_error(
    prepare_lv_cross_family_bridge(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      data = contract$data,
      family_id_vec = contract$family_id_vec,
      weights = rep(2, nrow(contract$data))
    ),
    regexp = "automatic.*Psi|identif|covariance moment"
  )
})

test_that("the cross-family predictor bridge still rejects an explicit Psi companion", {
  expect_error(
    prepare_lv_cross_family_bridge(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 2, unique = FALSE, lv = ~x) +
        indep(0 + trait | unit)
    ),
    regexp = "not admitted|diagonal Psi|only covariance term|explicit"
  )
})

test_that("the loadings-only contract represents every registered family id", {
  contract <- make_lv_registered_family_contract_data(0:16)
  setup <- prepare_lv_cross_family_bridge(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 3, unique = FALSE, lv = ~x),
    data = contract$data,
    family_id_vec = contract$family_id_vec
  )

  expect_true(isTRUE(setup$enabled))
  expect_equal(setup$X_lv_B_names, "x")
})

test_that("compositional admission permits repeated family traits", {
  contract <- make_lv_registered_family_contract_data(c(0L, 2L, 2L, 4L))
  setup <- prepare_lv_cross_family_bridge(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 2, unique = FALSE, lv = ~x),
    data = contract$data,
    family_id_vec = contract$family_id_vec
  )

  expect_true(isTRUE(setup$enabled))
})

test_that("predictor-informed LV rank cannot exceed logical responses", {
  contract <- make_lv_registered_family_contract_data(c(0L, 2L, 4L))
  expect_error(
    prepare_lv_cross_family_bridge(
      value ~ 0 + trait +
        latent(0 + trait | unit, d = 4, unique = FALSE, lv = ~x),
      data = contract$data,
      family_id_vec = contract$family_id_vec
    ),
    regexp = "cannot exceed|logical responses"
  )
})
