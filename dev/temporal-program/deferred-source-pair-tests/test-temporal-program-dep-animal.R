.temporal_dep_animal_fixture <- function() {
  pedigree <- data.frame(
    id = paste0("a", 1:4),
    sire = c(NA, NA, "a1", "a1"),
    dam = c(NA, NA, "a2", "a2"),
    stringsAsFactors = FALSE
  )
  ## Independent hand calculation for two founders and their two full siblings.
  ## Keep the dense oracle independent of the package pedigree converter.
  A <- matrix(c(
    1, 0, .5, .5,
    0, 1, .5, .5,
    .5, .5, 1, .5,
    .5, .5, .5, 1
  ), 4L, 4L, byrow = TRUE,
  dimnames = list(paste0("a", 1:4), paste0("a", 1:4)))
  data <- expand.grid(animal = rownames(A), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  animal_effect <- c(a1 = -.20, a2 = .12, a3 = .25, a4 = -.08)
  data$value <- with(data, as.numeric(factor(trait)) + .08 * occasion +
    animal_effect[animal] + c(m1 = -.03, m2 = .03)[measurement])
  list(data = data, A = A, pedigree = pedigree)
}

.temporal_dep_animal_fit <- function(fx, source = c("A", "pedigree", "Ainv")) {
  source <- match.arg(source)
  switch(source,
    A = suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion,
        replicate = measurement) + animal_indep(0 + trait | animal, A = fx$A),
      data = fx$data, unit = "animal", cluster = "animal", family = gaussian(),
      silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
        optimizer_passes = 2L))),
    pedigree = suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion,
        replicate = measurement) + animal_indep(0 + trait | animal, pedigree = fx$pedigree),
      data = fx$data, unit = "animal", cluster = "animal", family = gaussian(),
      silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
        optimizer_passes = 2L))),
    Ainv = suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion,
        replicate = measurement) + animal_indep(0 + trait | animal,
          Ainv = Matrix::Matrix(solve(fx$A), sparse = TRUE)),
      data = fx$data, unit = "animal", cluster = "animal", family = gaussian(),
      silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
        optimizer_passes = 2L)))
  )
}

.temporal_dep_animal_unpack <- function(theta, n_trait) {
  out <- matrix(0, n_trait, n_trait); cursor <- 1L
  for (column in seq_len(n_trait)) {
    out[column, column] <- theta[[cursor]]; cursor <- cursor + 1L
  }
  for (column in seq_len(n_trait - 1L)) for (row in (column + 1L):n_trait) {
    out[row, column] <- theta[[cursor]]; cursor <- cursor + 1L
  }
  stopifnot(cursor == length(theta) + 1L)
  out
}

.temporal_dep_animal_nll <- function(fit, fixed, A,
                                     temporal = c("full", "diagonal", "rank_one"),
                                     product = FALSE) {
  temporal <- match.arg(temporal)
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L
  animal <- td$species_id + 1L; pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Rseries <- phi^abs(outer(pair$time, pair$time, `-`))
  Rseries[outer(pair$series, pair$series, `!=`)] <- 0
  Ltime <- .temporal_dep_animal_unpack(par$theta_temporal_rr, td$n_traits)
  Sigma_time <- tcrossprod(Ltime)
  Sigma_time <- switch(temporal,
    full = Sigma_time,
    diagonal = diag(diag(Sigma_time)),
    rank_one = tcrossprod(Ltime[, 1L])
  )
  Sigma_animal <- diag(par$theta_rr_phy^2, td$n_traits)
  V <- if (product) {
    Rall <- phi^abs(outer(pair$time, pair$time, `-`))
    Rall[state, state] * A[animal, animal] * Sigma_time[trait, trait]
  } else {
    Rseries[state, state] * Sigma_time[trait, trait] +
      A[animal, animal] * Sigma_animal[trait, trait]
  }
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); chol_V <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(chol_V))) +
    sum(backsolve(chol_V, residual, transpose = TRUE)^2))
}

.temporal_dep_animal_fixed <- function(fit, phi = -.4) {
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(phi / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.55, .45, .50, .08, -.12, .10)
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)
  fixed
}

.temporal_dep_animal_forecast_covariance <- function(fit, left, right = left,
                                                      product = FALSE) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  td <- fit$tmb_data
  trait_levels <- levels(fit$data[[fit$trait_col]])
  left_trait <- match(as.character(left[[fit$trait_col]]), trait_levels)
  right_trait <- match(as.character(right[[fit$trait_col]]), trait_levels)
  left_animal <- as.character(left[[fit$temporal$series_col]])
  right_animal <- as.character(right[[fit$temporal$series_col]])
  source_map <- split(td$species_aug_id,
    as.character(fit$data[[fit$temporal$series_col]]))
  source_map <- vapply(source_map, function(x) unique(x)[[1L]], integer(1))
  left_source <- unname(source_map[left_animal])
  right_source <- unname(source_map[right_animal])
  if (anyNA(left_source) || anyNA(right_source)) stop("unknown animal label")
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  left_time <- as.numeric(left[[fit$temporal$time_col]])
  right_time <- as.numeric(right[[fit$temporal$time_col]])
  Sigma_time <- tcrossprod(.temporal_dep_animal_unpack(
    par$theta_temporal_rr, length(trait_levels)))
  temporal <- outer(left_animal, right_animal, "==") *
    phi^abs(outer(left_time, right_time, "-")) *
    Sigma_time[left_trait, right_trait]
  A <- solve(as.matrix(td$Ainv_phy_rr))
  animal <- A[left_source + 1L, right_source + 1L] *
    diag(par$theta_rr_phy^2, nrow = length(trait_levels))[left_trait, right_trait]
  out <- if (isTRUE(product)) temporal * animal else temporal + animal
  if (identical(left, right)) diag(out) <- diag(out) + exp(2 * par$log_sigma_eps[[1L]])
  out
}

test_that("replicated temporal_dep plus fixed animal_indep keeps the animal covariance diagonal", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_animal_fixture(); fit <- .temporal_dep_animal_fit(fx)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$temporal$mode, "dep")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(all(c("z_temporal", "g_phy") %in% fit$random))
  expect_false("q_temporal" %in% fit$random)
  expect_equal(fit$report$Lambda_phy[row(fit$report$Lambda_phy) != col(fit$report$Lambda_phy)],
    rep(0, 6), tolerance = 1e-12)
  expect_equal(pedigree_to_A(fx$pedigree), fx$A, tolerance = 1e-12)
})

test_that("temporal_dep animal dense likelihood and every outer gradient match", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_animal_fixture(); fit <- .temporal_dep_animal_fit(fx)
  for (phi in c(-.4, 0, .6)) {
    fixed <- .temporal_dep_animal_fixed(fit, phi)
    oracle <- .temporal_dep_animal_nll(fit, fixed, fx$A)
    expect_equal(as.numeric(fit$tmb_obj$fn(fixed)), oracle, tolerance = 2e-6)
    expect_gt(abs(oracle - .temporal_dep_animal_nll(fit, fixed, fx$A, product = TRUE)), 1e-3)
    expect_gt(abs(oracle - .temporal_dep_animal_nll(fit, fixed, fx$A, temporal = "diagonal")), 1e-3)
    expect_gt(abs(oracle - .temporal_dep_animal_nll(fit, fixed, fx$A, temporal = "rank_one")), 1e-3)
    for (i in seq_along(fixed)) {
      h <- 1e-5; plus <- fixed; minus <- fixed
      plus[[i]] <- plus[[i]] + h; minus[[i]] <- minus[[i]] - h
      central <- (.temporal_dep_animal_nll(fit, plus, fx$A) -
        .temporal_dep_animal_nll(fit, minus, fx$A)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[[i]], central, tolerance = 4e-5,
        info = paste(names(fixed)[[i]], phi))
    }
  }
})

test_that("temporal_dep animal preserves relationship labels, fitted values, wide syntax, update, and simulation", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_animal_fixture(); dense <- .temporal_dep_animal_fit(fx)
  ped <- .temporal_dep_animal_fit(fx, "pedigree")
  ainv <- .temporal_dep_animal_fit(fx, "Ainv")
  fixed <- .temporal_dep_animal_fixed(dense, .3)
  expect_identical(names(fixed), names(ped$opt$par))
  expect_identical(names(fixed), names(ainv$opt$par))
  expect_equal(dense$tmb_obj$fn(fixed), ped$tmb_obj$fn(fixed), tolerance = 2e-6)
  expect_equal(dense$tmb_obj$fn(fixed), ainv$tmb_obj$fn(fixed), tolerance = 2e-6)
  perm <- rev(rownames(fx$A)); fx_perm <- fx; fx_perm$A <- fx$A[perm, perm]
  expect_equal(.temporal_dep_animal_fit(fx_perm)$tmb_obj$fn(fixed), dense$tmb_obj$fn(fixed), tolerance = 2e-6)
  key <- unique(fx$data[c("animal", "occasion", "measurement")])
  wide <- key[order(key$animal, key$occasion, key$measurement), ]
  for (j in 1:3) {
    z <- fx$data[fx$data$trait == paste0("t", j), c("animal", "occasion", "measurement", "value")]
    wide[[paste0("y", j)]] <- z$value[match(do.call(paste, wide[c("animal", "occasion", "measurement")]),
      do.call(paste, z[c("animal", "occasion", "measurement")]))]
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 + temporal_dep(1 | animal, time = occasion,
      replicate = measurement) + animal_indep(1 | animal, A = fx$A),
    data = wide, unit = "animal", cluster = "animal", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)), optimizer_passes = 2L)
  ))
  expect_identical(names(fixed), names(wide_fit$opt$par))
  expect_equal(dense$tmb_obj$fn(fixed), wide_fit$tmb_obj$fn(fixed), tolerance = 2e-6)
  replay <- suppressWarnings(update(dense))
  expect_s3_class(replay, "gllvmTMB_multi")
  expect_equal(extract_temporal(replay)$pair_index, extract_temporal(dense)$pair_index)
  ## `temporal_dep()` reports its full covariance through the labelled loading
  ## factor in `extract_temporal()`; it does not present that full-rank
  ## factorisation as a low-rank latent-variable ordination.
  temporal_details <- extract_temporal(dense)
  expect_identical(rownames(temporal_details$loading), c("t1", "t2", "t3"))
  expect_identical(temporal_details$pair_index$pair_id,
    paste(temporal_details$pair_index$series, temporal_details$pair_index$time, sep = "."))
  fitted_link <- suppressMessages(fitted(dense, type = "link"))
  expect_equal(fitted_link[c("animal", "occasion", "measurement", "trait")],
    dense$data[c("animal", "occasion", "measurement", "trait")])
  expect_equal(fitted_link$est, as.numeric(dense$report$eta), tolerance = 1e-12)
  rows <- dense$data
  i <- which(as.character(rows$animal) == "a3" & rows$occasion == 1L & rows$measurement == "m1" & rows$trait == "t1")
  cross_same <- which(as.character(rows$animal) == "a3" & rows$occasion == 1L & rows$measurement == "m1" & rows$trait == "t2")
  cross_lag <- which(as.character(rows$animal) == "a3" & rows$occasion == 2L & rows$measurement == "m1" & rows$trait == "t2")
  related <- which(as.character(rows$animal) == "a4" & rows$occasion == 1L & rows$measurement == "m1" & rows$trait == "t1")
  td <- dense$tmb_data; par <- dense$tmb_obj$env$parList(dense$opt$par)
  Sigma_time <- tcrossprod(.temporal_dep_animal_unpack(par$theta_temporal_rr, td$n_traits))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  expected <- c(
    cross_same = Sigma_time[1L, 2L],
    cross_lag = phi * Sigma_time[1L, 2L],
    related = fx$A["a3", "a4"] * dense$report$Lambda_phy[1L, 1L]^2
  )
  draw <- simulate(dense, nsim = 2000L, seed = 2609111L)
  observed <- c(
    cross_same = cov(draw[i, ], draw[cross_same, ]),
    cross_lag = cov(draw[i, ], draw[cross_lag, ]),
    related = cov(draw[i, ], draw[related, ])
  )
  variance <- apply(draw[c(i, cross_same, cross_lag, related), , drop = FALSE], 1L, var)
  se <- c(
    cross_same = sqrt((variance[[1L]] * variance[[2L]] + expected[[1L]]^2) / 1999),
    cross_lag = sqrt((variance[[1L]] * variance[[3L]] + expected[[2L]]^2) / 1999),
    related = sqrt((variance[[1L]] * variance[[4L]] + expected[[3L]]^2) / 1999)
  )
  expect_true(all(abs(observed - expected) <= qnorm(1 - .05 / (2 * length(expected))) * se))
  conditional <- simulate(dense, nsim = 1000L, seed = 2609112L, condition_on_RE = TRUE)
  expect_equal(rowMeans(conditional), as.numeric(dense$report$eta), tolerance = .04)
})

test_that("temporal_dep animal fences unqualified variants", {
  fx <- .temporal_dep_animal_fixture(); unrep <- fx$data[fx$data$measurement == "m1", , drop = FALSE]
  base <- value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion,
    replicate = measurement) + animal_indep(0 + trait | animal, A = fx$A)
  expect_error(suppressWarnings(gllvmTMB(update(base, . ~ . + indep(0 + trait | animal)),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)),
    "cannot include an ordinary")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion) +
    animal_indep(0 + trait | animal, A = fx$A), data = unrep, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)),
    "requires a replicated panel")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | animal, time = occasion,
    replicate = measurement, structure = "ou") + animal_indep(0 + trait | animal, A = fx$A),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)),
    "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(update(base, . ~ . + animal_dep(0 + trait | animal, A = fx$A)),
    data = fx$data, unit = "animal", cluster = "animal", family = gaussian(), silent = TRUE)),
    "cannot be combined")
})

test_that("replicated temporal_dep-animal forecasts match additive dense conditioning", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_animal_fixture(); fit <- .temporal_dep_animal_fit(fx)
  fixed <- .temporal_dep_animal_fixed(fit, .45)
  fit$opt$par <- fixed
  future <- expand.grid(animal = paste0("a", 1:4), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  observed <- forecast_temporal(fit, future, se.fit = TRUE)
  all_rows <- rbind(fx$data[, names(future)], future)
  V <- .temporal_dep_animal_forecast_covariance(fit, all_rows)
  n_observed <- nrow(fx$data)
  Voo <- V[seq_len(n_observed), seq_len(n_observed), drop = FALSE]
  Von <- V[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE]
  Vnn <- V[n_observed + seq_len(nrow(future)), n_observed + seq_len(nrow(future)), drop = FALSE]
  beta <- fixed[names(fixed) == "b_fix"]
  Xo <- model.matrix(~ 0 + trait, fx$data)
  Xn <- model.matrix(~ 0 + trait, future)
  solved <- solve(Voo, cbind(fx$data$value - drop(Xo %*% beta), Von))
  expected_mean <- drop(Xn %*% beta + crossprod(Von, solved[, 1L]))
  expected_variance <- diag(Vnn - crossprod(Von, solved[, -1L, drop = FALSE]))
  expect_equal(observed$est, unname(expected_mean), tolerance = 1e-8)
  expect_equal(observed$se.fit, unname(sqrt(pmax(expected_variance, 0))), tolerance = 1e-8)
  expect_gt(max(abs(V - .temporal_dep_animal_forecast_covariance(fit, all_rows, product = TRUE))), 1e-3)

  fit$opt$par[names(fit$opt$par) == "theta_temporal_time"] <- atanh(-.45 / (1 - 1e-6))
  negative <- forecast_temporal(fit, future, se.fit = TRUE)
  negative_V <- .temporal_dep_animal_forecast_covariance(fit, all_rows)
  negative_solved <- solve(negative_V[seq_len(n_observed), seq_len(n_observed), drop = FALSE],
    cbind(fx$data$value - drop(Xo %*% beta), negative_V[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE]))
  expect_equal(negative$est, unname(drop(Xn %*% beta + crossprod(
    negative_V[seq_len(n_observed), n_observed + seq_len(nrow(future)), drop = FALSE], negative_solved[, 1L]))), tolerance = 1e-8)
})

test_that("temporal_dep-animal forecast preserves row order and refuses unseen animals", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_animal_fixture(); fit <- .temporal_dep_animal_fit(fx)
  future <- expand.grid(animal = paste0("a", 1:4), occasion = 5L,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  shuffled <- future[sample(nrow(future)), , drop = FALSE]
  expect_identical(as.character(forecast_temporal(fit, shuffled)$animal), shuffled$animal)
  unseen <- future; unseen$animal[[1L]] <- "a_new"
  expect_error(forecast_temporal(fit, unseen), "supports existing series only")
})
