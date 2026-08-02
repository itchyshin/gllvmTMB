## Tests for the internal cross-validation layer:
##   R/cv-internal.R: .cv_check_cv_supported(), .cv_make_folds(),
##                     .cv_mask_response()
##   R/cv-metrics.R:   .cv_join_truth(), .cv_score()
## All five are unexported (dot-prefixed, @noRd); reached here via
## gllvmTMB:::. `.cv_run()` (R/cv-internal.R) is owned and tested by a
## concurrent slice; nothing here calls it.
##
## Model-fitting tests are gated by skip_if_not_heavy() (tests/testthat/
## setup.R) -- they fit real gllvmTMB() models on the cached CV fixture
## (gllvmTMB:::load_cv_fixture()). Nothing here hardcodes the fixture's
## trait count, row count, or fold sizes: every such quantity is derived
## from the loaded fixture / fitted object at test time, so the tests stay
## valid across fixture regenerations (the fixture is moving from 3 to 5
## traits, 2026-08-02, to fix an identifiability flat direction).
##
## Pure-arithmetic tests (masking, metric formulas) fit no model and run
## unskipped in the fast suite.

.cvi_formula <- value ~ 0 + trait + latent(0 + trait | site, d = 2)

## Fit the shared arc formula on one family variant of the CV fixture.
## Returns list(fixture = <load_cv_fixture() output>, fit = <gllvmTMB fit>).
## Called fresh inside each heavy test_that() (no cross-test caching),
## matching the test-block-conditional-recovery.R convention in this file's
## neighbourhood.
.cvi_fit <- function(family) {
  fixture <- gllvmTMB:::load_cv_fixture(family)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    .cvi_formula,
    data    = fixture$data,
    family  = fixture$family_arg,
    unit    = "site",
    cluster = "species"
  )))
  list(fixture = fixture, fit = fit)
}

## ---- 1. Folds partition the observed cells exactly once ------------------

test_that(".cv_make_folds() partitions observed cells exactly once, with balanced fold sizes", {
  skip_if_not_heavy()
  fit <- .cvi_fit("gaussian")$fit

  folds <- gllvmTMB:::.cv_make_folds(fit, n_folds = 5L, seed = 101L)
  expect_length(folds, 5L)

  obs_idx  <- which(fit$tmb_data$is_y_observed == 1L)
  all_rows <- unlist(folds)

  expect_setequal(all_rows, obs_idx)                        ## nothing outside the observed cells
  expect_equal(length(all_rows), length(obs_idx))           ## nothing missing
  expect_equal(length(unique(all_rows)), length(all_rows))  ## no cell in two folds

  sizes <- vapply(folds, length, integer(1))
  expect_lte(max(sizes) - min(sizes), 1L)
})

## ---- 2. Degeneracy guard ---------------------------------------------------

test_that(".cv_make_folds() training remainder respects the per-trait minimum size (gaussian fixture)", {
  skip_if_not_heavy()
  fit <- .cvi_fit("gaussian")$fit

  folds     <- gllvmTMB:::.cv_make_folds(fit, n_folds = 5L, seed = 102L)
  min_train <- max(5L, ncol(fit$X_fix) + 1L)
  trait_id  <- fit$tmb_data$trait_id
  is_obs    <- fit$tmb_data$is_y_observed == 1L

  for (k in seq_along(folds)) {
    held <- folds[[k]]
    for (t in unique(trait_id[is_obs])) {
      rows_t  <- which(trait_id == t & is_obs)
      train_t <- setdiff(rows_t, held)
      expect_gte(
        length(train_t), min_train,
        label = sprintf("fold %d trait_id %d training size", k, t)
      )
    }
  }
})

test_that(".cv_make_folds() training remainder keeps both outcome classes per trait (binomial fixture)", {
  skip_if_not_heavy()
  fit <- .cvi_fit("binomial")$fit

  folds    <- gllvmTMB:::.cv_make_folds(fit, n_folds = 5L, seed = 103L)
  trait_id <- fit$tmb_data$trait_id
  is_obs   <- fit$tmb_data$is_y_observed == 1L
  y        <- fit$tmb_data$y
  n_trials <- fit$tmb_data$n_trials

  for (k in seq_along(folds)) {
    held <- folds[[k]]
    for (t in unique(trait_id[is_obs])) {
      rows_t  <- which(trait_id == t & is_obs)
      train_t <- setdiff(rows_t, held)
      expect_true(
        any(y[train_t] > 0),
        label = sprintf("fold %d trait_id %d has a training success", k, t)
      )
      expect_true(
        any(y[train_t] < n_trials[train_t]),
        label = sprintf("fold %d trait_id %d has a training failure", k, t)
      )
    }
  }
})

test_that(".cv_make_folds() aborts rather than silently returning a broken partition when starved", {
  skip_if_not_heavy()
  fit <- .cvi_fit("gaussian")$fit

  ## An n_folds larger than the number of observed cells can never be
  ## satisfied; this must abort loudly, not return a partition with empty
  ## or otherwise broken folds.
  n_obs <- sum(fit$tmb_data$is_y_observed == 1L)
  expect_error(
    gllvmTMB:::.cv_make_folds(fit, n_folds = n_obs + 1L, seed = 104L),
    regexp = "[Nn]ot enough observed cells"
  )
})

## ---- 3. Masking -------------------------------------------------------------

test_that(".cv_mask_response() NAs exactly the requested rows and leaves everything else untouched", {
  data <- data.frame(
    id    = 1:6,
    value = c(10, 20, 30, 40, 50, 60),
    other = letters[1:6],
    stringsAsFactors = FALSE
  )
  rows <- c(2L, 4L)

  masked <- gllvmTMB:::.cv_mask_response(data, "value", rows)

  expect_true(all(is.na(masked$value[rows])))
  expect_false(any(is.na(masked$value[-rows])))
  expect_equal(masked$value[-rows], data$value[-rows])
  expect_equal(masked$id, data$id)
  expect_equal(masked$other, data$other)
  expect_equal(dim(masked), dim(data))
})

test_that(".cv_mask_response() NAs both columns of a two-column (successes, failures) response", {
  data <- data.frame(
    id   = 1:4,
    succ = c(3, 5, 2, 8),
    fail = c(1, 0, 4, 2),
    stringsAsFactors = FALSE
  )
  rows <- c(1L, 3L)

  masked <- gllvmTMB:::.cv_mask_response(data, c("succ", "fail"), rows)

  expect_true(all(is.na(masked$succ[rows])))
  expect_true(all(is.na(masked$fail[rows])))
  expect_equal(masked$succ[-rows], data$succ[-rows])
  expect_equal(masked$fail[-rows], data$fail[-rows])
  expect_equal(masked$id, data$id)
})

test_that(".cv_mask_response() aborts on an unknown response column", {
  data <- data.frame(id = 1:3, value = c(1, 2, 3))
  expect_error(
    gllvmTMB:::.cv_mask_response(data, "nope", 1L),
    regexp = "not found"
  )
})

## ---- 4. Truth-source regression -------------------------------------------
##
## Held-out cells carry a SENTINEL ZERO inside the fit (R/fit-multi.R:2226
## sets y[masked_response] <- 0; :2230 sets n_trials <- 1), gated out of the
## likelihood by is_y_observed. If .cv_join_truth() is ever rewired to read
## truth from fit$tmb_data$y instead of the caller-supplied pre-mask
## truth_data, every held-out cell would be scored against 0 -- plausible-
## looking metrics that are actually meaningless. THIS TEST FAILS LOUDLY IF
## THAT REGRESSION IS REINTRODUCED: it fits on masked data, confirms the
## sentinel is really there, then asserts .cv_join_truth()'s y_true is the
## TRUE pre-mask value, not the sentinel.
test_that(".cv_join_truth() sources held-out y_true from pre-mask truth_data, NOT the sentinel-zeroed fit$tmb_data$y", {
  skip_if_not_heavy()
  fixture <- gllvmTMB:::load_cv_fixture("gaussian")
  dat <- fixture$data

  fit0 <- suppressMessages(suppressWarnings(gllvmTMB(
    .cvi_formula,
    data = dat, family = fixture$family_arg, unit = "site", cluster = "species"
  )))
  held <- gllvmTMB:::.cv_make_folds(fit0, n_folds = 5L, seed = 105L)[[1L]]
  expect_gt(length(held), 0L)

  masked_dat <- gllvmTMB:::.cv_mask_response(dat, "value", held)
  fit1 <- suppressMessages(suppressWarnings(gllvmTMB(
    .cvi_formula,
    data = masked_dat, family = fixture$family_arg, unit = "site", cluster = "species",
    missing = miss_control(response = "include")
  )))

  ## Sanity: the fit really did mask `held`, and the sentinel is really 0 --
  ## the regression this test guards against would look identical without
  ## this check failing to hold.
  expect_true(all(fit1$tmb_data$is_y_observed[held] == 0L))
  expect_true(all(fit1$tmb_data$y[held] == 0))

  pm_out <- predict_missing(fit1, type = "response")
  expect_equal(nrow(pm_out), length(held))

  trait_col <- fit1$trait_col
  truth_data <- data.frame(
    original_row = seq_len(nrow(dat)),
    value         = dat$value,
    stringsAsFactors = FALSE
  )
  truth_data[[trait_col]] <- as.character(dat[[trait_col]])

  joined <- gllvmTMB:::.cv_join_truth(fit1, pm_out, truth_data, response_col = "value")
  expect_equal(nrow(joined), length(held))

  expected_y_true <- dat$value[joined$original_row]
  expect_equal(joined$y_true, expected_y_true)  ## THE regression assertion
  expect_false(all(joined$y_true == 0))         ## not the sentinel
})

## ---- 5. Join fan-out --------------------------------------------------------

test_that(".cv_join_truth() aborts on duplicate (original_row, trait) keys and preserves row order on the happy path", {
  skip_if_not_heavy()
  built <- .cvi_fit("gaussian")
  fit <- built$fit
  dat <- built$fixture$data
  trait_col <- fit$trait_col

  n_model <- nrow(fit$data)
  set.seed(9001L)
  pick <- sort(sample(seq_len(n_model), size = min(8L, n_model)))

  pm_out <- data.frame(
    original_row = pick,
    model_row    = pick,
    est          = stats::runif(length(pick)),
    stringsAsFactors = FALSE
  )
  pm_out[[trait_col]] <- as.character(fit$data[[trait_col]][pick])

  truth_ok <- data.frame(
    original_row = seq_len(n_model),
    value = dat$value,
    stringsAsFactors = FALSE
  )
  truth_ok[[trait_col]] <- as.character(dat[[trait_col]])

  joined <- gllvmTMB:::.cv_join_truth(fit, pm_out, truth_ok, response_col = "value")
  expect_equal(nrow(joined), nrow(pm_out))
  expect_equal(joined$original_row, pm_out$original_row)  ## row order preserved
  expect_equal(joined$y_true, dat$value[pick])

  ## A duplicate (original_row, trait) key in truth_data must abort the join,
  ## not silently fan truth out across the duplicate.
  dup_row <- truth_ok[
    truth_ok$original_row == pick[1] & truth_ok[[trait_col]] == pm_out[[trait_col]][1], ,
    drop = FALSE
  ]
  truth_dup <- rbind(truth_ok, dup_row)
  expect_error(
    gllvmTMB:::.cv_join_truth(fit, pm_out, truth_dup, response_col = "value"),
    regexp = "[Dd]uplicate|row count"
  )
})

## ---- 6. Metric correctness against hand-computed values --------------------

test_that(".cv_score() matches hand-computed RMSE, Tjur R2, and AUC (incl. a tie), and reports NA for an unsupported family", {
  ## Gaussian (family_id 0): RMSE = sqrt(mean((y - yhat)^2)).
  y_g <- c(2, 4, 6)
  yhat_g <- c(1, 5, 5)
  joined_gaussian <- data.frame(
    trait = "t1", family_id = 0L,
    est = yhat_g, y_true = y_g,
    n_trials = 1, disp = NA_real_,
    stringsAsFactors = FALSE
  )
  res_gaussian <- gllvmTMB:::.cv_score(joined_gaussian)
  expect_equal(res_gaussian$pooled$RMSE, sqrt(mean((y_g - yhat_g)^2)))
  expect_equal(res_gaussian$pooled$RMSE, 1)

  ## Binomial (family_id 1): Tjur R2 = mean(phat | y=1) - mean(phat | y=0);
  ## RMSE is also reported for binomial.
  y_b <- c(1, 1, 0, 0, 0)
  p_b <- c(0.9, 0.7, 0.2, 0.5, 0.3)
  joined_tjur <- data.frame(
    trait = "t1", family_id = 1L,
    est = p_b, y_true = y_b,
    n_trials = 1, disp = NA_real_,
    stringsAsFactors = FALSE
  )
  res_tjur <- gllvmTMB:::.cv_score(joined_tjur)
  expect_equal(res_tjur$pooled$TjurR2, mean(p_b[y_b == 1]) - mean(p_b[y_b == 0]))
  expect_equal(res_tjur$pooled$RMSE, sqrt(mean((y_b - p_b)^2)))

  ## Binomial AUC, including a tie in the predicted probability: the
  ## closed-form Mann-Whitney U statistic averages ranks over ties.
  ## pos = c(0.8, 0.5), neg = c(0.5, 0.2); pairwise pos-beats-neg score is
  ## (1 + 1 + 0.5 + 1) / 4 = 0.875 (the 0.5-vs-0.5 pair is a half-credit tie).
  y_auc <- c(1, 1, 0, 0)
  p_auc <- c(0.8, 0.5, 0.5, 0.2)
  joined_auc <- data.frame(
    trait = "t2", family_id = 1L,
    est = p_auc, y_true = y_auc,
    n_trials = 1, disp = NA_real_,
    stringsAsFactors = FALSE
  )
  res_auc <- gllvmTMB:::.cv_score(joined_auc)
  expect_equal(res_auc$pooled$AUC, 0.875)

  ## An unsupported family_id must report NA for every metric, not a wrong
  ## number computed under a guessed branch.
  joined_unsupported <- data.frame(
    trait = "tx", family_id = 999L,
    est = c(1, 2, 3), y_true = c(1, 2, 3),
    n_trials = 1, disp = NA_real_,
    stringsAsFactors = FALSE
  )
  res_unsupported <- gllvmTMB:::.cv_score(joined_unsupported)
  metric_cols <- c(
    "RMSE", "R2", "TjurR2", "AUC", "Brier",
    "SpearmanR2", "O.AUC", "O.TjurR2", "C.RMSE", "LogScore"
  )
  for (col in metric_cols) {
    expect_true(
      is.na(res_unsupported$pooled[[col]]),
      label = sprintf("pooled$%s for an unsupported family_id", col)
    )
  }
})
