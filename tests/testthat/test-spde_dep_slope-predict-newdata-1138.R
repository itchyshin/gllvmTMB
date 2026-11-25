## #1138: predict(newdata = ) re-adds the per-trait augmented SPDE slope tier
## (`spde_dep_slope`), the intercept and slope fields that every trait gets
## under spatial_dep(1 + x | coords) and spatial_indep(1 + x | coords).
##
## Acceptance is the issue's own: on a fit carrying the tier,
## predict(fit, newdata = <training rows>)$est equals fit$report$eta with
## max|diff| == 0. A non-zero contribution, or agreement to a tolerance, does
## not tell a correct reshape from a plausible one; the exact identity does.
##
## The covariate takes values in {0, +-2^k} on purpose. Per row the template
## adds A_alpha_t(o) + x(o) * A_beta_t(o) (src/gllvmTMB.cpp:3486-3494). With x
## a signed power of two that product is exact in floating point, so the
## identity is exact whether or not the compiler fuses the template's
## multiply-add into one rounding (clang on arm64 does by default). With a
## general covariate the rebuilt predictor is exact only where that fusing is
## absent.

.spde_dep_slope_1138_data <- function(seed = 5L, n_sites = 70L,
                                      n_traits = 3L) {
  set.seed(seed)
  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$species <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]
  df$lat <- coords[df$site, 2]
  df$x <- sample(c(-2, -1, -0.5, 0, 0.5, 1, 2), nrow(df), replace = TRUE)
  ## A different intercept surface and a different slope surface per trait,
  ## so reading one trait's fields for another is visibly wrong.
  field_a <- cbind(
    sin(4 * df$lon) + cos(3 * df$lat),
    cos(6 * df$lon) * sin(5 * df$lat),
    sin(5 * (df$lon + df$lat))
  )[cbind(seq_len(nrow(df)), df$trait_id)]
  field_b <- cbind(
    0.8 * cos(5 * df$lon * df$lat),
    0.7 * sin(7 * (df$lon - df$lat)),
    -0.6 * cos(4 * df$lat)
  )[cbind(seq_len(nrow(df)), df$trait_id)]
  df$value <- c(0.3, -0.2, 0.5)[df$trait_id] + field_a + df$x * field_b +
    stats::rnorm(nrow(df), sd = 0.2)
  df$site <- factor(df$site)
  df$species <- factor(df$species)
  df$site_species <- factor(df$site_species)
  df
}

## One fit per keyword, shared by the tests below.
.spde_dep_slope_1138_fit <- local({
  cache <- list()
  function(kind = c("dep", "indep")) {
    kind <- match.arg(kind)
    if (is.null(cache[[kind]])) {
      df <- .spde_dep_slope_1138_data()
      mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1)
      form <- switch(kind,
        dep = value ~ 0 + trait + spatial_dep(1 + x | coords),
        indep = value ~ 0 + trait + spatial_indep(1 + x | coords)
      )
      fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        form, data = df, mesh = mesh, unit = "site", silent = TRUE
      )))
      cache[[kind]] <<- list(fit = fit, df = df)
    }
    cache[[kind]]
  }
})

.spde_dep_slope_1138_flag <- function(fit, name) {
  isTRUE(as.integer(fit$tmb_data[[name]]) == 1L)
}

## The projected field matrix, n_obs x 2T, as the template forms it.
.spde_dep_slope_1138_fields <- function(fit) {
  n_mesh <- ncol(fit$tmb_data$A_proj)
  par <- fit$tmb_obj$env$last.par.best
  om <- matrix(par[names(par) == "omega_spde_aug"],
               nrow = n_mesh, ncol = 2L * fit$n_traits)
  as.matrix(fit$tmb_data$A_proj %*% om)
}

test_that("#1138: spde_dep_slope is re-added on newdata, exactly (spatial_dep)", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_dep_slope_1138_fit("dep")
  fit <- fx$fit
  df <- fx$df
  expect_true(.spde_dep_slope_1138_flag(fit, "use_spde_dep_slope"))
  expect_true(.spde_dep_slope_1138_flag(fit, "use_spde_slope"))
  expect_false(.spde_dep_slope_1138_flag(fit, "use_spde"))
  expect_identical(as.integer(fit$tmb_data$n_lhs_cols_spde), 6L)

  on_newdata <- suppressMessages(predict(fit, newdata = df))
  expect_equal(max(abs(on_newdata$est - fit$report$eta)), 0, tolerance = 1e-10)
  expect_equal(on_newdata$est, suppressMessages(predict(fit))$est, tolerance = 1e-10)

  ## The tier is the fit's only random effect and it is not small, so the
  ## identity above cannot hold by the tier being absent on both sides.
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))
  expect_gt(max(abs(fit$report$eta - fixed_only$est)), 0.1)

  ## Nothing is left to name as omitted: the tier runs through the template's
  ## `use_spde_slope` block, so both switches are accounted for.
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
  expect_message(
    predict(fit, newdata = df),
    "spde_dep_slope", fixed = TRUE
  )
})

test_that("#1138: spde_dep_slope is re-added on newdata, exactly (spatial_indep)", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_dep_slope_1138_fit("indep")
  fit <- fx$fit
  df <- fx$df
  expect_true(.spde_dep_slope_1138_flag(fit, "use_spde_dep_slope"))
  expect_identical(as.integer(fit$tmb_data$n_lhs_cols_spde), 6L)

  on_newdata <- suppressMessages(predict(fit, newdata = df))
  expect_equal(max(abs(on_newdata$est - fit$report$eta)), 0, tolerance = 1e-10)

  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))
  expect_gt(max(abs(fit$report$eta - fixed_only$est)), 0.1)
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
})

test_that("#1138: spde_dep_slope follows each newdata row, in any order", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_dep_slope_1138_fit("dep")
  fit <- fx$fit
  df <- fx$df

  set.seed(2)
  rows <- sample(nrow(df), 45L)
  sub <- suppressMessages(predict(fit, newdata = df[rows, ]))
  expect_equal(max(abs(sub$est - fit$report$eta[rows])), 0, tolerance = 1e-10)

  one <- suppressMessages(predict(fit, newdata = df[rows[1L], ]))
  expect_equal(one$est, fit$report$eta[rows[1L]], tolerance = 1e-10)

  ## One trait on its own: its rows must still read that trait's pair of
  ## fields, not the first pair.
  last <- df[df$trait == "trait_3", ]
  est_last <- suppressMessages(predict(fit, newdata = last))$est
  expect_equal(est_last, fit$report$eta[df$trait == "trait_3"], tolerance = 1e-10)
})

test_that("#1138: spde_dep_slope reads each trait's own interleaved field pair", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_dep_slope_1138_fit("dep")
  fit <- fx$fit
  df <- fx$df
  fields <- .spde_dep_slope_1138_fields(fit)
  t0 <- as.integer(df$trait) - 1L
  rows <- seq_len(nrow(df))
  ## Interleaved: (alpha_t0, beta_t0, alpha_t1, beta_t1, ...)
  ## (R/fit-multi.R:5815-5823).
  field_alpha <- fields[cbind(rows, 2L * t0 + 1L)]
  field_beta <- fields[cbind(rows, 2L * t0 + 2L)]
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est

  ## x = 0 leaves the trait's intercept field alone; x = 1 adds its slope
  ## field once.
  at0 <- df
  at0$x <- 0
  at1 <- df
  at1$x <- 1
  est0 <- suppressMessages(predict(fit, newdata = at0))$est
  est1 <- suppressMessages(predict(fit, newdata = at1))$est
  expect_equal(est0, fixed_only + field_alpha, tolerance = 1e-10)
  expect_equal(est1, fixed_only + (field_alpha + field_beta), tolerance = 1e-10)
  expect_gt(max(abs(field_beta)), 0.01)

  ## What the identity has to tell apart: the same matrix read as blocked,
  ## (alpha_t0, alpha_t1, ..., beta_t0, beta_t1, ...), is finite and wrong.
  n_traits <- fit$n_traits
  blocked <- fields[cbind(rows, t0 + 1L)] +
    fields[cbind(rows, n_traits + t0 + 1L)] * df$x
  expect_gt(max(abs(fixed_only + blocked - fit$report$eta)), 1e-3)

  ## A row with no covariate value has no defined slope term.
  na_x <- df
  na_x$x[3L] <- NA
  est_na <- suppressMessages(predict(fit, newdata = na_x))$est
  expect_true(is.na(est_na[3L]))
  expect_equal(est_na[-3L], fit$report$eta[-3L], tolerance = 1e-10)
})

test_that("#1138: spde_dep_slope is named, not dropped in silence, when it cannot be rebuilt", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_dep_slope_1138_fit("dep")
  fit <- fx$fit
  df <- fx$df
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est

  ## Without the covariate the slope term cannot be formed.
  no_x <- df[, setdiff(names(df), "x"), drop = FALSE]
  expect_warning(
    est_no_x <- suppressMessages(predict(fit, newdata = no_x))$est,
    class = "gllvmTMB_predict_newdata_re_dropped"
  )
  expect_equal(est_no_x, fixed_only, tolerance = 1e-10)

  ## Without the coordinates the fields cannot be projected.
  no_xy <- df[, setdiff(names(df), c("lon", "lat")), drop = FALSE]
  expect_warning(
    est_no_xy <- suppressMessages(predict(fit, newdata = no_xy))$est,
    class = "gllvmTMB_predict_newdata_re_dropped"
  )
  expect_equal(est_no_xy, fixed_only, tolerance = 1e-10)

  ## Outside the mesh hull the fields are exactly 0, and that is reported.
  far <- df
  far$lon <- df$lon + 500
  far$lat <- df$lat + 500
  expect_warning(
    suppressMessages(predict(fit, newdata = far)),
    class = "gllvmTMB_predict_newdata_outside_mesh"
  )
})
