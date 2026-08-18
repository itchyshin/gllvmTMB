b0_control <- function(...) {
  screen_control(
    rare_warn_n = 0,
    rare_strong_n = 0,
    separation = "fixed",
    ...
  )
}

b0_data <- function(y, x = seq_along(y)) {
  data.frame(
    unit = factor(seq_along(y)),
    trait = factor("a"),
    y = y,
    x = x
  )
}

skip_without_detector <- function() {
  skip_if_not_installed("detectseparation")
  skip_if(
    utils::packageVersion("detectseparation") < numeric_version("0.4.0"),
    "detectseparation >= 0.4.0 is required"
  )
}

test_that("separation = none leaves existing screen output unchanged", {
  local_mocked_bindings(
    .screen_detectseparation_state = function() stop("detector was called"),
    .package = "gllvmTMB"
  )
  df <- b0_data(rep(c(0, 1), 10), rep(c(-1, 1), 10))
  scr <- screen_gllvmTMB(
    y ~ 1,
    data = df,
    trait = "trait",
    family = binomial(),
    control = screen_control(rare_warn_n = 0, rare_strong_n = 0)
  )

  expect_equal(nrow(screen_table(scr, "separation")), 0L)
  expect_equal(
    capture.output(print(scr)),
    c(
      "gllvmTMB pre-fit response screen",
      "  NOT_CHECKED 2 | PASS 3",
      "  No pre-fit FAIL/WARN recommendations."
    )
  )
})

test_that("fixed separation classifies all links", {
  skip_without_detector()
  fixtures <- list(
    overlap = list(x = c(-2, -1, 1, 2), y = c(0, 1, 0, 1),
                   severity = "overlap", status = "PASS"),
    complete = list(x = c(-2, -1, 1, 2), y = c(0, 0, 1, 1),
                    severity = "complete", status = "WARN"),
    quasi = list(x = c(-1, 0, 0, 1), y = c(0, 0, 1, 1),
                 severity = "quasi_complete", status = "WARN")
  )

  for (link in c("logit", "probit", "cloglog")) {
    for (fixture in fixtures) {
      scr <- screen_gllvmTMB(
        y ~ 1 + x,
        data = b0_data(fixture$y, fixture$x),
        trait = "trait",
        family = binomial(link = link),
        control = b0_control()
      )
      sep <- screen_table(scr, "separation")
      expect_equal(sep$status, fixture$status, info = link)
      expect_equal(sep$severity, fixture$severity, info = link)
      expect_equal(sep$link, link)
    }
  }
})

test_that("sparse prevalence is distinct from separation", {
  skip_without_detector()
  separated <- b0_data(c(rep(0, 9), 1), seq_len(10))
  overlap <- b0_data(c(1, rep(0, 8), 1), seq_len(10))

  separated_scr <- screen_gllvmTMB(
    y ~ 1 + x, separated, trait = "trait", family = binomial(),
    control = b0_control()
  )
  overlap_scr <- screen_gllvmTMB(
    y ~ 1 + x, overlap, trait = "trait", family = binomial(),
    control = b0_control()
  )

  expect_equal(screen_table(separated_scr, "separation")$severity, "complete")
  expect_equal(screen_table(overlap_scr, "separation")$severity, "overlap")
})

test_that("constant and rank-deficient blocks are not certificates", {
  constant_zero <- screen_gllvmTMB(
    y ~ 1 + x, b0_data(rep(0, 5)), trait = "trait", family = binomial(),
    control = b0_control()
  )
  constant_one <- screen_gllvmTMB(
    y ~ 1 + x, b0_data(rep(1, 5)), trait = "trait", family = binomial(),
    control = b0_control()
  )
  aliased <- b0_data(c(0, 1, 0, 1), c(-1, 0, 1, 2))
  aliased$x_copy <- aliased$x
  aliased_scr <- screen_gllvmTMB(
    y ~ 1 + x + x_copy,
    aliased,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )

  expect_equal(
    screen_table(constant_zero, "separation")$severity,
    "constant_response"
  )
  expect_equal(
    screen_table(constant_one, "separation")$severity,
    "constant_response"
  )
  expect_equal(
    screen_table(aliased_scr, "separation")$severity,
    "rank_deficient"
  )
  expect_equal(screen_table(aliased_scr, "separation")$status, "NOT_CHECKED")
})

test_that("maximal blocks respect shared and pinned coefficients", {
  skip_without_detector()
  x <- c(-2, -1, 1, 2)
  dat <- data.frame(
    unit = factor(rep(seq_along(x), 2)),
    trait = factor(rep(c("a", "b"), each = length(x))),
    y = c(0, 0, 1, 1, 1, 1, 0, 0),
    x = rep(x, 2)
  )
  shared <- screen_gllvmTMB(
    y ~ 0 + trait + x,
    dat,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )
  pinned <- screen_gllvmTMB(
    y ~ 0 + trait + x,
    dat,
    trait = "trait",
    family = binomial(),
    control = b0_control(),
    Xcoef_fixed = c(x = 0)
  )

  shared_sep <- screen_table(shared, "separation")
  pinned_sep <- screen_table(pinned, "separation")
  expect_equal(nrow(shared_sep), 1L)
  expect_equal(shared_sep$n_traits, 2L)
  expect_equal(shared_sep$severity, "overlap")
  expect_equal(nrow(pinned_sep), 2L)
  expect_equal(pinned_sep$n_traits, c(1L, 1L))
  expect_match(pinned_sep$pinned_zero_terms, "x")
})

test_that("structural-zero columns are removed before rank checking", {
  skip_without_detector()
  dat <- b0_data(rep(c(0, 1), 4), rep(c(-1, 1), 4))
  dat$z <- 0
  scr <- screen_gllvmTMB(
    y ~ 1 + z,
    dat,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )
  sep <- screen_table(scr, "separation")
  design <- screen_table(scr, "design")

  expect_equal(sep$status, "PASS")
  expect_equal(sep$n_columns_active, 1L)
  expect_match(sep$structural_zero_terms, "z")
  expect_equal(
    design$status[design$component == "fixed_effect_rank"],
    "PASS"
  )
})

test_that("missing, old, and failed detectors return NOT_CHECKED", {
  df <- b0_data(c(0, 1, 0, 1), c(-2, -1, 1, 2))
  missing_state <- function() list(
    ok = FALSE,
    severity = "dependency_missing",
    action = "install_or_disable_separation",
    message = "install detector"
  )
  local_mocked_bindings(
    .screen_detectseparation_state = missing_state,
    .package = "gllvmTMB"
  )
  missing_scr <- screen_gllvmTMB(
    y ~ 1 + x, df, trait = "trait", family = binomial(),
    control = b0_control()
  )
  expect_equal(screen_table(missing_scr, "separation")$status, "NOT_CHECKED")
  expect_equal(
    screen_table(missing_scr, "separation")$severity,
    "dependency_missing"
  )

  local_mocked_bindings(
    .screen_detectseparation_state = function() list(
      ok = FALSE,
      severity = "dependency_too_old",
      action = "update_or_disable_separation",
      message = "old detector"
    ),
    .package = "gllvmTMB"
  )
  old_scr <- screen_gllvmTMB(
    y ~ 1 + x, df, trait = "trait", family = binomial(),
    control = b0_control()
  )
  expect_equal(
    screen_table(old_scr, "separation")$severity,
    "dependency_too_old"
  )

  local_mocked_bindings(
    .screen_detectseparation_state = function() list(ok = TRUE),
    .screen_run_detectseparation = function(...) stop("LP failed"),
    .package = "gllvmTMB"
  )
  failed_scr <- screen_gllvmTMB(
    y ~ 1 + x, df, trait = "trait", family = binomial(),
    control = b0_control()
  )
  expect_equal(screen_table(failed_scr, "separation")$severity, "solver_failure")
  expect_match(screen_table(failed_scr, "separation")$message, "LP failed")
})

test_that("indeterminate detector certificates fail closed", {
  df <- b0_data(c(0, 1, 0, 1), c(-2, -1, 1, 2))
  local_mocked_bindings(
    .screen_detectseparation_state = function() list(ok = TRUE),
    .screen_run_detectseparation = function(...) list(
      outcome = NA,
      complete = NA,
      coefficients = c(`(Intercept)` = 0, x = 0)
    ),
    .package = "gllvmTMB"
  )
  outcome_unknown <- screen_gllvmTMB(
    y ~ 1 + x, df, trait = "trait", family = binomial(),
    control = b0_control()
  )
  expect_equal(
    screen_table(outcome_unknown, "separation")$severity,
    "solver_failure"
  )

  local_mocked_bindings(
    .screen_run_detectseparation = function(...) list(
      outcome = TRUE,
      complete = NA,
      coefficients = c(`(Intercept)` = 0, x = Inf)
    ),
    .package = "gllvmTMB"
  )
  subtype_unknown <- screen_gllvmTMB(
    y ~ 1 + x, df, trait = "trait", family = binomial(),
    control = b0_control()
  )
  expect_equal(
    screen_table(subtype_unknown, "separation")$severity,
    "solver_failure"
  )
  expect_equal(
    screen_table(subtype_unknown, "separation")$status,
    "NOT_CHECKED"
  )
})

test_that("unsupported response and predictor shapes stay visible", {
  dat <- b0_data(c(0, 1, 0, 1), c(-2, -1, 1, 2))
  weighted <- screen_gllvmTMB(
    y ~ 1 + x,
    dat,
    trait = "trait",
    weights = rep(1, nrow(dat)),
    family = binomial(),
    control = b0_control()
  )
  grouped_dat <- transform(dat, success = y, failure = 2 - y)
  grouped <- screen_gllvmTMB(
    cbind(success, failure) ~ 1 + x,
    grouped_dat,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )
  missing_x <- dat
  missing_x$x[[2L]] <- NA_real_
  missing_predictor <- screen_gllvmTMB(
    y ~ 1 + x,
    missing_x,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )

  expect_equal(screen_table(weighted, "separation")$severity, "grouped_binomial")
  expect_equal(screen_table(grouped, "separation")$severity, "grouped_binomial")
  expect_equal(
    screen_table(missing_predictor, "separation")$severity,
    "missing_predictor"
  )
})

test_that("finite known offsets are admitted for every binary link", {
  skip_without_detector()
  dat <- b0_data(c(0, 1, 0, 1), c(-2, -1, 1, 2))
  dat$off <- c(1, -0.5, 0.25, -1)
  for (link in c("logit", "probit", "cloglog")) {
    scr <- screen_gllvmTMB(
      y ~ 1 + x + offset(off),
      dat,
      trait = "trait",
      family = binomial(link = link),
      control = b0_control()
    )
    sep <- screen_table(scr, "separation")
    expect_equal(sep$severity, "overlap", info = link)
    expect_true(sep$has_offset, info = link)
  }
})

test_that("missing response drop and include use the same observed cells", {
  skip_without_detector()
  dat <- b0_data(c(0, 1, NA, 0, 1), c(-2, -1, 0, 1, 2))
  drop <- suppressMessages(screen_gllvmTMB(
    y ~ 1 + x,
    dat,
    trait = "trait",
    family = binomial(),
    missing = miss_control(response = "drop"),
    control = b0_control()
  ))
  include <- screen_gllvmTMB(
    y ~ 1 + x,
    dat,
    trait = "trait",
    family = binomial(),
    missing = miss_control(response = "include"),
    control = b0_control()
  )

  expect_equal(
    screen_table(drop, "separation"),
    screen_table(include, "separation")
  )
})

test_that("long and wide fixed designs produce the same certificates", {
  skip_without_detector()
  wide <- data.frame(
    unit = factor(seq_len(6)),
    x = c(-2, -1, 0, 0, 1, 2),
    a = c(0, 0, 0, 1, 1, 1),
    b = c(1, 1, 1, 0, 0, 0)
  )
  long <- data.frame(
    unit = rep(wide$unit, times = 2),
    trait = factor(rep(c("a", "b"), each = nrow(wide))),
    x = rep(wide$x, times = 2),
    y = c(wide$a, wide$b)
  )
  wide_scr <- screen_gllvmTMB(
    traits(a, b) ~ x,
    wide,
    unit = "unit",
    family = binomial(),
    control = b0_control()
  )
  long_scr <- screen_gllvmTMB(
    y ~ 0 + trait:x,
    long,
    unit = "unit",
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )

  keep <- c("traits", "n_traits", "n_observed", "n_columns_active",
            "status", "severity")
  expect_equal(
    screen_table(wide_scr, "separation")[keep],
    screen_table(long_scr, "separation")[keep]
  )
})

test_that("separation integrates with print and recommendations", {
  skip_without_detector()
  dat <- b0_data(c(rep(0, 10), rep(1, 10)), c(-10:-1, 1:10))
  scr <- screen_gllvmTMB(
    y ~ 1 + x,
    dat,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )
  rec <- screen_table(scr, "recommendations")
  printed <- capture.output(print(scr))

  expect_equal(rec$scope[rec$scope == "separation"], "separation")
  expect_equal(rec$action[rec$scope == "separation"], "consider_penalized_fit")
  expect_true(any(grepl("Fixed-design separation: complete 1", printed)))
})

test_that("no free coefficient and rare factor mappings are explicit", {
  no_free <- b0_data(c(0, 1, 0, 1), c(-1, 0, 1, 2))
  no_free_scr <- screen_gllvmTMB(
    y ~ 0 + x,
    no_free,
    trait = "trait",
    family = binomial(),
    control = b0_control(),
    Xcoef_fixed = c(x = 0)
  )
  expect_equal(
    screen_table(no_free_scr, "separation")$severity,
    "no_free_coefficients"
  )

  skip_without_detector()
  factor_dat <- b0_data(c(0, 1, 0, 1, 1, 1), seq_len(6))
  factor_dat$f <- factor(rep(c("a", "b", "c"), each = 2))
  factor_scr <- screen_gllvmTMB(
    y ~ 1 + f,
    factor_dat,
    trait = "trait",
    family = binomial(),
    control = b0_control()
  )
  sep <- screen_table(factor_scr, "separation")
  expect_equal(sep$severity, "quasi_complete")
  expect_match(sep$infinite_terms, "f")
})
