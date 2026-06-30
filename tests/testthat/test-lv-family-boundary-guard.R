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

test_that("latent lv top-level fit keeps the binomial/ordinal boundary loud", {
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

  expect_lv_family_boundary_rejects(
    gllvmTMB(
      ord ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, lv = ~x),
      data = df,
      unit = "unit",
      trait = "trait",
      family = ordinal_probit(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "only Gaussian and pure binomial|standard links|LV-05"
  )

  family_list <- list(gaussian(), binomial(), poisson())
  attr(family_list, "family_var") <- "family"
  expect_lv_family_boundary_rejects(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, lv = ~x),
      data = df,
      unit = "unit",
      trait = "trait",
      family = family_list,
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "only Gaussian and pure binomial|standard links|LV-05"
  )
})
