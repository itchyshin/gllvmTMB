# Stage 13: tidy() and predict() methods.

test_that("tidy(fixed) returns a coefficient table with SEs and a link column", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(1.0, 0.7, -0.3,
                        0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2),
    data = sim$data
  )
  tf <- tidy(fit, "fixed", conf.int = TRUE)
  expect_s3_class(tf, "data.frame")
  expect_true(all(c("term", "estimate", "std.error", "link",
                    "conf.low", "conf.high") %in% names(tf)))
  expect_equal(length(unique(tf$term)), nrow(tf))   # unique terms
  expect_true(all(tf$std.error > 0))
  ## Single-family Gaussian fit -> all rows on the identity link.
  expect_true(all(tf$link == "identity"))
})

test_that("tidy(fixed) link column reports per-trait link in mixed-family fits", {
  skip_on_cran()
  set.seed(11)
  sim <- simulate_site_trait(n_sites = 20, n_species = 3, n_traits = 3,
                             mean_species_per_site = 4,
                             Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
                             seed = 11)
  ## Replace columns to match families (gaussian / binomial / poisson).
  sim$data$value[sim$data$trait == "trait_2"] <-
    as.numeric(rbinom(sum(sim$data$trait == "trait_2"), 1, 0.4))
  sim$data$value[sim$data$trait == "trait_3"] <-
    as.numeric(rpois(sum(sim$data$trait == "trait_3"), 2))
  sim$data$family <- factor(c("gaussian", "binomial", "poisson")[
    as.integer(sim$data$trait)],
    levels = c("gaussian", "binomial", "poisson"))
  fams <- list(gaussian(), binomial(), poisson())
  attr(fams, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + indep(0 + trait | site),
    data   = sim$data,
    family = fams
  )))
  tf <- tidy(fit, "fixed")
  expect_true("link" %in% names(tf))
  ## Each row's link reflects its trait: identity for trait_1, logit for
  ## trait_2 (binomial default link), log for trait_3 (poisson).
  expect_equal(tf$link[grepl("trait_1", tf$term)],
               rep("identity", sum(grepl("trait_1", tf$term))))
  expect_equal(tf$link[grepl("trait_2", tf$term)],
               rep("logit", sum(grepl("trait_2", tf$term))))
  expect_equal(tf$link[grepl("trait_3", tf$term)],
               rep("log", sum(grepl("trait_3", tf$term))))
})

test_that("print(fit) annotates per-trait link in mixed-family fits", {
  skip_on_cran()
  set.seed(11)
  sim <- simulate_site_trait(n_sites = 20, n_species = 3, n_traits = 3,
                             mean_species_per_site = 4,
                             Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
                             seed = 11)
  sim$data$value[sim$data$trait == "trait_2"] <-
    as.numeric(rbinom(sum(sim$data$trait == "trait_2"), 1, 0.4))
  sim$data$value[sim$data$trait == "trait_3"] <-
    as.numeric(rpois(sum(sim$data$trait == "trait_3"), 2))
  sim$data$family <- factor(c("gaussian", "binomial", "poisson")[
    as.integer(sim$data$trait)],
    levels = c("gaussian", "binomial", "poisson"))
  fams <- list(gaussian(), binomial(), poisson())
  attr(fams, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + indep(0 + trait | site),
    data   = sim$data,
    family = fams
  )))
  out <- capture.output(print(fit))
  expect_true(any(grepl("Per-trait link", out)))
  expect_true(any(grepl("logit",   out)))
  expect_true(any(grepl("log",     out)))
  expect_true(any(grepl("identity", out)))
})

test_that("tidy(cutpoint) returns ordinal_probit thresholds, not ran_pars", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 200L
  Tn    <- 2L
  trait_names <- c("a", "b")
  true_intercept <- c(0.3, -0.1)
  ystar <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    ystar[, t] <- stats::rnorm(n_ind, mean = true_intercept[t], sd = 1)
  y_a <- 1L + (ystar[, 1] > 0) + (ystar[, 1] > 0.7) + (ystar[, 1] > 1.4)
  y_b <- 1L + (ystar[, 2] > 0) + (ystar[, 2] > 0.5)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = c(t(cbind(y_a, y_b)))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | individual),
    data   = df,
    unit   = "individual",
    family = ordinal_probit()
  )))
  ## tidy(fit, "cutpoint") returns a dedicated effect class.
  cuts <- tidy(fit, "cutpoint")
  expect_s3_class(cuts, "data.frame")
  expect_true(all(c("term", "estimate") %in% names(cuts)))
  expect_true(any(grepl("^ordinal_cutpoint\\[", cuts$term)))
  ## tidy(fit, "ran_pars") no longer carries the cutpoints.
  rp <- tidy(fit, "ran_pars")
  expect_false(any(grepl("^ordinal_cutpoint\\[", rp$term)))
})

test_that("tidy(cutpoint) is empty for fits with no ordinal_probit traits", {
  set.seed(7)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  cuts <- tidy(fit, "cutpoint")
  expect_s3_class(cuts, "data.frame")
  expect_equal(nrow(cuts), 0L)
})

test_that("tidy(ran_pars) returns rows for active covstructs", {
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(1.0, 0.7, -0.3,
                        0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 7
  )
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2),
    data = sim$data
  )
  tr <- tidy(fit, "ran_pars")
  expect_true(any(grepl("^sd_diag_B\\[", tr$term)))
  expect_true(any(grepl("^sd_global\\[", tr$term)))
  expect_true(all(tr$estimate > 0 | grepl("^loglambda", tr$term)))
})

test_that("predict() returns one row per training observation", {
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    seed = 11
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  pf <- predict(fit)
  expect_s3_class(pf, "data.frame")
  expect_equal(nrow(pf), nrow(sim$data))
  expect_true(all(c("site", "species", "trait", "est") %in% names(pf)))
})

test_that("predict(type = 'response') uses per-trait inverse links", {
  skip_on_cran()
  set.seed(29)
  sim <- simulate_site_trait(
    n_sites = 20, n_species = 3, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3), 3, 1),
    seed = 29
  )
  sim$data$value[sim$data$trait == "trait_2"] <-
    as.numeric(rbinom(sum(sim$data$trait == "trait_2"), 1, 0.35))
  sim$data$value[sim$data$trait == "trait_3"] <-
    as.numeric(rpois(sum(sim$data$trait == "trait_3"), 1.8))
  sim$data$family <- factor(
    c("gaussian", "binomial", "poisson")[as.integer(sim$data$trait)],
    levels = c("gaussian", "binomial", "poisson")
  )
  fams <- list(gaussian(), binomial(), poisson())
  attr(fams, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + indep(0 + trait | site),
    data = sim$data,
    family = fams
  )))

  link <- predict(fit, type = "link")
  resp <- suppressMessages(predict(fit, type = "response"))
  expect_equal(nrow(link), nrow(resp))
  expect_equal(link$est, as.numeric(fit$report$eta), tolerance = 1e-8)

  tr <- as.character(link[[fit$trait_col]])
  expected <- link$est
  expected[tr == "trait_2"] <- plogis(expected[tr == "trait_2"])
  expected[tr == "trait_3"] <- exp(expected[tr == "trait_3"])
  expect_equal(resp$est, expected, tolerance = 1e-8)
  expect_gt(min(resp$est[tr == "trait_2"]), 0)
  expect_lt(max(resp$est[tr == "trait_2"]), 1)
  expect_gte(min(resp$est[tr == "trait_3"]), 0)

  nd <- sim$data[c(1L, 2L, 3L), ]
  new_link <- predict(fit, newdata = nd, type = "link", re_form = ~0)
  new_resp <- predict(fit, newdata = nd, type = "response", re_form = ~0)
  new_tr <- as.character(new_link[[fit$trait_col]])
  new_expected <- new_link$est
  new_expected[new_tr == "trait_2"] <- plogis(new_expected[new_tr == "trait_2"])
  new_expected[new_tr == "trait_3"] <- exp(new_expected[new_tr == "trait_3"])
  expect_equal(new_resp$est, new_expected, tolerance = 1e-8)
})

test_that("predict(newdata) emits a notice about random-effect handling", {
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    seed = 13
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  ## After Stage 19 the default re_form = ~ . adds RE contributions for
  ## levels that match training factors and emits a notice describing
  ## that. Just verify that *some* informational message is emitted.
  testthat::expect_message(
    pn <- predict(fit, newdata = head(sim$data, 4)),
    regexp = "Random"
  )
  expect_equal(nrow(pn), 4)
  expect_true(is.numeric(pn$est))
})

test_that("predict(newdata) aligns fixed-effect columns by training names", {
  train <- expand.grid(
    site = factor(paste0("s", 1:2)),
    species = factor("sp1"),
    trait = factor(c("t1", "t2"), levels = c("t1", "t2")),
    habitat = factor(c("A", "B", "C"), levels = c("A", "B", "C")),
    KEEP.OUT.ATTRS = FALSE
  )
  train$value <- 0
  form <- value ~ 0 + trait + trait:habitat
  X_train <- stats::model.matrix(form, train)
  beta <- seq_along(colnames(X_train))
  names(beta) <- colnames(X_train)
  fit <- structure(
    list(
      data = train,
      formula = form,
      trait_col = "trait",
      unit_col = "site",
      species_col = "species",
      X_fix_names = colnames(X_train),
      opt = list(par = stats::setNames(unname(beta), rep("b_fix", length(beta)))),
      use = list()
    ),
    class = "gllvmTMB_multi"
  )

  nd <- data.frame(
    value = 0,
    site = c("s1", "s2"),
    species = "sp1",
    trait = c("t1", "t2"),
    habitat = c("B", "C")
  )
  pred <- predict(fit, newdata = nd, re_form = ~0)

  nd_ref <- nd
  nd_ref$site <- factor(nd_ref$site, levels = levels(train$site))
  nd_ref$species <- factor(nd_ref$species, levels = levels(train$species))
  nd_ref$trait <- factor(nd_ref$trait, levels = levels(train$trait))
  nd_ref$habitat <- factor(nd_ref$habitat, levels = levels(train$habitat))
  X_ref <- stats::model.matrix(form, nd_ref)
  expected <- as.numeric(X_ref %*% beta[colnames(X_ref)])

  expect_equal(pred$est, expected)
  expect_equal(
    pred$est[1],
    beta[["traitt1"]] + beta[["traitt1:habitatB"]]
  )
  pred_new_site <- predict(
    fit,
    newdata = transform(nd, site = c("s-new-1", "s-new-2")),
    re_form = ~0
  )
  expect_equal(pred_new_site$est, expected)
  expect_error(
    predict(
      fit,
      newdata = transform(nd, habitat = c("B", "D")),
      re_form = ~0
    ),
    "unseen level"
  )
})
