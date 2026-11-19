## Issue #1765: animal_*(individual, ...) with cluster omitted must group by
## individual, not by a placeholder species column.

.fix1765_layout <- function() {
  set.seed(1765)
  ids <- paste0("i", 1:6)
  df <- expand.grid(
    individual = factor(ids),
    trait = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- stats::rnorm(nrow(df))
  A <- diag(length(ids))
  dimnames(A) <- list(ids, ids)
  list(df = df, A = A)
}

.fix1765_control <- function() {
  gllvmTMBcontrol(n_init = 1L, se = FALSE, laplace_auto_refit = FALSE)
}

test_that("animal_latent(individual) fits without cluster and matches cluster = individual (#1765)", {
  fx <- .fix1765_layout()
  A <- fx$A
  ctrl <- .fix1765_control()
  fit_omit <- gllvmTMB(
    value ~ 0 + trait + animal_latent(individual, d = 1, A = A),
    data = fx$df, unit = "individual", trait = "trait",
    control = ctrl, silent = TRUE
  )
  fit_cluster <- gllvmTMB(
    value ~ 0 + trait + animal_latent(individual, d = 1, A = A),
    data = fx$df, unit = "individual", trait = "trait",
    cluster = "individual",
    control = ctrl, silent = TRUE
  )
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(fit_cluster$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-8
  )
})

test_that("animal_indep(0 + trait | individual) fits without cluster (#1765)", {
  fx <- .fix1765_layout()
  A <- fx$A
  fit <- gllvmTMB(
    value ~ 0 + trait + animal_indep(0 + trait | individual, A = A),
    data = fx$df, unit = "individual", trait = "trait",
    control = .fix1765_control(), silent = TRUE
  )
  expect_s3_class(fit, "gllvmTMB")
  expect_equal(fit$opt$convergence, 0L)
})

test_that("a missing animal grouping names that column (#1765)", {
  fx <- .fix1765_layout()
  A <- fx$A
  df <- fx$df
  df$individual <- NULL
  df$unit <- factor(rep(paste0("u", 1:6), length.out = nrow(df)))
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + animal_latent(individual, d = 1, A = A),
      data = df, unit = "unit", trait = "trait",
      control = .fix1765_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_animal_grouping")
  expect_match(conditionMessage(err), "groups by [^a-z]*individual")
  expect_no_match(conditionMessage(err), "placeholder")
})

test_that("an explicit cluster is not replaced by the animal term (#1765)", {
  fx <- .fix1765_layout()
  A <- fx$A
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + animal_latent(individual, d = 1, A = A),
      data = fx$df, unit = "individual", trait = "trait",
      cluster = "trait",
      control = .fix1765_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_false(inherits(err, "gllvmTMB_animal_grouping"))
})

test_that("animal_latent ignores id_label partial-name trap (#1765)", {
  groups <- gllvmTMB:::.gllvmTMB_animal_bare_groups(
    quote(value ~ animal_latent(d = 1, id_label = taxon, A = A))
  )
  expect_equal(nrow(groups), 0L)
  groups_named <- gllvmTMB:::.gllvmTMB_animal_bare_groups(
    quote(value ~ animal_latent(id = taxon, d = 1, A = A))
  )
  expect_equal(groups_named$group, "taxon")
})