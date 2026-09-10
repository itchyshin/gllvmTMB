.temporal_animal_rep_fixture <- function() {
  pedigree <- data.frame(
    id = paste0("a", 1:4), sire = c(NA, NA, "a1", "a1"),
    dam = c(NA, NA, "a2", "a2"), stringsAsFactors = FALSE
  )
  A <- pedigree_to_A(pedigree)
  data <- expand.grid(
    animal = rownames(A), occasion = 1:4, measurement = c("m1", "m2"),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data, as.numeric(factor(trait)) + .1 * occasion +
    c(a1 = -.2, a2 = .15, a3 = .05, a4 = .3)[animal] + c(m1 = -.03, m2 = .03)[measurement])
  list(data = data, A = A, pedigree = pedigree)
}

.temporal_animal_unobserved_fixture <- function() {
  ## a3/a4 are full siblings; a5 is their offspring.  The first two founders
  ## have no observations, so the sparse-Ainv path must marginalise them.
  pedigree <- data.frame(
    id = paste0("a", 1:5), sire = c(NA, NA, "a1", "a1", "a3"),
    dam = c(NA, NA, "a2", "a2", "a4"), stringsAsFactors = FALSE
  )
  A_expected <- matrix(c(
    1, 0, .5, .5, .5,
    0, 1, .5, .5, .5,
    .5, .5, 1, .5, .75,
    .5, .5, .5, 1, .75,
    .5, .5, .75, .75, 1.25
  ), 5L, 5L, byrow = TRUE, dimnames = list(paste0("a", 1:5), paste0("a", 1:5)))
  A <- pedigree_to_A(pedigree)
  observed <- c("a3", "a4", "a5")
  data <- expand.grid(
    animal = observed, occasion = 1:4, measurement = c("m1", "m2"),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data, as.numeric(factor(trait)) + .1 * occasion +
    c(a3 = .05, a4 = .3, a5 = -.1)[animal] + c(m1 = -.03, m2 = .03)[measurement])
  list(data = data, A = A, A_expected = A_expected, A_observed = A[observed, observed],
    pedigree = pedigree, observed = observed)
}

.temporal_animal_rep_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) +
      animal_indep(0 + trait | animal, A = fx$A),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
}

.temporal_animal_rep_dense_nll <- function(fit, fixed, A) {
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L; source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  Ktime <- ((1 - 1e-6) * tanh(par$theta_temporal_time)) ^ abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  temporal_var <- diag(exp(2 * par$theta_temporal_diag), td$n_traits)
  animal_var <- diag(par$theta_rr_phy^2, td$n_traits)
  V <- Ktime[state, state] * temporal_var[trait, trait] + A[source, source] * animal_var[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) + sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_animal_rep_product_nll <- function(fit, fixed, A) {
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L; source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  Ktime <- ((1 - 1e-6) * tanh(par$theta_temporal_time)) ^ abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  temporal_var <- diag(exp(2 * par$theta_temporal_diag), td$n_traits)
  V <- Ktime[state, state] * A[source, source] * temporal_var[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) + sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated AR1 temporal_indep plus fixed animal_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_animal_rep_fixture(); fit <- .temporal_animal_rep_fit(fx)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active)); expect_identical(fit$temporal$workflow, "replicated")
  expect_true(isTRUE(fit$use$phylo_rr)); expect_true(all(c("q_temporal", "g_phy") %in% fit$random))
  expect_equal(fit$phylo_vcv[rownames(fx$A), colnames(fx$A)], fx$A)
})

test_that("replicated temporal-animal likelihood and gradient equal a dense additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_animal_rep_fixture(); fit <- .temporal_animal_rep_fit(fx); fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(-.5 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6); fixed[names(fixed) == "log_sigma_eps"] <- log(.3)
  dense <- .temporal_animal_rep_dense_nll(fit, fixed, fx$A)
  expect_equal(as.numeric(fit$tmb_obj$fn(fixed)), dense, tolerance = 2e-6)
  expect_gt(abs(dense - .temporal_animal_rep_product_nll(fit, fixed, fx$A)), 1e-3)
  i <- match("theta_temporal_time", names(fixed)); h <- 1e-5
  plus <- fixed; plus[[i]] <- plus[[i]] + h; minus <- fixed; minus[[i]] <- minus[[i]] - h
  central <- (.temporal_animal_rep_dense_nll(fit, plus, fx$A) - .temporal_animal_rep_dense_nll(fit, minus, fx$A)) / (2 * h)
  expect_equal(fit$tmb_obj$gr(fixed)[[i]], central, tolerance = 2e-5)
})

test_that("animal pedigree precision marginalises unobserved ancestors and preserves inbreeding", {
  skip_if_not_installed("TMB")
  fx <- .temporal_animal_unobserved_fixture()
  expect_equal(fx$A, fx$A_expected, tolerance = 1e-12)
  expect_equal(fx$A["a5", "a5"], 1.25, tolerance = 1e-12)
  expect_equal(unname(fx$A["a5", c("a3", "a4")]), c(.75, .75), tolerance = 1e-12)
  dense_fx <- fx; dense_fx$A <- fx$A_observed
  dense <- .temporal_animal_rep_fit(dense_fx)
  pedigree_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) +
      animal_indep(0 + trait | animal, pedigree = fx$pedigree),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  Ainv <- pedigree_to_Ainv_sparse(fx$pedigree)
  precision_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) +
      animal_indep(0 + trait | animal, Ainv = Ainv),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  ## Conditioning on the observed rows of Ainv is not the marginal relatedness
  ## covariance.  This makes the control fail if ancestors are silently dropped.
  conditioned <- solve(as.matrix(Ainv)[fx$observed, fx$observed, drop = FALSE])
  expect_gt(max(abs(conditioned - fx$A_observed)), 1e-3)
  fixed <- dense$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(.4 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)
  expect_identical(names(pedigree_fit$opt$par), names(fixed))
  expect_identical(names(precision_fit$opt$par), names(fixed))
  expect_equal(as.numeric(dense$tmb_obj$fn(fixed)), as.numeric(pedigree_fit$tmb_obj$fn(fixed)), tolerance = 2e-6)
  expect_equal(as.numeric(dense$tmb_obj$fn(fixed)), as.numeric(precision_fit$tmb_obj$fn(fixed)), tolerance = 2e-6)
  expect_equal(dense$tmb_obj$gr(fixed), pedigree_fit$tmb_obj$gr(fixed), tolerance = 3e-5)
  expect_equal(dense$tmb_obj$gr(fixed), precision_fit$tmb_obj$gr(fixed), tolerance = 3e-5)
})

test_that("animal pedigree provenance, wide rewrite, simulation, and update preserve the source", {
  skip_if_not_installed("TMB")
  fx <- .temporal_animal_rep_fixture(); dense <- .temporal_animal_rep_fit(fx)
  pedigree_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) +
      animal_indep(0 + trait | animal, pedigree = fx$pedigree),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  Ainv <- Matrix::Matrix(solve(fx$A), sparse = TRUE)
  precision_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) +
      animal_indep(0 + trait | animal, Ainv = Ainv),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  order_a <- rev(rownames(fx$A)); A_permuted <- fx$A[order_a, order_a]
  permuted_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) +
      animal_indep(0 + trait | animal, A = A_permuted),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  wide_key <- unique(fx$data[c("animal", "occasion", "measurement")])
  wide <- wide_key[order(wide_key$animal, wide_key$occasion, wide_key$measurement), , drop = FALSE]
  for (j in 1:3) {
    s <- fx$data[fx$data$trait == paste0("t", j), ]
    wide[[paste0("y", j)]] <- s$value[order(s$animal, s$occasion, s$measurement)]
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 + temporal_indep(1 | animal, time = occasion, replicate = measurement) +
      animal_indep(1 | animal, A = fx$A),
    data = wide, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_equal(dense$opt$objective, pedigree_fit$opt$objective, tolerance = 1e-6)
  expect_equal(dense$opt$objective, precision_fit$opt$objective, tolerance = 1e-6)
  expect_equal(dense$opt$objective, permuted_fit$opt$objective, tolerance = 1e-6)
  expect_equal(unname(as.matrix(extract_temporal(dense)$pair_index)), unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  rows <- dense$data
  locate <- function(animal, occasion, measurement, trait) which(as.character(rows$animal) == animal & rows$occasion == occasion & as.character(rows$measurement) == measurement & as.character(rows$trait) == trait)
  i1 <- locate("a3", 1, "m1", "t1"); itime <- locate("a3", 2, "m1", "t1"); irep <- locate("a3", 1, "m2", "t1"); isource <- locate("a4", 1, "m1", "t1")
  par <- dense$tmb_obj$env$parList(dense$opt$par); phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal_var <- exp(2 * par$theta_temporal_diag[[1L]]); animal_var <- dense$report$Lambda_phy[1L, 1L]^2
  expected <- c(time = phi * temporal_var + fx$A["a3", "a3"] * animal_var,
    replicate = temporal_var + fx$A["a3", "a3"] * animal_var, source = fx$A["a3", "a4"] * animal_var)
  draw <- simulate(dense, nsim = 2000L, seed = 2609191L)
  observed <- c(time = cov(draw[i1, ], draw[itime, ]), replicate = cov(draw[i1, ], draw[irep, ]), source = cov(draw[i1, ], draw[isource, ]))
  variance <- apply(draw[c(i1, itime, irep, isource), , drop = FALSE], 1L, var)
  se <- c(time = sqrt((variance[[1L]] * variance[[2L]] + expected[["time"]]^2) / 1999),
    replicate = sqrt((variance[[1L]] * variance[[3L]] + expected[["replicate"]]^2) / 1999),
    source = sqrt((variance[[1L]] * variance[[4L]] + expected[["source"]]^2) / 1999))
  expect_true(all(abs(observed - expected) <= qnorm(1 - .05 / 6) * se))
  replay <- suppressWarnings(update(dense)); changed <- fx$data; changed$value <- changed$value + .01
  refit <- suppressWarnings(update(dense, data = changed))
  expect_s3_class(replay, "gllvmTMB_multi"); expect_equal(replay$phylo_vcv, dense$phylo_vcv)
  expect_s3_class(refit, "gllvmTMB_multi")
})

test_that("only the replicated AR1 temporal_indep animal cell is opened", {
  fx <- .temporal_animal_rep_fixture(); unrep <- fx$data[fx$data$measurement == "m1", , drop = FALSE]
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion) + animal_indep(0 + trait | animal, A = fx$A), data = unrep, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement, structure = "ou") + animal_indep(0 + trait | animal, A = fx$A), data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion, replicate = measurement) + animal_indep(0 + trait | animal, A = fx$A), data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)), "cannot be combined")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) + animal_dep(0 + trait | animal, A = fx$A), data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)), "cannot be combined")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement) + animal_indep(0 + trait | animal, A = fx$A, rho = .5), data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)), "cannot be combined")
})

test_that("animal relationship representations are unambiguous and do not duplicate an ordinary basis", {
  skip_if_not_installed("TMB")
  fx <- .temporal_animal_rep_fixture()
  common <- value ~ 0 + trait + temporal_indep(0 + trait | animal, time = occasion, replicate = measurement)
  expect_error(suppressWarnings(gllvmTMB(
    update(common, . ~ . + animal_indep(0 + trait | animal, A = Matrix::Matrix(fx$A, sparse = TRUE))),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE
  )), "dense relatedness")
  expect_error(suppressWarnings(gllvmTMB(
    update(common, . ~ . + animal_indep(0 + trait | animal, pedigree = fx$pedigree, A = fx$A)),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE
  )), "exactly one")
  identity_A <- diag(4L); dimnames(identity_A) <- list(paste0("a", 1:4), paste0("a", 1:4))
  identity_only <- suppressWarnings(gllvmTMB(
    update(common, . ~ . + animal_indep(0 + trait | animal, A = identity_A)),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_s3_class(identity_only, "gllvmTMB_multi")
  expect_error(suppressWarnings(gllvmTMB(
    update(common, . ~ . + animal_indep(0 + trait | animal, A = identity_A) + indep(0 + trait | animal)),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE
  )), "duplicates.*indep")
})
