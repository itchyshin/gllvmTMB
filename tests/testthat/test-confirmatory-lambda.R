## Tests for confirmatory_lambda(): biology-aware builder for a
## `lambda_constraint` matrix from functional-group membership.

test_that("confirmatory_lambda() returns the expected pin pattern", {
  species <- c("A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2", "C3", "C4")
  group   <- c(rep("A", 3), rep("B", 3), rep("C", 4))

  M <- confirmatory_lambda(
    species  = species,
    group    = group,
    d        = 2L,
    loads_on = list(A = 1L, B = 2L)
  )

  ## Shape + names
  expect_equal(dim(M), c(10L, 2L))
  expect_equal(rownames(M), species)
  expect_equal(colnames(M), c("LV1", "LV2"))

  ## Group A: zero on axis 2 (anchored at A1 on axis 1 = +1).
  expect_equal(M["A1", 1], 1)
  expect_true(is.na(M["A2", 1]))
  expect_true(is.na(M["A3", 1]))
  expect_equal(M["A1", 2], 0)
  expect_equal(M["A2", 2], 0)
  expect_equal(M["A3", 2], 0)

  ## Group B: zero on axis 1 (anchored at B1 on axis 2 = +1).
  expect_equal(M["B1", 1], 0)
  expect_equal(M["B2", 1], 0)
  expect_equal(M["B3", 1], 0)
  expect_equal(M["B1", 2], 1)
  expect_true(is.na(M["B2", 2]))
  expect_true(is.na(M["B3", 2]))

  ## Group C: free on both axes.
  for (sp in c("C1", "C2", "C3", "C4")) {
    expect_true(is.na(M[sp, 1]))
    expect_true(is.na(M[sp, 2]))
  }
})

test_that("confirmatory_lambda() honours manual anchor override", {
  species <- c("A1", "A2", "A3", "B1", "B2", "B3")
  group   <- c(rep("A", 3), rep("B", 3))

  ## Manually anchor A2 on axis 1 and B3 on axis 2 (not the defaults).
  M <- confirmatory_lambda(
    species  = species,
    group    = group,
    d        = 2L,
    loads_on = list(A = 1L, B = 2L),
    anchors  = c("A2", "B3")
  )

  expect_equal(M["A2", 1], 1)
  expect_true(is.na(M["A1", 1]))
  expect_true(is.na(M["A3", 1]))
  expect_equal(M["B3", 2], 1)
  expect_true(is.na(M["B1", 2]))
  expect_true(is.na(M["B2", 2]))
})

test_that("confirmatory_lambda() respects custom axis_labels", {
  M <- confirmatory_lambda(
    species     = c("A1", "B1"),
    group       = c("A", "B"),
    d           = 2L,
    loads_on    = list(A = 1L, B = 2L),
    axis_labels = c("shade", "drought")
  )
  expect_equal(colnames(M), c("shade", "drought"))
})

test_that("confirmatory_lambda() errors on bad inputs", {
  species <- c("A1", "B1")
  group   <- c("A", "B")

  ## Mismatched length
  expect_error(
    confirmatory_lambda(
      species  = species,
      group    = c("A", "B", "C"),
      d        = 2L,
      loads_on = list(A = 1L, B = 2L)
    ),
    "same length"
  )

  ## Anchor not in species
  expect_error(
    confirmatory_lambda(
      species  = species,
      group    = group,
      d        = 2L,
      loads_on = list(A = 1L, B = 2L),
      anchors  = c("ZZZ", "B1")
    ),
    "Anchor species"
  )

  ## Axis index out of range
  expect_error(
    confirmatory_lambda(
      species  = species,
      group    = group,
      d        = 2L,
      loads_on = list(A = 1L, B = 99L)
    ),
    "outside|must be in"
  )

  ## Unnamed loads_on
  expect_error(
    confirmatory_lambda(
      species  = species,
      group    = group,
      d        = 2L,
      loads_on = list(1L, 2L)
    ),
    "named"
  )

  ## Duplicate species names
  expect_error(
    confirmatory_lambda(
      species  = c("A1", "A1"),
      group    = c("A", "A"),
      d        = 2L,
      loads_on = list(A = 1L)
    ),
    "duplicates"
  )
})

test_that("confirmatory_lambda() output is consumable by gllvmTMB()", {
  ## Build a small fixture to confirm end-to-end the matrix shape works.
  skip_if_not_installed("TMB")

  set.seed(20260527)
  n_sites <- 40L
  species_names <- c(paste0("A_", 1:3), paste0("B_", 1:3), paste0("C_", 1:4))
  group <- c(rep("A", 3), rep("B", 3), rep("C", 4))

  ## True loadings.
  Lambda <- matrix(0, length(species_names), 2L)
  Lambda[1:3, 1]  <- runif(3, 0.7, 1.1)
  Lambda[4:6, 2]  <- runif(3, 0.7, 1.1)
  Lambda[7:10, ] <- runif(8, -0.8, 0.8)

  U <- matrix(rnorm(n_sites * 2L), n_sites, 2L)
  alpha <- rnorm(length(species_names), 0, 0.3)
  eta <- matrix(alpha, n_sites, length(species_names), byrow = TRUE) +
    U %*% t(Lambda)
  y_wide <- matrix(rbinom(length(eta), 1, pnorm(eta)),
                   n_sites, length(species_names))
  colnames(y_wide) <- species_names
  df_long <- data.frame(
    site  = factor(rep(seq_len(n_sites), times = length(species_names))),
    trait = factor(rep(species_names, each = n_sites),
                   levels = species_names),
    value = as.integer(c(y_wide))
  )

  M <- confirmatory_lambda(
    species  = species_names,
    group    = group,
    d        = 2L,
    loads_on = list(A = 1L, B = 2L)
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data              = df_long,
    family            = stats::binomial(link = "probit"),
    lambda_constraint = list(unit = M)
  )

  expect_equal(fit$opt$convergence, 0L)

  ## Pinned cells in fitted Lambda are exactly the pins we asked for.
  L_hat <- getLoadings(fit, level = "unit")
  expect_equal(L_hat["A_1", 1], 1, tolerance = 1e-6)
  for (sp in paste0("A_", 1:3)) expect_equal(L_hat[sp, 2], 0, tolerance = 1e-6)
  for (sp in paste0("B_", 1:3)) expect_equal(L_hat[sp, 1], 0, tolerance = 1e-6)
  expect_equal(L_hat["B_1", 2], 1, tolerance = 1e-6)
})

test_that("legacy lambda_constraint = list(B = ...) still works with deprecation message", {
  skip_if_not_installed("TMB")

  ## Reset the once-per-session option so we actually see the warning.
  withr::local_options(gllvmTMB.warned_lambda_constraint_B = NULL)

  set.seed(20260527)
  n_sites <- 30L
  species_names <- c(paste0("A_", 1:3), paste0("B_", 1:3))
  Lambda <- matrix(0, 6L, 2L)
  Lambda[1:3, 1] <- runif(3, 0.7, 1.0)
  Lambda[4:6, 2] <- runif(3, 0.7, 1.0)
  U <- matrix(rnorm(n_sites * 2L), n_sites, 2L)
  eta <- U %*% t(Lambda)
  y_wide <- matrix(rbinom(length(eta), 1, pnorm(eta)), n_sites, 6L)
  colnames(y_wide) <- species_names
  df_long <- data.frame(
    site  = factor(rep(seq_len(n_sites), times = 6L)),
    trait = factor(rep(species_names, each = n_sites), levels = species_names),
    value = as.integer(c(y_wide))
  )

  M <- confirmatory_lambda(
    species  = species_names,
    group    = c(rep("A", 3), rep("B", 3)),
    d        = 2L,
    loads_on = list(A = 1L, B = 2L)
  )

  ## Legacy name `B` should warn but still fit successfully.
  expect_warning(
    fit_legacy <- gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2L),
      data              = df_long,
      family            = stats::binomial(link = "probit"),
      lambda_constraint = list(B = M)
    ),
    "deprecated"
  )
  expect_equal(fit_legacy$opt$convergence, 0L)
})

test_that("unknown lambda_constraint element name errors clearly", {
  expect_error(
    .normalise_lambda_constraint_names(list(banana = matrix(NA, 2, 2))),
    "Unknown element"
  )
})
