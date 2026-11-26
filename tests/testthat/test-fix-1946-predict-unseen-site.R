## #1946: all-unseen unit (site) levels must not claim rr_B/diag_B were re-added,
## must warn that those rows are population-level, and must echo the user's site
## labels in the returned data frame.

test_that("all-unseen site levels: truthful message, echoed site, FE-only preds (#1946)", {
  set.seed(1126L)
  sim <- simulate_unit_trait(
    n_units = 20L, n_obs_per_unit = 1L, n_traits = 2L,
    Lambda_B = matrix(c(0.7, 0.4), ncol = 1L),
    psi_B = c(0.2, 0.2), seed = 1126L
  )
  dat <- sim$data
  colnames(dat)[colnames(dat) == "unit"] <- "site"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1L),
    data = dat,
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, laplace_auto_refit = FALSE),
    silent = TRUE
  )))
  newdata <- data.frame(
    site = c("NEW1", "NEW2"),
    trait = c("trait_1", "trait_2"),
    stringsAsFactors = FALSE
  )
  msgs <- paste(
    capture_messages(predict(fit, newdata = newdata, type = "link")),
    collapse = " "
  )
  expect_false(grepl("re-added", msgs, fixed = TRUE))
  expect_true(grepl("unseen", msgs, ignore.case = TRUE))
  expect_true(grepl("population-level", msgs, fixed = TRUE))

  pred <- suppressMessages(predict(fit, newdata = newdata, type = "link"))
  pred_fx <- predict(fit, newdata = newdata, type = "link", re_form = ~0)
  expect_equal(as.character(pred$site), c("NEW1", "NEW2"))
  expect_equal(pred$est, pred_fx$est)
})