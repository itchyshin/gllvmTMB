make_lv_reml_boundary_data <- function() {
  units <- paste0("u", 1:8)
  traits <- paste0("t", 1:3)
  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        block = units[[i]],
        x = i,
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df$block <- factor(df$block, levels = units)
  df$x <- rep(as.numeric(scale(seq_along(units))), each = length(traits))
  df$value <- 0.1 * seq_len(nrow(df))
  df
}

expect_lv_reml_boundary_rejects <- function(expr, regexp) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  expect_error(
    suppressWarnings(suppressMessages(force(expr))),
    regexp = regexp
  )
}

test_that("latent lv top-level fit keeps ML and fixed-predictor boundaries loud", {
  df <- make_lv_reml_boundary_data()

  expect_lv_reml_boundary_rejects(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, lv = ~x),
      data = df,
      unit = "unit",
      trait = "trait",
      REML = TRUE,
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "REML|ML|separate derivation"
  )

  expect_lv_reml_boundary_rejects(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, lv = ~ offset(x)),
      data = df,
      unit = "unit",
      trait = "trait",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "offset|not derived"
  )

  expect_lv_reml_boundary_rejects(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, lv = ~ (1 | block)),
      data = df,
      unit = "unit",
      trait = "trait",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "random-effect|fixed unit-level predictors"
  )
})
