.temporal_phylo_rep_fixture <- function() {
  data <- expand.grid(
    series = paste0("sp", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data,
    as.numeric(factor(trait)) + .1 * occasion +
      c(sp1 = -.2, sp2 = .15, sp3 = .05, sp4 = .3)[series] +
      c(m1 = -.03, m2 = .03)[measurement])
  Cphy <- matrix(c(
    1, .55, .20, .10,
    .55, 1, .30, .15,
    .20, .30, 1, .40,
    .10, .15, .40, 1
  ), 4L, 4L, byrow = TRUE,
  dimnames = list(paste0("sp", 1:4), paste0("sp", 1:4)))
  list(data = data, Cphy = Cphy)
}

.temporal_phylo_rep_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement, structure = "ar1") +
      phylo_indep(0 + trait | series, vcv = fx$Cphy),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
}

.temporal_phylo_rep_dense_nll <- function(fit, fixed, Cphy) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  Ktime <- ((1 - 1e-6) * tanh(par$theta_temporal_time)) ^
    abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  temporal_var <- diag(exp(2 * par$theta_temporal_diag), td$n_traits)
  phylo_var <- diag(par$theta_rr_phy^2, td$n_traits)
  V <- Ktime[state, state] * temporal_var[trait, trait] +
    Cphy[source, source] * phylo_var[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_phylo_rep_product_nll <- function(fit, fixed, Cphy) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  Ktime <- ((1 - 1e-6) * tanh(par$theta_temporal_time)) ^
    abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  temporal_var <- diag(exp(2 * par$theta_temporal_diag), td$n_traits)
  V <- Ktime[state, state] * Cphy[source, source] * temporal_var[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated AR1 temporal_indep plus fixed phylo_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_phylo_rep_fixture()
  fit <- .temporal_phylo_rep_fit(fx)

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_identical(fit$temporal$workflow, "replicated")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_equal(fit$phylo_vcv[rownames(fx$Cphy), colnames(fx$Cphy)], fx$Cphy)
  expect_true(all(c("q_temporal", "g_phy") %in% fit$random))
})

test_that("replicated temporal-phylo likelihood and gradient equal a dense additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_phylo_rep_fixture()
  fit <- .temporal_phylo_rep_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(-.5 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)

  native <- as.numeric(fit$tmb_obj$fn(fixed))
  dense <- .temporal_phylo_rep_dense_nll(fit, fixed, fx$Cphy)
  expect_equal(native, dense, tolerance = 2e-6)
  expect_gt(abs(dense - .temporal_phylo_rep_product_nll(fit, fixed, fx$Cphy)), 1e-3)
  index <- match("theta_temporal_time", names(fixed))
  h <- 1e-5
  plus <- fixed; plus[[index]] <- plus[[index]] + h
  minus <- fixed; minus[[index]] <- minus[[index]] - h
  central <- (.temporal_phylo_rep_dense_nll(fit, plus, fx$Cphy) -
    .temporal_phylo_rep_dense_nll(fit, minus, fx$Cphy)) / (2 * h)
  expect_equal(fit$tmb_obj$gr(fixed)[[index]], central, tolerance = 2e-5)
})

test_that("phylogenetic temporal cells enforce their specific bounds", {
  fx <- .temporal_phylo_rep_fixture()
  unrep <- fx$data[fx$data$measurement == "m1", , drop = FALSE]
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      phylo_indep(0 + trait | series, vcv = fx$Cphy),
    data = unrep, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires a replicated panel")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement,
        structure = "ou") + phylo_indep(0 + trait | series, vcv = fx$Cphy),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      phylo_dep(0 + trait | series, vcv = fx$Cphy),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot be combined")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      phylo_indep(0 + trait | series),
    data = fx$data, unit = "series", cluster = "series", phylo_vcv = fx$Cphy,
    family = gaussian(), silent = TRUE
  )), "cannot be combined")
  expect_error(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      phylo_indep(0 + trait | series, vcv = fx$Cphy, rho = .5),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE
  )), "cannot be combined")
})

test_that("phylogenetic labels, tree route, and wide rewrite preserve the same temporal source cell", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("ape")
  fx <- .temporal_phylo_rep_fixture()
  set.seed(2609162L)
  tree <- ape::rcoal(4L)
  tree$tip.label <- paste0("sp", 1:4)
  Ctree <- ape::vcv(tree, corr = TRUE)
  fx$Cphy <- Ctree
  dense <- .temporal_phylo_rep_fit(fx)
  tree_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
      phylo_indep(0 + trait | series, tree = tree),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  wide_key <- unique(fx$data[c("series", "occasion", "measurement")])
  wide <- wide_key[order(wide_key$series, wide_key$occasion, wide_key$measurement), , drop = FALSE]
  for (j in 1:3) {
    values <- fx$data[fx$data$trait == paste0("t", j), "value"]
    wide[[paste0("y", j)]] <- values[order(fx$data$series[fx$data$trait == paste0("t", j)],
      fx$data$occasion[fx$data$trait == paste0("t", j)],
      fx$data$measurement[fx$data$trait == paste0("t", j)])]
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_indep(1 | series, time = occasion, replicate = measurement) +
      phylo_indep(1 | series, vcv = Ctree),
    data = wide, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_equal(dense$opt$objective, tree_fit$opt$objective, tolerance = 1e-6)
  expect_equal(tree_fit$phylo_tree$tip.label, rownames(Ctree))
  expect_equal(unname(as.matrix(extract_temporal(dense)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  expect_equal(wide_fit$phylo_vcv[rownames(Ctree), colnames(Ctree)], Ctree)
})

test_that("replicated temporal-phylo simulation and update retain additive labels", {
  skip_if_not_installed("TMB")
  fx <- .temporal_phylo_rep_fixture()
  fit <- .temporal_phylo_rep_fit(fx)
  rows <- fit$data
  find_row <- function(series, occasion, measurement, trait) {
    which(as.character(rows$series) == series & rows$occasion == occasion &
      as.character(rows$measurement) == measurement & as.character(rows$trait) == trait)
  }
  i1 <- find_row("sp1", 1, "m1", "t1")
  itime <- find_row("sp1", 2, "m1", "t1")
  irep <- find_row("sp1", 1, "m2", "t1")
  isource <- find_row("sp2", 1, "m1", "t1")
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  time_var <- exp(2 * par$theta_temporal_diag[[1L]])
  phy_var <- fit$report$Lambda_phy[1L, 1L]^2
  expected <- c(
    time = phi * time_var + fx$Cphy[1L, 1L] * phy_var,
    replicate = time_var + fx$Cphy[1L, 1L] * phy_var,
    source = fx$Cphy[1L, 2L] * phy_var
  )
  draw <- simulate(fit, nsim = 2000L, seed = 2609163L)
  observed <- c(time = cov(draw[i1, ], draw[itime, ]),
    replicate = cov(draw[i1, ], draw[irep, ]),
    source = cov(draw[i1, ], draw[isource, ]))
  variances <- apply(draw[c(i1, itime, irep, isource), , drop = FALSE], 1L, var)
  se <- c(
    time = sqrt((variances[[1L]] * variances[[2L]] + expected[["time"]]^2) / 1999),
    replicate = sqrt((variances[[1L]] * variances[[3L]] + expected[["replicate"]]^2) / 1999),
    source = sqrt((variances[[1L]] * variances[[4L]] + expected[["source"]]^2) / 1999)
  )
  bound <- qnorm(1 - .05 / (2 * length(expected))) * se
  expect_true(all(abs(observed - expected) <= bound),
    info = paste(capture.output(rbind(observed, expected, bound)), collapse = "\n"))
  replay <- suppressWarnings(update(fit))
  replacement <- fx$data
  replacement$value <- replacement$value + .01
  refit <- suppressWarnings(update(fit, data = replacement))
  expect_s3_class(replay, "gllvmTMB_multi")
  expect_equal(replay$phylo_vcv, fit$phylo_vcv)
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_equal(nrow(extract_temporal(refit)$pair_index), nrow(extract_temporal(fit)$pair_index))
})
