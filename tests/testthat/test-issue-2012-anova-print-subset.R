test_that("print(anova) works on column-subsetted tables (refs #2012)", {
  skip_on_cran()
  set.seed(12)
  dat <- do.call(rbind, lapply(paste0("s", 1:12), function(u) {
    data.frame(unit = u, trait = rep(paste0("t", 1:4), 1), value = stats::rnorm(4))
  }))
  dat$unit <- factor(dat$unit)
  dat$trait <- factor(dat$trait)
  f1 <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat,
    unit = "unit",
    trait = "trait"
  ))
  f2 <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2),
    data = dat,
    unit = "unit",
    trait = "trait"
  ))
  av <- anova(f1, f2)
  slim <- av[, c("model", "npar", "logLik")]
  expect_s3_class(slim, "anova.gllvmTMB_multi")
  expect_output(print(slim), "Likelihood-ratio comparison")
  expect_no_error(print(slim))
})