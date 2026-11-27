## Extra coverage for R/[s-z]*.R — cursor coverage 27 Nov 2026.
## Fast, behaviour-locked tests only; no fits slower than existing smoke cells.

expect_rlang <- function(expr, pattern) {
  err <- tryCatch(expr, error = function(e) e)
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), pattern)
}

## ---- R/two-stage.R (block_V) -----------------------------------------------

test_that("block_V() refuses unnamed multi-element rho_within", {
  study <- factor(c("a", "a", "b", "b"))
  expect_rlang(
    block_V(study, rep(0.1, 4), rho_within = c(0.5, 0.6)),
    "named with study levels"
  )
})

test_that("block_V() refuses rho_within below the compound-symmetric PD bound", {
  study <- factor(c("s", "s", "s"))
  expect_rlang(
    block_V(study, rep(0.1, 3), rho_within = -0.6),
    "too negative"
  )
})

test_that("block_V() coerces study_id to factor", {
  var <- c(0.1, 0.2, 0.3, 0.4)
  V_fac <- block_V(factor(c("a", "a", "b", "b")), var, rho_within = 0.3)
  V_chr <- block_V(c("a", "a", "b", "b"), var, rho_within = 0.3)
  expect_equal(V_chr, V_fac, tolerance = 1e-12)
})

test_that("block_V() assigns diagonal blocks for single-row studies", {
  study <- factor(c("a", "b"))
  V <- block_V(study, c(0.25, 0.36), rho_within = 0.5)
  expect_equal(diag(V), c(0.25, 0.36))
  expect_equal(V[1, 2], 0)
})

## ---- R/spde-keyword.R ------------------------------------------------------

test_that("spde() documentation stub executes", {
  expect_null(spde(coords, trait))
})

## ---- R/weights-shape.R -----------------------------------------------------

test_that("normalise_weights() validates internal drop_masked argument", {
  expect_rlang(
    gllvmTMB:::normalise_weights(1, "long", n_obs = 1, drop_masked = NA),
    "drop_masked"
  )
})

test_that("normalise_weights() coerces numeric na_mask to logical", {
  mask <- matrix(c(0, 1, 0, 0), 2, 2)
  w_mat <- matrix(c(1, 2, 3, 4), 2, 2)
  w_mat[2, 1] <- NA
  out <- gllvmTMB:::normalise_weights(
    weights = w_mat,
    response_shape = "wide_matrix",
    n_obs = 3L,
    n_units = 2L,
    n_traits = 2L,
    na_mask = mask
  )
  expect_equal(out, c(1, 3, 4))
})

test_that("normalise_weights() keeps masked cells when drop_masked is FALSE", {
  mask <- matrix(c(TRUE, FALSE, FALSE, FALSE), 2, 2)
  w_mat <- matrix(c(NA, 2, 3, 4), 2, 2)
  expect_equal(
    gllvmTMB:::normalise_weights(
      w_mat,
      response_shape = "wide_matrix",
      n_obs = 4L,
      n_units = 2L,
      n_traits = 2L,
      na_mask = mask,
      drop_masked = FALSE
    ),
    c(0, 2, 3, 4)
  )
})

## ---- R/vcov-coef.R ---------------------------------------------------------

test_that("coef() and vcov() return empty objects when there are no fixed names", {
  fit <- structure(
    list(
      X_fix_names = character(0),
      likelihood_weights = list(active = FALSE)
    ),
    class = "gllvmTMB_multi"
  )
  expect_equal(coef(fit), stats::setNames(numeric(0), character(0)))
  expect_equal(vcov(fit), matrix(numeric(0), 0L, 0L))
})

## ---- R/screen-separation.R -------------------------------------------------

test_that(".screen_empty_separation() returns the zero-row schema", {
  empty <- gllvmTMB:::.screen_empty_separation()
  expect_s3_class(empty, "data.frame")
  expect_equal(nrow(empty), 0L)
  expect_true(all(c(
    "block_id", "traits", "status", "severity", "separated", "message"
  ) %in% names(empty)))
})

## ---- R/s3-gllvm-mask.R -----------------------------------------------------

test_that(".gllvm_mask_is_generic() recognises S3 generics", {
  expect_false(gllvmTMB:::.gllvm_mask_is_generic(1L))
  expect_false(gllvmTMB:::.gllvm_mask_is_generic(function(x) x))
  expect_true(gllvmTMB:::.gllvm_mask_is_generic(stats::simulate))
})

test_that(".register_gllvm_masking_methods() is a no-op without gllvm", {
  skip_if(isNamespaceLoaded("gllvm"), "gllvm already attached")
  expect_false(gllvmTMB:::.register_gllvm_masking_methods())
})

## ---- R/utils.R -------------------------------------------------------------

test_that("safe_deparse() and extract_call_name() format language objects", {
  long <- quote(foo(bar(baz(x = 1), another = 2)))
  dep <- gllvmTMB:::safe_deparse(long)
  expect_type(dep, "character")
  expect_match(dep, "foo")
  expect_equal(
    gllvmTMB:::extract_call_name(quote(spatial_indep(1 | site))),
    "spatial_indep(1 | site)"
  )
  wide <- gllvmTMB:::extract_call_name(
    quote(phylo_latent(0 + trait | species, d = 2, unique = TRUE)),
    max_width = 12
  )
  expect_equal(nchar(wide), 14L)
  expect_match(wide, "\\.\\.\\.$")
})

test_that("ggplot2_installed() reflects requireNamespace", {
  expect_type(gllvmTMB:::ggplot2_installed(), "logical")
  expect_equal(
    gllvmTMB:::ggplot2_installed(),
    requireNamespace("ggplot2", quietly = TRUE)
  )
})

## ---- R/vgh-verify.R --------------------------------------------------------

test_that(".vgh_read_loglik() errors on a missing objective", {
  fit <- list(opt = list(convergence = 0L), class = "gllvmTMB_multi")
  expect_error(
    gllvmTMB:::.vgh_read_loglik(fit, "fit"),
    "objective is missing"
  )
})

test_that(".vgh_read_converged() returns NA when no evidence is recorded", {
  expect_equal(
    gllvmTMB:::.vgh_read_converged(list(opt = list(), sd_report = list())),
    NA
  )
  expect_true(gllvmTMB:::.vgh_read_converged(
    list(opt = list(convergence = 0L), sd_report = list())
  ))
})

## ---- R/temporal-bootstrap.R ------------------------------------------------

test_that("bootstrap_temporal() validates n_boot and seed", {
  d <- expand.grid(
    series = c("a", "b"),
    occasion = 1:3,
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE
  )
  d$value <- stats::rnorm(nrow(d))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = d,
    unit = "series",
    family = gaussian(),
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_rlang(bootstrap_temporal(fit, n_boot = 0), "positive integer")
  expect_rlang(bootstrap_temporal(fit, n_boot = 1.5), "positive integer")
  expect_rlang(bootstrap_temporal(fit, n_boot = 1L, seed = -1), "seed")
})