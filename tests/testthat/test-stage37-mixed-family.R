# Stage 37: per-row mixed response families.
# Same package call can fit Gaussian + binomial + Poisson rows in one shot
# by passing family = list(gaussian(), binomial(), poisson()) plus a
# family_var column in data that picks family per row.

test_that("Stage 37: family = list(...) locks row-aligned mixed-family oracle", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(1, 0.7, -0.3, 0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2025
  )
  df <- sim$data
  df$family <- factor(with(df, ifelse(trait == "trait_1", "g",
                                ifelse(trait == "trait_2", "b", "p"))),
                       levels = c("g", "b", "p"))
  df$value[df$family == "b"] <- as.integer(df$value[df$family == "b"] > 0)
  df$value[df$family == "p"] <- pmax(0L,
                                     as.integer(round(df$value[df$family == "p"] + 1)))

  ## Named lists are deliberately out of order: the fit should resolve by
  ## selector level, not by accidental list position.
  family_list <- list(p = poisson(), g = gaussian(), b = binomial())
  attr(family_list, "family_var") <- "family"

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df,
    family = family_list,
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(as.numeric(logLik(fit))))
  ## family_id_vec assigns 0 = Gaussian, 1 = binomial, 2 = Poisson rows.
  fid <- fit$tmb_data$family_id_vec
  expect_equal(sum(fid == 0L), sum(df$family == "g"))
  expect_equal(sum(fid == 1L), sum(df$family == "b"))
  expect_equal(sum(fid == 2L), sum(df$family == "p"))

  selector <- fit$family_selector
  expect_type(selector, "list")
  expect_equal(selector$family_var, "family")
  expect_equal(selector$levels, c("g", "b", "p"))
  expect_true(selector$list_names_matched)
  expect_equal(selector$family_names, c("g", "b", "p"))
  expect_equal(unname(selector$family_id_by_level), c(0L, 1L, 2L))
  expect_equal(unname(selector$link_id_by_level), c(0L, 0L, 0L))
  expect_equal(selector$row_index, as.integer(df$family))
  expect_equal(selector$row_level, as.character(df$family))
  expect_equal(
    fit$tmb_data$family_id_vec,
    unname(selector$family_id_by_level)[selector$row_index]
  )
  expect_equal(
    fit$tmb_data$link_id_vec,
    unname(selector$link_id_by_level)[selector$row_index]
  )
  expect_equal(fit$tmb_data$trait_id, as.integer(df$trait) - 1L)
  expect_identical(names(fit$family_input), c("p", "g", "b"))
  expect_identical(attr(fit$family_input, "family_var"), "family")

  sm <- summary(fit)
  expect_equal(sm$fixef$link, c("identity", "logit", "log"))

  pred <- predict(fit, type = "response")
  expect_equal(nrow(pred), nrow(fit$data))
  expect_true(all(is.finite(pred$est)))
  expect_true(all(pred$est[pred$trait == "trait_2"] >= 0))
  expect_true(all(pred$est[pred$trait == "trait_2"] <= 1))
  expect_true(all(pred$est[pred$trait == "trait_3"] >= 0))

  sim_y <- simulate(
    fit,
    nsim = 2L,
    seed = 20260615L,
    condition_on_RE = TRUE
  )
  expect_equal(dim(sim_y), c(nrow(fit$data), 2L))
  expect_true(all(is.finite(sim_y)))
  expect_true(all(sim_y[selector$row_level == "b", ] %in% c(0, 1)))
  expect_true(all(sim_y[selector$row_level == "p", ] >= 0))
  expect_true(all(sim_y[selector$row_level == "p", ] == floor(sim_y[selector$row_level == "p", ])))
})

test_that("Stage 37: named mixed-family list must match selector levels", {
  df <- data.frame(
    site = factor(rep(seq_len(4L), each = 3L)),
    trait = factor(rep(c("trait_1", "trait_2", "trait_3"), times = 4L)),
    family = factor(rep(c("g", "b", "p"), times = 4L), levels = c("g", "b", "p")),
    value = c(0.1, 1, 2, 0.2, 0, 1, 0.3, 1, 3, 0.4, 0, 2)
  )
  bad <- list(g = gaussian(), b = binomial(), count = poisson())
  attr(bad, "family_var") <- "family"

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = df,
      family = bad,
      control = gllvmTMBcontrol(se = FALSE),
      silent = TRUE
    ),
    "must match levels"
  )
})

test_that("Stage 37: scalar family still works (backward compatible)", {
  set.seed(7)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4, seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data,
    family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(all(fit$tmb_data$family_id_vec == 0L))
})
