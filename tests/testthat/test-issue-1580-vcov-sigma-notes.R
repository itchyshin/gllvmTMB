## #1580 remaining items: vcov() must not offer method = "profile",
## and extract_Sigma(part = "shared" / "unique") must not claim a
## link residual was added.

test_that("#1580 vcov() on se = FALSE does not offer method = profile", {
  set.seed(11L)
  d <- expand.grid(
    unit = factor(seq_len(20L)),
    trait = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  d$value <- rnorm(nrow(d))
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = d,
    trait = "trait",
    unit = "unit",
    family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  ))
  err <- tryCatch(vcov(fit), error = function(e) e)
  expect_s3_class(err, "gllvmTMB_confint_no_sdreport")
  expect_match(conditionMessage(err), "standard_errors")
  expect_false(grepl("method = \"profile\"", conditionMessage(err), fixed = TRUE))
})

test_that("#1580 extract_Sigma shared/unique do not print a residual note", {
  set.seed(12L)
  n <- 40L
  p <- 2L
  z <- rnorm(n)
  d <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  eta <- 0.4 * c(1, -0.6)[as.integer(d$trait)] * z[as.integer(d$unit)]
  d$value <- rbinom(nrow(d), 1L, plogis(eta))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  shared <- NULL
  unique_part <- NULL
  expect_no_message({
    shared <- extract_Sigma(fit, level = "unit", part = "shared")
    unique_part <- extract_Sigma(fit, level = "unit", part = "unique")
  })
  expect_false(any(grepl("link-implicit residual", shared$note, fixed = TRUE)))
  expect_false(any(grepl(
    "link-implicit residual",
    unique_part$note,
    fixed = TRUE
  )))
  total <- suppressMessages(
    extract_Sigma(fit, level = "unit", part = "total")
  )
  expect_true(any(grepl("link-implicit residual", total$note, fixed = TRUE)))
})
