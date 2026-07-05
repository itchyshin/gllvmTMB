test_that("kernel_latent() emits an automatic kernel Psi companion by default", {
  A <- diag(3)
  rownames(A) <- colnames(A) <- paste0("u", seq_len(3))

  f <- ~ 1 + kernel_latent(unit_id, K = A, d = 2, name = "known")
  environment(f) <- environment()
  p <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::rewrite_canonical_aliases(f)
  )

  expect_length(p$covstructs, 2L)
  expect_equal(p$covstructs[[1L]]$kind, "phylo_rr")
  expect_equal(p$covstructs[[1L]]$extra$d, 2)
  expect_equal(p$covstructs[[1L]]$extra$.kernel_name, "known")
  expect_equal(p$covstructs[[1L]]$extra$.kernel_mode, "latent")
  expect_equal(p$covstructs[[1L]]$extra$vcv, A)

  expect_equal(p$covstructs[[2L]]$kind, "phylo_rr")
  expect_true(isTRUE(p$covstructs[[2L]]$extra$.phylo_unique))
  expect_true(isTRUE(p$covstructs[[2L]]$extra$.auto_unique))
  expect_equal(p$covstructs[[2L]]$extra$.kernel_name, "known")
  expect_equal(p$covstructs[[2L]]$extra$.kernel_mode, "unique")
  expect_equal(p$covstructs[[2L]]$extra$vcv, A)
})

test_that("kernel_latent(unique = FALSE) keeps the loadings-only route", {
  A <- diag(3)
  rownames(A) <- colnames(A) <- paste0("u", seq_len(3))

  f <- ~ 1 +
    kernel_latent(
      unit_id,
      K = A,
      d = 2,
      name = "known",
      unique = FALSE
    )
  environment(f) <- environment()
  p <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::rewrite_canonical_aliases(f)
  )

  expect_length(p$covstructs, 1L)
  expect_equal(p$covstructs[[1L]]$kind, "phylo_rr")
  expect_equal(p$covstructs[[1L]]$extra$d, 2)
  expect_equal(p$covstructs[[1L]]$extra$.kernel_name, "known")
  expect_equal(p$covstructs[[1L]]$extra$.kernel_mode, "latent")
  expect_null(p$covstructs[[1L]]$extra$.phylo_unique)
})

test_that("kernel_latent() rejects malformed unique values", {
  A <- diag(3)
  rownames(A) <- colnames(A) <- paste0("u", seq_len(3))

  f <- ~ 1 + kernel_latent(unit_id, K = A, unique = NA, name = "known")
  environment(f) <- environment()
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(f),
    "unique.*kernel_latent"
  )
})

test_that("kernel_latent() folded default is equivalent to explicit pair", {
  testthat::skip_if_not_installed("TMB")

  set.seed(31)
  n_unit <- 7L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.25, n_unit, n_unit)
  diag(A) <- 1
  rownames(A) <- colnames(A) <- unit_levels

  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)

  L_A <- t(chol(A + diag(1e-8, n_unit)))
  scores <- L_A %*% matrix(stats::rnorm(n_unit * 2L), n_unit, 2L)
  Lambda <- matrix(c(0.7, 0.0, 0.25, 0.6, -0.15, 0.45), 3, 2, byrow = TRUE)
  eta_unit <- scores %*% t(Lambda)
  colnames(eta_unit) <- c("y1", "y2", "y3")
  eta <- eta_unit[as.integer(rows$unit_id), , drop = FALSE]
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.2)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.2)
  rows$y3 <- eta[, 3L] + stats::rnorm(nrow(rows), sd = 0.2)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_default <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~
      1 +
      kernel_latent(unit_id, K = A, d = 2, name = "known"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_explicit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~
      1 +
      kernel_latent(unit_id, K = A, d = 2, name = "known", unique = FALSE) +
      kernel_unique(unit_id, K = A, name = "known"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit_default$opt$convergence, 0L)
  expect_equal(fit_explicit$opt$convergence, 0L)
  expect_lt(
    abs(
      as.numeric(stats::logLik(fit_default)) -
        as.numeric(stats::logLik(fit_explicit))
    ),
    1e-6
  )
  expect_equal(
    suppressMessages(
      gllvmTMB::extract_Sigma(
        fit_default,
        level = "known",
        part = "total"
      )$Sigma
    ),
    suppressMessages(
      gllvmTMB::extract_Sigma(
        fit_explicit,
        level = "known",
        part = "total"
      )$Sigma
    ),
    tolerance = 1e-6
  )
})
