## #1783 follow-up: screen_gllvmTMB() must record class gllvmTMB_one_level_factor
## when a fixed-effect factor has one level, without aborting. On main the design
## table stores the bare contrasts string under NOT_CHECKED and no classed warning.

.one_trait_1783_screen <- function() {
  set.seed(1)
  d <- expand.grid(
    unit = factor(1:12),
    trait = factor(paste0("t", 1:3)),
    KEEP.OUT.ATTRS = FALSE
  )
  d$y <- stats::rbinom(nrow(d), size = 1, prob = 0.5)
  d1 <- d[d$trait == "t1", ]
  d1$trait <- factor(d1$trait)
  list(d = d, d1 = d1)
}

test_that("#1783 screen records gllvmTMB_one_level_factor for one-level 0 + trait", {
  d1 <- .one_trait_1783_screen()$d1
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  scr <- NULL
  expect_warning(
    scr <- screen_gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = d1,
      trait = "trait",
      unit = "unit",
      family = binomial()
    ),
    "trait",
    class = "gllvmTMB_one_level_factor"
  )
  expect_s3_class(scr, "gllvmTMB_screen")
  design <- screen_table(scr, "design")
  fe <- design[design$component == "fixed_effect_design", , drop = FALSE]
  expect_equal(fe$status, "FAIL")
  expect_equal(fe$severity, "one_level_factor")
  expect_match(fe$message, "two levels")
})

test_that("#1783 screen still checks a two-level 0 + trait fixed design", {
  dat <- .one_trait_1783_screen()$d
  dat <- dat[dat$trait != "t3", ]
  dat$trait <- factor(dat$trait)
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  scr <- suppressWarnings(screen_gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat,
    trait = "trait",
    unit = "unit",
    family = binomial()
  ))
  design <- screen_table(scr, "design")
  fe <- design[design$component == "fixed_effect_rank", , drop = FALSE]
  expect_equal(fe$status, "PASS")
  expect_equal(fe$severity, "none")
})
