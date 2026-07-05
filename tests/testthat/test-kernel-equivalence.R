test_that("kernel_latent + kernel_unique is equivalent to dense phylo vcv path", {
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  set.seed(11)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.35, n_unit, n_unit)
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
  Lambda <- matrix(c(0.8, 0.0, 0.3, 0.7, -0.2, 0.5), 3, 2, byrow = TRUE)
  eta_unit <- scores %*% t(Lambda)
  colnames(eta_unit) <- c("y1", "y2", "y3")
  eta <- eta_unit[as.integer(rows$unit_id), , drop = FALSE]
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y3 <- eta[, 3L] + stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_phy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~
      1 +
      phylo_latent(unit_id, d = 2, vcv = A) +
      phylo_unique(unit_id, vcv = A),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_kernel <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~
      1 +
      kernel_latent(unit_id, K = A, d = 2, name = "known") +
      kernel_unique(unit_id, K = A, name = "known"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit_phy$opt$convergence, 0L)
  expect_equal(fit_kernel$opt$convergence, 0L)
  expect_true(isTRUE(fit_kernel$use$kernel))
  expect_equal(fit_kernel$kernel_levels$name, "known")
  expect_equal(fit_phy$tmb_data$n_aug_phy, fit_kernel$tmb_data$n_aug_phy)
  expect_equal(fit_phy$tmb_data$d_phy, fit_kernel$tmb_data$d_phy)
  expect_lt(
    abs(
      as.numeric(stats::logLik(fit_phy)) -
        as.numeric(stats::logLik(fit_kernel))
    ),
    1e-6
  )

  Sigma_phy <- suppressMessages(
    gllvmTMB::extract_Sigma(
      fit_phy,
      level = "phy",
      part = "total"
    )$Sigma
  )
  Sigma_kernel <- suppressMessages(
    gllvmTMB::extract_Sigma(
      fit_kernel,
      level = "known",
      part = "total"
    )$Sigma
  )
  expect_equal(Sigma_kernel, Sigma_phy, tolerance = 1e-6)
  expect_equal(
    suppressMessages(
      gllvmTMB::extract_Sigma(
        fit_kernel,
        level = "known",
        part = "total"
      )$level
    ),
    "known"
  )
})

test_that("kernel companion modes carry dense-K metadata through the parser", {
  A <- diag(3)
  rownames(A) <- colnames(A) <- paste0("u", seq_len(3))

  f_indep <- ~ 1 + kernel_indep(unit_id, K = A, name = "known")
  environment(f_indep) <- environment()
  p_indep <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::rewrite_canonical_aliases(f_indep)
  )
  expect_equal(p_indep$covstructs[[1L]]$kind, "phylo_rr")
  expect_true(isTRUE(p_indep$covstructs[[1L]]$extra$.phylo_unique))
  expect_true(isTRUE(p_indep$covstructs[[1L]]$extra$.indep))
  expect_equal(p_indep$covstructs[[1L]]$extra$.kernel_name, "known")
  expect_equal(p_indep$covstructs[[1L]]$extra$.kernel_mode, "indep")
  expect_equal(p_indep$covstructs[[1L]]$extra$vcv, A)

  f_dep <- ~ 1 + kernel_dep(unit_id, K = A, name = "known")
  environment(f_dep) <- environment()
  p_dep <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::rewrite_canonical_aliases(f_dep)
  )
  expect_equal(p_dep$covstructs[[1L]]$kind, "phylo_rr")
  expect_true(isTRUE(p_dep$covstructs[[1L]]$extra$.dep))
  expect_equal(p_dep$covstructs[[1L]]$extra$.kernel_name, "known")
  expect_equal(p_dep$covstructs[[1L]]$extra$.kernel_mode, "dep")
  expect_equal(p_dep$covstructs[[1L]]$extra$vcv, A)
})

test_that("kernel_latent(unique = FALSE) is equivalent to dense phylo_latent vcv path", {
  testthat::skip_if_not_installed("TMB")

  set.seed(12)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.3, n_unit, n_unit)
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
  fit_phy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~
      1 +
      phylo_latent(unit_id, d = 2, vcv = A, unique = FALSE),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_kernel <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2, y3) ~
      1 +
      kernel_latent(unit_id, K = A, d = 2, name = "known", unique = FALSE),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit_phy$opt$convergence, 0L)
  expect_equal(fit_kernel$opt$convergence, 0L)
  expect_equal(fit_phy$tmb_data$n_aug_phy, fit_kernel$tmb_data$n_aug_phy)
  expect_equal(fit_phy$tmb_data$d_phy, fit_kernel$tmb_data$d_phy)
  expect_lt(
    abs(
      as.numeric(stats::logLik(fit_phy)) -
        as.numeric(stats::logLik(fit_kernel))
    ),
    1e-6
  )

  Sigma_phy <- suppressMessages(
    gllvmTMB::extract_Sigma(
      fit_phy,
      level = "phy",
      part = "shared"
    )$Sigma
  )
  Sigma_kernel <- suppressMessages(
    gllvmTMB::extract_Sigma(
      fit_kernel,
      level = "known",
      part = "shared"
    )$Sigma
  )
  expect_equal(Sigma_kernel, Sigma_phy, tolerance = 1e-6)
})

test_that("kernel companion modes are equivalent to dense phylo vcv paths", {
  testthat::skip_if_not_installed("TMB")

  set.seed(13)
  n_unit <- 7L
  n_rep <- 4L
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
  unit_effect <- L_A %*% matrix(stats::rnorm(n_unit * 2L), n_unit, 2L)
  eta <- unit_effect[as.integer(rows$unit_id), , drop = FALSE]
  rows$y1 <- 0.8 * eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- -0.2 * eta[, 1L] + 0.7 * eta[, 2L] +
    stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  cases <- list(
    unique = list(
      phy = traits(y1, y2) ~ 1 + phylo_unique(unit_id, vcv = A),
      kernel = traits(y1, y2) ~ 1 +
        kernel_unique(unit_id, K = A, name = "known")
    ),
    indep = list(
      phy = traits(y1, y2) ~ 1 +
        phylo_indep(0 + trait | unit_id, vcv = A),
      kernel = traits(y1, y2) ~ 1 +
        kernel_indep(unit_id, K = A, name = "known")
    ),
    dep = list(
      phy = traits(y1, y2) ~ 1 +
        phylo_dep(0 + trait | unit_id, vcv = A),
      kernel = traits(y1, y2) ~ 1 +
        kernel_dep(unit_id, K = A, name = "known")
    )
  )

  for (case in cases) {
    fit_phy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      case$phy,
      data = rows,
      unit = "row_id",
      cluster = "unit_id",
      family = stats::gaussian(),
      control = ctl
    )))
    fit_kernel <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      case$kernel,
      data = rows,
      unit = "row_id",
      cluster = "unit_id",
      family = stats::gaussian(),
      control = ctl
    )))

    expect_equal(fit_phy$opt$convergence, 0L)
    expect_equal(fit_kernel$opt$convergence, 0L)
    expect_lt(
      abs(
        as.numeric(stats::logLik(fit_phy)) -
          as.numeric(stats::logLik(fit_kernel))
      ),
      1e-6
    )
    expect_equal(
      suppressMessages(
        gllvmTMB::extract_Sigma(
          fit_kernel,
          level = "known",
          part = "total"
        )$Sigma
      ),
      suppressMessages(
        gllvmTMB::extract_Sigma(
          fit_phy,
          level = "phy",
          part = "total"
        )$Sigma
      ),
      tolerance = 1e-6
    )
  }
})
