## Design 79 scalar-collapse: the covariance grid collapses to THREE modes
## {indep, dep, latent}. The one-shared-variance case is the canonical
## `*_indep(..., common = TRUE)`, which routes byte-identically to the (now
## soft-deprecated) `*_scalar()` engine. These tests lock (a) the byte-identity
## of the routing, (b) the warn-once soft-deprecation of the scalar family,
## (c) the canonical spelling staying silent, and (d) one real-fit equivalence.

local_reset_scalar_cache <- function(env = parent.frame()) {
  seen <- tryCatch(
    get(".gllvmTMB_deprecation_seen", envir = asNamespace("gllvmTMB")),
    error = function(e) NULL
  )
  if (is.environment(seen)) {
    saved_seen <- as.list(seen, all.names = TRUE)
    withr::defer(
      {
        rlang::env_unbind(seen, rlang::env_names(seen))
        rlang::env_bind(seen, !!!saved_seen)
      },
      envir = env
    )
    rlang::env_unbind(seen, rlang::env_names(seen))
  }
  invisible(NULL)
}

rw <- function(f) {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  paste(deparse(gllvmTMB:::rewrite_canonical_aliases(f)), collapse = " ")
}

test_that("*_indep(common = TRUE) desugars byte-identically to *_scalar()", {
  A <- diag(3)

  expect_identical(
    rw(value ~ 0 + trait + phylo_indep(0 + trait | sp, common = TRUE, vcv = A)),
    rw(value ~ 0 + trait + phylo_scalar(sp, vcv = A))
  )
  expect_identical(
    rw(value ~ 0 + trait + spatial_indep(0 + trait | site, common = TRUE)),
    rw(value ~ 0 + trait + spatial_scalar(0 + trait | site))
  )
  expect_identical(
    rw(value ~ 0 + trait + animal_indep(0 + trait | id, common = TRUE, A = A)),
    rw(value ~ 0 + trait + animal_scalar(id, A = A))
  )
  expect_identical(
    rw(value ~ 0 + trait + kernel_indep(unit, K = A, common = TRUE)),
    rw(value ~ 0 + trait + kernel_scalar(unit, K = A))
  )
  # no-prefix scalar() already collapsed; assert it too
  expect_identical(
    rw(value ~ 0 + trait + indep(0 + trait | site, common = TRUE)),
    rw(value ~ 0 + trait + scalar(0 + trait | site))
  )
})

test_that("common = FALSE keeps the per-trait indep engine path", {
  A <- diag(3)
  txt <- rw(value ~ 0 + trait + phylo_indep(0 + trait | sp, vcv = A))
  # per-trait diagonal path (phylo_unique engine), NOT the shared phylo() scalar
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, ".indep = TRUE", fixed = TRUE)
})

test_that("scalar-family keywords emit a warn-once soft-deprecation", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  A <- diag(3)

  local_reset_scalar_cache()
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(value ~ 0 + trait + scalar(0 + trait | site)),
    regexp = "soft-deprecated|compatibility syntax"
  )
  local_reset_scalar_cache()
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(value ~ 0 + trait + phylo_scalar(sp, vcv = A)),
    regexp = "soft-deprecated|compatibility syntax"
  )
  local_reset_scalar_cache()
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(value ~ 0 + trait + animal_scalar(id, A = A)),
    regexp = "soft-deprecated|compatibility syntax"
  )
  local_reset_scalar_cache()
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(value ~ 0 + trait + spatial_scalar(0 + trait | site)),
    regexp = "soft-deprecated|compatibility syntax"
  )
  local_reset_scalar_cache()
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(value ~ 0 + trait + kernel_scalar(unit, K = A)),
    regexp = "soft-deprecated|compatibility syntax"
  )
})

test_that("the canonical *_indep(common = TRUE) spelling is silent", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  A <- diag(3)
  local_reset_scalar_cache()
  expect_no_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + phylo_indep(0 + trait | sp, common = TRUE, vcv = A)
    )
  )
  local_reset_scalar_cache()
  expect_no_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + kernel_indep(unit, K = A, common = TRUE)
    )
  )
})

test_that("*_indep(common = TRUE) is intercept-only (slope case errors)", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  A <- diag(3)
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + phylo_indep(1 + x | sp, common = TRUE, vcv = A)
    ),
    regexp = "intercept-only"
  )
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + spatial_indep(1 + x | site, common = TRUE)
    ),
    regexp = "intercept-only"
  )
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + animal_indep(1 + x | id, common = TRUE, A = A)
    ),
    regexp = "intercept-only"
  )
})

test_that("indep(common = TRUE) fits and matches scalar() at the likelihood", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  df <- gllvmTMB::simulate_site_trait(
    n_sites = 25,
    n_species = 4,
    n_traits = 3,
    mean_species_per_site = 4,
    seed = 4207
  )$data

  fit_indep <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site, common = TRUE),
    data = df
  ))
  fit_scalar <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + scalar(0 + trait | site),
    data = df
  )))

  expect_equal(fit_indep$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_indep)),
    as.numeric(stats::logLik(fit_scalar)),
    tolerance = 1e-8
  )
})
