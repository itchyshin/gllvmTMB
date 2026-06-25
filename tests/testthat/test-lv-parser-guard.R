make_lv_preflight_data <- function() {
  units <- paste0("u", 1:4)
  traits <- c("t1", "t2")
  df <- do.call(
    rbind,
    lapply(units, function(u) {
      data.frame(
        unit = u,
        trait = traits,
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df$obs <- factor(seq_len(nrow(df)))
  df$block <- factor(rep(c("b1", "b2"), each = 4L))
  df$value <- seq_len(nrow(df)) / 10
  df$y_bin <- rep(c(0, 1), length.out = nrow(df))
  df$x <- rep(c(-1, 0, 1, 2), each = length(traits))
  df$z <- rep(c(2, 3, 5, 7), each = length(traits))
  df$x2 <- 2 * df$x
  df$fac <- factor(rep(c("a", "b", "a", "b"), each = length(traits)))
  df$vary <- rep(c(0, 1), times = length(units))
  df
}

lv_preflight_setup <- function(
  formula,
  data = make_lv_preflight_data(),
  family_id_vec = rep(0L, nrow(data)),
  REML = FALSE
) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  f <- gllvmTMB:::desugar_brms_sugar(formula)
  p <- gllvmTMB:::parse_multi_formula(f)
  gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = p,
    data = data,
    trait = "trait",
    site = "unit",
    family_id_vec = family_id_vec,
    REML = REML
  )
}

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
  expect_s3_class(p$covstructs[[1L]]$extra$lv_formula, "formula")
  expect_null(p$covstructs[[1L]]$extra[["lv"]])
  expect_null(p$covstructs[[2L]]$extra[["lv_formula"]])
  expect_identical(
    as.character(p$covstructs[[1L]]$extra$lv_formula),
    c("~", "x")
  )
})

test_that("latent lv preflight builds unit-level no-intercept designs", {
  by_default <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
  )
  explicit_zero <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ 0 + x)
  )

  expect_true(isTRUE(by_default$enabled))
  expect_equal(by_default$X_lv_B, explicit_zero$X_lv_B)
  expect_equal(
    rownames(by_default$X_lv_B),
    levels(make_lv_preflight_data()$unit)
  )
  expect_equal(colnames(by_default$X_lv_B), "x")
  expect_equal(as.numeric(by_default$X_lv_B[, "x"]), c(-1, 0, 1, 2))
})

test_that("latent lv preflight treats factor formulas as no-intercept designs", {
  by_default <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~fac)
  )
  explicit_zero <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ 0 + fac)
  )

  expect_equal(by_default$X_lv_B, explicit_zero$X_lv_B)
  expect_equal(colnames(by_default$X_lv_B), c("faca", "facb"))
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

test_that("latent lv preflight also covers the wide traits surface", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  wide <- data.frame(
    unit = factor(paste0("u", 1:4)),
    x = c(-1, 0, 1, 2),
    t1 = c(0.1, 0.2, 0.3, 0.4),
    t2 = c(0.5, 0.6, 0.7, 0.8)
  )

  expect_error(
    gllvmTMB(
      traits(t1, t2) ~ 1 + latent(1 | unit, d = 1, lv = ~x),
      data = wide,
      unit = "unit",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "Design 73|not implemented|unit-level design columns"
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

test_that("latent lv preflight rejects malformed lv formulas", {
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~1)
    ),
    regexp = "at least one predictor|intercept-only"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~0)
    ),
    regexp = "at least one predictor|intercept-only"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = value ~ x)
    ),
    regexp = "one-sided"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ (1 | block))
    ),
    regexp = "random-effect"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ offset(x))
    ),
    regexp = "offset"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ mi(x))
    ),
    regexp = "mi"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ s(x))
    ),
    regexp = "smooth"
  )
})

test_that("latent lv preflight rejects invalid predictor columns", {
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~missing_x)
    ),
    regexp = "not found|Missing"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~value)
    ),
    regexp = "response"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~trait)
    ),
    regexp = "trait"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~vary)
    ),
    regexp = "constant within"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ x + x2)
    ),
    regexp = "rank deficient"
  )

  unused <- make_lv_preflight_data()
  unused$unit <- factor(unused$unit, levels = c(levels(unused$unit), "u5"))
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      data = unused
    ),
    regexp = "unused.*unit|u5"
  )
})

test_that("latent lv preflight rejects unsupported model regimes", {
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 1, lv = ~x)
    ),
    regexp = "fixed-effect RHS|Overlapping"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      REML = TRUE
    ),
    regexp = "REML"
  )
  expect_error(
    lv_preflight_setup(
      y_bin ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      family_id_vec = rep(1L, nrow(make_lv_preflight_data()))
    ),
    regexp = "Gaussian-only|non-Gaussian"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | obs, d = 1, lv = ~x)
    ),
    regexp = "ordinary unit-tier|W-tier"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 +
        trait +
        latent(0 + trait + (0 + trait):z | unit, d = 1, lv = ~x)
    ),
    regexp = "augmented latent random-regression|intercept-only"
  )
})

test_that("non-ordinary latent lv surfaces fail before metadata is dropped", {
  A <- diag(4)
  rownames(A) <- colnames(A) <- paste0("u", 1:4)

  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + unique(0 + trait | unit, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_unique(unit, vcv = A, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_latent(unit, d = 1, vcv = A, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + kernel_latent(unit, K = A, d = 1, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 +
        trait +
        spatial_latent(
          0 + trait | unit,
          d = 1,
          coords = c("lon", "lat"),
          lv = ~x
        )
    ),
    regexp = "ordinary|LV-07|does not support"
  )
})
