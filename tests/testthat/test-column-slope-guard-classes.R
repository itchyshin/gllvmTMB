## Class-level pins for guards that had a condition class but no test that
## asserts it. Each test reaches the raise site with the smallest input and
## checks the class plus the advice (">") line of the message.
##
## Fixtures follow test-spatial-column-slope.R and
## test-fixed-column-slope-family.R.

.guard_spatial_fixture <- function(seed = 1301L, n_unit = 8L) {
  set.seed(seed)
  locations <- expand.grid(east_km = 0:2, north_km = 0:1,
                           KEEP.OUT.ATTRS = FALSE)
  locations$trait <- paste0("t", seq_len(nrow(locations)))
  locations <- locations[c("trait", "east_km", "north_km")]
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(locations$trait, levels = locations$trait),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  dat$value <- stats::rnorm(nrow(dat))
  list(data = dat, locations = locations)
}

.guard_fit_spatial <- function(fx, mesh, family = stats::gaussian()) {
  suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_slope(x + z || trait, mesh = mesh),
    data = fx$data, trait = "trait", unit = "unit", family = family,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
}

.guard_kernel_fixture <- function(seed = 130L, n_traits = 4L, n_unit = 10L) {
  set.seed(seed)
  tr <- paste0("t", seq_len(n_traits))
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(tr, levels = tr),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  dat$value <- stats::rnorm(nrow(dat), sd = 0.45)
  K <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 2)
  dimnames(K) <- list(tr, tr)
  list(data = dat, K = K)
}

.guard_small_multi_fit <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      set.seed(41)
      d <- expand.grid(unit = factor(1:30), trait = factor(c("a", "b", "c")),
                       KEEP.OUT.ATTRS = FALSE)
      f <- stats::rnorm(30)
      d$value <- f[as.integer(d$unit)] + stats::rnorm(nrow(d), sd = 0.7)
      cache <<- suppressMessages(gllvmTMB::gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE),
        data = d, trait = "trait", unit = "unit",
        control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
      ))
    }
    cache
  }
})

.guard_advice <- function(cnd) paste(cnd$body, collapse = "\n")

.guard_catch <- function(expr, class) {
  tryCatch(expr, error = function(e) {
    if (inherits(e, class)) e else stop(e)
  })
}

test_that("spatial_slope refuses a non-Gaussian family and names the way out", {
  skip_if_not_installed("fmesher")
  fx <- .guard_spatial_fixture()
  mesh <- make_mesh(fx$locations, c("east_km", "north_km"), cutoff = 0.15,
                    id_col = "trait")
  fx$data$value <- stats::rpois(nrow(fx$data), 2)
  expect_error(
    .guard_fit_spatial(fx, mesh, family = stats::poisson()),
    class = "gllvmTMB_spatial_column_slope_family"
  )
  cnd <- .guard_catch(
    .guard_fit_spatial(fx, mesh, family = stats::poisson()),
    "gllvmTMB_spatial_column_slope_family"
  )
  expect_match(.guard_advice(cnd), "family = gaussian()", fixed = TRUE)
})

test_that("spatial_slope refuses a mesh with no label metadata", {
  skip_if_not_installed("fmesher")
  fx <- .guard_spatial_fixture()
  ## No id_col: the mesh carries no row_labels / id_col.
  mesh <- make_mesh(fx$locations, c("east_km", "north_km"), cutoff = 0.15)
  expect_error(
    .guard_fit_spatial(fx, mesh),
    class = "gllvmTMB_spatial_column_slope_mesh_labels"
  )
  cnd <- .guard_catch(.guard_fit_spatial(fx, mesh),
                      "gllvmTMB_spatial_column_slope_mesh_labels")
  expect_match(conditionMessage(cnd), "labelled response-column mesh")
  expect_match(.guard_advice(cnd), "make_mesh", fixed = TRUE)
  expect_match(.guard_advice(cnd), "id_col", fixed = TRUE)
})

test_that("spatial_slope refuses a mesh whose id_col is not the trait column", {
  skip_if_not_installed("fmesher")
  fx <- .guard_spatial_fixture()
  loc <- fx$locations
  names(loc)[1L] <- "species"
  mesh <- make_mesh(loc, c("east_km", "north_km"), cutoff = 0.15,
                    id_col = "species")
  cnd <- .guard_catch(.guard_fit_spatial(fx, mesh),
                      "gllvmTMB_spatial_column_slope_mesh_labels")
  expect_s3_class(cnd, "gllvmTMB_spatial_column_slope_mesh_labels")
  expect_match(conditionMessage(cnd), "species")
  expect_match(.guard_advice(cnd), "Rebuild the mesh", fixed = TRUE)
})

test_that("spatial_slope refuses mesh labels that differ from the trait levels", {
  skip_if_not_installed("fmesher")
  fx <- .guard_spatial_fixture()
  loc <- fx$locations
  loc$trait[2L] <- "not_a_trait"
  mesh <- make_mesh(loc, c("east_km", "north_km"), cutoff = 0.15,
                    id_col = "trait")
  expect_error(
    .guard_fit_spatial(fx, mesh),
    class = "gllvmTMB_spatial_column_slope_mesh_labels"
  )
  cnd <- .guard_catch(.guard_fit_spatial(fx, mesh),
                      "gllvmTMB_spatial_column_slope_mesh_labels")
  expect_match(conditionMessage(cnd), "must match the response-column levels")
  expect_match(paste(cnd$body, collapse = "\n"), "not_a_trait", fixed = TRUE)
  expect_match(.guard_advice(cnd), "Rebuild the mesh", fixed = TRUE)
})

test_that("spatial_slope refuses two response columns at one location", {
  skip_if_not_installed("fmesher")
  fx <- .guard_spatial_fixture()
  loc <- fx$locations
  loc[2L, c("east_km", "north_km")] <- loc[1L, c("east_km", "north_km")]
  mesh <- suppressWarnings(make_mesh(
    loc, c("east_km", "north_km"), cutoff = 0.15, id_col = "trait"
  ))
  expect_error(
    .guard_fit_spatial(fx, mesh),
    class = "gllvmTMB_spatial_column_slope_coordinates"
  )
  cnd <- .guard_catch(.guard_fit_spatial(fx, mesh),
                      "gllvmTMB_spatial_column_slope_coordinates")
  expect_match(.guard_advice(cnd), "own coordinate row", fixed = TRUE)
})

test_that("kernel_slope refuses K labels that do not match the trait levels", {
  fx <- .guard_kernel_fixture()
  K <- fx$K
  dimnames(K) <- list(paste0("s", 1:4), paste0("s", 1:4))
  fit_k <- function() suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + kernel_slope(x + z | trait, K = K),
    data = fx$data, trait = "trait", unit = "unit",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_error(fit_k(), class = "gllvmTMB_column_slope_kernel_labels")
  cnd <- .guard_catch(fit_k(), "gllvmTMB_column_slope_kernel_labels")
  expect_match(.guard_advice(cnd), "rownames(K)", fixed = TRUE)
  expect_match(.guard_advice(cnd), "colnames(K)", fixed = TRUE)
})

test_that("engine fence for reserved column-coefficient helpers names a route", {
  ## Every public *_coef() helper is admitted by gllvmTMB() before this fence
  ## is consulted, so the raise site is reached only by a direct call.
  cnd <- .guard_catch(
    gllvmTMB:::.column_coef_engine_fence(list(helper = "reserved_coef")),
    "gllvmTMB_column_coef_engine_not_admitted"
  )
  expect_s3_class(cnd, "gllvmTMB_column_coef_engine_not_admitted")
  expect_match(conditionMessage(cnd), "reserved_coef")
  expect_match(conditionMessage(cnd), "not yet available")
  expect_match(.guard_advice(cnd), "response-column slope helper")
})

test_that("objective components abort when the likelihood cannot be evaluated", {
  obj <- list(fn = function(par) NA_real_)
  opt <- list(par = c(a = 0))
  expect_error(
    gllvmTMB:::.gllvmTMB_objective_components(obj, opt, list()),
    class = "gllvmTMB_objective_components_unavailable"
  )
  cnd <- .guard_catch(
    gllvmTMB:::.gllvmTMB_objective_components(obj, opt, list()),
    "gllvmTMB_objective_components_unavailable"
  )
  expect_match(.guard_advice(cnd), "start_method", fixed = TRUE)
  ## A throwing objective is handled the same way.
  obj$fn <- function(par) stop("boom")
  expect_error(
    gllvmTMB:::.gllvmTMB_objective_components(obj, opt, list()),
    class = "gllvmTMB_objective_components_unavailable"
  )
})

test_that("a VA-only control field on the Laplace route is refused", {
  d <- data.frame(
    unit = factor(rep(1:6, each = 2)),
    trait = factor(rep(c("a", "b"), 6)),
    value = stats::rnorm(12)
  )
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait, data = d, trait = "trait", unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(va_polish = FALSE)
    ),
    class = "gllvmTMB_unsupported_control"
  )
  cnd <- .guard_catch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait, data = d, trait = "trait", unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(va_polish = FALSE)
    ),
    "gllvmTMB_unsupported_control"
  )
  expect_match(conditionMessage(cnd), "va_polish")
  expect_match(.guard_advice(cnd), "integration = \"va\"", fixed = TRUE)
})

test_that("profile_ci_correlation validates diag_resid before profiling", {
  fit <- .guard_small_multi_fit()
  bad <- list(c(1, NA), c(1, 2, 3), "a", c(Inf, 1))
  for (v in bad) {
    expect_error(
      gllvmTMB:::profile_ci_correlation(fit, tier = "unit", i = 1L, j = 2L,
                                        diag_resid = v),
      class = "gllvmTMB_profile_diag_resid_invalid"
    )
  }
  cnd <- .guard_catch(
    gllvmTMB:::profile_ci_correlation(fit, tier = "unit", i = 1L, j = 2L,
                                      diag_resid = c(1, NA)),
    "gllvmTMB_profile_diag_resid_invalid"
  )
  expect_match(conditionMessage(cnd), "length-2 finite numeric")
  expect_match(.guard_advice(cnd), "link-residual variances", fixed = TRUE)
})

test_that("impute_model() objects carry the internal marker class", {
  m <- impute_model(x ~ z)
  expect_s3_class(m, "gllvmTMB_impute_model")
  expect_s3_class(
    impute_model(score ~ z, family = cumulative_logit()),
    "gllvmTMB_impute_model"
  )
  ## The standardiser passes a marked object through untouched, and lifts a
  ## bare formula to a marked Gaussian model.
  expect_identical(gllvmTMB:::gll_standardize_impute_model(m), m)
  lifted <- gllvmTMB:::gll_standardize_impute_model(x ~ z)
  expect_s3_class(lifted, "gllvmTMB_impute_model")
  expect_identical(lifted$family_type, m$family_type)
  ## A plain list with the same fields is not an impute model.
  expect_false(inherits(unclass(m), "gllvmTMB_impute_model"))
})
