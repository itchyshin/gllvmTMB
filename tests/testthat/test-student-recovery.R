## Tests for the Student-t response family added to the multivariate engine.
##
## DGP:  y_it = b_t + sigma * t_df(eps_it);   identity link
## Fit:  family = student() (df estimated) or student(df = 3) (df fixed)
##
## Biological motivation: heavy-tailed continuous responses with occasional
## outliers — common in trait data where measurement error has heavier tails
## than Gaussian (Lange, Little & Taylor 1989, JASA 84:881-896, robust mixed
## models; Pinheiro, Liu & Wu 2001, Comput. Stat. Data Anal. 38:367-386,
## Student-t random-effects models).

test_that("student() family converges and recovers trait intercepts + sigma + df", {
  skip_on_cran()
  set.seed(2026)
  n_ind <- 250
  Tn    <- 4
  trait_names <- letters[seq_len(Tn)]
  mu_true    <- c(0.0, 1.0, -0.5, 2.0)
  sigma_true <- 1.0
  df_true    <- 5

  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- mu_true[t] + sigma_true * stats::rt(n_ind, df = df_true)

  df_long <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df_long,
    site   = "individual",
    family = student()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 9L)

  ## Trait intercepts should match mu_true within ~0.3 (heavy-tailed noise).
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.30)

  ## Per-trait sigma and df reasonably close to truth.
  sigma_hat <- as.numeric(fit$report$sigma_student)
  df_hat    <- as.numeric(fit$report$df_student)
  expect_equal(length(sigma_hat), Tn)
  expect_equal(length(df_hat),    Tn)
  expect_true(all(df_hat > 1))   # parameter constraint
  expect_true(all(sigma_hat > 0.5 * sigma_true & sigma_hat < 2 * sigma_true))
  ## df is loosely identified for moderate samples; allow [2, 30] around 5.
  expect_true(all(df_hat > 2 & df_hat < 30))
})

test_that("student(df = 3) pins df via the TMB map", {
  skip_on_cran()
  set.seed(11)
  n_ind <- 200
  Tn    <- 2
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) y[, t] <- (t - 1) + stats::rt(n_ind, df = 3)
  df_long <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df_long, site = "individual",
    family = student(df = 3)
  )))
  expect_equal(fit$opt$convergence, 0L)
  df_hat <- as.numeric(fit$report$df_student)
  ## Pinned exactly at 3 (within numeric tolerance).
  expect_true(all(abs(df_hat - 3) < 1e-6))
})

test_that("student logLik agrees with glmmTMB::t_family() at the obs-likelihood level", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")
  ## glmmTMB exposes Student-t via family = glmmTMB::t_family() (added in
  ## glmmTMB 1.1.5+). If unavailable, skip rather than fail.
  skip_if_not(exists("t_family", envir = asNamespace("glmmTMB")),
              "glmmTMB::t_family() not available in installed glmmTMB")
  set.seed(7)
  n_ind <- 250
  Tn    <- 2
  mu_true    <- c(0.5, 1.5)
  sigma_true <- 1.0
  df_true    <- 4
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- mu_true[t] + sigma_true * stats::rt(n_ind, df = df_true)

  df_long <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = as.vector(t(y))
  )

  fit_g <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df_long, site = "individual", family = student()
  )))

  ## Per-trait glmmTMB t_family() fits with a per-individual RE.
  fit_a <- glmmTMB::glmmTMB(
    value ~ 1 + (1 | individual),
    data = df_long[df_long$trait == "a", ],
    family = glmmTMB::t_family()
  )
  fit_b <- glmmTMB::glmmTMB(
    value ~ 1 + (1 | individual),
    data = df_long[df_long$trait == "b", ],
    family = glmmTMB::t_family()
  )

  ll_gllvm   <- -fit_g$opt$objective
  ll_glmmTMB <- as.numeric(stats::logLik(fit_a)) + as.numeric(stats::logLik(fit_b))
  rel_err    <- abs(ll_gllvm - ll_glmmTMB) / abs(ll_glmmTMB)
  expect_lt(rel_err, 0.05)
})

test_that("student rejects non-identity link", {
  expect_error(
    suppressMessages(gllvmTMB(
      data.frame(individual = factor(1:10), trait = factor("a"), value = rnorm(10)),
      formula = value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      site = "individual",
      family = student(link = "log")
    )),
    regexp = "identity link"
  )
})
