## #1138: predict(newdata =) re-adds the augmented unit-level diagonal random
## regression tier diag_B_slope, exactly.
##
## Symbolic alignment:
## | Symbol | Covstruct keyword | Template term | Reconstruction | Check |
## | --- | --- | --- | --- | --- |
## | b_i ~ N(0, diag(psi_aug)) | unique(1 + x | unit) | eta(o) += sum_j Z_B_diag(o, j) s_B_slope(j, s) | s_B_slope[2t, s] + x * s_B_slope[2t + 1, s] | predict(newdata = training)$est == fit$report$eta |

make_diag_B_slope_1138_data <- function(seed = 11383L, n_ind = 16L, n_rep = 3L) {
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
  ## Independent intercept and slope deviations with trait-specific SDs, so
  ## a swapped intercept/slope row or a wrong trait stride cannot cancel out.
  sd_int <- c(0.7, 0.3, 0.5)
  sd_slp <- c(0.2, 0.6, 0.4)
  b_int <- matrix(stats::rnorm(3L * n_ind, sd = sd_int), nrow = 3L)
  b_slp <- matrix(stats::rnorm(3L * n_ind, sd = sd_slp), nrow = 3L)
  tt <- as.integer(df$trait)
  ii <- as.integer(df$individual)
  df$value <- 0.2 * tt + 0.1 * df$temperature +
    b_int[cbind(tt, ii)] + b_slp[cbind(tt, ii)] * df$temperature +
    stats::rnorm(nrow(df), sd = 0.3)
  df
}

fit_diag_B_slope_1138 <- function(df, formula) {
  withr::local_options(lifecycle_verbosity = "quiet")
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

test_that("#1138: diag_B_slope is re-added on training newdata with zero difference", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- make_diag_B_slope_1138_data()
  fit <- fit_diag_B_slope_1138(
    df,
    value ~ 0 + trait + (0 + trait):temperature +
      unique(1 + temperature | individual)
  )
  expect_identical(as.integer(fit$tmb_data$use_diag_B_slope), 1L)
  expect_identical(as.integer(fit$tmb_data$use_rr_B_slope), 0L)

  ## The tier is not trivially zero: dropping it moves eta.
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est
  expect_gt(max(abs(fit$report$eta - fixed_only)), 1e-3)

  expect_no_warning(p_nd <- suppressMessages(predict(fit, newdata = df)))
  expect_identical(max(abs(p_nd$est - as.numeric(fit$report$eta))), 0)
  expect_identical(max(abs(p_nd$est - suppressMessages(predict(fit))$est)), 0)

  ## A shuffled subset must still pick up each row's own unit and trait.
  set.seed(2)
  rows <- sample(nrow(df), 40L)
  p_sub <- suppressMessages(predict(fit, newdata = df[rows, ]))$est
  expect_identical(max(abs(p_sub - as.numeric(fit$report$eta)[rows])), 0)
})

test_that("#1138: diag_B_slope long-form LHS is re-added with zero difference", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- make_diag_B_slope_1138_data(seed = 11384L)
  fit <- fit_diag_B_slope_1138(
    df,
    value ~ 0 + trait + (0 + trait):temperature +
      unique(0 + trait + (0 + trait):temperature | individual)
  )
  expect_identical(as.integer(fit$tmb_data$use_diag_B_slope), 1L)
  expect_identical(as.integer(fit$tmb_data$use_rr_B_slope), 0L)

  expect_no_warning(p_nd <- suppressMessages(predict(fit, newdata = df)))
  expect_identical(max(abs(p_nd$est - as.numeric(fit$report$eta))), 0)
})

test_that("#1138: diag_B_slope without its slope covariate is reported, not dropped in silence", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  df <- make_diag_B_slope_1138_data()
  fit <- fit_diag_B_slope_1138(
    df,
    value ~ 0 + trait + unique(1 + temperature | individual)
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
  expect_match(w, "diag_B_slope", fixed = TRUE)
})
