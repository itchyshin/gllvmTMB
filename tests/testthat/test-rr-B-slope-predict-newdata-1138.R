## #1138: predict(newdata =) re-adds the augmented unit-level latent random
## regression tier rr_B_slope, exactly.
##
## Symbolic alignment:
## | Symbol | Covstruct keyword | Template term | Reconstruction | Check |
## | --- | --- | --- | --- | --- |
## | b_i = Lambda_aug z_i | latent(1 + x | unit, d = K, unique = FALSE) | eta(o) += sum_j Z_B_lat(o, j) (Lambda_B_slope z_B_slope)(j, s) | rows 2t / 2t + 1 of Lambda_B_slope z_B_slope[, s], times (1, x) | predict(newdata = training)$est == fit$report$eta |

make_rr_B_slope_1138_data <- function(seed = 11381L, n_ind = 16L, n_rep = 3L) {
  set.seed(seed)
  traits <- paste0("t", 1:3)
  ids <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(ids, levels = ids),
    rep = seq_len(n_rep),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sess <- unique(df[c("individual", "rep", "session_id")])
  sess$temperature <- stats::rnorm(nrow(sess))
  df <- merge(df, sess, by = c("individual", "rep", "session_id"), sort = FALSE)
  ## Trait-specific intercept and slope loadings, so a swapped
  ## intercept/slope row or a wrong trait stride cannot cancel out.
  Lambda <- matrix(
    c(0.6, 0.0,  0.3, 0.4,  -0.5, 0.2,
      0.1, -0.4,  0.5, 0.0,  -0.2, 0.3),
    nrow = 6L, ncol = 2L
  )
  z <- matrix(stats::rnorm(2L * n_ind), nrow = 2L)
  tt <- as.integer(df$trait)
  ii <- as.integer(df$individual)
  coef <- Lambda %*% z
  df$value <- 0.2 * tt + 0.1 * df$temperature +
    coef[cbind(2L * tt - 1L, ii)] +
    coef[cbind(2L * tt, ii)] * df$temperature +
    stats::rnorm(nrow(df), sd = 0.3)
  df
}

## The fixed part is trait intercepts only, so each design row has a single
## nonzero entry. With a fixed slope as well, R's `X %*% b` and the template's
## Eigen product can round a + b * x differently (an FMA-capable BLAS such as
## OpenBLAS fuses it), which would break an exact identity for reasons
## unrelated to the random-effect tier.
fit_rr_B_slope_1138 <- function(df, formula) {
  suppressMessages(suppressWarnings(gllvmTMB(
    formula,
    data = df,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
}

test_that("#1138: rr_B_slope is re-added on training newdata with zero difference", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- make_rr_B_slope_1138_data()
  fit <- fit_rr_B_slope_1138(
    df,
    value ~ 0 + trait +
      latent(1 + temperature | individual, d = 2, unique = FALSE)
  )
  expect_identical(as.integer(fit$tmb_data$use_rr_B_slope), 1L)
  expect_identical(as.integer(fit$tmb_data$use_diag_B_slope), 0L)

  ## The tier is not trivially zero: dropping it moves eta.
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est
  expect_gt(max(abs(fit$report$eta - fixed_only)), 1e-3)

  expect_no_warning(p_nd <- suppressMessages(predict(fit, newdata = df)))
  expect_equal(max(abs(p_nd$est - as.numeric(fit$report$eta))), 0, tolerance = 1e-10)
  expect_equal(max(abs(p_nd$est - suppressMessages(predict(fit))$est)), 0, tolerance = 1e-10)

  ## A shuffled subset must still pick up each row's own unit and trait.
  set.seed(2)
  rows <- sample(nrow(df), 40L)
  p_sub <- suppressMessages(predict(fit, newdata = df[rows, ]))$est
  expect_equal(max(abs(p_sub - as.numeric(fit$report$eta)[rows])), 0, tolerance = 1e-10)
})

test_that("#1138: rr_B_slope long-form LHS is re-added with zero difference", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- make_rr_B_slope_1138_data(seed = 11382L)
  fit <- fit_rr_B_slope_1138(
    df,
    value ~ 0 + trait +
      latent(0 + trait + (0 + trait):temperature | individual,
             d = 2, unique = FALSE)
  )
  expect_identical(as.integer(fit$tmb_data$use_rr_B_slope), 1L)
  expect_identical(as.integer(fit$tmb_data$use_diag_B_slope), 0L)

  expect_no_warning(p_nd <- suppressMessages(predict(fit, newdata = df)))
  expect_equal(max(abs(p_nd$est - as.numeric(fit$report$eta))), 0, tolerance = 1e-10)
})

test_that("#1138: rr_B_slope without its slope covariate is reported, not dropped in silence", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- make_rr_B_slope_1138_data()
  fit <- fit_rr_B_slope_1138(
    df,
    value ~ 0 + trait + latent(1 + temperature | individual, d = 2, unique = FALSE)
  )
  nd <- df[, setdiff(names(df), "temperature"), drop = FALSE]
  w <- NULL
  withCallingHandlers(
    suppressMessages(predict(fit, newdata = nd)),
    gllvmTMB_predict_newdata_re_dropped = function(cnd) {
      w <<- conditionMessage(cnd)
      invokeRestart("muffleWarning")
    }
  )
  expect_match(w, "rr_B_slope", fixed = TRUE)
})
