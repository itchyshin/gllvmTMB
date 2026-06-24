test_that("latent lv metadata is preserved until the runtime guard", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  f <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
  )
  p <- gllvmTMB:::parse_multi_formula(f)
  expect_equal(
    vapply(p$covstructs, `[[`, character(1), "kind"),
    c("rr", "diag")
  )
  expect_s3_class(p$covstructs[[1L]]$extra$lv, "formula")
  expect_identical(as.character(p$covstructs[[1L]]$extra$lv), c("~", "x"))
})

test_that("latent lv errors before fit implementation", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  df <- expand.grid(
    unit = paste0("u", 1:3),
    trait = paste0("t", 1:2),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- seq_len(nrow(df)) / 10
  df$x <- rep(c(0, 1, 2), each = 2)

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      data = df,
      unit = "unit",
      trait = "trait",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "Design 73|not implemented|FG-18|RE-13|LV-01"
  )
})

test_that("latent lv guard also covers the loadings-only subset", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  df <- expand.grid(
    unit = paste0("u", 1:3),
    trait = paste0("t", 1:2),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- stats::rnorm(nrow(df))
  df$x <- rep(c(0, 1, 2), each = 2)

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = df,
      unit = "unit",
      trait = "trait",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "Design 73|not implemented|FG-18|RE-13|LV-01"
  )
})
