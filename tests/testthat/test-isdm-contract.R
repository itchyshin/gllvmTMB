.isdm_rows <- function() {
  data.frame(
    cell_id = c("c1", "c2", "c3"),
    trait = c("sp1", "sp1", "sp2"),
    source = c("gbif", "survey", "survey"),
    survey_event_id = c(NA, "e1", "e2"),
    branch = c("count", "pa", "pa"),
    value = c(1, 0, 1),
    support = c(4, 2, 5)
  )
}

.isdm_X <- function(n = 3L) {
  matrix(seq_len(n), ncol = 1L, dimnames = list(NULL, "elevation"))
}

.isdm_B <- function() {
  matrix(c(0.2, NA, NA), ncol = 1L, dimnames = list(NULL, "road_bias"))
}

test_that("the two-source iSDM contract normalises the two branches", {
  got <- .prepare_isdm_contract(.isdm_rows(), X = .isdm_X(), B = .isdm_B())

  expect_identical(got$rows$trait, c("sp1", "sp1", "sp2"))
  expect_identical(got$rows$family, c("poisson", "binomial", "binomial"))
  expect_identical(got$rows$link, c("log", "cloglog", "cloglog"))
  expect_equal(got$rows$log_support, log(c(4, 2, 5)))
  expect_identical(got$gbif_row, 1L)
  expect_identical(got$survey_row, c(2L, 3L))
  expect_equal(unname(got$B_gbif[, "road_bias"]), 0.2)
})

test_that("the contract accepts species as the single trait identifier", {
  rows <- .isdm_rows()
  names(rows)[names(rows) == "trait"] <- "species"
  got <- .prepare_isdm_contract(rows, X = .isdm_X(), B = .isdm_B())

  expect_identical(got$rows$trait, c("sp1", "sp1", "sp2"))
})

test_that("the contract rejects malformed source, branch, support, and designs", {
  rows <- .isdm_rows()
  rows$source[1] <- "atlas"
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
  )

  rows <- .isdm_rows()
  rows$branch[1] <- "pa"
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
  )

  rows <- .isdm_rows()
  rows$support[1] <- 0
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
  )

  bad_x <- .isdm_X()
  bad_x[1] <- Inf
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(.isdm_rows(), bad_x, .isdm_B())
  )
})

test_that("the contract rejects incompatible observation records", {
  rows <- .isdm_rows()
  rows$survey_event_id[1] <- "e0"
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
  )

  rows <- .isdm_rows()
  rows$value[2] <- 2
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
  )

  rows <- .isdm_rows()
  count_duplicate <- rows[2, ]
  count_duplicate$branch <- "pa"
  count_duplicate$value <- 1
  rows <- rbind(rows, count_duplicate)
  X <- rbind(.isdm_X(), 4)
  colnames(X) <- "elevation"
  B <- rbind(.isdm_B(), NA_real_)
  colnames(B) <- "road_bias"
  expect_snapshot(error = TRUE, .prepare_isdm_contract(rows, X, B))
})

test_that("survey alternatives are branch-pure and ecological X is cell-level", {
  rows <- .isdm_rows()
  rows$branch[3] <- "count"
  rows$value[3] <- 2
  expect_error(
    .prepare_isdm_contract(rows, .isdm_X(), .isdm_B()),
    "exactly one survey branch"
  )

  rows <- .isdm_rows()
  rows$branch[2:3] <- "count"
  rows$value[2:3] <- c(0, 3)
  got <- .prepare_isdm_contract(rows, .isdm_X(), .isdm_B())
  expect_identical(got$rows$family, rep("poisson", 3L))

  rows <- .isdm_rows()
  rows$cell_id[] <- "one_cell"
  X <- .isdm_X()
  X[2, 1] <- X[1, 1] + 1
  expect_error(
    .prepare_isdm_contract(rows, X, .isdm_B()),
    "ecological and cell-level"
  )
})

test_that("B remains GBIF-only", {
  B <- .isdm_B()
  B[2] <- 0
  expect_snapshot(
    error = TRUE,
    .prepare_isdm_contract(.isdm_rows(), .isdm_X(), B)
  )
})

test_that("independent oracle gates GBIF bias and uses known support", {
  rows <- .prepare_isdm_contract(.isdm_rows(), .isdm_X(), .isdm_B())$rows
  eta_ecological <- c(-0.2, 0.1, 0.3)
  baseline <- .isdm_observation_nll(rows, eta_ecological, eta_gbif_bias = 0)
  changed <- .isdm_observation_nll(
    rows, eta_ecological,
    eta_gbif_bias = c(log(2), -10, 10)
  )

  expect_false(isTRUE(all.equal(baseline$gbif_nll, changed$gbif_nll)))
  expect_identical(baseline$survey_nll, changed$survey_nll)
  expect_equal(
    baseline$nll,
    baseline$gbif_nll + baseline$survey_nll
  )
  expect_equal(
    baseline$log_lik[1],
    stats::dpois(1, lambda = 4 * exp(-0.2), log = TRUE)
  )
  expect_equal(
    baseline$log_lik[2],
    stats::dbinom(
      0, size = 1L,
      prob = 1 - exp(-2 * exp(0.1)), log = TRUE
    )
  )
})
