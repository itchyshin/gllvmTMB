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

prepare_lv_cross_family_bridge <- function(formula, data = make_lv_cross_family_bridge_data()) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(formula)
  )
  family_id <- c(g = 0L, b = 1L, p = 2L)
  family_id_vec <- unname(family_id[as.character(data$family)])
  gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = parsed,
    data = data,
    trait = "trait",
    site = "unit",
    family_id_vec = family_id_vec,
    link_id_vec = rep(0L, nrow(data)),
    n_missing_response = 0L,
    REML = FALSE
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

test_that("the existing core cross-family block admits rank three with auto Psi", {
  setup <- prepare_lv_cross_family_bridge(
    value ~ 0 + trait + latent(0 + trait | unit, d = 3, lv = ~x)
  )

  expect_true(isTRUE(setup$enabled))
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
