## Issues #1396, #1356, #1394, #1375: inputs that used to reach the TMB
## objective unchecked must fail early with a message that names the cause,
## not "All 1 restarts failed." (or, worse, fit silently).

.iv_long <- function(n = 14L, seed = 5L) {
  set.seed(seed)
  d <- expand.grid(
    trait = factor(c("a", "b", "c")),
    unit = factor(sprintf("u%02d", seq_len(n))),
    rep = 1:2
  )
  d$x <- stats::rnorm(nrow(d))
  d$value <- stats::rnorm(nrow(d))
  d
}

.iv_ctl <- function() gllvmTMBcontrol(n_init = 1, se = FALSE)

## ---- #1396: factor response -------------------------------------------------
test_that("a factor response on a gaussian trait is refused, not fitted as level codes (#1396)", {
  set.seed(2)
  d <- .iv_long(20L)
  d$value <- factor(sample(c("3", "7", "12"), nrow(d), TRUE))
  expect_error(
    gllvmTMB(value ~ 0 + trait + unique(0 + trait | unit), data = d,
             unit = "unit", trait = "trait", family = gaussian(),
             control = .iv_ctl()),
    class = "gllvmTMB_factor_response"
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + unique(0 + trait | unit), data = d,
             unit = "unit", trait = "trait", family = gaussian(),
             control = .iv_ctl()),
    "factor"
  )
})

## ---- #1356: response support -------------------------------------------------
.iv_count <- function(y_edit, family) {
  d <- .iv_long()
  d$value <- stats::rpois(nrow(d), 3)
  d$value <- y_edit(d$value)
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1), data = d,
           unit = "unit", trait = "trait", family = family,
           control = .iv_ctl())
}

test_that("plain poisson / nbinom2 refuse negative and non-integer counts (#1356)", {
  neg <- function(y) { y[1L] <- -1; y }
  frac <- function(y) y + 0.5
  for (fam in list(poisson(), nbinom2())) {
    expect_error(.iv_count(neg, fam), class = "gllvmTMB_count_response_support")
    expect_error(.iv_count(frac, fam), class = "gllvmTMB_count_response_support")
  }
  expect_error(.iv_count(neg, poisson()), "non-negative integer")
})

test_that("a non-integer binomial success count warns (#1356)", {
  d <- .iv_long()
  set.seed(1)
  d$value <- stats::rbinom(nrow(d), 1, 0.5)
  d$value[1:5] <- 0.5
  expect_warning(
    try(gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1), data = d,
                 unit = "unit", trait = "trait", family = binomial(),
                 control = .iv_ctl()), silent = TRUE),
    class = "gllvmTMB_binomial_noninteger"
  )
})

## ---- #1394: NA in a random-slope covariate -----------------------------------
test_that("NA in a latent(1 + x | unit) slope covariate names the column (#1394)", {
  d <- .iv_long()
  d$x[7L] <- NA
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(1 + x | unit, d = 1), data = d,
             unit = "unit", trait = "trait", family = gaussian(),
             control = .iv_ctl()),
    class = "gllvmTMB_slope_covariate_nonfinite"
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(1 + x | unit, d = 1), data = d,
             unit = "unit", trait = "trait", family = gaussian(),
             control = .iv_ctl()),
    "slope covariate.*\"x\""
  )
})

## ---- #1375: NA in a phylo_slope() covariate ----------------------------------
test_that("NA in a phylo_slope(x | species) covariate names the column (#1375)", {
  set.seed(5)
  ns <- 15L; nt <- 3L
  sp <- paste0("sp", seq_len(ns))
  A <- 0.5^abs(outer(seq_len(ns), seq_len(ns), "-"))
  dimnames(A) <- list(sp, sp)
  d <- expand.grid(species = factor(sp, levels = sp),
                   trait = factor(paste0("t", seq_len(nt))), rep = 1:3)
  d$x <- stats::rnorm(nrow(d))
  d$value <- stats::rnorm(nrow(d))
  d$x[c(4L, 40L)] <- NA
  expect_error(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + phylo_slope(x | species, vcv = A), data = d,
      unit = "species", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE))),
    class = "gllvmTMB_slope_covariate_nonfinite"
  )
})
