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

expect_native_nongaussian_lv_rejects <- function(
  kind,
  family,
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
  expect_error(
    suppressWarnings(gllvmTMB(
      formula,
      data = make_lv_native_nongaussian_guard_data(kind),
      unit = "unit",
      trait = "trait",
      family = family,
      control = gllvmTMBcontrol(se = FALSE)
    )),
    regexp = "only Gaussian and pure binomial|LV-05|non-Gaussian",
    info = kind
  )
}

test_that("native TMB latent lv rejects non-binomial non-Gaussian families", {
  ## The Julia bridge has narrow point routes for some non-Gaussian X_lv rows,
  ## but native TMB C1 support remains Gaussian plus pure binomial standard
  ## links. These top-level fit calls protect that claim boundary.
  cases <- list(
    poisson = stats::poisson(),
    nbinom1 = nbinom1(),
    nbinom2 = nbinom2(),
    lognormal = lognormal(),
    gamma = stats::Gamma(link = "log"),
    beta = Beta(),
    tweedie = tweedie(),
    student = suppressMessages(student(df = 3)),
    truncated_poisson = truncated_poisson(),
    truncated_nbinom2 = truncated_nbinom2(),
    betabinomial = list(
      family = betabinomial(),
      response = "cbind(value, failure)"
    ),
    delta_lognormal = delta_lognormal(),
    delta_gamma = delta_gamma()
  )

  for (kind in names(cases)) {
    case <- cases[[kind]]
    if (inherits(case, "family")) {
      case <- list(family = case)
    }
    expect_native_nongaussian_lv_rejects(
      kind,
      case$family,
      response = case$response %||% "value"
    )
  }
})
