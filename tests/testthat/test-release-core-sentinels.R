## CRAN 0.7 ordinary-core sentinels.
##
## These are deterministic route/algebra sentinels, not recovery-campaign
## evidence. The frozen scientific contract is under
## docs/dev-log/simulation-artifacts/2026-08-08-cran07-core-recovery/.
##
## Symbol <-> implementation alignment (all six fits):
##
## Symbol          Keyword                 DGP draw              Extractor                         Truth
## beta_0t,beta_1t 0+trait + trait:x       planted trait effects b_fix                              beta_0,beta_1
## Lambda z_i      latent(..., d=1)        z_i %*% t(Lambda)     extract_Sigma(part="shared")       Lambda Lambda'
## e_it            latent default / indep independent normals   extract_Sigma(part="unique")$s    diag(Psi)
## b_i             dep                     MVN(0,Sigma)          extract_Sigma(part="shared")       Sigma
## b_i total       all applicable pieces   sum of DGP draws      extract_Sigma(part="total")        shared + Psi

.cran07_make_fixture <- function(
  family_name = c("gaussian", "poisson", "nbinom2", "binomial"),
  mode = c("indep", "dep", "latent"),
  seed = 27080001L
) {
  family_name <- match.arg(family_name)
  mode <- match.arg(mode)
  set.seed(seed)

  n_unit <- 24L
  n_traits <- 3L
  n_rep <- if (family_name == "binomial") 4L else 2L
  beta_0 <- switch(
    family_name,
    gaussian = c(0.2, -0.1, 0.35),
    poisson = c(1.0, 0.8, 1.15),
    nbinom2 = c(1.0, 0.8, 1.15),
    binomial = c(-0.3, 0.1, 0.35)
  )
  beta_1 <- c(0.25, -0.20, 0.15)
  x <- as.numeric(scale(seq_len(n_unit)))
  Lambda <- matrix(c(0.55, -0.40, 0.35), n_traits, 1L)
  psi <- c(0.14, 0.10, 0.12)
  Sigma_dep <- matrix(
    c(0.42, 0.18, -0.08,
      0.18, 0.35, 0.10,
      -0.08, 0.10, 0.30),
    n_traits, n_traits, byrow = TRUE
  )

  B <- switch(
    mode,
    indep = sweep(matrix(stats::rnorm(n_unit * n_traits), n_unit),
                  2L, sqrt(psi), `*`),
    dep = matrix(stats::rnorm(n_unit * n_traits), n_unit) %*% chol(Sigma_dep),
    latent = {
      z <- matrix(stats::rnorm(n_unit), n_unit, 1L)
      e <- sweep(matrix(stats::rnorm(n_unit * n_traits), n_unit),
                 2L, sqrt(psi), `*`)
      z %*% t(Lambda) + e
    }
  )

  dat <- expand.grid(
    rep = seq_len(n_rep),
    trait_idx = seq_len(n_traits),
    unit_idx = seq_len(n_unit)
  )
  eta <- beta_0[dat$trait_idx] + beta_1[dat$trait_idx] * x[dat$unit_idx] +
    B[cbind(dat$unit_idx, dat$trait_idx)]
  dat$value <- switch(
    family_name,
    gaussian = eta + stats::rnorm(nrow(dat), sd = 0.45),
    poisson = stats::rpois(nrow(dat), lambda = exp(eta)),
    nbinom2 = stats::rnbinom(nrow(dat), mu = exp(eta), size = 5),
    binomial = stats::rbinom(nrow(dat), size = 1L, prob = stats::plogis(eta))
  )
  dat$unit <- factor(dat$unit_idx)
  dat$trait <- factor(
    paste0("t", dat$trait_idx),
    levels = paste0("t", seq_len(n_traits))
  )
  dat$x <- x[dat$unit_idx]

  family <- switch(
    family_name,
    gaussian = stats::gaussian(),
    poisson = stats::poisson(),
    nbinom2 = gllvmTMB::nbinom2(),
    binomial = stats::binomial()
  )
  formula <- switch(
    mode,
    indep = value ~ 0 + trait + trait:x + indep(0 + trait | unit),
    dep = value ~ 0 + trait + trait:x + dep(0 + trait | unit),
    latent = value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1)
  )

  list(
    data = dat,
    family = family,
    formula = formula,
    truth = list(
      beta_0 = beta_0,
      beta_1 = beta_1,
      Sigma_shared = switch(
        mode,
        indep = matrix(0, n_traits, n_traits),
        dep = Sigma_dep,
        latent = Lambda %*% t(Lambda)
      ),
      Psi = if (mode == "dep") matrix(0, n_traits, n_traits) else diag(psi),
      Sigma_total = switch(
        mode,
        indep = diag(psi),
        dep = Sigma_dep,
        latent = Lambda %*% t(Lambda) + diag(psi)
      )
    )
  )
}

.cran07_fit_sentinel <- function(family_name, mode, seed) {
  fx <- .cran07_make_fixture(family_name, mode, seed)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    fx$formula,
    data = fx$data,
    unit = "unit",
    family = fx$family,
    silent = TRUE
  )))
  list(fit = fit, truth = fx$truth)
}

.cran07_expect_common <- function(x) {
  fit <- x$fit
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  b_fix <- unname(fit$opt$par[names(fit$opt$par) == "b_fix"])
  expect_length(b_fix, 6L)
  expect_true(all(is.finite(b_fix)))
  total <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "none"
  ))$Sigma
  expect_equal(dim(total), c(3L, 3L))
  expect_true(all(is.finite(total)))
  expect_equal(total, t(total), tolerance = 1e-10)
  expect_gte(min(eigen(total, symmetric = TRUE, only.values = TRUE)$values), -1e-8)
  invisible(total)
}

test_that("release core sentinel: gaussian indep routes and extracts Psi", {
  x <- .cran07_fit_sentinel("gaussian", "indep", 27080011L)
  .cran07_expect_common(x)
  expect_true(isTRUE(x$fit$use$indep_B))
  expect_true(isTRUE(x$fit$use$diag_B))
  unique <- gllvmTMB::extract_Sigma(
    x$fit, level = "unit", part = "unique", link_residual = "none"
  )$s
  expect_length(unique, 3L)
  expect_true(all(is.finite(unique) & unique >= 0))
})

test_that("release core sentinel: gaussian dep routes a full Sigma", {
  x <- .cran07_fit_sentinel("gaussian", "dep", 27080012L)
  .cran07_expect_common(x)
  expect_true(isTRUE(x$fit$use$dep_B))
  expect_true(isTRUE(x$fit$use$rr_B))
  shared <- gllvmTMB::extract_Sigma(
    x$fit, level = "unit", part = "shared", link_residual = "none"
  )$Sigma
  expect_equal(dim(shared), c(3L, 3L))
  expect_true(any(abs(shared[upper.tri(shared)]) > 1e-8))
})

test_that("release core sentinel: gaussian latent preserves shared plus Psi algebra", {
  x <- .cran07_fit_sentinel("gaussian", "latent", 27080013L)
  total <- .cran07_expect_common(x)
  expect_true(isTRUE(x$fit$use$rr_B))
  expect_true(isTRUE(x$fit$use$diag_B))
  shared <- gllvmTMB::extract_Sigma(
    x$fit, level = "unit", part = "shared", link_residual = "none"
  )$Sigma
  unique <- gllvmTMB::extract_Sigma(
    x$fit, level = "unit", part = "unique", link_residual = "none"
  )$s
  expect_equal(total, shared + diag(unique), tolerance = 1e-8)
})

for (case in list(
  list(family = "poisson", seed = 27080014L, family_id = 2L),
  list(family = "nbinom2", seed = 27080015L, family_id = 5L),
  list(family = "binomial", seed = 27080016L, family_id = 1L)
)) {
  local({
    case <- case
    test_that(paste0("release core sentinel: ", case$family,
                     " latent preserves shared plus Psi algebra"), {
      x <- .cran07_fit_sentinel(case$family, "latent", case$seed)
      total <- .cran07_expect_common(x)
      expect_true(all(x$fit$tmb_data$family_id_vec == case$family_id))
      expect_true(isTRUE(x$fit$use$rr_B))
      expect_true(isTRUE(x$fit$use$diag_B))
      shared <- gllvmTMB::extract_Sigma(
        x$fit, level = "unit", part = "shared", link_residual = "none"
      )$Sigma
      unique <- gllvmTMB::extract_Sigma(
        x$fit, level = "unit", part = "unique", link_residual = "none"
      )$s
      expect_equal(total, shared + diag(unique), tolerance = 1e-8)
      if (case$family == "nbinom2") {
        expect_true(all(is.finite(x$fit$report$phi_nbinom2)))
      }
    })
  })
}

test_that("release campaign classifier accepts the healthy case", {
  expect_identical(.release_core_classify_attempt(), "usable")
})

test_that("release campaign classifier rejects silent-failure cases", {
  expect_identical(
    .release_core_classify_attempt(
      optimizer_converged = TRUE, stationary = TRUE,
      pd_hessian = TRUE, geometry_flag = TRUE
    ),
    "geometry_failed"
  )
  expect_identical(.release_core_classify_attempt(finite_estimands = FALSE),
                   "nonfinite")
  expect_identical(.release_core_classify_attempt(optimizer_converged = FALSE),
                   "optimizer_failed")
  expect_identical(.release_core_classify_attempt(stationary = FALSE),
                   "nonstationary")
  expect_identical(.release_core_classify_attempt(pd_hessian = FALSE),
                   "non_pd_hessian")
  expect_error(.release_core_classify_attempt(stationary = NA),
               "non-missing logical")
})

test_that("release campaign ledger accepts canonical rows and rejects duplicates", {
  row <- data.frame(
    campaign_id = "cran07-core-recovery-v2",
    registry_sha256 = paste(rep("a", 64L), collapse = ""),
    cell_id = "g_indep_n60",
    replicate = 1L,
    seed = 270900001L,
    status = "usable",
    constructed = TRUE,
    optimizer_converged = TRUE,
    stationary = TRUE,
    pd_hessian = TRUE,
    finite_estimands = TRUE,
    boundary = FALSE,
    geometry_flag = FALSE,
    detector_flagged = FALSE,
    catastrophic_truth_error = FALSE,
    relative_covariance_error = 0.1,
    max_eigen_ratio = 1,
    family = "gaussian",
    n_trials_min = NA_integer_,
    n_trials_max = NA_integer_,
    diag_B_skip = "",
    diag_B_all_free = NA,
    error_class = "",
    error_message = "",
    elapsed_seconds = 1,
    stringsAsFactors = FALSE
  )
  expect_true(.release_core_validate_attempt_table(row))
  expect_error(.release_core_validate_attempt_table(rbind(row, row)), "duplicate")
  bad <- row
  bad$status <- "quietly_dropped"
  expect_error(.release_core_validate_attempt_table(bad), "unknown status")
  contradicted <- row
  contradicted$geometry_flag <- TRUE
  expect_error(.release_core_validate_attempt_table(contradicted), "contradicts")

  catastrophic_but_healthy <- row
  catastrophic_but_healthy$replicate <- 2L
  catastrophic_but_healthy$seed <- 270900002L
  catastrophic_but_healthy$catastrophic_truth_error <- TRUE
  catastrophic_but_healthy$relative_covariance_error <- 3
  catastrophic_but_healthy$max_eigen_ratio <- 11
  expect_true(.release_core_validate_attempt_table(catastrophic_but_healthy))

  coupled <- catastrophic_but_healthy
  coupled$detector_flagged <- TRUE
  expect_error(.release_core_validate_attempt_table(coupled),
               "observable terminal status")
})

test_that("shipped release schema mirror matches the repository campaign schema", {
  schema_path <- testthat::test_path(
    "..", "..", "inst", "sim", "cran07-core", "schema.R"
  )
  skip_if_not(file.exists(schema_path),
              "Repository-only campaign schema is excluded from the tarball")

  campaign <- new.env(parent = baseenv())
  sys.source(schema_path, envir = campaign)
  expect_identical(campaign$cran07_attempt_status_levels,
                   .release_core_attempt_status_levels)
  expect_identical(campaign$cran07_attempt_columns,
                   .release_core_attempt_columns)

  flags <- expand.grid(
    constructed = c(FALSE, TRUE),
    fit_error = c(FALSE, TRUE),
    finite_estimands = c(FALSE, TRUE),
    optimizer_converged = c(FALSE, TRUE),
    stationary = c(FALSE, TRUE),
    pd_hessian = c(FALSE, TRUE),
    boundary = c(FALSE, TRUE),
    geometry_flag = c(FALSE, TRUE),
    KEEP.OUT.ATTRS = FALSE
  )
  for (i in seq_len(nrow(flags))) {
    args <- as.list(flags[i, , drop = FALSE])
    expect_identical(
      do.call(campaign$cran07_classify_attempt, args),
      do.call(.release_core_classify_attempt, args)
    )
  }
})
