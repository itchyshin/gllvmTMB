## Regression tests for four C++ likelihood kernels that lost precision, or
## went flat, at large but reachable parameter values:
##   #1362 binomial logit/probit clamped p to [1e-12, 1 - 1e-12] before
##         dbinom(): constant objective, zero gradient beyond |eta| 27.6 /
##         7.03 (and the multinomial log(1e-12) floor, same mechanism).
##   #1363 zero-truncated NB2: log P(0) = phi (log phi - log(mu + phi))
##         cancelled at large phi and was exactly 0 at phi = 1e14 -> +Inf;
##         dnbinom_robust's lgamma(y + phi) - lgamma(phi) has the same
##         cancellation (NB2, NB1, zi_nbinom2 share it).
##   #1364 Student dt() and the beta-binomial nine-lgamma sum: noisy from
##         df / phi ~ 1e10 and above the Gaussian / binomial limit beyond.
##   #1386 phylo / SPDE intercept-slope prior: 1 - tanh(eta)^2 cancelled and
##         was exactly 0 (Inf precisions) from |atanh_cor| ~ 19.5.
##
## Each test drives the engine to the edge value through obj$fn / obj$gr on
## a small fit. With the loadings set to ~0 the Laplace marginal reduces to
## an iid likelihood that base R evaluates accurately, so the engine can be
## compared with an R reference row by row.

.edge_fit <- function(df, family, formula = NULL, ...) {
  if (is.null(formula)) {
    formula <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  }
  suppressMessages(suppressWarnings(gllvmTMB(
    formula, data = df, trait = "trait", unit = "unit", family = family,
    control = gllvmTMBcontrol(se = FALSE), ...
  )))
}

## Fitted parameters with the loadings at ~0 (iid reduction).
.edge_par <- function(fit) {
  p <- fit$opt$par
  p[names(p) == "theta_rr_B"] <- 1e-12
  p
}

.edge_set <- function(p, name, value) {
  p[names(p) == name] <- value
  p
}

.edge_long <- function(Y) {
  n <- nrow(Y)
  Tn <- ncol(Y)
  data.frame(
    unit = factor(rep(seq_len(n), each = Tn)),
    trait = factor(rep(letters[seq_len(Tn)], n), levels = letters[seq_len(Tn)]),
    value = as.vector(t(Y))
  )
}

## ---- #1362: binomial without a probability clamp --------------------------

test_that("binomial logit/probit keep their value and slope deep in the tail (#1362)", {
  set.seed(1362)
  df <- .edge_long(matrix(stats::rbinom(40 * 3, 1, 0.5), 40, 3))
  ia <- df$trait == "a"
  for (link in c("logit", "probit")) {
    fit <- .edge_fit(df, stats::binomial(link = link))
    obj <- fit$tmb_obj
    p <- .edge_par(fit)
    i_b1 <- which(names(p) == "b_fix")[1L]
    for (eta_a in c(0.3, -9, -30, 30)) {
      p1 <- p
      p1[i_b1] <- eta_a
      eta <- p1[names(p1) == "b_fix"][as.integer(df$trait)]
      if (link == "logit") {
        lp1 <- stats::plogis(eta, log.p = TRUE)
        lp0 <- stats::plogis(eta, lower.tail = FALSE, log.p = TRUE)
        d1 <- stats::plogis(eta, lower.tail = FALSE)          # d lp1 / d eta
        d0 <- -stats::plogis(eta)                             # d lp0 / d eta
      } else {
        lp1 <- stats::pnorm(eta, log.p = TRUE)
        lp0 <- stats::pnorm(eta, lower.tail = FALSE, log.p = TRUE)
        d1 <- exp(stats::dnorm(eta, log = TRUE) - lp1)
        d0 <- -exp(stats::dnorm(eta, log = TRUE) - lp0)
      }
      y <- df$value
      ref <- -sum(ifelse(y == 1, lp1, lp0))
      got <- as.numeric(obj$fn(p1))
      expect_true(is.finite(got))
      expect_equal(got, ref, tolerance = 1e-10)
      ## Analytic d nll / d b_a: the clamp made this exactly 0 for the rows
      ## on the wrong side of the tail.
      g_ref <- -sum(ifelse(y[ia] == 1, d1[ia], d0[ia]))
      g <- as.numeric(obj$gr(p1))[i_b1]
      expect_true(is.finite(g))
      expect_equal(g, g_ref, tolerance = 1e-6)
      if (abs(eta_a) >= 9) expect_gt(abs(g), 1)
    }
    invisible(obj$fn(fit$opt$par))
  }
})

test_that("multinomial has no log(1e-12) floor on the observed category (#1362)", {
  set.seed(13621)
  N <- 60L
  rows <- list()
  for (i in seq_len(N)) for (r in 1:2) {
    yc <- sample.int(3L, 1L)
    rows[[length(rows) + 1L]] <- data.frame(unit = i, trait = "cat", family = "m", value = yc)
    rows[[length(rows) + 1L]] <- data.frame(unit = i, trait = "g", family = "g",
                                            value = stats::rnorm(1))
  }
  dat <- do.call(rbind, rows)
  dat$unit <- factor(dat$unit, levels = seq_len(N))
  dat$trait <- factor(dat$trait)
  dat$family <- factor(dat$family)
  fam <- list(g = stats::gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, trait = "trait", unit = "unit", family = fam,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  obj <- fit$tmb_obj
  p <- fit$opt$par
  n_cat <- table(factor(dat$value[dat$trait == "cat"], levels = 1:3))
  ## Push every contrast intercept to -40: each observed non-baseline
  ## category then has log p ~ -40, well past log(1e-12) = -27.63. The
  ## contrast coefficients are the b_fix columns used only on multinomial
  ## rows.
  i_b <- which(names(p) == "b_fix")
  X <- fit$tmb_data$X_fix
  fid <- fit$tmb_data$family_id_vec
  contrast_cols <- which(colSums(abs(X[fid == 16, , drop = FALSE])) > 0 &
                           colSums(abs(X[fid != 16, , drop = FALSE])) == 0)
  expect_gt(length(contrast_cols), 0L)
  p_all <- p
  p_all[i_b[contrast_cols]] <- -40
  g_all <- as.numeric(obj$gr(p_all))[i_b[contrast_cols]]
  ## True slope: d nll / d b_c = -(n_c - sum p_c) ~ -n_c (p_c ~ e^-40). With
  ## the floor every observed-category row contributed 0 and g was ~0.
  expect_true(is.finite(as.numeric(obj$fn(p_all))))
  expect_true(all(is.finite(g_all)))
  expect_true(all(abs(g_all) > 1))
  expect_equal(sum(g_all), -sum(n_cat[2:3]), tolerance = 1e-6)
  invisible(obj$fn(fit$opt$par))
})

## ---- #1363: negative-binomial kernels at the Poisson limit ----------------

.count_fixture <- function(seed, mu = 0.6, truncated = FALSE) {
  set.seed(seed)
  n <- 40
  Y <- matrix(stats::rpois(n * 3, mu), n, 3)
  if (truncated) Y[Y == 0] <- 1
  .edge_long(Y)
}

test_that("zero-truncated NB2 stays finite at phi = 1e14 and matches the ZT-Poisson limit (#1363)", {
  df <- .count_fixture(1363, truncated = TRUE)
  fit <- .edge_fit(df, truncated_nbinom2())
  obj <- fit$tmb_obj
  p <- .edge_par(fit)
  y <- df$value
  for (mu in c(0.1, 1e-3, 3)) {
    p1 <- .edge_set(p, "b_fix", log(mu))
    ## Moderate size: agrees with R's dnbinom.
    p2 <- .edge_set(p1, "log_phi_truncnb2", log(5))
    ref_nb <- -sum(stats::dnbinom(y, size = 5, mu = mu, log = TRUE) -
                     log1p(-stats::dnbinom(0, size = 5, mu = mu)))
    expect_equal(as.numeric(obj$fn(p2)), ref_nb, tolerance = 1e-10)
    ## The issue's edge: phi = 1e14 (and beyond, to the exp(700) cap).
    ref_ztp <- -sum(stats::dpois(y, mu, log = TRUE) - log(-expm1(-mu)))
    for (lphi in c(log(1e9), log(1e12), log(1e14), 100, 800)) {
      p3 <- .edge_set(p1, "log_phi_truncnb2", lphi)
      got <- as.numeric(obj$fn(p3))
      expect_true(is.finite(got))
      expect_equal(got, ref_ztp, tolerance = 1e-9)
      expect_true(all(is.finite(as.numeric(obj$gr(p3)))))
    }
  }
  invisible(obj$fn(fit$opt$par))
})

test_that("NB2, NB1 and zi_nbinom2 kernels reach their Poisson limits (#1363 siblings)", {
  df <- .count_fixture(13631, mu = 2)
  y <- df$value
  mu <- 2
  ## NB2: size = phi.
  fit <- .edge_fit(df, nbinom2())
  obj <- fit$tmb_obj
  p <- .edge_set(.edge_par(fit), "b_fix", log(mu))
  p2 <- .edge_set(p, "log_phi_nbinom2", log(1.5))
  expect_equal(as.numeric(obj$fn(p2)),
               -sum(stats::dnbinom(y, size = 1.5, mu = mu, log = TRUE)),
               tolerance = 1e-10)
  ref_pois <- -sum(stats::dpois(y, mu, log = TRUE))
  for (lphi in c(log(1e10), log(1e14), 40, 800)) {
    p3 <- .edge_set(p, "log_phi_nbinom2", lphi)
    expect_equal(as.numeric(obj$fn(p3)), ref_pois, tolerance = 1e-9)
    expect_true(all(is.finite(as.numeric(obj$gr(p3)))))
  }
  invisible(obj$fn(fit$opt$par))

  ## NB1: size = mu / phi, Poisson as phi -> 0.
  fit1 <- .edge_fit(df, nbinom1())
  obj1 <- fit1$tmb_obj
  q <- .edge_set(.edge_par(fit1), "b_fix", log(mu))
  q2 <- .edge_set(q, "log_phi_nbinom1", log(0.5))
  expect_equal(as.numeric(obj1$fn(q2)),
               -sum(stats::dnbinom(y, size = mu / 0.5, mu = mu, log = TRUE)),
               tolerance = 1e-10)
  for (lphi in c(log(1e-10), log(1e-14), -40)) {
    q3 <- .edge_set(q, "log_phi_nbinom1", lphi)
    expect_equal(as.numeric(obj1$fn(q3)), ref_pois, tolerance = 1e-9)
  }
  invisible(obj1$fn(fit1$opt$par))

  ## zi_nbinom2: same NB2 kernel inside the zero-inflation mixture.
  fitz <- .edge_fit(df, zi_nbinom2())
  objz <- fitz$tmb_obj
  r <- .edge_set(.edge_par(fitz), "b_fix", log(mu))
  zi <- stats::plogis(r[names(r) == "logit_zi"])[as.integer(df$trait)]
  zi_ref <- function(f0, fy) {
    -sum(ifelse(y == 0, log(zi + (1 - zi) * f0), log1p(-zi) + fy))
  }
  r2 <- .edge_set(r, "log_phi_nbinom2", log(1.5))
  expect_equal(as.numeric(objz$fn(r2)),
               zi_ref(stats::dnbinom(0, size = 1.5, mu = mu),
                      stats::dnbinom(y, size = 1.5, mu = mu, log = TRUE)),
               tolerance = 1e-10)
  r3 <- .edge_set(r, "log_phi_nbinom2", log(1e14))
  expect_equal(as.numeric(objz$fn(r3)),
               zi_ref(exp(-mu), stats::dpois(y, mu, log = TRUE)),
               tolerance = 1e-9)
  invisible(objz$fn(fitz$opt$par))
})

## ---- #1364: Student and beta-binomial lgamma sums -------------------------

test_that("Student-t with df = 1e8 is close to normal and never above it (#1364)", {
  set.seed(1364)
  df <- .edge_long(matrix(stats::rnorm(60 * 3), 60, 3))
  fit <- .edge_fit(df, student())
  obj <- fit$tmb_obj
  p <- .edge_set(.edge_par(fit), "b_fix", 0.1)
  p <- .edge_set(p, "log_sigma_student", log(1.3))
  z <- (df$value - 0.1) / 1.3
  n <- nrow(df)
  ref_norm <- -sum(stats::dnorm(z, log = TRUE) - log(1.3))
  ## Ordinary df agrees with R's dt(); df = 1e8 is within ~1e-8 per row of
  ## the Gaussian; df up to exp(800) never exceeds the Gaussian likelihood.
  for (ldf in c(log(3), log(1e8 - 1), 25, 30, 34.5, 40, 800)) {
    nu <- 1 + exp(ldf)
    p1 <- .edge_set(p, "log_df_student", ldf)
    got <- as.numeric(obj$fn(p1))
    expect_true(is.finite(got))
    if (is.finite(nu)) {
      ref_t <- -sum(stats::dt(z, df = nu, log = TRUE) - log(1.3))
      expect_equal(got, ref_t, tolerance = 1e-11)
    }
    if (ldf >= log(1e8 - 1)) {
      expect_lt(abs(got - ref_norm) / n, 1e-8)
      expect_gte(got, ref_norm - 1e-9)
    }
    expect_true(all(is.finite(as.numeric(obj$gr(p1)))))
  }
  invisible(obj$fn(fit$opt$par))
})

## Exact beta-binomial log pmf as finite sums (no lgamma cancellation).
.bb_log_pmf_exact <- function(y, N, mu, phi) {
  a <- mu * phi
  b <- (1 - mu) * phi
  vapply(seq_along(y), function(i) {
    yi <- y[i]
    Ni <- N[i]
    lchoose(Ni, yi) + yi * log(mu[i]) + (Ni - yi) * log1p(-mu[i]) +
      sum(log1p((seq_len(yi) - 1) / a[i])) +
      sum(log1p((seq_len(Ni - yi) - 1) / b[i])) -
      sum(log1p((seq_len(Ni) - 1) / phi))
  }, numeric(1))
}

test_that("beta-binomial with phi = 1e10 is close to binomial (#1364)", {
  set.seed(13641)
  n <- 40
  Nt <- 10L
  succ <- matrix(stats::rbinom(n * 3, Nt, 0.4), n, 3)
  df <- .edge_long(succ)
  df$succ <- df$value
  df$fail <- Nt - df$value
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = betabinomial(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  obj <- fit$tmb_obj
  p <- .edge_set(.edge_par(fit), "b_fix", stats::qlogis(0.4))
  mu <- rep(0.4, nrow(df))
  N <- rep(Nt, nrow(df))
  y <- df$succ
  ref_binom <- -sum(stats::dbinom(y, Nt, 0.4, log = TRUE))
  for (phi in c(5, 1e4, 1e10, 1e13, 1e300)) {
    p1 <- .edge_set(p, "log_phi_betabinom", log(phi))
    got <- as.numeric(obj$fn(p1))
    expect_true(is.finite(got))
    ref <- -sum(.bb_log_pmf_exact(y, N, mu, phi))
    expect_equal(got, ref, tolerance = 1e-11)
    if (phi >= 1e10) expect_lt(abs(got - ref_binom) / nrow(df), 1e-8)
    expect_true(all(is.finite(as.numeric(obj$gr(p1)))))
  }
  ## Ordinary phi: the classic lgamma / lbeta form.
  p5 <- .edge_set(p, "log_phi_betabinom", log(5))
  ref_lbeta <- -sum(lchoose(Nt, y) + lbeta(y + 2, Nt - y + 3) - lbeta(2, 3))
  expect_equal(as.numeric(obj$fn(p5)), ref_lbeta, tolerance = 1e-11)
  invisible(obj$fn(fit$opt$par))
})

## ---- #1386: closed-form log(1 - rho^2) in the intercept-slope priors -------

test_that("phylo intercept-slope prior has a finite gradient at |atanh_cor_b| = 20 (#1386)", {
  skip_on_cran()
  skip_if_not_installed("ape")
  set.seed(1386)
  n_sp <- 20
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  dat <- expand.grid(species = tree$tip.label, rep = 1:3,
                     stringsAsFactors = FALSE)
  dat$species <- factor(dat$species, levels = tree$tip.label)
  dat$x <- stats::rnorm(nrow(dat))
  dat$t1 <- 1 + 0.5 * dat$x + stats::rnorm(nrow(dat))
  dat$t2 <- 0.5 - 0.3 * dat$x + stats::rnorm(nrow(dat))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2) ~ 1 + phylo_unique(1 + x | species),
    data = dat, phylo_tree = tree, unit = "species",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  obj <- fit$tmb_obj
  p <- fit$opt$par
  expect_true(any(names(p) == "atanh_cor_b"))
  i_c <- which(names(p) == "atanh_cor_b")
  f_hat <- as.numeric(obj$fn(p))
  ## |atanh_cor_b| >= 14 used to give a spurious improvement on the optimum
  ## (an ill-conditioned inner Laplace Hessian) and NaN from ~16.
  for (eta in c(-25, -20, -14, 14, 20, 25)) {
    p1 <- p
    p1[i_c] <- eta
    f <- as.numeric(obj$fn(p1))
    g <- as.numeric(obj$gr(p1))
    expect_true(is.finite(f))
    expect_true(all(is.finite(g)))
    expect_gte(f, f_hat - 1e-6)
  }
  ## The reported correlation stays strictly inside (-1, 1).
  invisible(obj$fn(p1))
  expect_lt(max(abs(as.numeric(obj$report()$cor_b))), 1)
  invisible(obj$fn(fit$opt$par))
})

test_that("SPDE intercept-slope prior matches the closed-form density at atanh_cor = +-20 (#1386)", {
  skip_on_cran()
  skip_if_not_installed("fmesher")
  set.seed(13861)
  sim <- simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1, spatial_range = 0.3,
    sigma2_spa = rep(0.2, 2), seed = 7)
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.12)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  td <- fit$tmb_data
  tp <- fit$tmb_params
  n_mesh <- td$n_mesh
  n_obs <- length(td$y)
  td$use_spde <- 0L
  td$use_spde_slope <- 1L
  td$n_lhs_cols_spde <- 2L
  td$Z_spde_aug <- cbind(rep(1, n_obs), stats::rnorm(n_obs))
  td$A_proj <- Matrix::sparseMatrix(i = integer(0), j = integer(0),
                                    x = numeric(0), dims = c(n_obs, n_mesh))
  kappa <- 2.5
  sd_a <- 0.7
  sd_b <- 1.2
  tp$log_kappa_spde <- log(kappa)
  tp$log_sd_spde_b <- c(log(sd_a), log(sd_b))
  omega <- matrix(stats::rnorm(n_mesh * 2L), n_mesh, 2L)
  M0 <- mesh$spde$c0
  M1 <- mesh$spde$g1
  M2 <- mesh$spde$g2
  Q <- Matrix::forceSymmetric(kappa^4 * M0 + 2 * kappa^2 * M1 + M2)
  Qom <- as.matrix(Q %*% omega)
  q00 <- sum(omega[, 1] * Qom[, 1])
  q11 <- sum(omega[, 2] * Qom[, 2])
  q01 <- sum(omega[, 1] * Qom[, 2])
  fn_at <- function(eta, om) {
    tp2 <- tp
    tp2$atanh_cor_spde_b <- eta
    tp2$omega_spde_aug <- om
    tmap <- lapply(tp2, function(v) factor(rep(NA_integer_, length(v))))
    obj <- TMB::MakeADFun(data = td, parameters = tp2, map = tmap,
                          DLL = "gllvmTMB", silent = TRUE)
    obj$fn()
  }
  for (eta in c(-20, 20, 3)) {
    ## R reference for the engine's bounded rho = (1 - delta) tanh(eta) and
    ## 1 - rho^2 = sech(eta)^2 + tanh(eta)^2 delta (2 - delta).
    delta <- 1e-6
    rho <- (1 - delta) * tanh(eta)
    sech2 <- exp(2 * log(2) - 2 * (abs(eta) + log1p(exp(-2 * abs(eta)))))
    log_om <- log(sech2 + tanh(eta)^2 * delta * (2 - delta))
    s00 <- exp(-2 * log(sd_a) - log_om)
    s11 <- exp(-2 * log(sd_b) - log_om)
    s01 <- -rho * exp(-log(sd_a) - log(sd_b) - log_om)
    logdet_Sf <- 2 * log(sd_a) + 2 * log(sd_b) + log_om
    quad <- s00 * q00 + s11 * q11 + 2 * s01 * q01
    ## Engine: fn(omega) - fn(0) is the quadratic part only.
    d_engine <- fn_at(eta, omega) - fn_at(eta, matrix(0, n_mesh, 2L))
    expect_true(is.finite(d_engine))
    expect_equal(d_engine, 0.5 * quad, tolerance = 1e-9)
    ## log-determinant part: fn(0) at eta minus fn(0) at eta = 0.
    d_logdet <- fn_at(eta, matrix(0, n_mesh, 2L)) -
      fn_at(0, matrix(0, n_mesh, 2L))
    expect_equal(d_logdet, 0.5 * n_mesh * log_om, tolerance = 1e-9)
  }
})

test_that("R's beta-binomial CDF (residuals) agrees with the exact pmf at large phi (#1364)", {
  cdf_fn <- getFromNamespace(".gllvmTMB_betabinom_cdf", "gllvmTMB")
  N <- 10L
  mu <- 0.4
  for (phi in c(0.01, 5, 1e4, 1e10, 1e13, 1e300)) {
    ref <- cumsum(exp(.bb_log_pmf_exact(0:N, rep(N, N + 1L), rep(mu, N + 1L), phi)))
    got <- cdf_fn(N, mu * phi, (1 - mu) * phi)
    expect_equal(got, ref, tolerance = 1e-12)
    expect_lte(max(got), 1 + 1e-12)
    if (phi >= 1e10) {
      expect_equal(got, stats::pbinom(0:N, N, mu), tolerance = 1e-8)
    }
  }
})
