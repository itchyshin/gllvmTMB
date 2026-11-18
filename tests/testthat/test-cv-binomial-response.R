.cv_binomial_fixture <- function(lhs = quote(cbind(s, f)), missing = TRUE) {
  set.seed(1496)
  d <- expand.grid(
    unit = factor(seq_len(24)),
    trait = factor(letters[1:3]),
    rep = 1:2
  )
  d <- d[sample(nrow(d)), ]
  d$n <- rep(c(2, 7, 11), length.out = nrow(d))
  d$env_1 <- rep(seq(-1, 1, length.out = 24), length.out = nrow(d))
  d$env_2 <- rep(c(-.5, .5), length.out = nrow(d))
  d$s <- rbinom(nrow(d), d$n, plogis(-.3 + .4 * d$env_1))
  d$s[1:2] <- c(0, d$n[2])
  d$f <- d$n - d$s
  if (missing) {
    d$s[4] <- d$f[4] <- NA_real_
  }
  formula <- cbind(s, f) ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2
  formula[[2]] <- lhs
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    formula,
    data = d,
    family = binomial(),
    unit = 'unit',
    trait = 'trait',
    weights = if (identical(lhs, quote(s))) d$n else NULL,
    missing = miss_control(response = 'include')
  )))
  fit
}

test_that('grouped binomial scores equal independent trial-expansion oracles', {
  s <- c(0, 2, 4, 1, 3)
  n <- c(2, 7, 4, 3, 5)
  p <- c(.1, .5, .9, .5, .5)
  j <- data.frame(
    trait = 'a',
    family_id = 1L,
    y_true = s,
    n_trials = n,
    est = p,
    disp = NA_real_
  )
  yy <- unlist(Map(function(s, n) c(rep(1, s), rep(0, n - s)), s, n))
  pp <- rep(p, n)
  score <- .cv_score(j)$by_trait
  pos <- pp[yy == 1]
  neg <- pp[yy == 0]
  auc <- mean(outer(pos, neg, '>') + .5 * outer(pos, neg, '=='))
  expect_equal(score$RMSE, sqrt(mean((s / n - p)^2)))
  expect_equal(score$Brier, mean((yy - pp)^2))
  expect_equal(score$AUC, auc)
  expect_equal(score$TjurR2, mean(pos) - mean(neg))
  for (s0 in list(rep(0, length(n)), n)) {
    j$y_true <- s0
    score <- .cv_score(j)$by_trait
    expect_true(is.na(score$AUC))
    expect_true(is.na(score$TjurR2))
  }
})

test_that('CV retains pre-mask successes and unequal trial totals in prediction order', {
  fit <- .cv_binomial_fixture()
  held <- .cv_make_folds(fit, 3L, 1496)[[1]]
  masked <- .cv_mask_response(fit$data, c('s', 'f'), held)
  refit <- suppressMessages(suppressWarnings(.cv_do_refit(
    fit,
    .reconstruct_multi_formula(fit),
    masked
  )))
  pm <- predict_missing(refit, type = 'response')
  pm <- pm[pm$model_row %in% held, ]
  pm <- pm[rev(seq_len(nrow(pm))), ]
  truth <- fit$data
  truth$original_row <- seq_len(nrow(truth))
  joined <- .cv_join_truth(refit, pm, truth, c('s', 'f'))
  expect_equal(joined$model_row, pm$model_row)
  expect_equal(joined$y_true, truth$s[pm$original_row])
  expect_equal(
    joined$n_trials,
    truth$s[pm$original_row] + truth$f[pm$original_row]
  )
  expect_equal(
    .cv_logscore(joined, refit),
    dbinom(joined$y_true, joined$n_trials, joined$est, log = TRUE)
  )
  expect_true(all(is.finite(.cv_logscore(joined, refit))))
})

test_that('CV preserves trial weights in single-column refits', {
  fit <- .cv_binomial_fixture(quote(s))
  held <- .cv_make_folds(fit, 3L, 1496)[[1]]
  masked <- .cv_mask_response(fit$data, 's', held)
  refit <- suppressMessages(suppressWarnings(.cv_do_refit(
    fit,
    .reconstruct_multi_formula(fit),
    masked
  )))
  train <- which(
    fit$tmb_data$is_y_observed == 1 & !seq_len(nrow(fit$data)) %in% held
  )
  expect_equal(refit$tmb_data$n_trials[train], fit$tmb_data$n_trials[train])
})

test_that('CV and all nulls agree with paired manual folds and exclude previously missing cells', {
  fit <- .cv_binomial_fixture(quote(cbind(s, n - s)))
  data <- fit$data
  result <- suppressMessages(suppressWarnings(.cv_run(
    fit,
    data,
    c('s', 'n'),
    n_folds = 3L,
    seed = 1496
  )))
  expect_equal(result$meta$n_failed, 0)
  expect_equal(result$per_fold$n_scored, result$per_fold$n_heldout)
  expect_true(all(is.finite(result$per_fold$LogScore)))
  folds <- .cv_make_folds(fit, 3L, 1496)
  manual <- list()
  for (i in seq_along(folds)) {
    held <- folds[[i]]
    md <- data
    md$manual_pair <- cbind(data$s, data$n - data$s)
    md$manual_pair[held, ] <- NA_real_
    forms <- list(
      main = .reconstruct_multi_formula(fit),
      null_trait = manual_pair ~ 0 + trait,
      null_env = manual_pair ~ 0 +
        trait +
        (0 + trait):env_1 +
        (0 + trait):env_2,
      null_diag = manual_pair ~ 0 + trait + indep(0 + trait | unit)
    )
    forms$main[[2]] <- quote(manual_pair)
    for (nm in names(forms)) {
      m <- suppressMessages(suppressWarnings(gllvmTMB(
        forms[[nm]],
        data = md,
        family = binomial(),
        unit = 'unit',
        trait = 'trait',
        missing = miss_control(response = 'include')
      )))
      expect_equal(m$opt$convergence, 0L)
      pred <- predict_missing(m, type = 'response')
      pred <- pred[pred$model_row %in% held, ]
      idx <- pred$model_row
      score <- sum(dbinom(data$s[idx], data$n[idx], pred$est, log = TRUE))
      manual[[paste(i, nm)]] <- score
    }
    expect_equal(
      result$per_fold$LogScore[i],
      manual[[paste(i, 'main')]],
      tolerance = 1e-6
    )
    for (nm in c('null_trait', 'null_env', 'null_diag')) {
      expect_equal(
        result$pooled[[paste0('dLogScore_vs_', nm)]][result$pooled$fold == i],
        manual[[paste(i, 'main')]] - manual[[paste(i, nm)]],
        tolerance = 1e-6
      )
    }
  }
  weighted <- .cv_binomial_fixture(quote(s))
  wr <- suppressMessages(suppressWarnings(.cv_run(
    weighted,
    weighted$data,
    's',
    3L,
    1496
  )))
  expect_equal(wr$per_fold$LogScore, result$per_fold$LogScore, tolerance = 1e-6)
  shuffled <- data[rev(seq_len(nrow(data))), ]
  expect_error(
    .cv_run(fit, shuffled, c('s', 'n'), 3L, 1496),
    'same.*order|align'
  )
})

test_that('canonical cbind expressions preserve RHS trial predictors and matrix masks', {
  fit <- .cv_binomial_fixture(quote(cbind(s, n - s)))
  f <- .reconstruct_multi_formula(fit)
  f <- update(f, . ~ . + n)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    f,
    data = fit$data,
    family = binomial(),
    unit = 'unit',
    trait = 'trait',
    missing = miss_control(response = 'include')
  )))
  r <- .cv_response_setup(fit, fit$data)
  held <- .cv_make_folds(fit, 3, 1496)[[1]]
  masked <- .cv_mask_response(r$data, r$name, held)
  expect_equal(masked$n, fit$data$n)
  expect_true(all(is.na(masked[[r$name]][held, ])))
  refit <- suppressMessages(suppressWarnings(.cv_do_refit(
    fit,
    r$formula,
    masked
  )))
  expect_equal(nrow(refit$data), nrow(fit$data))
  expect_setequal(
    which(refit$tmb_data$is_y_observed == 0),
    c(held, which(fit$tmb_data$is_y_observed == 0))
  )
})

test_that('CV joins explicit weighted truth totals and refuses malformed count scores', {
  fit <- .cv_binomial_fixture(quote(s))
  held <- .cv_make_folds(fit, 3, 1496)[[1]]
  masked <- .cv_mask_response(fit$data, 's', held)
  refit <- suppressMessages(suppressWarnings(.cv_do_refit(
    fit,
    .reconstruct_multi_formula(fit),
    masked
  )))
  pm <- predict_missing(refit, type = 'response')
  pm <- pm[pm$model_row %in% held, ]
  tr <- fit$data
  tr$original_row <- seq_len(nrow(tr))
  j <- .cv_join_truth(refit, pm, tr, 's', n_trials = fit$tmb_data$n_trials)
  expect_equal(j$n_trials, fit$tmb_data$n_trials[j$model_row])
  expect_error(.cv_join_truth(refit, pm, tr, 's', n_trials = 2), 'one pre-mask')
  bad <- j
  bad$y_true[1] <- bad$n_trials[1] + 1
  expect_error(.cv_score(bad), 'integer successes')
  bad <- j
  bad$n_trials[1] <- 1.5
  expect_error(.cv_score(bad), 'integer successes')
  j$family_id <- 8L
  expect_true(all(is.na(.cv_score(j)$by_trait$Brier)))
})

test_that('stacked wide mixed responses retain row identity and trial totals in CV', {
  set.seed(1496)
  d <- data.frame(
    unit = factor(seq_len(24)),
    s1 = rbinom(24, 2, .3),
    s2 = rbinom(24, 7, .6),
    mass = rnorm(24)
  )
  d$f1 <- 2 - d$s1
  d$f2 <- 7 - d$s2
  d$s1[2] <- d$f1[2] <- NA_real_
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(cbind(s1, f1), cbind(s2, f2), mass) ~ 1,
    data = d,
    unit = 'unit',
    family = list(s1 = binomial(), s2 = binomial(), mass = gaussian()),
    missing = miss_control(response = 'include')
  )))
  r <- .cv_response_setup(fit, fit$data)
  held <- .cv_make_folds(fit, 3, 1496)[[1]]
  m <- .cv_mask_response(r$data, r$name, held)
  refit <- suppressMessages(suppressWarnings(.cv_do_refit(fit, r$formula, m)))
  train <- setdiff(which(fit$tmb_data$is_y_observed == 1), held)
  expect_equal(refit$tmb_data$n_trials[train], fit$tmb_data$n_trials[train])
  pm <- predict_missing(refit, type = 'response')
  pm <- pm[pm$model_row %in% held, ]
  tr <- .cv_truth_frame(r$data, fit$trait_col, r$name)
  j <- .cv_join_truth(refit, pm, tr, r$name, n_trials = r$trials)
  expect_equal(nrow(j), length(held))
  expect_equal(j$n_trials, r$trials[j$model_row])
  expect_equal(j$y_true, fit$tmb_data$y[j$model_row])
  b <- j$family_id == 1L
  expect_equal(
    .cv_logscore(j, refit)[b],
    dbinom(j$y_true[b], j$n_trials[b], j$est[b], log = TRUE)
  )
  matrix_truth <- r$data
  matrix_truth$original_row <- seq_len(nrow(matrix_truth))
  jm <- .cv_join_truth(refit, pm, matrix_truth, r$name)
  expect_equal(jm$y_true, j$y_true)
  expect_equal(jm$n_trials, j$n_trials)
  result <- suppressMessages(suppressWarnings(.cv_run(
    fit,
    fit$data,
    c('.succ_wide_', '.fail_wide_'),
    3,
    1496
  )))
  expect_equal(result$meta$n_failed, 0)
  expect_equal(
    as.numeric(tapply(result$per_trait$n, result$per_trait$fold, sum)),
    result$per_fold$n_heldout
  )
  expect_true(all(is.finite(result$per_trait$LogScore)))
})

test_that('Bernoulli compatibility, ties, endpoints and empty trial groups are explicit', {
  y <- c(0, 1, 0, 1)
  p <- c(.1, .8, .8, .8)
  j <- data.frame(
    trait = 'a',
    family_id = 1L,
    y_true = y,
    n_trials = 1,
    est = p,
    disp = NA_real_
  )
  sc <- .cv_score(j)$by_trait
  expect_equal(sc$RMSE, .cv_rmse(y, p))
  expect_equal(sc$Brier, mean((y - p)^2))
  expect_equal(sc$AUC, .cv_auc(y, p))
  expect_equal(sc$TjurR2, .cv_tjur_r2(y, p))
  j$est <- .5
  expect_equal(.cv_score(j)$by_trait$AUC, .5)
  j$est <- y
  expect_equal(.cv_score(j)$by_trait$Brier, 0)
  j$y_true <- 0
  j$n_trials <- 0
  expect_true(all(is.na(.cv_score(j)$by_trait[, c(
    'RMSE',
    'Brier',
    'AUC',
    'TjurR2'
  )])))
})

test_that('CV refuses missing fitted predictors rather than using formula environments', {
  fit <- .cv_binomial_fixture()
  bad <- fit$data
  bad$env_1 <- NULL
  env_1 <- rep(99, nrow(bad))
  expect_error(.cv_run(fit, bad, c('s', 'f'), 3, 1496), 'predictors.*align')
})
