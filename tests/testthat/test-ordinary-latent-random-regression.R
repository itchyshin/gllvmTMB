## Ordinary individual-level latent random regression.
##
## Symbolic alignment:
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth value |
## | --- | --- | --- | --- | --- |
## | b_i = Lambda_aug z_i | latent(0 + trait + (0 + trait):x | individual, d=K) | z_i ~ N(0,I), Lambda_aug fixed | extract_Sigma(level="unit_slope", part="shared") | Lambda_aug Lambda_aug^T |
## | q_i | unique(0 + trait + (0 + trait):x | individual) | q_i ~ N(0, diag(psi_aug)) | extract_Sigma(level="unit_slope", part="unique") | psi_aug |
## | beta_t x_ij | fixed (0 + trait):x | deterministic trait slopes | model matrix / fitted eta | beta_t |
## | e_ijt | Gaussian residual | rnorm(sd=sigma_eps) | fit$report$sigma_eps | sigma_eps |

make_ordinary_latent_rr_fixture <- function(
  seed = 9101L,
  n_ind = 14L,
  n_traits = 3L,
  n_rep = 3L
) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(n_traits))
  individuals <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(individuals, levels = individuals),
    rep = seq_len(n_rep),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sessions <- unique(df[c("individual", "rep", "session_id")])
  sessions$temperature <- stats::rnorm(nrow(sessions))
  df <- merge(
    df,
    sessions,
    by = c("individual", "rep", "session_id"),
    sort = FALSE
  )

  alpha <- c(0.2, -0.1, 0.05)[seq_len(n_traits)]
  beta <- c(0.3, -0.2, 0.1)[seq_len(n_traits)]
  Lambda_aug <- matrix(
    c(
      0.45,
      0.00,
      0.18,
      0.25,
      -0.30,
      0.00,
      0.10,
      -0.18,
      0.35,
      0.00,
      -0.08,
      0.20
    )[seq_len(2L * n_traits * 2L)],
    nrow = 2L * n_traits,
    ncol = 2L,
    byrow = TRUE
  )
  z <- matrix(stats::rnorm(2L * n_ind), nrow = 2L)
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    tt <- as.integer(df$trait[o])
    ii <- as.integer(df$individual[o])
    base <- 2L * (tt - 1L)
    coeff <- Lambda_aug %*% z[, ii]
    eta[o] <- alpha[tt] +
      beta[tt] * df$temperature[o] +
      coeff[base + 1L] +
      coeff[base + 2L] * df$temperature[o]
  }
  df$value <- eta + stats::rnorm(nrow(df), sd = 0.35)

  wide <- reshape(
    df[c("individual", "rep", "session_id", "temperature", "trait", "value")],
    idvar = c("individual", "rep", "session_id", "temperature"),
    timevar = "trait",
    direction = "wide"
  )
  names(wide) <- sub("^value\\.", "", names(wide))
  rownames(wide) <- NULL

  list(data = df, wide = wide, n_traits = n_traits)
}

test_that("ordinary latent augmented LHS is classified for long and wide forms", {
  withr::local_options(lifecycle_verbosity = "quiet")

  wide_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + latent(1 + temperature | individual, d = 2)
  )
  wide <- gllvmTMB:::parse_multi_formula(wide_formula)$covstructs[[1L]]
  expect_identical(wide$kind, "rr")
  expect_true(isTRUE(wide$extra$.latent_augmented))
  expect_identical(wide$extra$lhs_form, "wide_intercept_slope")
  expect_identical(wide$extra$slope_col, "temperature")

  long_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 +
      trait +
      latent(0 + trait + (0 + trait):temperature | individual, d = 2)
  )
  long <- gllvmTMB:::parse_multi_formula(long_formula)$covstructs[[1L]]
  expect_identical(long$kind, "rr")
  expect_true(isTRUE(long$extra$.latent_augmented))
  expect_identical(long$extra$lhs_form, "long_intercept_slope")
  expect_identical(long$extra$slope_col, "temperature")

  unique_wide_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + unique(1 + temperature | individual)
  )
  unique_wide <- gllvmTMB:::parse_multi_formula(
    unique_wide_formula
  )$covstructs[[1L]]
  expect_identical(unique_wide$kind, "diag")
  expect_true(isTRUE(unique_wide$extra$.unique_augmented))
  expect_identical(unique_wide$extra$lhs_form, "wide_intercept_slope")
  expect_identical(unique_wide$extra$slope_col, "temperature")

  unique_long_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + unique(0 + trait + (0 + trait):temperature | individual)
  )
  unique_long <- gllvmTMB:::parse_multi_formula(
    unique_long_formula
  )$covstructs[[1L]]
  expect_identical(unique_long$kind, "diag")
  expect_true(isTRUE(unique_long$extra$.unique_augmented))
  expect_identical(unique_long$extra$lhs_form, "long_intercept_slope")
  expect_identical(unique_long$extra$slope_col, "temperature")
})

test_that("ordinary latent random-regression fit builds augmented B-tier covariance", {
  testthat::skip_on_cran()
  fx <- make_ordinary_latent_rr_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 2),
    data = fx$data,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_rr_B_slope, 1L)
  expect_identical(fit$tmb_data$use_diag_B_slope, 1L)
  expect_true(isTRUE(fit$use$diag_B_slope_default))
  expect_equal(dim(fit$tmb_data$Z_B_lat), c(nrow(fx$data), 2L * fx$n_traits))
  expect_equal(dim(fit$tmb_data$Z_B_diag), c(nrow(fx$data), 2L * fx$n_traits))
  expect_equal(dim(fit$report$Lambda_B_slope), c(2L * fx$n_traits, 2L))
  expect_equal(
    dim(fit$report$Sigma_B_slope),
    c(2L * fx$n_traits, 2L * fx$n_traits)
  )
  expect_true(any(names(fit$tmb_obj$env$last.par.best) == "z_B_slope"))
  expect_true(any(names(fit$tmb_obj$env$last.par.best) == "s_B_slope"))

  rows_t1 <- which(fx$data$trait == "t1")
  expect_equal(fit$tmb_data$Z_B_lat[rows_t1, 1L], rep(1, length(rows_t1)))
  expect_equal(fit$tmb_data$Z_B_lat[rows_t1, 2L], fx$data$temperature[rows_t1])
  expect_true(all(fit$tmb_data$Z_B_lat[rows_t1, -(1:2), drop = FALSE] == 0))

  Sigma <- extract_Sigma(fit, level = "unit_slope")
  shared <- extract_Sigma(fit, level = "unit_slope", part = "shared")$Sigma
  unique <- extract_Sigma(fit, level = "unit_slope", part = "unique")$s
  expect_equal(dim(Sigma$Sigma), c(2L * fx$n_traits, 2L * fx$n_traits))
  expect_equal(
    Sigma$Sigma,
    shared + diag(unique, nrow = length(unique)),
    tolerance = 1e-8
  )
  expect_identical(
    rownames(Sigma$Sigma),
    c(
      "intercept.t1",
      "slope.temperature.t1",
      "intercept.t2",
      "slope.temperature.t2",
      "intercept.t3",
      "slope.temperature.t3"
    )
  )
})

test_that("ordinary latent plus unique random-regression fit composes augmented covariance", {
  testthat::skip_on_cran()
  fx <- make_ordinary_latent_rr_fixture(seed = 9112L, n_ind = 18L, n_rep = 4L)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 1) +
      unique(0 + trait + (0 + trait):temperature | individual),
    data = fx$data,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_rr_B_slope, 1L)
  expect_identical(fit$tmb_data$use_diag_B_slope, 1L)
  expect_equal(dim(fit$tmb_data$Z_B_diag), c(nrow(fx$data), 2L * fx$n_traits))
  expect_equal(length(as.numeric(fit$report$sd_B_slope)), 2L * fx$n_traits)
  expect_true(any(names(fit$tmb_obj$env$last.par.best) == "s_B_slope"))

  shared <- extract_Sigma(fit, level = "unit_slope", part = "shared")$Sigma
  unique <- extract_Sigma(fit, level = "unit_slope", part = "unique")$s
  total <- extract_Sigma(fit, level = "unit_slope", part = "total")$Sigma

  expect_equal(
    total,
    shared + diag(unique, nrow = length(unique)),
    tolerance = 1e-8
  )
  expect_equal(
    unname(diag(total) - diag(shared)),
    unname(unique),
    tolerance = 1e-8
  )
  expect_equal(
    total[row(total) != col(total)],
    shared[row(shared) != col(shared)],
    tolerance = 1e-8
  )
})

test_that("ordinary Gaussian latent random regression recovers default augmented covariance", {
  testthat::skip_on_cran()
  set.seed(9121L)
  n_ind <- 48L
  n_traits <- 2L
  n_rep <- 6L
  trait_levels <- paste0("t", seq_len(n_traits))
  individuals <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(individuals, levels = individuals),
    rep = seq_len(n_rep),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sessions <- unique(df[c("individual", "rep", "session_id")])
  sessions$temperature <- stats::rnorm(nrow(sessions))
  df <- merge(
    df,
    sessions,
    by = c("individual", "rep", "session_id"),
    sort = FALSE
  )

  alpha <- c(0.2, -0.1)
  beta <- c(0.12, -0.10)
  Lambda_aug <- matrix(c(0.40, 0.18, -0.22, 0.10), ncol = 1L)
  sd_aug <- c(0.30, 0.18, 0.20, 0.12)
  z <- stats::rnorm(n_ind)
  q <- matrix(
    stats::rnorm(2L * n_traits * n_ind, sd = rep(sd_aug, n_ind)),
    nrow = 2L * n_traits,
    ncol = n_ind
  )
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    tt <- as.integer(df$trait[o])
    ii <- as.integer(df$individual[o])
    base <- 2L * (tt - 1L)
    coeff <- Lambda_aug[, 1L] * z[ii] + q[, ii]
    eta[o] <- alpha[tt] +
      beta[tt] * df$temperature[o] +
      coeff[base + 1L] +
      coeff[base + 2L] * df$temperature[o]
  }
  df$value <- eta + stats::rnorm(nrow(df), sd = 0.18)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 1),
    data = df,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$diag_B_slope_default))
  shared <- extract_Sigma(fit, level = "unit_slope", part = "shared")$Sigma
  unique <- extract_Sigma(fit, level = "unit_slope", part = "unique")$s
  total <- extract_Sigma(fit, level = "unit_slope", part = "total")$Sigma

  truth_shared <- Lambda_aug %*% t(Lambda_aug)
  dimnames(truth_shared) <- dimnames(shared)
  truth_total <- truth_shared + diag(sd_aug^2)
  dimnames(truth_total) <- dimnames(total)

  expect_lt(max(abs(shared - truth_shared)), 0.08)
  expect_lt(max(abs(sqrt(unique) - sd_aug)), 0.08)
  expect_lt(max(abs(total - truth_total)), 0.08)

  truth_R <- stats::cov2cor(truth_total)
  ci <- suppressMessages(confint(
    fit,
    parm = "rho:unit_slope:1,2",
    method = "profile"
  ))
  bounds <- unname(ci[1L, ])
  truth_rho <- unname(truth_R[1L, 2L])

  expect_equal(rownames(ci), "rho:unit_slope:1,2")
  expect_true(all(is.finite(bounds)))
  expect_true(
    bounds[1L] <= truth_rho && truth_rho <= bounds[2L],
    info = sprintf(
      "Known-DGP rho:unit_slope:1,2 truth %.3f outside profile CI [%.3f, %.3f]",
      truth_rho, bounds[1L], bounds[2L]
    )
  )
})

test_that("ordinary Poisson low-rank latent random regression recovers shared augmented covariance", {
  ## RE-12 evidence: non-Gaussian (Poisson) low-rank augmented `latent()`
  ## recovery. Latent-only (no `unique()` tier), rank-1 augmented loading,
  ## so the recovery target is `Lambda_aug Lambda_aug^T`. This is the
  ## low-rank non-Gaussian latent boundary; augmented `unique()` is
  ## deliberately Gaussian-only (guarded elsewhere) and delta/hurdle are out
  ## of scope, so neither is exercised here.
  skip_if_not_heavy()
  testthat::skip_on_cran()
  set.seed(9131L)
  n_ind <- 80L
  n_traits <- 3L
  n_rep <- 8L
  trait_levels <- paste0("t", seq_len(n_traits))
  individuals <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(individuals, levels = individuals),
    rep = seq_len(n_rep),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sessions <- unique(df[c("individual", "rep", "session_id")])
  sessions$temperature <- stats::rnorm(nrow(sessions), sd = 0.8)
  df <- merge(df, sessions, by = c("individual", "rep", "session_id"),
              sort = FALSE)

  ## Rank-1 augmented loading over (intercept, slope) x trait, so
  ## Sigma_shared = Lambda_aug Lambda_aug^T has max entry ~0.30 -- well above
  ## the recovery band, so a degenerate (near-zero) fit cannot pass.
  Lambda_aug <- matrix(c(0.55, 0.30, -0.45, 0.22, 0.40, -0.28),
                       nrow = 2L * n_traits, ncol = 1L)
  z <- stats::rnorm(n_ind)
  alpha <- c(1.6, 1.4, 1.8)    # log-link intercepts -> mean count ~ exp(1.6) ~ 5
  beta <- c(0.15, -0.10, 0.12)
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    tt <- as.integer(df$trait[o])
    ii <- as.integer(df$individual[o])
    base <- 2L * (tt - 1L)
    coeff <- Lambda_aug[, 1L] * z[ii]
    eta[o] <- alpha[tt] + beta[tt] * df$temperature[o] +
      coeff[base + 1L] + coeff[base + 2L] * df$temperature[o]
  }
  df$value <- stats::rpois(nrow(df), lambda = exp(eta))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 1),
    data = df,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    family = poisson(),
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_rr_B_slope, 1L)

  shared <- extract_Sigma(fit, level = "unit_slope", part = "shared")$Sigma
  total <- extract_Sigma(fit, level = "unit_slope", part = "total")$Sigma
  expect_equal(dim(shared), c(2L * n_traits, 2L * n_traits))

  truth_shared <- Lambda_aug %*% t(Lambda_aug)
  dimnames(truth_shared) <- dimnames(shared)

  ## Count-family recovery band: with mean counts ~5 the rank-1 loading is
  ## recovered to <0.06 across seeds 9131-9135; 0.08 matches the file's
  ## Gaussian latent+unique recovery band and stays well under the ~0.30
  ## signal (an honest count band, not a widened Gaussian tolerance).
  expect_lt(max(abs(shared - truth_shared)), 0.08)
  ## Latent-only fit: no unique tier, so total == shared.
  expect_equal(total, shared, tolerance = 1e-8)
})

test_that("ordinary unique-only random regression fits Gaussian diagonal augmented covariance", {
  testthat::skip_on_cran()
  fx <- make_ordinary_latent_rr_fixture(seed = 9113L, n_ind = 16L, n_rep = 4L)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      unique(0 + trait + (0 + trait):temperature | individual),
    data = fx$data,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_false(isTRUE(fit$use$rr_B_slope))
  expect_true(isTRUE(fit$use$diag_B_slope))
  unique <- extract_Sigma(fit, level = "unit_slope", part = "unique")$s
  total <- extract_Sigma(fit, level = "unit_slope", part = "total")$Sigma
  expected <- diag(unique, nrow = length(unique))
  dimnames(expected) <- dimnames(total)
  expect_equal(total, expected, tolerance = 1e-8)
  expect_error(
    extract_Sigma(fit, level = "unit_slope", part = "shared"),
    regexp = "no augmented ordinary.*latent"
  )
})

test_that("traits() wide surface reaches ordinary latent random-regression engine", {
  testthat::skip_on_cran()
  fx <- make_ordinary_latent_rr_fixture(seed = 9102L)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2, t3) ~ 1 +
      temperature +
      latent(1 + temperature | individual, d = 2),
    data = fx$wide,
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_rr_B_slope, 1L)
  expect_identical(fit$tmb_data$use_diag_B_slope, 1L)
  expect_true(isTRUE(fit$use$diag_B_slope_default))
  expect_equal(
    dim(fit$tmb_data$Z_B_lat),
    c(nrow(fx$wide) * fx$n_traits, 2L * fx$n_traits)
  )
  expect_equal(
    dim(fit$tmb_data$Z_B_diag),
    c(nrow(fx$wide) * fx$n_traits, 2L * fx$n_traits)
  )
  expect_identical(fit$use$rr_B_slope_col, "temperature")
  expect_identical(fit$use$diag_B_slope_col, "temperature")
})

test_that("ordinary latent random-regression path fits a Poisson response", {
  testthat::skip_on_cran()
  set.seed(9103L)
  n_ind <- 24L
  n_traits <- 3L
  n_rep <- 4L
  trait_levels <- paste0("t", seq_len(n_traits))
  individuals <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(individuals, levels = individuals),
    rep = seq_len(n_rep),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sessions <- unique(df[c("individual", "rep", "session_id")])
  sessions$temperature <- stats::rnorm(nrow(sessions), sd = 0.8)
  df <- merge(
    df,
    sessions,
    by = c("individual", "rep", "session_id"),
    sort = FALSE
  )

  Lambda_aug <- matrix(
    c(0.25, 0.10, -0.15, 0.08, 0.20, -0.06),
    nrow = 2L * n_traits,
    ncol = 1L
  )
  z <- stats::rnorm(n_ind)
  alpha <- c(0.3, 0.0, -0.2)
  beta <- c(0.15, -0.10, 0.12)
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    tt <- as.integer(df$trait[o])
    ii <- as.integer(df$individual[o])
    base <- 2L * (tt - 1L)
    coeff <- Lambda_aug[, 1L] * z[ii]
    eta[o] <- alpha[tt] +
      beta[tt] * df$temperature[o] +
      coeff[base + 1L] +
      coeff[base + 2L] * df$temperature[o]
  }
  df$value <- stats::rpois(nrow(df), lambda = exp(eta))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 1),
    data = df,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    family = poisson(),
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_rr_B_slope, 1L)
  expect_identical(fit$tmb_data$use_diag_B_slope, 0L)
  expect_false(isTRUE(fit$use$diag_B_slope_default))
  expect_equal(
    dim(extract_Sigma(fit, level = "unit_slope")$Sigma),
    c(2L * n_traits, 2L * n_traits)
  )
})

test_that("ordinary latent random-regression guards unsupported slope variants", {
  withr::local_options(lifecycle_verbosity = "quiet")

  fx <- make_ordinary_latent_rr_fixture(n_ind = 4L, n_rep = 2L)

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        latent(0 + trait + (0 + trait):temperature | session_id, d = 1),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "unit.*tier only|unit_obs"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        latent(
          0 + trait + (0 + trait):temperature | individual,
          d = 2L * fx$n_traits + 1L
        ),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "2 \\* n_traits|augmented random-regression coefficient dimension"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        latent(0 + trait | individual, d = 1) +
        latent(0 + trait + (0 + trait):temperature | individual, d = 1),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "Do not combine augmented ordinary.*intercept-only"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        unique(0 + trait + (0 + trait):temperature | session_id),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "unit.*tier only|unit_obs"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        unique(0 + trait | individual) +
        unique(0 + trait + (0 + trait):temperature | individual),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "Do not combine augmented ordinary.*intercept-only"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        unique(0 + trait + (0 + trait):temperature | individual, common = TRUE),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "common = TRUE"
  )

  fx$data$humidity <- stats::rnorm(nrow(fx$data))
  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        (0 + trait):humidity +
        latent(0 + trait + (0 + trait):temperature | individual, d = 1) +
        unique(0 + trait + (0 + trait):humidity | individual),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "same slope covariate"
  )
})

test_that("ordinary augmented unique random regression is Gaussian-only for now", {
  withr::local_options(lifecycle_verbosity = "quiet")

  testthat::skip_on_cran()
  set.seed(9114L)
  fx <- make_ordinary_latent_rr_fixture(n_ind = 6L, n_rep = 2L)
  fx$data$value <- stats::rpois(nrow(fx$data), lambda = exp(0.1))

  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):temperature +
        unique(0 + trait + (0 + trait):temperature | individual),
      data = fx$data,
      trait = "trait",
      unit = "individual",
      unit_obs = "session_id",
      family = poisson(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    regexp = "Gaussian responses only"
  )
})

## ---- Slice 2a (#608): augmented latent unique= opt-out ---------------------
## Decisions (Shinichi 2026-07-05): unify on `unique=`, default TRUE, keep the
## free intercept-slope correlation in the rr_B_slope block. The augmented
## `latent(1 + x | g)` parser previously returned a bare rr() and ignored the
## fold argument, so users could not opt out of the Gaussian default diagonal.

test_that("augmented latent unique= argument sets the diagonal-companion marker", {
  withr::local_options(lifecycle_verbosity = "quiet")

  aug_cs <- function(form) {
    gllvmTMB:::parse_multi_formula(
      gllvmTMB:::desugar_brms_sugar(form)
    )$covstructs[[1L]]
  }

  ## Default: unique companion on (marker TRUE, not FALSE).
  default_cs <- aug_cs(
    value ~ 0 + trait + latent(1 + temperature | individual, d = 2)
  )
  expect_true(isTRUE(default_cs$extra$.latent_augmented))
  expect_true(isTRUE(default_cs$extra$.latent_augmented_unique))

  ## Explicit opt-out.
  off_cs <- aug_cs(
    value ~ 0 + trait + latent(1 + temperature | individual, d = 2, unique = FALSE)
  )
  expect_true(isFALSE(off_cs$extra$.latent_augmented_unique))

  ## Explicit opt-in (long form too).
  on_cs <- aug_cs(
    value ~ 0 +
      trait +
      latent(0 + trait + (0 + trait):temperature | individual, d = 2, unique = TRUE)
  )
  expect_true(isTRUE(on_cs$extra$.latent_augmented_unique))
})

test_that("augmented latent residual= is a soft-deprecated alias for unique=", {
  ## tests/testthat/setup.R sets gllvmTMB.quiet_grammar_notes = TRUE suite-wide
  ## so the one-shot fire-on-use grammar notices don't trip unrelated
  ## expect_silent()/expect_no_warning() assertions elsewhere; re-enable it
  ## locally to observe the residual= alias warning (same idiom as
  ## test-latent-unique-rename.R's "residual = ) is a soft-deprecated alias"
  ## test).
  withr::local_options(
    lifecycle_verbosity = "warning",
    gllvmTMB.quiet_grammar_notes = FALSE
  )

  ## The residual= -> unique= alias warning fires once per R session via
  ## gllvmTMB's own env-based tracker (.gllvmTMB_deprecation_seen, see
  ## .gllvmTMB_warn_latent_residual_alias() in R/brms-sugar.R), not
  ## lifecycle::deprecate_warn(). Reset the tracker so the warning is
  ## guaranteed to fire here regardless of whether an earlier test in the
  ## suite already triggered it, and restore it afterwards (same pattern
  ## as test-latent-unique-rename.R's reset_gllvmTMB_dep_seen()).
  seen <- get(".gllvmTMB_deprecation_seen", envir = asNamespace("gllvmTMB"))
  saved <- as.list(seen, all.names = TRUE)
  withr::defer({
    rlang::env_unbind(seen, rlang::env_names(seen))
    rlang::env_bind(seen, !!!saved)
  })
  rlang::env_unbind(seen, rlang::env_names(seen))

  expect_warning(
    off_cs <- gllvmTMB:::parse_multi_formula(
      gllvmTMB:::desugar_brms_sugar(
        value ~ 0 + trait + latent(1 + temperature | individual, d = 2, residual = FALSE)
      )
    )$covstructs[[1L]],
    regexp = "renamed|soft-deprecated alias"
  )
  expect_true(isFALSE(off_cs$extra$.latent_augmented_unique))
})

test_that("augmented latent unique = FALSE suppresses the diagonal companion but keeps the free correlation", {
  testthat::skip_on_cran()
  withr::local_options(lifecycle_verbosity = "quiet")
  fx <- make_ordinary_latent_rr_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 2, unique = FALSE),
    data = fx$data,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = FALSE,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_rr_B_slope, 1L)
  ## The opt-out: no augmented diagonal companion even though the fit is Gaussian.
  expect_identical(fit$tmb_data$use_diag_B_slope, 0L)
  expect_false(isTRUE(fit$use$diag_B_slope_default))

  ## The free intercept-slope correlation lives in the rr block, so it survives
  ## the opt-out: the shared augmented covariance has a non-zero intercept-slope
  ## off-diagonal for trait 1.
  shared <- extract_Sigma(fit, level = "unit_slope", part = "shared")$Sigma
  expect_gt(abs(shared[1L, 2L]), 0)
})
