test_that("spatial_latent(unique = TRUE) carries the spatial Psi marker", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1,
                     coords = c("lon", "lat"), unique = TRUE)
  )
  txt <- paste(deparse(f), collapse = " ")
  expect_match(txt, "spde", fixed = TRUE)
  expect_match(txt, ".spatial_latent = TRUE", fixed = TRUE)
  expect_match(txt, ".spatial_unique_diag = TRUE", fixed = TRUE)
})

test_that("spatial_latent() default remains loadings-only", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1,
                     coords = c("lon", "lat"))
  )
  txt <- paste(deparse(f), collapse = " ")
  expect_match(txt, "spde", fixed = TRUE)
  expect_match(txt, ".spatial_latent = TRUE", fixed = TRUE)
  expect_match(txt, ".spatial_unique_diag = FALSE", fixed = TRUE)
})

test_that("spatial_latent(unique = ) validates a literal logical scalar", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait +
        spatial_latent(0 + trait | site, d = 1,
                       coords = c("lon", "lat"), unique = NA)
    ),
    "unique.*spatial_latent"
  )
})

test_that("spatial_latent(1 + x | coords, unique = TRUE) folds to the augmented pair (parser)", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  ## Augmented fold desugars to the loadings-only slope + the spatial_unique
  ## companion -- both SPDE slope engines (use_spde_latent_slope + use_spde_slope),
  ## byte-identical to the explicit pair. Fit-level byte-identity is gated heavily
  ## (Codex); here assert the parser emits both engine markers and matches the pair.
  fold <- paste(deparse(gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + spatial_latent(1 + x | coords, d = 1, unique = TRUE)
  )), collapse = " ")
  expect_match(fold, ".spatial_latent_augmented = TRUE", fixed = TRUE)
  expect_match(fold, ".spatial_unique_augmented = TRUE", fixed = TRUE)

  pair <- paste(deparse(gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + spatial_latent(1 + x | coords, d = 1) +
      spatial_unique(1 + x | coords)
  )), collapse = " ")
  norm <- function(s) gsub("[[:space:]()]", "", s)
  expect_equal(norm(fold), norm(pair))

  ## unique = FALSE / absent stay loadings-only (no companion).
  bare <- paste(deparse(gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + spatial_latent(1 + x | coords, d = 1)
  )), collapse = " ")
  expect_match(bare, ".spatial_latent_augmented = TRUE", fixed = TRUE)
  expect_false(grepl(".spatial_unique_augmented", bare, fixed = TRUE))
})

.spatial_unique_fold_fixture <- function(seed = 20260703L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 55,
    n_species = 1,
    n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.25,
    sigma2_spa = c(0.45, 0.55, 0.35),
    seed = seed
  )
  df <- sim$data
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.08)
  list(data = df, mesh = mesh)
}

test_that("spatial_latent(unique = TRUE) keeps shared and unique SPDE blocks", {
  testthat::skip_if_not_installed("TMB")
  s <- .spatial_unique_fold_fixture()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1, unique = TRUE),
    data = s$data,
    mesh = s$mesh,
    family = stats::gaussian(),
    control = ctl,
    silent = TRUE
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$spatial_latent))
  expect_true(isTRUE(fit$use$spatial_latent_unique))
  expect_equal(fit$tmb_data$spde_lv_k, 1L)
  expect_equal(fit$tmb_data$spde_lv_unique, 1L)
  expect_equal(dim(fit$report$Lambda_spde), c(3L, 1L))
  expect_equal(length(fit$report$sd_spde_unique), 3L)
  expect_equal(length(fit$report$Psi_spde_unique), 3L)

  S_shared <- fit$report$Sigma_spde_shared
  S_total <- fit$report$Sigma_spde
  expect_equal(
    diag(S_total),
    diag(S_shared) + as.numeric(fit$report$Psi_spde_unique),
    tolerance = 1e-8
  )

  R_shared <- stats::cov2cor(S_shared)
  R_total <- stats::cov2cor(S_total)
  expect_true(all(as.numeric(fit$report$Psi_spde_unique) > 0))
  expect_true(any(abs(R_total[lower.tri(R_total)]) <
                    abs(R_shared[lower.tri(R_shared)]) - 1e-8))

  out <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "spatial", part = "total")
  )
  expect_equal(unname(out$Sigma), unname(S_total), tolerance = 1e-8)
})

test_that("spatial_latent(unique = FALSE) + spatial_unique() activates the same fold", {
  testthat::skip_if_not_installed("TMB")
  s <- .spatial_unique_fold_fixture(seed = 20260704L)
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)

  fit_pair <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1, unique = FALSE) +
      spatial_unique(0 + trait | site),
    data = s$data,
    mesh = s$mesh,
    family = stats::gaussian(),
    control = ctl,
    silent = TRUE
  )))
  fit_fold <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1, unique = TRUE),
    data = s$data,
    mesh = s$mesh,
    family = stats::gaussian(),
    control = ctl,
    silent = TRUE
  )))

  expect_true(isTRUE(fit_pair$use$spatial_latent_unique))
  expect_equal(fit_pair$tmb_data$spde_lv_unique, 1L)
  expect_equal(fit_fold$tmb_data$spde_lv_unique, 1L)
  expect_equal(
    as.numeric(stats::logLik(fit_fold)),
    as.numeric(stats::logLik(fit_pair)),
    tolerance = 1e-6
  )
})

test_that("spatial_latent(unique = TRUE) + spatial_unique() errors as duplicate Psi", {
  testthat::skip_if_not_installed("TMB")
  s <- .spatial_unique_fold_fixture(seed = 20260705L)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        spatial_latent(0 + trait | site, d = 1, unique = TRUE) +
        spatial_unique(0 + trait | site),
      data = s$data,
      mesh = s$mesh,
      family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
      silent = TRUE
    ))),
    "Duplicate spatial"
  )
})
