## A missing value in a random-slope covariate must stop the fit with the
## missing-predictor message that names the covariate, not the bare
## "All 1 restarts failed." (issues #1394 and #1375). The check fires in the
## design-matrix build, before TMB, so no optimiser run is needed.

.na_slope_msg <- "missing predictors still need to be removed or imputed"

.na_slope_unit_data <- function() {
  set.seed(5)
  n <- 14
  d <- expand.grid(
    trait = factor(c("a", "b", "c")),
    unit = factor(sprintf("u%02d", 1:n)),
    rep = 1:2
  )
  d$x <- stats::rnorm(nrow(d))
  d$value <- stats::rnorm(nrow(d))
  d
}

.na_slope_phylo_data <- function() {
  set.seed(5)
  ns <- 15
  nt <- 3
  sp <- paste0("sp", 1:ns)
  A <- 0.5^abs(outer(1:ns, 1:ns, "-"))
  dimnames(A) <- list(sp, sp)
  d <- expand.grid(
    species = factor(sp, levels = sp),
    trait = factor(paste0("t", 1:nt)),
    rep = 1:3
  )
  d$x <- stats::rnorm(nrow(d))
  d$x2 <- stats::rnorm(nrow(d))
  d$value <- stats::rnorm(nrow(d))
  list(d = d, A = A)
}

test_that("NA in a latent(1 + x | unit) slope covariate names x (#1394)", {
  d <- .na_slope_unit_data()
  d$x[7] <- NA
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(1 + x | unit, d = 1),
      data = d, unit = "unit", trait = "trait", family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1, se = FALSE)
    ),
    .na_slope_msg
  )
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(1 + x | unit, d = 1),
      data = d, unit = "unit", trait = "trait", family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1, se = FALSE)
    ),
    "`x`"
  )
})

test_that("NA in an unique(1 + x | unit) slope covariate names x (#1394)", {
  d <- .na_slope_unit_data()
  d$x[7] <- NA
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + unique(1 + x | unit),
      data = d, unit = "unit", trait = "trait", family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1, se = FALSE)
    ),
    .na_slope_msg
  )
})

test_that("NA in a phylo_slope(x | species) covariate names x (#1375)", {
  fx <- .na_slope_phylo_data()
  fx$d$x[c(4, 40)] <- NA
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_slope(x | species, vcv = fx$A),
      data = fx$d, unit = "species", cluster = "species",
      family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ),
    .na_slope_msg
  )
})

test_that("NA in a phylo_dep(1 + x + x2 | species) covariate names it (#1375)", {
  fx <- .na_slope_phylo_data()
  fx$d$x2[3] <- NA
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(1 + x + x2 | species, vcv = fx$A),
      data = fx$d, unit = "species", cluster = "species",
      family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ),
    "`x2`"
  )
})

test_that("NA in a phylo_latent(1 + x | species) covariate names x (#1394)", {
  fx <- .na_slope_phylo_data()
  fx$d$x[3] <- NA
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(1 + x | species, d = 1, vcv = fx$A),
      data = fx$d, unit = "species", cluster = "species",
      family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ),
    .na_slope_msg
  )
})
