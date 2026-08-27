make_lv_family_boundary_data <- function() {
  units <- paste0("u", 1:8)
  traits <- paste0("t", 1:3)
  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        x = i,
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df$family <- factor(
    rep(c("gaussian", "binomial", "poisson"), times = length(units)),
    levels = c("gaussian", "binomial", "poisson")
  )
  df$x <- rep(as.numeric(scale(seq_along(units))), each = length(traits))
  df$success <- rep(c(0L, 1L, 0L), length.out = nrow(df))
  df$failure <- 1L - df$success
  df$ord <- rep(c(1L, 2L, 3L), length.out = nrow(df))
  df$value <- rep(c(0.2, 1, 2), times = length(units))
  df
}

expect_lv_family_boundary_rejects <- function(expr, regexp) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  expect_error(
    suppressWarnings(suppressMessages(force(expr))),
    regexp = regexp
  )
}

test_that("latent lv keeps invalid links loud and admits registered compositions", {
  df <- make_lv_family_boundary_data()

  expect_lv_family_boundary_rejects(
    gllvmTMB(
      cbind(success, failure) ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, lv = ~x),
      data = df,
      unit = "unit",
      trait = "trait",
      family = stats::binomial(link = "cauchit"),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "binomial: link|not supported|logit|probit|cloglog"
  )

  ordinal_formula <- ord ~ 0 + trait +
    latent(0 + trait | unit, d = 1, lv = ~x)
  ordinal_parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(ordinal_formula)
  )
  expect_no_error(ordinal_setup <- gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = ordinal_parsed,
    data = df,
    trait = "trait",
    site = "unit",
    family_id_vec = rep(14L, nrow(df)),
    link_id_vec = rep(0L, nrow(df)),
    REML = FALSE
  ))
  expect_true(isTRUE(ordinal_setup$enabled))

  mixed_formula <- value ~ 0 + trait +
    latent(0 + trait | unit, d = 1, lv = ~x)
  mixed_parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(mixed_formula)
  )
  mixed_ids <- c(gaussian = 0L, binomial = 1L, poisson = 2L)
  expect_no_error(mixed_setup <- gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = mixed_parsed,
    data = df,
    trait = "trait",
    site = "unit",
    family_id_vec = unname(mixed_ids[as.character(df$family)]),
    link_id_vec = rep(0L, nrow(df)),
    REML = FALSE
  ))
  expect_true(isTRUE(mixed_setup$enabled))
})
