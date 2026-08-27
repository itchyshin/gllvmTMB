make_lv_native_nongaussian_guard_data <- function(kind) {
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
  df$x <- rep(as.numeric(scale(seq_along(units))), each = length(traits))
  df$value <- switch(
    kind,
    poisson = rep(c(1, 2, 3), length.out = nrow(df)),
    nbinom1 = rep(c(1, 2, 4), length.out = nrow(df)),
    nbinom2 = rep(c(1, 2, 4), length.out = nrow(df)),
    lognormal = rep(c(0.8, 1.1, 1.5), length.out = nrow(df)),
    gamma = rep(c(0.8, 1.1, 1.5), length.out = nrow(df)),
    beta = rep(c(0.25, 0.55, 0.75), length.out = nrow(df)),
    tweedie = rep(c(0.8, 1.1, 1.5), length.out = nrow(df)),
    student = seq_len(nrow(df)) / 10,
    truncated_poisson = rep(c(1, 2, 3), length.out = nrow(df)),
    truncated_nbinom2 = rep(c(1, 2, 4), length.out = nrow(df)),
    betabinomial = rep(c(1, 2, 3), length.out = nrow(df)),
    delta_lognormal = rep(c(0, 0.8, 1.3), length.out = nrow(df)),
    delta_gamma = rep(c(0, 0.8, 1.3), length.out = nrow(df)),
    stop("Unknown guard fixture kind: ", kind)
  )
  df$failure <- 4L - as.integer(round(df$value))
  df
}

expect_native_nongaussian_lv_admitted <- function(
  kind,
  family_id,
  response = "value"
) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  formula <- stats::as.formula(paste(
    response,
    "~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)"
  ))
  data <- make_lv_native_nongaussian_guard_data(kind)
  parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(formula)
  )
  expect_no_error(
    setup <- gllvmTMB:::gll_prepare_lv_predictor_setup(
      parsed = parsed,
      data = data,
      trait = "trait",
      site = "unit",
      family_id_vec = rep(as.integer(family_id), nrow(data)),
      link_id_vec = rep(0L, nrow(data)),
      REML = FALSE
    )
  )
  expect_true(isTRUE(setup$enabled), info = kind)
}

test_that("family-wide native lv admits default Psi for registered families", {
  cases <- list(
    poisson = list(id = 2L),
    nbinom1 = list(id = 15L),
    nbinom2 = list(id = 5L),
    lognormal = list(id = 3L),
    gamma = list(id = 4L),
    beta = list(id = 7L),
    tweedie = list(id = 6L),
    student = list(id = 9L),
    truncated_poisson = list(id = 10L),
    truncated_nbinom2 = list(id = 11L),
    betabinomial = list(id = 8L, response = "cbind(value, failure)"),
    delta_lognormal = list(id = 12L),
    delta_gamma = list(id = 13L)
  )

  for (kind in names(cases)) {
    case <- cases[[kind]]
    expect_native_nongaussian_lv_admitted(
      kind,
      case$id,
      response = case$response %||% "value"
    )
  }
})
