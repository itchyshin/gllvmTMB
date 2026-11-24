## #1138: predict(newdata = ) re-adds the reduced-rank SPDE slope tier
## (`spde_latent_slope`), the intercept and slope fields of
## spatial_latent(1 + x | coords, d = K).
##
## Acceptance is the issue's own: on a fit carrying the tier,
## predict(fit, newdata = <training rows>)$est equals fit$report$eta with
## max|diff| == 0. A non-zero contribution, or agreement to a tolerance, does
## not tell a correct reshape from a plausible one; the exact identity does.
##
## The exact pin is on a d = 1 fit whose covariate takes values in
## {0, +-2^k}. Per row the template adds
##   sum_k Z(o, k) * sum_f Lambda(t, f, k) * A_g(o, f, k)
## (src/gllvmTMB.cpp:3495-3507). With one factor the inner sum is a single
## product, and with x a signed power of two the outer product is exact, so
## the identity does not depend on whether the compiler fuses the template's
## multiply-adds into one rounding (clang on arm64 does by default). With
## d >= 2 the inner sum is a genuine multiply-add: the d = 2 test below pins
## the reshape to within a few units in the last place, plus a check that the
## transposed reading of each block is far outside that.

.spde_latent_slope_1138_data <- function(seed = 23L, n_sites = 60L,
                                         n_traits = 4L) {
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
  ## Two fields behind the intercept and two behind the slope, so a d = 2 fit
  ## has a second factor to find in each design column.
  field_a1 <- sin(4 * df$lon) + cos(3 * df$lat)
  field_a2 <- cos(6 * df$lon) * sin(5 * df$lat)
  field_b1 <- cos(5 * df$lon * df$lat)
  field_b2 <- sin(7 * (df$lon - df$lat))
  load_a1 <- c(1, 0.6, -0.5, 0.8)[df$trait_id]
  load_a2 <- c(-0.6, 0.8, 0.7, 0.2)[df$trait_id]
  load_b1 <- c(0.7, -0.4, 0.5, 0.3)[df$trait_id]
  load_b2 <- c(0.4, 0.6, -0.5, -0.7)[df$trait_id]
  df$value <- c(0.3, -0.2, 0.5, 0.1)[df$trait_id] +
    load_a1 * field_a1 + load_a2 * field_a2 +
    df$x * (load_b1 * field_b1 + load_b2 * field_b2) +
    stats::rnorm(nrow(df), sd = 0.2)
  df$site <- factor(df$site)
  df$species <- factor(df$species)
  df$site_species <- factor(df$site_species)
  df
}

## One fit per rank, shared by the tests below.
.spde_latent_slope_1138_fit <- local({
  cache <- list()
  function(kind = c("d1", "d2")) {
    kind <- match.arg(kind)
    if (is.null(cache[[kind]])) {
      df <- .spde_latent_slope_1138_data()
      mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1)
      form <- switch(kind,
        d1 = value ~ 0 + trait + spatial_latent(1 + x | coords, d = 1),
        d2 = value ~ 0 + trait + spatial_latent(1 + x | coords, d = 2)
      )
      fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        form, data = df, mesh = mesh, unit = "site", silent = TRUE
      )))
      cache[[kind]] <<- list(fit = fit, df = df)
    }
    cache[[kind]]
  }
})

.spde_latent_slope_1138_flag <- function(fit, name) {
  isTRUE(as.integer(fit$tmb_data[[name]]) == 1L)
}

test_that("#1138: spde_latent_slope is re-added on newdata, exactly", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_latent_slope_1138_fit("d1")
  fit <- fx$fit
  df <- fx$df
  expect_true(.spde_latent_slope_1138_flag(fit, "use_spde_latent_slope"))
  expect_false(.spde_latent_slope_1138_flag(fit, "use_spde_slope"))
  expect_false(.spde_latent_slope_1138_flag(fit, "use_spde"))
  expect_identical(as.integer(fit$tmb_data$d_spde_slope), 1L)

  on_newdata <- suppressMessages(predict(fit, newdata = df))
  expect_identical(max(abs(on_newdata$est - fit$report$eta)), 0)
  expect_identical(on_newdata$est, suppressMessages(predict(fit))$est)

  ## The tier is the fit's only random effect and it is not small, so the
  ## identity above cannot hold by the tier being absent on both sides.
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))
  expect_gt(max(abs(fit$report$eta - fixed_only$est)), 0.1)

  ## Nothing is left to name as omitted.
  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
  expect_message(
    predict(fit, newdata = df),
    "spde_latent_slope", fixed = TRUE
  )
})

test_that("#1138: spde_latent_slope follows each newdata row, in any order", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_latent_slope_1138_fit("d1")
  fit <- fx$fit
  df <- fx$df

  set.seed(2)
  rows <- sample(nrow(df), 50L)
  sub <- suppressMessages(predict(fit, newdata = df[rows, ]))
  expect_identical(max(abs(sub$est - fit$report$eta[rows])), 0)

  one <- suppressMessages(predict(fit, newdata = df[rows[1L], ]))
  expect_identical(one$est, fit$report$eta[rows[1L]])
})

test_that("#1138: spde_latent_slope uses the covariate carried by newdata", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_latent_slope_1138_fit("d1")
  fit <- fx$fit
  df <- fx$df
  n_mesh <- ncol(fit$tmb_data$A_proj)
  par <- fit$tmb_obj$env$last.par.best
  g <- array(par[names(par) == "g_spde_slope"], dim = c(n_mesh, 1L, 2L))
  lam <- array(as.numeric(fit$report$Lambda_spde_slope),
               dim = c(fit$n_traits, 1L, 2L))
  tr <- as.integer(df$trait)
  field_alpha <- lam[tr, 1L, 1L] *
    as.numeric(fit$tmb_data$A_proj %*% g[, 1L, 1L])
  field_beta <- lam[tr, 1L, 2L] *
    as.numeric(fit$tmb_data$A_proj %*% g[, 1L, 2L])
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est

  ## x = 0 leaves the intercept fields alone; x = 1 adds the slope fields once.
  at0 <- df
  at0$x <- 0
  at1 <- df
  at1$x <- 1
  est0 <- suppressMessages(predict(fit, newdata = at0))$est
  est1 <- suppressMessages(predict(fit, newdata = at1))$est
  expect_identical(est0, fixed_only + field_alpha)
  expect_identical(est1, fixed_only + (field_alpha + field_beta))
  expect_gt(max(abs(field_beta)), 0.01)

  ## A row with no covariate value has no defined slope term.
  na_x <- df
  na_x$x[3L] <- NA
  est_na <- suppressMessages(predict(fit, newdata = na_x))$est
  expect_true(is.na(est_na[3L]))
  expect_identical(est_na[-3L], fit$report$eta[-3L])
})

test_that("#1138: spde_latent_slope is named, not dropped in silence, when it cannot be rebuilt", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_latent_slope_1138_fit("d1")
  fit <- fx$fit
  df <- fx$df
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est

  ## Without the covariate the slope term cannot be formed.
  no_x <- df[, setdiff(names(df), "x"), drop = FALSE]
  expect_warning(
    est_no_x <- suppressMessages(predict(fit, newdata = no_x))$est,
    class = "gllvmTMB_predict_newdata_re_dropped"
  )
  expect_identical(est_no_x, fixed_only)

  ## Without the coordinates the fields cannot be projected.
  no_xy <- df[, setdiff(names(df), c("lon", "lat")), drop = FALSE]
  expect_warning(
    est_no_xy <- suppressMessages(predict(fit, newdata = no_xy))$est,
    class = "gllvmTMB_predict_newdata_re_dropped"
  )
  expect_identical(est_no_xy, fixed_only)

  ## Outside the mesh hull the fields are exactly 0, and that is reported.
  far <- df
  far$lon <- df$lon + 500
  far$lat <- df$lat + 500
  expect_warning(
    suppressMessages(predict(fit, newdata = far)),
    class = "gllvmTMB_predict_newdata_outside_mesh"
  )
})

test_that("#1138: spde_latent_slope is re-added with two factors per column", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")

  fx <- .spde_latent_slope_1138_fit("d2")
  fit <- fx$fit
  df <- fx$df
  expect_true(.spde_latent_slope_1138_flag(fit, "use_spde_latent_slope"))
  expect_identical(as.integer(fit$tmb_data$d_spde_slope), 2L)

  expect_no_warning(suppressMessages(predict(fit, newdata = df)))
  on_newdata <- suppressMessages(predict(fit, newdata = df))
  gap <- max(abs(on_newdata$est - fit$report$eta))

  ## With two factors the template's inner sum is a multiply-add, which a
  ## compiler may round once instead of twice. The bound is a few units in the
  ## last place of the largest predictor, not a statistical tolerance.
  ulp <- .Machine$double.eps * max(1, max(abs(fit$report$eta)))
  expect_lte(gap, 8 * ulp)

  ## What the bound has to tell apart: the same blocks read with the factor
  ## and design-column axes swapped give a finite predictor that is wrong by
  ## many orders of magnitude more.
  n_mesh <- ncol(fit$tmb_data$A_proj)
  par <- fit$tmb_obj$env$last.par.best
  g_swapped <- aperm(
    array(par[names(par) == "g_spde_slope"], dim = c(n_mesh, 2L, 2L)),
    c(1L, 3L, 2L)
  )
  lam <- array(as.numeric(fit$report$Lambda_spde_slope),
               dim = c(fit$n_traits, 2L, 2L))
  tr <- as.integer(df$trait)
  Z <- cbind(1, df$x)
  wrong <- numeric(nrow(df))
  for (k in 1:2) {
    u <- numeric(nrow(df))
    for (f in 1:2) {
      u <- u + lam[tr, f, k] *
        as.numeric(fit$tmb_data$A_proj %*% g_swapped[, f, k])
    }
    wrong <- wrong + Z[, k] * u
  }
  fixed_only <- suppressMessages(predict(fit, newdata = df, re_form = ~0))$est
  expect_gt(max(abs(fixed_only + wrong - fit$report$eta)), 1e-3)
})
