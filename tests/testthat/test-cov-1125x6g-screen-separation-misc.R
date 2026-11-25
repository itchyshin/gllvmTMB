test_that(".screen_empty_separation schema is stable", {
  empty <- .screen_empty_separation()
  expect_equal(nrow(empty), 0L)
  expect_true(all(c("status", "separated", "action") %in% names(empty)))
  expect_s3_class(empty, "data.frame")
})

test_that(".screen_recommend_from_separation maps rows to recommendations", {
  sep <- data.frame(
    traits = "tA",
    status = "OK",
    action = "none",
    message = "ok",
    stringsAsFactors = FALSE
  )
  rec <- .screen_recommend_from_separation(sep)
  expect_equal(nrow(rec), 1L)
  expect_equal(rec$scope, "separation")
  expect_true(nzchar(rec$model_implication))
  empty_rec <- .screen_recommend_from_separation(.screen_empty_separation())
  expect_equal(nrow(empty_rec), 0L)
  warn <- .screen_recommend_from_separation(data.frame(
    traits = "t",
    status = "WARN",
    action = "check",
    message = "sep",
    stringsAsFactors = FALSE
  ))
  expect_match(warn$model_implication, "separation", ignore.case = TRUE)
})

test_that(".screen_detectseparation_state reports dependency availability", {
  st <- .screen_detectseparation_state()
  expect_type(st, "list")
  if (st$ok) {
    expect_true(st$ok)
  } else {
    expect_true(nzchar(st$message))
    expect_true(nzchar(st$action))
  }
})

test_that(".screen_fixed_blocks splits trait support", {
  X <- cbind(
    intercept = 1,
    x1 = c(1, 0, 1, 0),
    x2 = c(0, 1, 0, 1)
  )
  trait <- factor(c("A", "A", "B", "B"))
  observed <- rep(TRUE, 4)
  active <- c(TRUE, TRUE, FALSE)
  bl <- .screen_fixed_blocks(X, trait, observed, active)
  expect_type(bl, "list")
  expect_true(length(bl$blocks) >= 1L)
  expect_error(
    .screen_fixed_blocks(X, trait, observed, active[-1]),
    regexp = "."
  )
})