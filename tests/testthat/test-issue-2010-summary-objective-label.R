## Issue #2010: print(summary()) must match print() on penalised MAP objective label.

test_that("print(summary) uses Unpenalised log L label for penalised MAP fits", {
  skip_on_cran()
  set.seed(11270427L)
  dat <- do.call(rbind, lapply(paste0("s", 1:10), function(u) {
    data.frame(
      unit = u,
      trait = rep(c("t1", "t2"), each = 1L),
      value = stats::rnorm(2L)
    )
  }))
  dat$unit <- factor(dat$unit)
  dat$trait <- factor(dat$trait)
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat,
    unit = "unit",
    family = gaussian(),
    control = gllvmTMBcontrol(aghq_ridge = 2, se = FALSE)
  ))
  expect_identical(summary(fit)$header$objective_label, "Unpenalised log L at MAP point")

  print_fit <- utils::capture.output(print(fit))
  print_sum <- utils::capture.output(print(summary(fit)))
  fit_line <- grep("log L", print_fit, value = TRUE)[1L]
  sum_line <- grep("log L", print_sum, value = TRUE)[1L]
  expect_match(fit_line, "Unpenalised log L at MAP point")
  expect_match(sum_line, "Unpenalised log L at MAP point")
  expect_no_match(sum_line, "ML log L at MAP point")
})