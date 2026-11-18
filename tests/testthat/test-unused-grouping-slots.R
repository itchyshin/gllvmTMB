## Issue #1190: optional unit_obs / cluster slots are defaults unless a
## covariance keyword consumes their explicitly supplied columns.

.unused_grouping_fixture <- function() {
  set.seed(1190)
  dat <- expand.grid(
    site = factor(seq_len(8L)),
    trait = factor(c("trait_1", "trait_2")),
    KEEP.OUT.ATTRS = FALSE
  )
  dat <- dat[order(dat$site, dat$trait), ]
  dat$value <- rnorm(nrow(dat))
  dat$obs <- factor(dat$site)
  dat$grp <- factor(rep(c("a", "b"), each = 8L))
  dat
}

.unused_grouping_warnings <- function(expr) {
  out <- character()
  withCallingHandlers(
    force(expr),
    warning = function(w) {
      out <<- c(out, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  grep("Unused optional grouping argument", out, value = TRUE)
}

.unused_grouping_control <- gllvmTMBcontrol(
  n_init = 1,
  init_jitter = 0,
  se = FALSE
)

.unused_grouping_formula <- value ~ 0 + trait + latent(0 + trait | site, d = 1)

test_that("explicit unused unit_obs, cluster, and both slots warn", {
  dat <- .unused_grouping_fixture()

  unit_obs_warning <- .unused_grouping_warnings(gllvmTMB(
    .unused_grouping_formula, data = dat, unit = "site", unit_obs = "obs",
    control = .unused_grouping_control
  ))
  cluster_warning <- .unused_grouping_warnings(gllvmTMB(
    .unused_grouping_formula, data = dat, unit = "site", cluster = "grp",
    control = .unused_grouping_control
  ))
  both_warning <- .unused_grouping_warnings(gllvmTMB(
    .unused_grouping_formula, data = dat, unit = "site", unit_obs = "obs",
    cluster = "grp", control = .unused_grouping_control
  ))

  expect_length(unit_obs_warning, 1L)
  expect_match(unit_obs_warning, "unit_obs")
  expect_length(cluster_warning, 1L)
  expect_match(cluster_warning, "cluster")
  expect_length(both_warning, 1L)
  expect_match(both_warning, "unit_obs")
  expect_match(both_warning, "cluster")
})

test_that("covariance keywords consuming explicit unit_obs and cluster do not warn", {
  dat <- .unused_grouping_fixture()
  form <- value ~ 0 + trait +
    indep(0 + trait | obs) +
    indep(0 + trait | grp)

  warnings <- .unused_grouping_warnings(gllvmTMB(
    form, data = dat, unit = "site", unit_obs = "obs", cluster = "grp",
    control = .unused_grouping_control
  ))

  expect_length(warnings, 0L)
})

test_that("a kernel keyword consuming an explicit cluster does not warn", {
  dat <- .unused_grouping_fixture()
  K <- diag(nlevels(dat$grp))
  dimnames(K) <- list(levels(dat$grp), levels(dat$grp))
  form <- value ~ 0 + trait + kernel_unique(grp, K = K, name = "fixture")

  warnings <- .unused_grouping_warnings(gllvmTMB(
    form, data = dat, unit = "site", cluster = "grp",
    control = .unused_grouping_control
  ))

  expect_length(warnings, 0L)
})

test_that("NULL and omitted optional slots do not warn", {
  dat <- .unused_grouping_fixture()

  explicit_null <- .unused_grouping_warnings(gllvmTMB(
    .unused_grouping_formula, data = dat, unit = "site", unit_obs = NULL,
    cluster = NULL, control = .unused_grouping_control
  ))
  omitted <- .unused_grouping_warnings(gllvmTMB(
    .unused_grouping_formula, data = dat, unit = "site",
    control = .unused_grouping_control
  ))

  expect_length(explicit_null, 0L)
  expect_length(omitted, 0L)
})

test_that("wide traits() calls preserve explicit unused-slot warnings", {
  set.seed(1190)
  wide <- data.frame(
    id = factor(seq_len(8L)),
    obs = factor(seq_len(8L)),
    y_1 = rnorm(8L),
    y_2 = rnorm(8L)
  )

  warnings <- .unused_grouping_warnings(gllvmTMB(
    traits(y_1, y_2) ~ 1, data = wide, unit = "id", unit_obs = "obs",
    control = .unused_grouping_control
  ))

  expect_length(warnings, 1L)
  expect_match(warnings, "unit_obs")
})
