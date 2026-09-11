.temporal_dep_phylo_fixture <- function() {
  data <- expand.grid(series = paste0("sp", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  data$value <- with(data, as.numeric(factor(trait)) + .08 * occasion +
    c(sp1 = -.2, sp2 = .1, sp3 = .25, sp4 = -.05)[series] +
    c(m1 = -.03, m2 = .03)[measurement])
  Cphy <- matrix(c(1, .35, .15, .10, .35, 1, .25, .20,
    .15, .25, 1, .40, .10, .20, .40, 1), 4L, 4L, byrow = TRUE,
    dimnames = list(paste0("sp", 1:4), paste0("sp", 1:4)))
  list(data = data, Cphy = Cphy)
}

.temporal_dep_phylo_fit <- function(fx, source = c("vcv", "tree"), tree = NULL) {
  source <- match.arg(source)
  if (identical(source, "vcv")) {
    return(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
        replicate = measurement) + phylo_indep(0 + trait | series, vcv = fx$Cphy),
      data = fx$data, unit = "series", cluster = "series", family = gaussian(),
      silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
        optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
        optimizer_passes = 2L)
    )))
  }
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + phylo_indep(0 + trait | series, tree = tree),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L)
  ))
}

.temporal_dep_phylo_unpack <- function(theta, n_trait) {
  out <- matrix(0, n_trait, n_trait); cursor <- 1L
  for (column in seq_len(n_trait)) { out[column, column] <- theta[[cursor]]; cursor <- cursor + 1L }
  for (column in seq_len(n_trait - 1L)) for (row in (column + 1L):n_trait) {
    out[row, column] <- theta[[cursor]]; cursor <- cursor + 1L
  }
  stopifnot(cursor == length(theta) + 1L); out
}

.temporal_dep_phylo_dense_nll <- function(fit, fixed, Cphy, product = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L; tip <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Rseries <- phi^abs(outer(pair$time, pair$time, `-`))
  Rseries[outer(pair$series, pair$series, `!=`)] <- 0
  Rall <- phi^abs(outer(pair$time, pair$time, `-`))
  Sigma_time <- tcrossprod(.temporal_dep_phylo_unpack(par$theta_temporal_rr, td$n_traits))
  Sigma_phylo <- diag(par$theta_rr_phy^2, td$n_traits)
  V <- if (product) {
    Rall[state, state] * Cphy[tip, tip] * Sigma_time[trait, trait]
  } else Rseries[state, state] * Sigma_time[trait, trait] +
    Cphy[tip, tip] * Sigma_phylo[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_dep_phylo_substitute_nll <- function(fit, fixed, Cphy, kind = c("diagonal", "rank_one")) {
  kind <- match.arg(kind)
  par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data
  state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L; tip <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Rseries <- phi^abs(outer(pair$time, pair$time, `-`))
  Rseries[outer(pair$series, pair$series, `!=`)] <- 0
  loading <- .temporal_dep_phylo_unpack(par$theta_temporal_rr, td$n_traits)
  Sigma_time <- tcrossprod(loading)
  Sigma_time <- switch(kind,
    diagonal = diag(diag(Sigma_time)),
    rank_one = tcrossprod(loading[, 1L])
  )
  Sigma_phylo <- diag(par$theta_rr_phy^2, td$n_traits)
  V <- Rseries[state, state] * Sigma_time[trait, trait] +
    Cphy[tip, tip] * Sigma_phylo[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix); L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated temporal_dep plus fixed phylo_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_phylo_fixture(); fit <- .temporal_dep_phylo_fit(fx)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$temporal$mode, "dep")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_equal(fit$phylo_vcv[rownames(fx$Cphy), colnames(fx$Cphy)], fx$Cphy)
  expect_true("g_phy" %in% fit$random)
  expect_false("q_temporal" %in% fit$random)
})

test_that("temporal_dep-phylo dense likelihood and every outer gradient match", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_phylo_fixture(); fit <- .temporal_dep_phylo_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.55, .45, .5, .08, -.12, .1)
  fixed[names(fixed) == "theta_rr_phy"] <- c(.3, .4, .5)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.25)
  for (phi in c(-.4, 0, .6)) {
    fixed[names(fixed) == "theta_temporal_time"] <- atanh(phi / (1 - 1e-6))
    par <- fit$tmb_obj$env$parList(fixed); td <- fit$tmb_data; pair <- fit$temporal$pair_table
    state <- td$temporal_state_id + 1L; trait <- td$trait_id + 1L; tip <- td$species_id + 1L
    actual_phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
    Rseries <- actual_phi^abs(outer(pair$time, pair$time, `-`)); Rseries[outer(pair$series, pair$series, `!=`)] <- 0
    Rall <- actual_phi^abs(outer(pair$time, pair$time, `-`))
    Sigma_time <- tcrossprod(.temporal_dep_phylo_unpack(par$theta_temporal_rr, td$n_traits))
    cross <- which(pair$series[state] != pair$series[[state[[1L]]]] & trait != trait[[1L]] &
      pair$time[state] == pair$time[[state[[1L]]]])[[1L]]
    expect_equal(Rseries[state[[1L]], state[[cross]]] * Sigma_time[trait[[1L]], trait[[cross]]] +
      fx$Cphy[tip[[1L]], tip[[cross]]] * (trait[[1L]] == trait[[cross]]) * par$theta_rr_phy[[trait[[1L]]]]^2,
      0, tolerance = 1e-12)
    expect_gt(abs(Rall[state[[1L]], state[[cross]]] * fx$Cphy[tip[[1L]], tip[[cross]]] *
      Sigma_time[trait[[1L]], trait[[cross]]]), 1e-8)
    oracle <- .temporal_dep_phylo_dense_nll(fit, fixed, fx$Cphy)
    expect_equal(as.numeric(fit$tmb_obj$fn(fixed)), oracle, tolerance = 2e-6)
    expect_gt(abs(oracle - .temporal_dep_phylo_dense_nll(fit, fixed, fx$Cphy, product = TRUE)), 1e-3)
    expect_gt(abs(oracle - .temporal_dep_phylo_substitute_nll(fit, fixed, fx$Cphy, "diagonal")), 1e-3)
    expect_gt(abs(oracle - .temporal_dep_phylo_substitute_nll(fit, fixed, fx$Cphy, "rank_one")), 1e-3)
    for (i in seq_along(fixed)) {
      h <- 1e-5; plus <- fixed; minus <- fixed; plus[[i]] <- plus[[i]] + h; minus[[i]] <- minus[[i]] - h
      central <- (.temporal_dep_phylo_dense_nll(fit, plus, fx$Cphy) -
        .temporal_dep_phylo_dense_nll(fit, minus, fx$Cphy)) / (2 * h)
      expect_equal(fit$tmb_obj$gr(fixed)[[i]], central, tolerance = 4e-5,
        info = paste(names(fixed)[[i]], phi))
    }
  }
})

test_that("temporal_dep-phylo preserves VCV/tree labels, wide syntax, and update", {
  skip_if_not_installed("TMB"); skip_if_not_installed("ape")
  fx <- .temporal_dep_phylo_fixture(); dense <- .temporal_dep_phylo_fit(fx)
  set.seed(260928L); tree <- ape::rcoal(4L); tree$tip.label <- rownames(fx$Cphy)
  fx_tree <- fx; fx_tree$Cphy <- ape::vcv(tree, corr = TRUE)
  dense_tree <- .temporal_dep_phylo_fit(fx_tree)
  tree_fit <- .temporal_dep_phylo_fit(fx_tree, "tree", tree)
  expect_equal(dense_tree$opt$objective, tree_fit$opt$objective, tolerance = 1e-6)
  perm <- sample(rownames(fx$Cphy)); fx_perm <- fx; fx_perm$Cphy <- fx$Cphy[perm, perm]
  expect_equal(.temporal_dep_phylo_fit(fx_perm)$opt$objective, dense$opt$objective, tolerance = 1e-6)
  key <- unique(fx$data[c("series", "occasion", "measurement")]); wide <- key[order(key$series, key$occasion, key$measurement), ]
  for (j in 1:3) {
    z <- fx$data[fx$data$trait == paste0("t", j), c("series", "occasion", "measurement", "value")]
    z <- z[order(z$series, z$occasion, z$measurement), ]; wide[[paste0("y", j)]] <- z$value
  }
  wide_fit <- suppressWarnings(gllvmTMB(traits(y1, y2, y3) ~ 1 +
    temporal_dep(1 | series, time = occasion, replicate = measurement) +
    phylo_indep(1 | series, vcv = fx$Cphy), data = wide, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE, control = gllvmTMBcontrol(se = FALSE)))
  expect_equal(unname(as.matrix(extract_temporal(dense)$pair_index)), unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
  expect_equal(wide_fit$phylo_vcv, dense$phylo_vcv)
  common <- dense$opt$par
  expect_identical(names(common), names(wide_fit$opt$par))
  expect_equal(dense$tmb_obj$fn(common), wide_fit$tmb_obj$fn(common), tolerance = 2e-6)
  shuffled <- fx; set.seed(260929L); shuffled$data <- shuffled$data[sample(nrow(shuffled$data)), ]
  shuffled_fit <- .temporal_dep_phylo_fit(shuffled)
  expect_identical(names(common), names(shuffled_fit$opt$par))
  expect_equal(dense$tmb_obj$fn(common), shuffled_fit$tmb_obj$fn(common), tolerance = 2e-6)
  refit <- suppressWarnings(update(dense))
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_equal(extract_temporal(refit)$pair_index, extract_temporal(dense)$pair_index)
  expect_identical(rownames(extract_temporal(refit)$loading), rownames(extract_temporal(dense)$loading))
  fitted_link <- suppressMessages(fitted(dense, type = "link"))
  expect_equal(fitted_link[c("series", "occasion", "measurement", "trait")], dense$data[c("series", "occasion", "measurement", "trait")])
  expect_equal(fitted_link$est, as.numeric(dense$report$eta), tolerance = 1e-12)
  replacement <- fx$data; replacement$value <- replacement$value + .01
  expect_s3_class(suppressWarnings(update(dense, data = replacement)), "gllvmTMB_multi")
})

test_that("temporal_dep-phylo unconditional simulation redraws both additive fields", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_phylo_fixture(); fit <- .temporal_dep_phylo_fit(fx)
  td <- fit$tmb_data; par <- fit$tmb_obj$env$parList(fit$opt$par); rows <- fit$data
  find_row <- function(series, occasion, measurement, trait) which(as.character(rows$series) == series & rows$occasion == occasion & as.character(rows$measurement) == measurement & as.character(rows$trait) == trait)
  i <- find_row("sp1", 1, "m1", "t1"); cross_trait <- find_row("sp1", 2, "m1", "t2"); related <- find_row("sp2", 1, "m1", "t1")
  Sigma <- tcrossprod(.temporal_dep_phylo_unpack(par$theta_temporal_rr, td$n_traits)); phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  expected <- c(cross_trait = phi * Sigma[1, 2], related = fx$Cphy[1, 2] * par$theta_rr_phy[[1L]]^2)
  draw <- simulate(fit, nsim = 2000L, seed = 260928L)
  observed <- c(cross_trait = cov(draw[i, ], draw[cross_trait, ]), related = cov(draw[i, ], draw[related, ]))
  variance <- apply(draw[c(i, cross_trait, related), , drop = FALSE], 1L, var)
  se <- c(cross_trait = sqrt((variance[[1L]] * variance[[2L]] + expected[[1L]]^2) / 1999),
    related = sqrt((variance[[1L]] * variance[[3L]] + expected[[2L]]^2) / 1999))
  expect_true(all(abs(observed - expected) <= qnorm(1 - .05 / (2 * length(expected))) * se))
  conditional_a <- simulate(fit, nsim = 1000L, seed = 12L, condition_on_RE = TRUE)
  conditional_b <- simulate(fit, nsim = 1000L, seed = 12L, condition_on_RE = TRUE)
  expect_equal(dim(conditional_a), c(nrow(fx$data), 1000L))
  expect_identical(conditional_a, conditional_b)
  expect_equal(rowMeans(conditional_a), as.numeric(fit$report$eta), tolerance = .04)
})

test_that("temporal_dep-phylo fences unqualified variants", {
  fx <- .temporal_dep_phylo_fixture(); base <- value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = fx$Cphy)
  expect_error(suppressWarnings(gllvmTMB(update(base, . ~ . + indep(0 + trait | series)), data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE)), "cannot include an ordinary")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion, replicate = measurement, structure = "ou") + phylo_indep(0 + trait | series, vcv = fx$Cphy), data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE)), "requires replicated AR1")
  expect_error(suppressWarnings(gllvmTMB(value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion, replicate = measurement) + phylo_indep(0 + trait + (0 + trait):occasion | series, vcv = fx$Cphy), data = fx$data, unit = "series", cluster = "series", family = gaussian(), silent = TRUE)), "intercept-only")
  even <- fx$data; even$occasion <- 2L * even$occasion
  expect_error(suppressWarnings(gllvmTMB(base, data = even, unit = "series", cluster = "series", family = gaussian(), silent = TRUE)), "odd within-series")
})
