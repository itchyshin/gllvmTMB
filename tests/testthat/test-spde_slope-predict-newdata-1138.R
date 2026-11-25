## #1138: predict(newdata = ) re-adds the base augmented SPDE slope tier
## (`spde_slope`), the intercept and slope fields of
## spatial_unique(1 + x | coords).
##
## Acceptance is the issue's own: on a fit carrying the tier,
## predict(fit, newdata = <training rows>)$est equals fit$report$eta with
## max|diff| == 0. A non-zero contribution, or agreement to a tolerance, does
## not tell a correct reshape from a plausible one; the exact identity does.
##
## The covariate takes values in {0, +-2^k} on purpose. Per row the template
## adds A_alpha(o) + x(o) * A_beta(o) (src/gllvmTMB.cpp:3486-3494). With x a
## signed power of two that product is exact in floating point, so the identity
## is exact whether or not the compiler fuses the template's multiply-add into
## one rounding (clang on arm64 does by default). With a general covariate the
## rebuilt predictor is exact only where that fusing is absent.

.spde_slope_1138_data <- function(seed = 11L, n_sites = 40L, n_traits = 3L) {
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
  field_a <- sin(4 * df$lon) + cos(3 * df$lat)
  field_b <- 0.6 * cos(5 * df$lon * df$lat)
  df$value <- c(0.3, -0.2, 0.5)[df$trait_id] + field_a + df$x * field_b +
    stats::rnorm(nrow(df), sd = 0.2)
  df$site <- factor(df$site)
  df$species <- factor(df$species)
  df$site_species <- factor(df$site_species)
  df
}

## One fit per formula, shared by the tests below.
.spde_slope_1138_fit <- local({
  cache <- list()
  function(kind = c("unique", "unique_long", "dep")) {
    kind <- match.arg(kind)
    if (is.null(cache[[kind]])) {
      df <- .spde_slope_1138_data()
      mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1)
      form <- switch(kind,
        unique = value ~ 0 + trait + spatial_unique(1 + x | coords),
        unique_long = value ~ 0 + trait +
          spatial_unique(0 + trait + (0 + trait):x | coords),
        dep = value ~ 0 + trait + spatial_dep(1 + x | coords)
      )
      fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        form, data = df, mesh = mesh, unit = "site", silent = TRUE
      )))
      cache[[kind]] <<- list(fit = fit, df = df)
    }
    cache[[kind]]
  }
})

.spde_slope_1138_flag <- function(fit, name) {
  isTRUE(as.integer(fit$tmb_data[[name]]) == 1L)
}

test_that("#1138: spde_slope is re-added on newdata, exactly", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_slope_1138_fit("unique")
  fit <- fx$fit
  df <- fx$df
  expect_true(.spde_slope_1138_flag(fit, "use_spde_slope"))
  expect_false(.spde_slope_1138_flag(fit, "use_spde_dep_slope"))
  expect_false(.spde_slope_1138_flag(fit, "use_spde"))

  on_newdata <- suppressMessages(predict(fit, newdata = df))
  expect_equal(max(abs(on_newdata$est - fit$report$eta)), 0, tolerance = 1e-10)
  expect_equal(on_newdata$est, suppressMessages(predict(fit))$est, tolerance = 1e-10)

  ## The tier is the fit's only random effect and it is not small, so the
  ## identity above cannot hold by the tier being absent on both sides.
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))
  expect_gt(max(abs(fit$report$eta - fixed_only$est)), 0.1)

  ## Nothing is left to name as omitted.
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
  expect_message(
    predict(fit, newdata = df),
    "spde_slope", fixed = TRUE
  )
})

test_that("#1138: spde_slope is re-added exactly for the long-format slope term", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  ## `0 + trait + (0 + trait):x` is the long spelling of `1 + x`; both build
  ## the same two-column Z_spde_aug (R/fit-multi.R:5736-5739).
  fx <- .spde_slope_1138_fit("unique_long")
  fit <- fx$fit
  expect_true(.spde_slope_1138_flag(fit, "use_spde_slope"))
  expect_false(.spde_slope_1138_flag(fit, "use_spde_dep_slope"))

  on_newdata <- suppressMessages(predict(fit, newdata = fx$df))
  expect_equal(max(abs(on_newdata$est - fit$report$eta)), 0, tolerance = 1e-10)
  expect_no_warning(suppressMessages(predict(fit, newdata = fx$df)))
})

test_that("#1138: spde_slope follows each newdata row, in any order", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_slope_1138_fit("unique")
  fit <- fx$fit
  df <- fx$df

  set.seed(2)
  rows <- sample(nrow(df), 45L)
  sub <- suppressMessages(predict(fit, newdata = df[rows, ]))
  expect_equal(max(abs(sub$est - fit$report$eta[rows])), 0, tolerance = 1e-10)

  one <- suppressMessages(predict(fit, newdata = df[rows[1L], ]))
  expect_equal(one$est, fit$report$eta[rows[1L]], tolerance = 1e-10)
})

test_that("#1138: spde_slope uses the covariate carried by newdata", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_slope_1138_fit("unique")
  fit <- fx$fit
  df <- fx$df
  par <- fit$tmb_obj$env$last.par.best
  om <- matrix(par[names(par) == "omega_spde_aug"],
               nrow = ncol(fit$tmb_data$A_proj), ncol = 2L)
  field_alpha <- as.numeric(fit$tmb_data$A_proj %*% om[, 1L])
  field_beta <- as.numeric(fit$tmb_data$A_proj %*% om[, 2L])
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est

  ## x = 0 leaves the intercept field alone; x = 1 adds the slope field once.
  at0 <- df
  at0$x <- 0
  at1 <- df
  at1$x <- 1
  est0 <- suppressMessages(predict(fit, newdata = at0))$est
  est1 <- suppressMessages(predict(fit, newdata = at1))$est
  expect_equal(est0, fixed_only + field_alpha, tolerance = 1e-10)
  expect_equal(est1, fixed_only + (field_alpha + field_beta), tolerance = 1e-10)
  expect_gt(max(abs(field_beta)), 0.01)

  ## A row with no covariate value has no defined slope term.
  na_x <- df
  na_x$x[3L] <- NA
  est_na <- suppressMessages(predict(fit, newdata = na_x))$est
  expect_true(is.na(est_na[3L]))
  expect_equal(est_na[-3L], fit$report$eta[-3L], tolerance = 1e-10)
})

test_that("#1138: spde_slope is named, not dropped in silence, when it cannot be rebuilt", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_slope_1138_fit("unique")
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

  ## Outside the mesh hull the fields are exactly 0; that is reported, as it
  ## is for the intercept-only SPDE tier.
  far <- df
  far$lon <- df$lon + 500
  far$lat <- df$lat + 500
  expect_warning(
    suppressMessages(predict(fit, newdata = far)),
    class = "gllvmTMB_predict_newdata_outside_mesh"
  )
})

test_that("#1138: the two-column spde_slope rebuild is not applied to the 2T-field channel", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  ## spatial_dep(1 + x | coords) raises use_spde_slope too, but its
  ## omega_spde_aug holds 2 * n_traits interleaved fields
  ## (src/gllvmTMB.cpp:1585-1586). Reading it as the two-column block would
  ## return a finite, plausible, wrong number.
  fx <- .spde_slope_1138_fit("dep")
  fit <- fx$fit
  expect_true(.spde_slope_1138_flag(fit, "use_spde_slope"))
  expect_true(.spde_slope_1138_flag(fit, "use_spde_dep_slope"))
  expect_identical(as.integer(fit$tmb_data$n_lhs_cols_spde), 6L)
  expect_null(.gllvmTMB_spde_slope_newdata_contrib(fit, fx$df))
})
