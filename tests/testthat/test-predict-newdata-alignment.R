## predict(newdata) row alignment, predvars, character levels, and contrasts.
## Failure-before-fix: each test was demonstrated against main 9354ac2f
## (issues #1384, #1423, #1425, #1424). Revert the helpers in
## R/methods-gllvmTMB.R and these fail again.

.alignment_stub_fit <- function(data, form) {
  X_train <- stats::model.matrix(
    stats::delete.response(stats::terms(form)),
    data
  )
  beta <- seq_along(colnames(X_train))
  names(beta) <- colnames(X_train)
  structure(
    list(
      data = data,
      formula = form,
      trait_col = "trait",
      unit_col = "unit",
      species_col = "species",
      X_fix_names = colnames(X_train),
      X_fix = X_train,
      opt = list(par = stats::setNames(
        unname(beta),
        rep("b_fix", length(beta))
      )),
      use = list(),
      tmb_data = list()
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("#1384 predict(newdata) keeps NA in missing-covariate rows and does not recycle", {
  train <- expand.grid(
    unit = factor("u1"),
    species = factor("sp1"),
    trait = factor(c("t1", "t2"), levels = c("t1", "t2")),
    x = c(-1, 1),
    KEEP.OUT.ATTRS = FALSE
  )
  train$value <- 0
  form <- value ~ 0 + trait + x
  fit <- .alignment_stub_fit(train, form)

  nd <- data.frame(
    unit = factor(rep("u1", 4), levels = levels(train$unit)),
    species = factor(rep("sp1", 4), levels = levels(train$species)),
    trait = factor(c("t1", "t1", "t2", "t2"), levels = levels(train$trait)),
    x = c(NA, 1, NA, 1)
  )
  pred <- predict(fit, newdata = nd, re_form = ~0)
  expect_equal(nrow(pred), 4L)
  expect_true(is.na(pred$est[1L]))
  expect_true(is.na(pred$est[3L]))
  expect_false(is.na(pred$est[2L]))
  expect_false(is.na(pred$est[4L]))

  one <- function(i) {
    predict(fit, newdata = nd[i, , drop = FALSE], re_form = ~0)$est
  }
  expect_equal(pred$est[2L], one(2L), tolerance = 1e-10)
  expect_equal(pred$est[4L], one(4L), tolerance = 1e-10)
  ## The recycled-before-fix values swapped t1 and t2 on the complete rows.
  expect_false(isTRUE(all.equal(pred$est[2L], one(4L))))
})

test_that("#1384 real fit: scattered NA rows stay NA; complete rows match row-by-row", {
  set.seed(4)
  n <- 30
  nt <- 3
  d <- data.frame(
    unit = factor(rep(seq_len(n), each = nt)),
    trait = factor(rep(paste0("t", 1:nt), n)),
    x = rnorm(n * nt)
  )
  d$value <- c(1, 0, -1)[as.integer(d$trait)] + 0.8 * d$x +
    rnorm(n * nt, sd = 0.5)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + x,
    data = d, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
  nd <- data.frame(
    unit = factor(c(1, 1, 1, 1), levels = levels(d$unit)),
    trait = factor(c("t1", "t1", "t2", "t2"), levels = levels(d$trait)),
    x = c(NA, 1, NA, 1)
  )
  pred <- suppressMessages(predict(fit, newdata = nd, re_form = ~0))
  expect_equal(nrow(pred), 4L)
  expect_true(is.na(pred$est[1L]))
  expect_true(is.na(pred$est[3L]))
  one <- function(i) {
    suppressMessages(
      predict(fit, newdata = nd[i, , drop = FALSE], re_form = ~0)$est
    )
  }
  expect_equal(pred$est[2L], one(2L), tolerance = 1e-8)
  expect_equal(pred$est[4L], one(4L), tolerance = 1e-8)
})

test_that("#1423 scale() in the formula reuses the training centre and scale", {
  set.seed(2)
  n <- 40
  train <- data.frame(
    unit = factor(rep(seq_len(n), each = 2)),
    species = factor("sp1"),
    trait = factor(rep(c("t1", "t2"), n)),
    x = rep(rnorm(n, 10, 3), each = 2)
  )
  train$value <- 0
  form <- value ~ 0 + trait + scale(x)
  fit <- .alignment_stub_fit(train, form)

  sub <- train[train$unit %in% levels(train$unit)[1:5], ]
  all_nd <- predict(fit, newdata = train, re_form = ~0)
  sub_nd <- predict(fit, newdata = sub, re_form = ~0)
  m <- match(paste(sub$unit, sub$trait), paste(train$unit, train$trait))
  expect_equal(sub_nd$est, all_nd$est[m], tolerance = 1e-10)

  one <- predict(fit, newdata = train[1, , drop = FALSE], re_form = ~0)
  expect_equal(one$est, all_nd$est[1L], tolerance = 1e-10)
})

test_that("#1423 real fit: scale(x) newdata matches in-sample; one-row works", {
  set.seed(2)
  n <- 40
  d <- do.call(rbind, lapply(1:3, function(j) {
    data.frame(unit = factor(seq_len(n)), trait = paste0("t", j))
  }))
  d$trait <- factor(d$trait)
  d$x <- rep(rnorm(n, 10, 3), 3)
  d$value <- 1 + 0.3 * d$x * (d$trait == "t2") + rnorm(nrow(d))
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:scale(x),
    data = d, unit = "unit", trait = "trait",
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
  ins <- suppressMessages(predict(fit, re_form = ~0))
  sub <- d[d$unit %in% levels(d$unit)[1:5], ]
  nd <- suppressMessages(predict(fit, newdata = sub, re_form = ~0))
  m <- match(paste(sub$unit, sub$trait), paste(ins$unit, ins$trait))
  expect_equal(nd$est, ins$est[m], tolerance = 1e-8)
  one <- suppressMessages(predict(fit, newdata = d[1, , drop = FALSE], re_form = ~0))
  expect_equal(one$est, ins$est[1L], tolerance = 1e-8)
})

test_that("#1425 character predictor without the baseline level keeps its own coefficient", {
  set.seed(5)
  n <- 30
  g <- rep(sample(c("a", "b", "c"), n, TRUE), 2)
  train <- data.frame(
    unit = factor(rep(seq_len(n), each = 2)),
    species = factor("sp1"),
    trait = factor(rep(c("t1", "t2"), n)),
    g = g,
    stringsAsFactors = FALSE
  )
  train$value <- 0
  form <- value ~ 0 + trait + g
  fit <- .alignment_stub_fit(train, form)

  rows_b <- which(train$g == "b")[1:3]
  rows_c <- which(train$g == "c")[1:3]
  rows_a <- which(train$g == "a")[1:3]
  with_a <- predict(fit, newdata = train[c(rows_b, rows_a), ], re_form = ~0)
  without_a <- predict(fit, newdata = train[c(rows_b, rows_c), ], re_form = ~0)
  expect_equal(without_a$est[1:3], with_a$est[1:3], tolerance = 1e-10)
})

test_that("#1425 real fit: character g without baseline matches in-sample b rows", {
  set.seed(5)
  n <- 40
  d <- do.call(rbind, lapply(1:3, function(j) {
    data.frame(
      unit = factor(seq_len(n)),
      trait = paste0("t", j),
      stringsAsFactors = FALSE
    )
  }))
  d$trait <- factor(d$trait)
  d$g <- rep(sample(c("a", "b", "c"), n, TRUE), 3)
  d$value <- 1 + 0.8 * (d$g == "b") + rnorm(nrow(d))
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + g,
    data = d, unit = "unit", trait = "trait",
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
  ins <- suppressMessages(predict(fit, re_form = ~0))
  rows_b <- which(d$g == "b")[1:3]
  rows_c <- which(d$g == "c")[1:3]
  nd <- suppressMessages(predict(fit, newdata = d[c(rows_b, rows_c), ], re_form = ~0))
  expect_equal(nd$est[1:3], ins$est[rows_b], tolerance = 1e-8)
})

test_that("#1424 restore_newdata_factor_levels copies user-set contrasts", {
  set.seed(5)
  n <- 30
  g <- factor(rep(sample(c("a", "b", "c"), n, TRUE), 2), levels = c("a", "b", "c"))
  contrasts(g) <- stats::contr.sum(3)
  train <- data.frame(
    unit = factor(rep(seq_len(n), each = 2)),
    species = factor("sp1"),
    trait = factor(rep(c("t1", "t2"), n)),
    g = g
  )
  train$value <- 0
  contrasts(train$g) <- stats::contr.sum(3)
  form <- value ~ 0 + trait + g
  fit <- .alignment_stub_fit(train, form)

  restored <- .gllvmTMB_restore_newdata_factor_levels(train, train)
  expect_equal(contrasts(restored$g), contrasts(train$g), tolerance = 1e-12)

  ins <- predict(fit, re_form = ~0)
  nd <- predict(fit, newdata = train, re_form = ~0)
  expect_equal(nd$est, ins$est, tolerance = 1e-10)
})

test_that("#1424 real fit: contr.sum newdata matches training predictions", {
  set.seed(5)
  n <- 40
  d <- do.call(rbind, lapply(1:3, function(j) {
    data.frame(unit = factor(seq_len(n)), trait = paste0("t", j))
  }))
  d$trait <- factor(d$trait)
  d$g <- factor(rep(sample(c("a", "b", "c"), n, TRUE), 3))
  d$value <- 1 + 0.8 * (d$g == "b") - 0.5 * (d$g == "c") + rnorm(nrow(d))
  contrasts(d$g) <- stats::contr.sum(3)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + g,
    data = d, unit = "unit", trait = "trait",
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
  ins <- suppressMessages(predict(fit, re_form = ~0))
  nd <- suppressMessages(predict(fit, newdata = d, re_form = ~0))
  expect_equal(nd$est, ins$est, tolerance = 1e-8)
})

test_that(".gllvmTMB_predict_fixed_eta aborts when a training column is missing", {
  train <- expand.grid(
    unit = factor("u1"),
    species = factor("sp1"),
    trait = factor(c("t1", "t2")),
    g = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  train$value <- 0
  form <- value ~ 0 + trait + g
  fit <- .alignment_stub_fit(train, form)
  X_short <- stats::model.matrix(~ 0 + trait, train)
  expect_error(
    .gllvmTMB_predict_fixed_eta(fit, X_short),
    class = "gllvmTMB_predict_missing_columns"
  )
})

test_that("simulate(newdata) inherits NA row alignment from predict()", {
  set.seed(4)
  n <- 20
  d <- data.frame(
    unit = factor(rep(seq_len(n), each = 2)),
    trait = factor(rep(c("t1", "t2"), n)),
    x = rnorm(n * 2)
  )
  d$value <- as.numeric(d$trait) + 0.5 * d$x + rnorm(nrow(d), sd = 0.3)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + x,
    data = d, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
  nd <- data.frame(
    unit = factor(c(1, 1, 1), levels = levels(d$unit)),
    trait = factor(c("t1", "t1", "t2"), levels = levels(d$trait)),
    x = c(NA, 0.5, NA)
  )
  sim <- suppressWarnings(simulate(fit, newdata = nd, nsim = 1L))
  expect_equal(nrow(sim), 3L)
  expect_true(is.na(sim[1L, 1L]))
  expect_true(is.na(sim[3L, 1L]))
  expect_false(is.na(sim[2L, 1L]))
})
