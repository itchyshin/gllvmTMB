.test_cursor_unpack_rr <- function(theta, p, rank) {
  expected <- p * rank - rank * (rank - 1L) / 2L
  stopifnot(length(theta) == expected, rank >= 1L, rank <= p)
  ans <- matrix(0, p, rank)
  cursor <- 1L
  for (column in seq_len(rank)) {
    ans[column, column] <- theta[cursor]
    cursor <- cursor + 1L
  }
  for (column in seq_len(rank)) {
    if (column < p) {
      for (row in seq.int(column + 1L, p)) {
        ans[row, column] <- theta[cursor]
        cursor <- cursor + 1L
      }
    }
  }
  stopifnot(cursor == length(theta) + 1L)
  ans
}

test_that("cursor loading unpack matches explicit packed-coordinate examples", {
  cases <- list(
    list(
      theta = 1:2,
      expected = matrix(c(1, 2), 2L, 1L)
    ),
    list(
      theta = 1:7,
      expected = matrix(c(
        1, 0,
        3, 2,
        4, 6,
        5, 7
      ), 4L, 2L, byrow = TRUE)
    ),
    list(
      theta = 1:12,
      expected = matrix(c(
        1,  0,  0,
        4,  2,  0,
        5,  8,  3,
        6,  9, 11,
        7, 10, 12
      ), 5L, 3L, byrow = TRUE)
    ),
    list(
      theta = 1:15,
      expected = matrix(c(
        1,  0,  0,  0, 0,
        6,  2,  0,  0, 0,
        7, 10,  3,  0, 0,
        8, 11, 13,  4, 0,
        9, 12, 14, 15, 5
      ), 5L, 5L, byrow = TRUE)
    )
  )
  for (case in cases) {
    expect_identical(
      .test_cursor_unpack_rr(
        case$theta,
        nrow(case$expected),
        ncol(case$expected)
      ),
      case$expected
    )
  }
})

test_that("the R loading-constraint index follows the explicit cursor order", {
  expected <- matrix(c(
     1, NA, NA,
     4,  2, NA,
     5,  8,  3,
     6,  9, 11,
     7, 10, 12
  ), 5L, 3L, byrow = TRUE)
  observed <- matrix(NA_integer_, 5L, 3L)
  for (row in seq_len(5L)) {
    for (column in seq_len(3L)) {
      observed[row, column] <- lambda_packed_index(
        row - 1L,
        column - 1L,
        p = 5L,
        rank = 3L
      )
    }
  }
  expect_equal(observed, expected, tolerance = 0)
})

test_that("the compiled ordinary latent route reports the exact packed loading", {
  set.seed(7301)
  p <- 5L
  rank <- 3L
  dat <- expand.grid(
    unit = factor(sprintf("u%02d", seq_len(12L))),
    trait = factor(sprintf("t%02d", seq_len(p)))
  )
  dat$value <- rnorm(nrow(dat))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = rank,
                               unique = FALSE),
    data = dat,
    unit = "unit"
  )))
  obj <- fit$tmb_obj
  par <- obj$par
  rr_at <- which(names(par) == "theta_rr_B")
  n_theta <- p * rank - rank * (rank - 1L) / 2L
  expect_length(rr_at, n_theta)

  theta <- seq_len(n_theta) / 10 - 0.7
  par[rr_at] <- theta
  full_par <- obj$env$last.par.best
  full_rr_at <- which(names(full_par) == "theta_rr_B")
  expect_length(full_rr_at, n_theta)
  full_par[full_rr_at] <- theta
  report <- obj$report(full_par)
  expected <- .test_cursor_unpack_rr(theta, p, rank)

  expect_equal(report$Lambda_B, expected, tolerance = 0)
  ## dep() reuses this full-rank packed factor. Its diagonal is deliberately
  ## unconstrained; it is not exponentiated into a canonical Cholesky factor.
  expect_true(all(diag(report$Lambda_B) < 0))
  expect_equal(report$Sigma_B, tcrossprod(expected), tolerance = 1e-12)
  reflected <- expected
  reflected[, 1L] <- -reflected[, 1L]
  expect_equal(tcrossprod(reflected), report$Sigma_B, tolerance = 1e-12)
  expect_true(is.finite(obj$fn(par)))
  expect_true(all(is.finite(obj$gr(par))))
})

test_that("the compiled VA route reports the same documented packed loading", {
  skip_on_cran()
  set.seed(7302)
  N <- 4L
  p <- 5L
  rank <- 3L
  validated <- .va_r3_validate_data(
    y = rnorm(N * p),
    n_trials = rep(1L, N * p),
    X = matrix(1, N * p, 1L),
    unit_id = rep(seq_len(N), each = p),
    trait_id = rep(seq_len(p), times = N),
    q = rank,
    family = "gaussian",
    link = "identity"
  )
  parameters <- .va_r3_default_parameters(validated)
  n_theta <- p * rank - rank * (rank - 1L) / 2L
  theta <- seq_len(n_theta) / 10 - 0.7
  parameters$theta_rr[] <- theta
  obj <- .va_r3_make_objective(
    validated,
    H = 7L,
    parameters = parameters,
    eval_method = "gh",
    rebuild = TRUE,
    silent = TRUE
  )
  report <- obj$report(obj$par)
  expected <- .test_cursor_unpack_rr(theta, p, rank)

  expect_equal(report$Lambda, expected, tolerance = 0)
  expect_equal(report$Sigma_B, tcrossprod(expected), tolerance = 1e-12)
  expect_true(is.finite(obj$fn(obj$par)))
  expect_true(all(is.finite(obj$gr(obj$par))))
})

test_that("the compiled EVA route reports the same documented packed loading", {
  skip_on_cran()
  skip_if_not_installed("jsonlite")
  obj <- .eva_make_objective("bernoulli_q2", rebuild = TRUE)
  par <- obj$par
  rr_at <- which(names(par) == "theta_rr")
  theta <- seq_along(rr_at) / 10 - 0.4
  par[rr_at] <- theta
  report <- obj$report(par)
  expected <- .test_cursor_unpack_rr(
    theta,
    nrow(report$Lambda),
    ncol(report$Lambda)
  )

  expect_equal(report$Lambda, expected, tolerance = 0)
  expect_true(all(is.finite(tcrossprod(report$Lambda))))
  expect_true(is.finite(obj$fn(par)))
  expect_true(all(is.finite(obj$gr(par))))
})

test_that("the Laplace, VA, and EVA loading routes use cursor-based unpacking", {
  source_paths <- c(
    engine = testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    va_engine = testthat::test_path(
      "..", "..", "inst", "tmb", "gllvmTMB_va_r3.cpp"
    ),
    eva_engine = testthat::test_path(
      "..", "..", "inst", "tmb", "gllvmTMB_eva.cpp"
    ),
    constraint_source = testthat::test_path(
      "..", "..", "R", "lambda-constraint.R"
    ),
    phylo_slope_test = testthat::test_path(
      "test-phylo-latent-slope-gaussian.R"
    )
  )
  skip_if_not(
    all(file.exists(source_paths)),
    "Repository-only source provenance scan is unavailable after installation"
  )
  sources <- lapply(source_paths, readLines, warn = FALSE)
  engine <- sources$engine
  va_engine <- sources$va_engine
  eva_engine <- sources$eva_engine
  constraint_source <- sources$constraint_source
  phylo_slope_test <- sources$phylo_slope_test
  calls <- grep("gll_unpack_rr_loadings\\(", engine, value = TRUE)
  expect_length(calls, 9L) # one definition plus eight engine routes
  expect_false(any(grepl("lam_lower\\(", engine, fixed = FALSE)))
  expect_false(any(grepl("lam_lower\\(", va_engine, fixed = FALSE)))
  expect_false(any(grepl("lam_lower\\(", eva_engine, fixed = FALSE)))
  expect_false(any(grepl("triangular <-", constraint_source, fixed = TRUE)))
  expect_false(any(grepl("lam_lower <-", phylo_slope_test, fixed = TRUE)))
  expect_false(any(grepl("direct port from glmmTMB", engine, fixed = TRUE)))
  expect_true(any(grepl("theta_cursor", va_engine, fixed = TRUE)))
  expect_true(any(grepl("loading_cursor", eva_engine, fixed = TRUE)))
  expect_true(any(grepl("cursor <- rank + 1L", constraint_source, fixed = TRUE)))
})
