test_that("R3 packing and rank-zero guards match the frozen contract", {
  for (q in c(1L, 2L, 4L, 6L)) {
    T <- 6L
    Lambda <- matrix(0, T, q)
    Lambda[row(Lambda) >= col(Lambda)] <- seq_len(.va_r3_theta_length(T, q)) / 10
    packed <- .va_r3_pack_theta_rr(Lambda)
    expect_length(packed, .va_r3_theta_length(T, q))
    expect_equal(.va_r3_unpack_theta_rr(packed, T, q), Lambda, tolerance = 0)
  }

  rank_zero <- .va_r3_fit(
    y = c(1L, 2L), n_trials = c(3L, 3L), X = matrix(1, 2L, 1L),
    unit_id = c(1L, 1L), trait_id = 1:2, q = 0L,
    source = "this-source-must-not-be-opened.cpp"
  )
  expect_identical(rank_zero$status, "not_applicable_rank_zero")
  expect_false(rank_zero$objective_constructed)
})

test_that("R3 objective agreement requires any three of four healthy starts", {
  objectives <- c(10, 10 + 2e-7, 10 + 4e-7, 10 + 3e-6)
  expect_lt(.va_r3_best_three_range(objectives), 1e-6)
  expect_gt(diff(range(objectives)), 1e-6)
  expect_identical(.va_r3_best_three_range(c(1, 2)), Inf)
})

test_that("R3 accepts only the predeclared complete ordinary model cell", {
  args <- list(
    y = c(1L, 2L, 0L, 3L), n_trials = rep(4L, 4L),
    X = cbind(1, c(-1, 1, -1, 1)),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L
  )
  expect_no_error(do.call(.va_r3_validate_data, args))
  ## Design 108 Gate A Stage 6 LIFTED the `unique`/`psi` half of this gate:
  ## Psi is a trait-diagonal tier, and Design 106 Prop. 1 admits it with no new
  ## machinery. It is now accepted -- and it must arrive as a SECOND tier. An
  ## `unique = TRUE` that quietly produced a one-tier model would be exactly
  ## the silent failure this replacement assertion exists to catch.
  admitted <- do.call(.va_r3_validate_data, c(args, list(unique = TRUE)))
  expect_identical(admitted$tier_layout$n_tiers, 2L)
  expect_identical(admitted$tier_layout$kind, c("dense", "diagonal"))
  expect_true(admitted$unique)
  ## `psi = TRUE` is the same request under its other spelling, not a third tier.
  expect_identical(
    do.call(.va_r3_validate_data, c(args, list(psi = TRUE)))$tier_layout$kind,
    c("dense", "diagonal")
  )
  ## Stage 7 opened `structured` -- but only as a list carrying the precision.
  ## A bare TRUE names a structure with nothing to be structured BY and is
  ## still refused; `provider` / `lv` / `missing` stay CLOSED, untouched. The
  ## structured tier itself is exercised in test-va-r3-structured-phylo.R.
  expect_error(do.call(.va_r3_validate_data, c(args, list(structured = TRUE))),
               "must be FALSE, or a list")
  expect_error(do.call(.va_r3_validate_data,
                       c(args, list(provider = list(kind = "phylo")))),
               "no structured provider")
  expect_error(do.call(.va_r3_validate_data, c(args, list(lv = TRUE))),
               "no structured provider")
  expect_error(do.call(.va_r3_validate_data, c(args, list(missing = TRUE))),
               "no structured provider")
  expect_error(do.call(.va_r3_validate_data,
                       within(args, trait_id <- c(1L, 1L, 1L, 2L))),
               "exactly one dense")
  rank_deficient <- args
  rank_deficient$X <- matrix(1, 4L, 2L)
  expect_error(do.call(.va_r3_validate_data, rank_deficient),
               "full column rank")
})

test_that("R3 Gauss-Hermite rules are normalized and stable", {
  ## The admitted set was c(15, 25, 61) and this test asserted that H = 9 was
  ## REFUSED. That whitelist was a typo-guard, not a numerical constraint -- the
  ## nodes are built by Golub--Welsch at runtime, so any odd H >= 3 is valid --
  ## and it blocked measuring GH's cost curve, which matters because GH is the
  ## dominant term in fit time and the quadrature loop is linear in H. The rule
  ## now admits any odd H >= 3, so the small orders are exercised HERE rather
  ## than merely permitted.
  for (H in c(3L, 5L, 7L, 9L, 15L, 25L, 61L)) {
    rule <- .va_r3_gh_rule(H)
    expect_equal(sum(rule$weights), sqrt(pi), tolerance = 1e-14)
    expect_equal(sum(rule$weights * rule$nodes), 0, tolerance = 1e-14)
    expect_equal(sum(rule$weights * rule$nodes^2) / sqrt(pi), 0.5,
                 tolerance = 1e-13)
  }

  ## Degree of exactness: an H-point Gauss rule integrates polynomials up to
  ## degree 2H-1 exactly. In probabilists' terms E[z^4] = 3 needs H >= 3 and
  ## E[z^6] = 15 needs H >= 4, so H = 3 is the LAST order that gets z^6 wrong
  ## (it returns 9). That boundary is asserted, not assumed -- it is the reason
  ## H = 5 is the smallest order worth using in practice.
  moment <- function(H, p) {
    r <- .va_r3_gh_rule(H)
    z <- r$nodes * sqrt(2); w <- r$weights / sqrt(pi)
    sum(w * z^p)
  }
  expect_equal(moment(3L, 4L), 3, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(moment(3L, 6L), 15)))   # H=3 cannot reach z^6
  for (H in c(5L, 7L, 15L, 61L)) {
    expect_equal(moment(H, 4L), 3, tolerance = 1e-12)
    expect_equal(moment(H, 6L), 15, tolerance = 1e-11)
  }

  ## What IS still refused: even orders (an odd rule keeps a node at the
  ## variational mean, where the integrand's mass is) and anything below 3.
  expect_error(.va_r3_gh_rule(8L), "odd integer H >= 3")
  expect_error(.va_r3_gh_rule(2L), "odd integer H >= 3")
  expect_error(.va_r3_gh_rule(1L), "odd integer H >= 3")
})

test_that("R3 H=61 scalar expectation passes the frozen oracle grid", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0, theta_rr = 0, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  ## eval_method = "gh" is explicit because this grid checks the QUADRATURE
  ## path against an exact integrate() oracle. Binomial "auto" resolves to the
  ## Jaakkola-Jordan bound, which is deliberately not exact, so leaving the
  ## default here would fail the oracle by construction rather than by defect.
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters,
                               eval_method = "gh")
  beta_index <- which(names(obj$par) == "beta")
  theta_index <- which(names(obj$par) == "theta_rr")
  stable_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  for (mu in c(-20, -5, 0, 5, 20)) {
    for (variance in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
      p <- obj$par
      p[beta_index] <- mu
      p[theta_index] <- sqrt(variance)
      observed <- obj$report(p)$softplus_expectation_by_obs[1L]
      expected <- if (variance == 0) stable_softplus(mu) else {
        stats::integrate(function(z) {
          stable_softplus(mu + sqrt(variance) * z) * stats::dnorm(z)
        }, -Inf, Inf, rel.tol = 1e-13)$value
      }
      expect_lt(abs(observed - expected), 1e-10)
    }
  }
})

test_that("R3 nbinom2 expected log-likelihood passes a direct integrate() oracle", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## Independent check of the template's nbinom2 branch. The oracle density
  ## uses base R's stats::dnbinom(mu = exp(eta), size = phi, log = TRUE) --
  ## algebraically identical to
  ##   log p(y|eta) = lgamma(y+phi) - lgamma(phi) - lgamma(y+1)
  ##                  + phi*log(phi) - (y+phi)*log(phi + exp(eta)) + y*eta
  ## but a genuinely separate implementation (R's own, numerically stable at
  ## large mu), not the shifted-softplus identity the template uses. This is
  ## then integrated against eta ~ N(mu, v) by stats::integrate() and compared
  ## to the template's reported expected_loglik_by_obs.
  validated <- .va_r3_validate_data(
    y = 2L, n_trials = 1L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L,
    family = "nbinom2", link = "log"
  )
  parameters <- list(
    beta = 0, theta_rr = 0, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters,
                               eval_method = "gh")
  beta_index <- which(names(obj$par) == "beta")
  theta_index <- which(names(obj$par) == "theta_rr")
  phi_index <- which(names(obj$par) == "log_phi")
  expect_length(phi_index, 1L)

  nbinom2_logdensity <- function(y, eta, phi) {
    stats::dnbinom(y, size = phi, mu = exp(eta), log = TRUE)
  }

  y_val <- 2
  for (mu in c(-3, -1, 0, 1, 3)) {
    for (variance in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
      for (phi in c(0.5, 2, 10)) {
        p <- obj$par
        p[beta_index] <- mu
        p[theta_index] <- sqrt(variance)
        p[phi_index] <- log(phi)
        observed <- obj$report(p)$expected_loglik_by_obs[1L]
        expected <- if (variance == 0) {
          nbinom2_logdensity(y_val, mu, phi)
        } else {
          ## Finite bounds, not (-Inf, Inf): unlike softplus (linear growth),
          ## the direct oracle exponentiates eta with no stabilisation, so an
          ## unbounded domain lets integrate() probe eta large enough to
          ## overflow exp(). +-40 SD is far beyond where the tail mass matters
          ## at this tolerance and stays well inside exp()'s safe range.
          stats::integrate(function(z) {
            eta <- mu + sqrt(variance) * z
            nbinom2_logdensity(y_val, eta, phi) * stats::dnorm(z)
          }, -40, 40, rel.tol = 1e-13)$value
        }
        expect_lt(abs(observed - expected), 1e-8)
      }
    }
  }
})

test_that("R3 nbinom2 is mapped off (inert) for every other family", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## log_phi must not appear in obj$par -- and must not change the objective
  ## or gradient -- for a family that never uses it. This is the guard against
  ## the parameter-vector-cascade risk: adding log_phi to the template must
  ## cost the pre-existing families nothing.
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0.4, theta_rr = 0.3, m = matrix(0.1, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters,
                               eval_method = "gh")
  expect_false("log_phi" %in% names(obj$par))
  ## beta, theta_rr, m, log_L_diag; L_off is empty at q=1 (0 off-diagonal
  ## entries), and log_phi is mapped off for this (binomial) family.
  expect_identical(length(obj$par), 4L)
})

test_that("R3 latent posterior reads variational means and SDs out of the fitted par", {
  ## N = 2, q = 2. TMB matrices are column-major, so the packed vectors below
  ## give unit 1 the Cholesky [[1, 0], [3, 2]] and unit 2 [[0.5, 0], [-1, 1]].
  ##   unit 1: L L' = [[1, 3], [3, 13]]     -> sd = (1, sqrt(13))
  ##   unit 2: L L' = [[0.25, -0.5], [-0.5, 2]] -> sd = (0.5, sqrt(2))
  par <- c(
    m = 0.1, m = 0.2, m = 0.3, m = 0.4,
    log_L_diag = 0, log_L_diag = log(0.5), log_L_diag = log(2), log_L_diag = 0,
    L_off = 3, L_off = -1
  )
  post <- .va_r3_latent_posterior(par, N = 2L, q = 2L)

  expect_equal(post$scores, matrix(c(0.1, 0.2, 0.3, 0.4), 2L, 2L))
  expect_equal(
    post$se,
    matrix(c(1, 0.5, sqrt(13), sqrt(2)), nrow = 2L, ncol = 2L),
    tolerance = 1e-12
  )
  ## These are variational posterior SDs, not Wald SEs, and they are not
  ## calibrated. Both facts must travel with the numbers.
  expect_false(post$calibrated)
  expect_match(post$uncertainty_basis, "variational posterior")

  ## An unnamed par cannot be unpacked and must fail rather than guess.
  expect_error(.va_r3_latent_posterior(unname(par), N = 2L, q = 2L),
               "parameter names")
})

test_that("R3 fit returns a latent posterior of the right shape", {
  set.seed(4242)
  n <- 40L; p <- 4L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.5)
  fit <- .va_r3_fit(
    y = rbinom(n * p, 1L, plogis(eta)), n_trials = rep(1L, n * p),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    q = 2L, family = "binomial", link = "logit", H = 15L
  )
  expect_false(is.null(fit$latent))
  expect_identical(dim(fit$latent$scores), c(n, 2L))
  expect_identical(dim(fit$latent$se), c(n, 2L))
  expect_true(all(is.finite(fit$latent$se)))
  expect_true(all(fit$latent$se > 0))
  expect_false(fit$latent$calibrated)
})

test_that("R3 nbinom2 fit is alive: simulate-then-fit returns a healthy status", {
  ## A recovery SMOKE test, not a recovery accuracy test: the point is to
  ## prove the whole nbinom2 pipeline (beta, loadings, per-trait log_phi, and
  ## the variational block) is alive end to end, not to certify accuracy.
  set.seed(2026L)
  N <- 60L; T <- 4L; q <- 2L
  trait_names <- paste0("sp", seq_len(T))
  long <- data.frame(
    unit = factor(rep(seq_len(N), each = T)),
    trait = factor(rep(trait_names, N), levels = trait_names)
  )
  beta <- c(1.0, 0.8, 0.6, 0.9)
  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <- c(0.5, 0.3, -0.2, 0.4, 0.35, -0.25, 0.2)
  score <- matrix(rnorm(N * q), N, q)
  unit <- as.integer(long$unit)
  trait <- as.integer(long$trait)
  eta <- beta[trait] + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  phi_true <- 2
  y <- rnbinom(N * T, size = phi_true, mu = exp(eta))

  fit <- .va_r3_fit(
    y = y, n_trials = rep(1L, N * T),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = unit, trait_id = trait,
    q = q, family = "nbinom2", link = "log", H = 15L
  )

  expect_identical(fit$status, "healthy")
  expect_true(is.finite(fit$best$objective))
  expect_gte(fit$health$healthy_starts, 3L)
  fitted_log_phi <- unname(fit$best$par[names(fit$best$par) == "log_phi"])
  expect_length(fitted_log_phi, T)
  expect_true(all(is.finite(fitted_log_phi)))
})

test_that("R3 fixed-parameter information marginalises the variational block", {
  set.seed(9191)
  n <- 60L; p <- 5L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  fit <- .va_r3_fit(
    y = rbinom(n * p, 1L, plogis(eta)), n_trials = rep(1L, n * p),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    q = 2L, family = "binomial", link = "logit", H = 15L
  )
  info <- .va_r3_fixed_information(fit$objective, fit$best$par)

  expect_identical(info$status, "ok")
  expect_true(info$pd_hessian)
  expect_true(all(is.finite(info$se_conditional)))
  expect_true(all(is.finite(info$se_profile)))
  expect_true(all(info$se_profile > 0))

  ## The load-bearing property. Profiling the variational block OUT can only
  ## reduce curvature (the Schur complement subtracts a positive semi-definite
  ## term), so the profile SE must be >= the conditional one. A naive
  ## optimHess over the fixed block alone is therefore anti-conservative --
  ## this test is what stops anyone "simplifying" to that later.
  expect_true(all(info$se_profile >= info$se_conditional * (1 - 1e-8)))

  ## Not calibrated, and that must travel with the numbers.
  expect_false(info$calibrated)

  ## Fails closed rather than returning a number it cannot justify.
  broken <- .va_r3_fixed_information(
    list(he = function(p) stop("no hessian")), fit$best$par
  )
  expect_false(broken$pd_hessian)
  expect_null(broken$se_profile)
  expect_match(broken$status, "hessian_error")
})

test_that("R3 blocked information reproduces the dense Schur complement exactly", {
  ## The blocked route never forms the dense Hessian. It relies on units being
  ## conditionally independent given the fixed parameters, so H_vv is EXACTLY
  ## block diagonal. That is a structural claim about the model, and this test
  ## is what verifies it rather than assuming it: if any cross-unit second
  ## derivative were non-zero, the two routes would disagree here.
  set.seed(31)
  n <- 60L; p <- 5L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  fit <- .va_r3_fit(
    y = rbinom(n * p, 1L, plogis(eta)), n_trials = rep(1L, n * p),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    q = 2L, family = "binomial", link = "logit", H = 15L
  )

  ## route = "dense" is REQUIRED here. The default dispatches to the blocked
  ## route, so calling it bare would compare blocked against blocked and this
  ## test would pass vacuously while verifying nothing.
  dense <- .va_r3_fixed_information(fit$objective, fit$best$par, route = "dense")
  blocked <- .va_r3_fixed_information_blocked(fit$objective, fit$best$par,
                                              N = n, q = 2L)
  expect_identical(dense$route, "dense")
  expect_identical(blocked$route, "blocked")

  ## The BLOCKED route is the one this package uses, so its health is asserted
  ## unconditionally.
  expect_identical(blocked$status, "ok")
  expect_identical(blocked$route, "blocked")
  expect_true(blocked$pd_hessian)

  ## The DENSE route is only the comparator, and its success is
  ## PLATFORM-DEPENDENT: it forms the full Hessian and Cholesky-factors it, so
  ## whether it comes back positive-definite at this fixture depends on the
  ## BLAS. Observed passing on macOS/Accelerate and failing on Linux CI at the
  ## same commit. Asserting dense$status == "ok" therefore tested the host's
  ## BLAS, not this package.
  ##
  ## Guarded rather than weakened: where dense DOES produce SEs the agreement
  ## is still checked at full 1e-8 strictness, so the block-diagonal claim is
  ## verified wherever it can be. Loosening the tolerance instead would
  ## silently stop verifying anything. The comparison is deferred to the END of
  ## this test so that every unconditional assertion below still runs when the
  ## comparator is unavailable.
  dense_available <- identical(dense$status, "ok") && !is.null(dense$se_profile)

  ## The anti-conservatism invariant must hold on the blocked route too.
  expect_true(all(blocked$se_profile >= blocked$se_conditional * (1 - 1e-8)))
  expect_false(blocked$calibrated)

  ## The index map must place every variational coordinate exactly once.
  map <- .va_r3_variational_index_map(names(fit$best$par), N = n, q = 2L)
  expect_identical(dim(map), c(n, 5L))          # k = 2q + q(q-1)/2 = 5
  expect_identical(anyDuplicated(as.integer(map)), 0L)
  expect_setequal(
    as.integer(map),
    which(names(fit$best$par) %in% c("m", "log_L_diag", "L_off"))
  )

  ## THE LOAD-BEARING ASSERTION, run wherever the comparator exists. If the
  ## dense route could not factor its Hessian on this BLAS, say so out loud
  ## rather than passing silently -- a green test that verified nothing is the
  ## failure mode this file has already hit three times.
  if (!dense_available) {
    skip(paste0("dense comparator unavailable on this BLAS (status: ",
                dense$status, ") -- blocked route asserted above, ",
                "cross-check not runnable here"))
  }
  expect_equal(blocked$se_profile, dense$se_profile, tolerance = 1e-8)
  expect_equal(blocked$se_conditional, dense$se_conditional, tolerance = 1e-8)
})

test_that("R3 n_starts exposes the gate width without weakening the gate", {
  set.seed(88)
  n <- 80L; p <- 5L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  y <- rbinom(n * p, 1L, plogis(eta))
  X <- stats::model.matrix(~ 0 + trait, long)
  u <- as.integer(long$unit); tr <- as.integer(long$trait)
  fit <- function(ns) {
    .va_r3_fit(y, rep(1L, n * p), X, u, tr, q = 2L, family = "binomial",
               link = "logit", H = 15L, n_starts = ns)
  }

  full <- fit(4L)
  single <- fit(1L)

  ## The default is unchanged: four starts, gate intact.
  expect_identical(full$health$attempted_starts, 4L)
  expect_identical(full$health$minimum_healthy_starts, 3L)

  ## n_starts = 1 reaches the SAME optimum -- that is what makes it a speed
  ## knob rather than a different fit.
  expect_lt(abs(full$best$objective - single$best$objective), 1e-6)
  expect_lt(max(abs(full$best$par - single$best$par)), 1e-3)

  ## ...but it must NOT be able to report a passed gate. Bypassing the gate has
  ## to be visible in the status, never silent.
  expect_identical(single$health$attempted_starts, 1L)
  expect_false(isTRUE(single$health$admitted))
  expect_identical(single$status, "failed_health_gate")

  ## 2 starts can never satisfy "3 healthy", so it is rejected rather than
  ## silently forcing failed_health_gate; 5 would index past the 4-entry
  ## jitter table in .va_r3_default_parameters() and produce NA starts.
  expect_error(fit(2L), "n_starts must be")
  expect_error(fit(5L), "n_starts must be")
})

test_that("R3 L-BFGS-B primary reaches the same optimum as nlminb", {
  ## The optimiser is a ROUTE choice, not a model choice: both minimise the same
  ## objective from the same start, so the fitted values must agree. This test
  ## is the guard on that. It deliberately asserts NOTHING about speed -- a
  ## timing assertion in a test suite is a flake generator, and the speed
  ## evidence lives in dev/r2-fragility-resolution.csv.
  set.seed(505)
  n <- 200L; p <- 6L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  y <- rbinom(n * p, 1L, plogis(eta))
  X <- stats::model.matrix(~ 0 + trait, long)
  u <- as.integer(long$unit); tr <- as.integer(long$trait)
  fit <- function(o) {
    .va_r3_fit(y, rep(1L, n * p), X, u, tr, q = 2L, family = "binomial",
               link = "logit", H = 15L, n_starts = 1L, optimizer = o)
  }

  a <- fit("nlminb")
  b <- fit("lbfgsb")

  expect_identical(a$optimizer, "nlminb")
  expect_identical(b$optimizer, "lbfgsb")
  expect_lt(abs(a$best$objective - b$best$objective), 1e-5)
  expect_lt(max(abs(a$best$par - b$best$par)), 1e-2)

  ## The DEFAULT is now "auto", which resolves per family AND per tier from the
  ## registry (see the auto-routing test). For binomial the default tier is jj,
  ## where lbfgsb was measured 2.54x faster with every cell agreeing -- so the
  ## default fit here resolves to lbfgsb, not to nlminb.
  expect_identical(.va_r3_fit(
    y, rep(1L, n * p), X, u, tr, q = 2L, family = "binomial", link = "logit",
    H = 15L, n_starts = 1L)$optimizer, "lbfgsb")

  ## The factr constant is load-bearing: optim's DEFAULT factr terminated in
  ## ~24ms at an objective 125-151 worse in 3 of 3 replicates at N=1600 while
  ## reporting convergence = 0. Pin it so it cannot be "simplified" away.
  expect_true(.VA_R3_LBFGSB_FACTR < 1e-6 / .Machine$double.eps)
  expect_equal(.VA_R3_LBFGSB_FACTR, 1e-12 / .Machine$double.eps)
})

test_that("R3 optimizer auto-routes per family AND per tier", {
  ## The routing is measured, not chosen by taste. Medians over the sweep in
  ## dev/lbfgsb-default-*.csv (nlminb/lbfgsb; > 1 means lbfgsb faster):
  ##   binomial jj       2.54x  (1.31-6.33)  -> lbfgsb
  ##   gaussian gh       2.13x  (1.76-2.50)  -> lbfgsb
  ##   poisson  gh       1.25x  (0.96-3.25)  -> nlminb, the range straddles 1
  ##   binomial gh       0.57x  (0.35-1.02)  -> nlminb, lbfgsb is SLOWER
  ##   nbinom2  gh       0.42x  (0.26-0.63)  -> nlminb, slower AND the only
  ##                                            same-optimum disagreement
  ## binomial_probit is the one family NOT measured, on ANY tier: Design 108
  ## Stage 4 is a numerics spike, the mature-VA arc's Albert-Chib tier ("ac")
  ## is a correctness slice, and its curvature-corrected sibling ("ac2") is a
  ## diagnosis/comparison tier -- no timing sweep has been run for any of the
  ## three, so all take the reference optimiser rather than claiming a route
  ## they have no evidence for. Give each a measured route only when a sweep
  ## exists for it.
  expected <- list(
    gaussian_anchor = c(gh = "lbfgsb"),
    binomial        = c(gh = "nlminb", jj = "lbfgsb"),
    poisson         = c(gh = "nlminb"),
    nbinom2         = c(gh = "nlminb"),
    binomial_probit = c(gh = "nlminb", ac = "nlminb", ac2 = "nlminb")
  )
  for (entry in .va_r3_family_registry) {
    want <- expected[[entry$family]]
    expect_false(is.null(want))
    for (tier in entry$tiers) {
      expect_identical(
        .va_r3_resolve_optimizer("auto", entry$family_code, tier),
        unname(want[[tier]]),
        info = paste(entry$family, tier)
      )
    }
  }

  ## binomial is the reason routing must be per TIER, not per family: its two
  ## tiers point in OPPOSITE directions. A family-level choice would have
  ## slowed down gh, the accurate tier.
  expect_identical(.va_r3_resolve_optimizer("auto", 1L, "jj"), "lbfgsb")
  expect_identical(.va_r3_resolve_optimizer("auto", 1L, "gh"), "nlminb")

  ## An explicit request always wins over the routing.
  expect_identical(.va_r3_resolve_optimizer("lbfgsb", 1L, "gh"), "lbfgsb")
  expect_identical(.va_r3_resolve_optimizer("nlminb", 1L, "jj"), "nlminb")

  ## A tier with no declared route falls back to the reference optimiser
  ## rather than guessing.
  expect_identical(.va_r3_resolve_optimizer("auto", 1L, "not_a_tier"), "nlminb")

  ## And the fit reports the RESOLVED optimiser, so a run is auditable.
  set.seed(606)
  n <- 120L; p <- 5L
  trait_names <- paste0("sp", seq_len(p))
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(trait_names, each = n), levels = trait_names)
  )
  eta <- rnorm(n * p, sd = 0.6)
  y <- rbinom(n * p, 1L, plogis(eta))
  X <- stats::model.matrix(~ 0 + trait, long)
  u <- as.integer(long$unit); tr <- as.integer(long$trait)
  fit <- function(em) {
    .va_r3_fit(y, rep(1L, n * p), X, u, tr, q = 2L, family = "binomial",
               link = "logit", H = 15L, n_starts = 1L, eval_method = em)
  }
  expect_identical(fit("jj")$optimizer, "lbfgsb")
  expect_identical(fit("gh")$optimizer, "nlminb")
})

test_that("R3 family registry agrees with the validator and drives eval_method", {
  ## The registry is the declared per-family evaluation contract. It must not
  ## drift from .va_r3_validate_data(), which is what actually assigns the
  ## family code the template sees. Adding a family without a registry entry
  ## (or with the wrong code/link) fails here rather than silently.
  y_for <- list(gaussian_anchor = 0.5, binomial = 1L, poisson = 2L,
                nbinom2 = 2L, binomial_probit = 1L)
  for (entry in .va_r3_family_registry) {
    validated <- .va_r3_validate_data(
      y = y_for[[entry$family]], n_trials = 3L, X = matrix(1, 1L, 1L),
      unit_id = 1L, trait_id = 1L, q = 1L,
      family = entry$family, link = entry$link
    )
    expect_true(all(validated$family == entry$family_code))

    ## "auto" resolves to whatever the registry declares.
    expect_identical(
      .va_r3_resolve_eval_method("auto", entry$family_code),
      entry$default_tier
    )
    ## Every declared tier is accepted; anything else fails closed.
    for (tier in entry$tiers) {
      expect_identical(
        .va_r3_resolve_eval_method(tier, entry$family_code), tier
      )
    }
    for (tier in setdiff(c("gh", "jj"), entry$tiers)) {
      expect_error(
        .va_r3_resolve_eval_method(tier, entry$family_code),
        "not implemented for the"
      )
    }
    ## objective_type reports the resolved bound, never a hardcoded one.
    expect_identical(
      .va_r3_objective_type(.va_r3_resolve_eval_method("auto", entry$family_code)),
      if (identical(entry$default_tier, "jj")) "ELBO_JJ" else "ELBO_GH"
    )
  }

  ## A family code with no registry entry is an error, not a silent default.
  expect_error(.va_r3_family_entry(99L), "no registry entry")
})

test_that("R3 JJ bound over-estimates the softplus expectation and is exact at zero variance", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## The Jaakkola-Jordan/PG bound is not a quadrature rule, so it must not be
  ## held to the oracle grid above. Its contract is an INEQUALITY: it bounds
  ## E[softplus(eta)] from ABOVE, which is what makes the ELBO -- which
  ## subtracts n * softplus_expectation -- a genuine lower bound. It is tight
  ## at v = 0, where xi = |mu| and the bound collapses to softplus(mu).
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0, theta_rr = 0, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters,
                               eval_method = "jj")
  beta_index <- which(names(obj$par) == "beta")
  theta_index <- which(names(obj$par) == "theta_rr")
  stable_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  for (mu in c(-20, -5, 0, 5, 20)) {
    for (variance in c(0, 1e-8, 1e-4, 0.1, 1, 4)) {
      p <- obj$par
      p[beta_index] <- mu
      p[theta_index] <- sqrt(variance)
      observed <- obj$report(p)$softplus_expectation_by_obs[1L]
      exact <- if (variance == 0) stable_softplus(mu) else {
        stats::integrate(function(z) {
          stable_softplus(mu + sqrt(variance) * z) * stats::dnorm(z)
        }, -Inf, Inf, rel.tol = 1e-13)$value
      }
      ## Upper bound, up to floating-point slack.
      expect_gt(observed - exact, -1e-10)
      if (variance == 0) {
        ## Tight at v = 0.
        expect_lt(abs(observed - exact), 1e-10)
      }
    }
  }
})

test_that("R3 fails closed outside the certified projected-variance domain", {
  fit <- .va_r3_fit(
    y = c(1, 2), n_trials = c(1L, 1L), X = matrix(1, 2L, 1L),
    unit_id = c(1L, 1L), trait_id = 1:2, q = 1L, H = 61L,
    fixed_global = list(beta = 0, theta_rr = c(3, 3)),
    family = "gaussian_anchor", gaussian_sd = 100,
    ## Pin residual SD so the Stage-2 free log_sigma path cannot collapse the
    ## projected-variance fixture back inside the certified domain.
    estimate_gaussian_sd = FALSE,
    rank_source = "fixed_fixture"
  )
  expect_identical(fit$status, "failed_variance_domain")
  expect_false(fit$health$variance_domain_ok)
  expect_gt(fit$health$max_projected_variance, 4)
})

test_that("R3 variational Cholesky unpack matches TMB column-major packing", {
  N <- 2L; q <- 3L
  diag_values <- matrix(c(1, 2, 3, 4, 5, 6), N, q)
  off <- matrix(c(0.1, 0.4, 0.2, 0.5, 0.3, 0.6), N, 3L)
  unpacked <- .va_r3_unpack_variational_chol(log(diag_values), off, N, q)
  expect_equal(unpacked[, , 1L],
               matrix(c(1, 0.1, 0.2, 0, 3, 0.3, 0, 0, 5), 3L, 3L),
               tolerance = 1e-15)
  expect_equal(unpacked[, , 2L],
               matrix(c(2, 0.4, 0.5, 0, 4, 0.6, 0, 0, 6), 3L, 3L),
               tolerance = 1e-15)
})

test_that("R3 q>1 projected variances and KL match direct matrix algebra", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  N <- 2L; T <- 3L; q <- 2L
  X <- model.matrix(~ 0 + factor(rep(seq_len(T), N), levels = seq_len(T)))
  validated <- .va_r3_validate_data(
    y = c(1L, 2L, 3L, 0L, 2L, 1L), n_trials = rep(4L, N * T), X = X,
    unit_id = rep(seq_len(N), each = T), trait_id = rep(seq_len(T), N), q = q
  )
  Lambda <- matrix(c(0.7, 0, -0.2, 0.5, 0.3, -0.4), T, q, byrow = TRUE)
  parameters <- list(
    beta = c(-0.2, 0.1, 0.3), theta_rr = .va_r3_pack_theta_rr(Lambda),
    m = matrix(c(0.1, -0.2, 0.3, 0.05), N, q),
    log_L_diag = matrix(log(c(0.8, 1.1, 0.9, 0.7)), N, q),
    L_off = matrix(c(0.15, -0.25), N, 1L)
  )
  obj <- .va_r3_make_objective(validated, H = 61L, parameters = parameters)
  report <- obj$report(obj$par)
  L <- .va_r3_unpack_variational_chol(
    parameters$log_L_diag, parameters$L_off, N, q
  )
  expected_v <- vapply(seq_len(N * T), function(r) {
    i <- validated$unit_id[r] + 1L
    lambda <- Lambda[validated$trait_id[r] + 1L, ]
    drop(crossprod(lambda, tcrossprod(L[, , i]) %*% lambda))
  }, numeric(1))
  expected_kl <- vapply(seq_len(N), function(i) {
    S <- tcrossprod(L[, , i])
    0.5 * (sum(diag(S)) + sum(parameters$m[i, ]^2) -
             as.numeric(determinant(S, logarithm = TRUE)$modulus) - q)
  }, numeric(1))
  expect_equal(report$v_by_obs, expected_v, tolerance = 1e-12)
  expect_equal(report$kl_by_unit, expected_kl, tolerance = 1e-12)
})

test_that("R3 scalar ELBO, KL sign, and autodiff match independent calculations", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  validated <- .va_r3_validate_data(
    y = 3L, n_trials = 8L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = -0.3, theta_rr = 0.7, m = matrix(0.2, 1L, 1L),
    log_L_diag = matrix(log(0.8), 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  ## expected_softplus below is an exact integrate() calculation, so the
  ## objective must use quadrature; binomial "auto" resolves to the JJ bound,
  ## which over-estimates it by construction.
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters,
                               eval_method = "gh")
  report <- obj$report(obj$par)
  mu <- -0.3 + 0.7 * 0.2
  variance <- 0.7^2 * 0.8^2
  expected_softplus <- stats::integrate(
    function(z) {
      eta <- mu + sqrt(variance) * z
      (pmax(eta, 0) + log1p(exp(-abs(eta)))) * stats::dnorm(z)
    },
    -Inf, Inf, rel.tol = 1e-13
  )$value
  expected_loglik <- lchoose(8, 3) + 3 * mu - 8 * expected_softplus
  expected_kl <- 0.5 * (0.2^2 + 0.8^2 - log(0.8^2) - 1)
  expect_equal(report$expected_loglik, expected_loglik, tolerance = 1e-10)
  expect_equal(report$total_kl, expected_kl, tolerance = 1e-12)
  expect_equal(obj$fn(obj$par), -(expected_loglik - expected_kl), tolerance = 1e-10)

  analytic <- obj$gr(obj$par)
  numeric <- vapply(seq_along(obj$par), function(j) {
    h <- 1e-6 * max(1, abs(obj$par[j]))
    plus <- minus <- obj$par
    plus[j] <- plus[j] + h
    minus[j] <- minus[j] - h
    (obj$fn(plus) - obj$fn(minus)) / (2 * h)
  }, numeric(1))
  expect_lt(max(abs(analytic - numeric) / pmax(1, abs(numeric))), 1e-5)
})

test_that("R3 small-variance branch is value- and derivative-continuous", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  validated <- .va_r3_validate_data(
    y = 1L, n_trials = 3L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  parameters <- list(
    beta = 0.4, theta_rr = 1e-3, m = matrix(0, 1L, 1L),
    log_L_diag = matrix(0, 1L, 1L), L_off = matrix(numeric(), 1L, 0L)
  )
  obj <- .va_r3_make_objective(validated, H = 25L, parameters = parameters)
  theta_index <- which(names(obj$par) == "theta_rr")
  evaluate <- function(theta) {
    p <- obj$par
    p[theta_index] <- theta
    c(value = obj$fn(p), gradient = obj$gr(p)[theta_index])
  }
  below <- evaluate(1e-3 * (1 - 1e-7))
  above <- evaluate(1e-3 * (1 + 1e-7))
  expect_lt(abs(below["value"] - above["value"]), 1e-9)
  expect_lt(abs(below["gradient"] - above["gradient"]), 1e-7)
})

test_that("R3 small-variance expansion is insensitive across switch candidates", {
  rule <- .va_r3_gh_rule(61L)
  stable_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  expansion <- function(mu, v) {
    p <- plogis(mu); pq <- p * (1 - p)
    f2 <- pq
    f4 <- pq * (1 - 6 * p + 6 * p^2)
    f6 <- pq * (1 - 30 * p + 150 * p^2 - 240 * p^3 + 120 * p^4)
    stable_softplus(mu) + v * f2 / 2 + v^2 * f4 / 8 + v^3 * f6 / 48
  }
  quadrature <- function(mu, v) {
    sum(rule$weights * stable_softplus(mu + sqrt(2 * v) * rule$nodes)) / sqrt(pi)
  }
  for (mu in c(-10, -2, 0, 2, 10)) {
    for (v in c(1e-8, 1e-7, 1e-6, 1e-5, 1e-4)) {
      expect_lt(abs(expansion(mu, v) - quadrature(mu, v)), 1e-10)
    }
  }
})

.va_r3_gaussian_fixture <- function() {
  N <- 4L; T <- 3L; q <- 2L
  beta <- c(0.2, -0.15, 0.35)
  Lambda <- matrix(c(0.8, 0, -0.3, 0.55, 0.25, -0.4), T, q, byrow = TRUE)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  scores <- matrix(c(-0.5, 0.3, 0.2, -0.4, 0.7, 0.1, -0.2, -0.6), N, q, byrow = TRUE)
  y <- drop(X %*% beta) +
    rowSums(Lambda[trait, , drop = FALSE] * scores[unit, , drop = FALSE])
  list(N = N, T = T, q = q, beta = beta, Lambda = Lambda, unit = unit,
       trait = trait, X = X, y = y, sd = 0.7)
}

test_that("R3 Gaussian variational posterior equals the analytic posterior", {
  z <- .va_r3_gaussian_fixture()
  fit <- .va_r3_fit(
    y = z$y, n_trials = rep(1L, length(z$y)), X = z$X,
    unit_id = z$unit, trait_id = z$trait, q = z$q,
    family = "gaussian_anchor", gaussian_sd = z$sd, H = 15L,
    ## Analytic oracle assumes known residual SD (pre-Stage-2 DATA_SCALAR).
    estimate_gaussian_sd = FALSE,
    fixed_global = list(beta = z$beta,
                        theta_rr = .va_r3_pack_theta_rr(z$Lambda))
  )
  expect_identical(fit$status, "healthy")
  V <- solve(diag(z$q) + crossprod(z$Lambda) / z$sd^2)
  residual <- matrix(z$y - drop(z$X %*% z$beta), z$T, z$N)
  analytic_m <- t(vapply(seq_len(z$N), function(i) {
    drop(V %*% crossprod(z$Lambda, residual[, i]) / z$sd^2)
  }, numeric(z$q)))
  expect_equal(fit$report$m, analytic_m, tolerance = 2e-7)
  for (i in seq_len(z$N)) {
    Si <- matrix(fit$report$S_flat[i, ], z$q, z$q, byrow = TRUE)
    expect_equal(Si, V, tolerance = 2e-7)
  }
  expect_lt(max(abs(fit$objective$gr(fit$best$par))), 1e-6)
  C <- tcrossprod(z$Lambda) + diag(z$sd^2, z$T)
  log_det_C <- as.numeric(determinant(C, logarithm = TRUE)$modulus)
  analytic_nll <- sum(vapply(seq_len(z$N), function(i) {
    r <- residual[, i]
    0.5 * (z$T * log(2 * pi) + log_det_C + drop(crossprod(r, solve(C, r))))
  }, numeric(1)))
  expect_equal(fit$report$negative_elbo, analytic_nll, tolerance = 1e-8)
})

test_that("R3 Gaussian variational gradients match analytic matrix derivatives", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  z <- .va_r3_gaussian_fixture()
  validated <- .va_r3_validate_data(
    z$y, rep(1L, length(z$y)), z$X, z$unit, z$trait, z$q,
    family = "gaussian_anchor", link = "identity", gaussian_sd = z$sd,
    estimate_gaussian_sd = FALSE
  )
  parameters <- list(
    beta = z$beta, theta_rr = .va_r3_pack_theta_rr(z$Lambda),
    m = matrix(c(-0.1, 0.2, 0.3, -0.2, 0.05, 0.15, -0.25, 0.1), z$N, z$q),
    log_L_diag = matrix(c(-0.2, 0.1, 0.05, -0.1, 0.15, -0.05, 0.08, -0.12),
                        z$N, z$q),
    L_off = matrix(c(0.1, -0.05, 0.08, -0.12), z$N, 1L),
    log_sigma = rep(log(z$sd), z$T)
  )
  fixed <- list(beta = z$beta, theta_rr = .va_r3_pack_theta_rr(z$Lambda))
  obj <- .va_r3_make_objective(
    validated, H = 15L, parameters = parameters, fixed_global = fixed
  )
  observed <- obj$gr(obj$par)
  A <- diag(z$q) + crossprod(z$Lambda) / z$sd^2
  residual <- matrix(z$y - drop(z$X %*% z$beta), z$T, z$N)
  expected_m <- matrix(NA_real_, z$N, z$q)
  expected_rho <- matrix(NA_real_, z$N, z$q)
  expected_off <- matrix(NA_real_, z$N, 1L)
  L <- .va_r3_unpack_variational_chol(
    parameters$log_L_diag, parameters$L_off, z$N, z$q
  )
  for (i in seq_len(z$N)) {
    expected_m[i, ] <- A %*% parameters$m[i, ] -
      crossprod(z$Lambda, residual[, i]) / z$sd^2
    G <- A %*% L[, , i] - solve(t(L[, , i]))
    expected_rho[i, ] <- diag(G) * diag(L[, , i])
    expected_off[i, 1L] <- G[2L, 1L]
  }
  expect_equal(unname(observed[names(obj$par) == "m"]), as.vector(expected_m),
               tolerance = 1e-10)
  expect_equal(unname(observed[names(obj$par) == "log_L_diag"]),
               as.vector(expected_rho), tolerance = 1e-10)
  expect_equal(unname(observed[names(obj$par) == "L_off"]),
               as.vector(expected_off), tolerance = 1e-10)
})

.va_r3_complete_fixture <- function(q, seed) {
  set.seed(seed)
  N <- if (q == 1L) 24L else 30L
  T <- q + 1L
  trials <- 24L
  beta <- seq(-0.35, 0.35, length.out = T)
  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <-
    if (q == 1L) c(0.75, -0.45) else c(0.72, 0.28, -0.35, 0.58, 0.22)
  score <- matrix(rnorm(N * q), N, q)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  eta <- beta[trait] + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  y <- rbinom(N * T, trials, plogis(eta))
  data.frame(
    succ = y, fail = trials - y,
    trait = factor(sprintf("t%02d", trait)),
    unit = factor(sprintf("u%03d", unit))
  )
}

.va_r3_fit_complete_fixture <- function(q, seed) {
  dat <- .va_r3_complete_fixture(q, seed)
  suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(paste0(
      "cbind(succ, fail) ~ 0 + trait + ",
      "latent(0 + trait | unit, d = ", q, ", unique = FALSE)"
    )),
    data = dat, family = binomial(), unit = "unit",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 2L, init_jitter = 0.02, se = FALSE)
  ))
}

.va_r3_r2_comparison <- function(q, seed) {
  ml_fit <- .va_r3_fit_complete_fixture(q, seed)
  stopifnot(ml_fit$opt$convergence == 0L)
  d <- ml_fit$tmb_obj$env$data
  par <- ml_fit$tmb_obj$env$last.par.best
  beta <- unname(par[names(par) == "b_fix"])
  Lambda <- ml_fit$report$Lambda_B
  y <- d$y
  trials <- d$n_trials
  unit <- d$site_id + 1L
  trait <- d$trait_id + 1L
  X <- d$X_fix
  validated <- .va_r3_validate_data(y, trials, X, unit, trait, q)
  identity <- list(
    y = identical(validated$y, as.numeric(d$y)),
    trials = identical(validated$n_trials, as.integer(d$n_trials)),
    X = identical(validated$X, unname(d$X_fix)),
    unit = identical(validated$unit_id, as.integer(d$site_id)),
    trait = identical(validated$trait_id, as.integer(d$trait_id))
  )
  aghq_data <- list(
    y = y, n_trials = trials, eta_fixed = drop(X %*% beta),
    loading = Lambda[trait, , drop = FALSE], trait_id = trait - 1L,
    unit = unit, q = q
  )
  nodes <- if (q == 1L) 25L else 9L
  aghq <- .o3_r2_evaluate(aghq_data, nodes)
  fixed_global <- list(beta = beta, theta_rr = .va_r3_pack_theta_rr(Lambda))
  va61 <- .va_r3_fit(
    y, trials, X, unit, trait, q, H = 61L,
    fixed_global = fixed_global, rank_source = "fixed_fixture"
  )
  ladder <- lapply(c(15L, 25L), function(H) {
    obj <- .va_r3_make_objective(
      validated, H = H, parameters = .va_r3_default_parameters(validated, 1L),
      fixed_global = fixed_global
    )
    list(objective = obj$fn(va61$best$par), report = obj$report(va61$best$par))
  })
  aghq_mean <- matrix(NA_real_, nrow = max(unit), ncol = q)
  aghq_cov <- vector("list", max(unit))
  for (i in seq_len(max(unit))) {
    mm <- subset(aghq$moments, unit_id == i & moment == "mean")
    cc <- subset(aghq$moments, unit_id == i & moment == "covariance")
    aghq_mean[i, mm$row] <- mm$value
    aghq_cov[[i]] <- matrix(cc$value, q, q)
  }
  va_cov <- lapply(seq_len(max(unit)), function(i) {
    matrix(va61$report$S_flat[i, ], q, q, byrow = TRUE)
  })
  cov_rel <- vapply(seq_len(max(unit)), function(i) {
    sqrt(sum((va_cov[[i]] - aghq_cov[[i]])^2)) /
      sqrt(sum(aghq_cov[[i]]^2))
  }, numeric(1))
  list(
    va61 = va61, aghq = aghq, identity = identity,
    mean_rmse = sqrt(mean((va61$report$m - aghq_mean)^2)),
    cov_rel = cov_rel,
    bound_gap = aghq$objective + va61$report$elbo,
    quadrature_gap = abs(ladder[[2L]]$objective - va61$report$negative_elbo),
    quadrature_obs_gap = max(abs(ladder[[2L]]$report$expected_loglik_by_obs -
                                     va61$report$expected_loglik_by_obs))
  )
}

test_that("R3 fixed-coordinate q=1/q=2 cells pass the AGHQ admission gate", {
  comparisons <- list(
    q1 = .va_r3_r2_comparison(1L, 20260719L),
    q2 = .va_r3_r2_comparison(2L, 20260720L)
  )
  for (x in comparisons) {
    expect_true(all(unlist(x$identity)))
    expect_identical(x$va61$status, "healthy")
    expect_identical(x$va61$rank_source, "fixed_fixture")
    expect_identical(x$va61$health$attempted_starts, 4L)
    expect_gte(x$va61$health$healthy_starts, 3L)
    expect_true(isTRUE(x$va61$best$healthy))
    expect_lte(x$bound_gap, 1e-6)
    expect_lt(x$mean_rmse, 0.05)
    expect_lt(stats::median(x$cov_rel), 0.10)
    expect_lt(max(x$cov_rel), 0.25)
    expect_lt(x$quadrature_gap, 1e-4)
    expect_lt(x$quadrature_obs_gap, 1e-8)
  }
})

test_that("R3 reasserts the landed one-node O3/Laplace anchors", {
  q1 <- o3_gllvm_unit_hook_self_test()
  q2 <- o3_q2_gllvm_unit_self_test()
  expect_lt(abs(q1$laplace_difference), 1e-6)
  expect_lt(abs(q2$laplace_difference), 1e-6)
})

## ---------------------------------------------------------------------------
## Design 108 Gate A Stage 6 -- multiple unstructured tiers (Design 106 s1).
## ---------------------------------------------------------------------------

## Shared fixture builder for the tier tests. Returns the validated data, the
## layout, hand-built parameters, and the accessors the oracle needs to read a
## flat, tier-major variational block back out.
.va_r3_tier_fixture <- function() {
  N <- 4L; T <- 3L; q <- 2L; n_cluster <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  ## Units 1-2 in cluster 1, units 3-4 in cluster 2: a SECOND grouping factor,
  ## coarser than the unit. A tier that only ever reused unit_id would pass a
  ## psi-only test while being wrong for `cluster` -- hence this third tier.
  cluster <- rep(c(1L, 1L, 2L, 2L), each = T)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  set.seed(7)
  y <- as.numeric(stats::rbinom(N * T, 5L, 0.5))

  validated <- .va_r3_validate_data(
    y = y, n_trials = rep(5L, N * T), X = X, unit_id = unit,
    trait_id = trait, q = q, unique = TRUE,
    extra_tiers = list(list(kind = "dense", dim = 1L, level_id = cluster,
                            n_levels = n_cluster, label = "cluster"))
  )
  layout <- validated$tier_layout

  Lambda1 <- matrix(0, T, q)
  Lambda1[row(Lambda1) >= col(Lambda1)] <- c(0.7, -0.2, 0.3, 0.45, 0.5)
  Lambda3 <- matrix(c(0.6, -0.3, 0.2), T, 1L)
  set.seed(99)
  parameters <- list(
    beta = c(-0.2, 0.1, 0.3),
    theta_rr = c(.va_r3_pack_theta_rr(Lambda1), .va_r3_pack_theta_rr(Lambda3)),
    log_sd_tier = log(c(0.4, 0.25, 0.6)),
    m = round(stats::rnorm(layout$total_mean), 3),
    log_L_diag = round(stats::rnorm(layout$total_mean, 0, 0.2), 3),
    L_off = round(stats::rnorm(layout$total_off, 0, 0.3), 3)
  )
  ## (tier k, coordinate c, level g) -> position in a flat, tier-major vector.
  ## Written out longhand rather than reusing the package's offsets, so the
  ## oracle below is an independent statement of the layout, not a restatement.
  slot <- function(v, k, c, g, which = "m") {
    base <- if (identical(which, "off")) layout$off_offset[k] else layout$m_offset[k]
    v[base + c * layout$n_levels[k] + g + 1L]
  }
  chol_dense <- function(k, g) {
    d <- layout$dim[k]
    L <- matrix(0, d, d)
    for (cc in seq_len(d)) {
      L[cc, cc] <- exp(slot(parameters$log_L_diag, k, cc - 1L, g))
    }
    pos <- 0L
    for (col in seq_len(d)) {
      for (row in seq.int(col + 1L, length.out = d - col)) {
        L[row, col] <- slot(parameters$L_off, k, pos, g, which = "off")
        pos <- pos + 1L
      }
    }
    L
  }
  list(N = N, T = T, q = q, n_cluster = n_cluster, X = X,
       validated = validated, layout = layout, parameters = parameters,
       Lambda1 = Lambda1, Lambda3 = Lambda3,
       slot = slot, chol_dense = chol_dense)
}

test_that("R3 multi-tier mu, v and KL match direct matrix algebra", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## The Stage 6 analogue of the single-tier q>1 oracle above, and the
  ## load-bearing test of this stage. Design 106 Proposition 1 says mu and v
  ## ACCUMULATE across tiers and the KL decomposes into a sum over tiers and
  ## levels. This builds all three by hand, from the stacked model, and asks
  ## the template to agree -- across THREE tiers of two different kinds at two
  ## different grouping factors.
  fx <- .va_r3_tier_fixture()
  obj <- .va_r3_make_objective(fx$validated, H = 15L,
                               parameters = fx$parameters, eval_method = "gh")
  report <- obj$report(obj$par)

  lay <- fx$layout
  pars <- fx$parameters
  uid <- fx$validated$unit_id
  tid <- fx$validated$trait_id
  expected_mu <- numeric(fx$N * fx$T)
  expected_v <- numeric(fx$N * fx$T)
  for (r in seq_len(fx$N * fx$T)) {
    i <- uid[r]
    t <- tid[r]
    g_cluster <- lay$level_id[r, 3L]
    mu <- drop(fx$X[r, ] %*% pars$beta)
    v <- 0

    ## Tier 1, dense: a = Lambda1[trait, ], full q x q Cholesky.
    a1 <- fx$Lambda1[t + 1L, ]
    m1 <- vapply(seq_len(fx$q), function(c) fx$slot(pars$m, 1L, c - 1L, i),
                 numeric(1))
    L1 <- fx$chol_dense(1L, i)
    mu <- mu + sum(a1 * m1)
    v <- v + sum((t(L1) %*% a1)^2)

    ## Tier 2, trait-diagonal Psi: a = sd_t * e_t, so ONE coordinate.
    sd_t <- exp(pars$log_sd_tier[t + 1L])
    mu <- mu + sd_t * fx$slot(pars$m, 2L, t, i)
    v <- v + (sd_t * exp(fx$slot(pars$log_L_diag, 2L, t, i)))^2

    ## Tier 3, dense d = 1 at the COARSER cluster grouping.
    a3 <- fx$Lambda3[t + 1L, ]
    L3 <- fx$chol_dense(3L, g_cluster)
    mu <- mu + sum(a3 * fx$slot(pars$m, 3L, 0L, g_cluster))
    v <- v + sum((t(L3) %*% a3)^2)

    expected_mu[r] <- mu
    expected_v[r] <- v
  }

  kl_dense <- function(k, n_levels) {
    vapply(seq_len(n_levels) - 1L, function(g) {
      L <- fx$chol_dense(k, g)
      S <- tcrossprod(L)
      mm <- vapply(seq_len(lay$dim[k]),
                   function(c) fx$slot(pars$m, k, c - 1L, g), numeric(1))
      0.5 * (sum(diag(S)) + sum(mm^2) -
               as.numeric(determinant(S, logarithm = TRUE)$modulus) - lay$dim[k])
    }, numeric(1))
  }
  kl_diagonal <- function(k, n_levels) {
    vapply(seq_len(n_levels) - 1L, function(g) {
      s <- exp(vapply(seq_len(fx$T) - 1L,
                      function(j) fx$slot(pars$log_L_diag, k, j, g), numeric(1)))
      mm <- vapply(seq_len(fx$T) - 1L,
                   function(j) fx$slot(pars$m, k, j, g), numeric(1))
      0.5 * sum(s^2 + mm^2 - 2 * log(s) - 1)
    }, numeric(1))
  }
  expected_kl <- c(kl_dense(1L, fx$N), kl_diagonal(2L, fx$N),
                   kl_dense(3L, fx$n_cluster))

  expect_equal(report$mu_by_obs, expected_mu, tolerance = 1e-12)
  expect_equal(report$v_by_obs, expected_v, tolerance = 1e-12)
  expect_equal(report$kl_by_level, expected_kl, tolerance = 1e-12)
  expect_equal(report$total_kl, sum(expected_kl), tolerance = 1e-12)
  ## Per-tier totals, and the back-compatible kl_by_unit, which keeps its
  ## pre-Stage-6 meaning: tier 1's per-level KL, NOT the unit's whole KL.
  expect_equal(as.numeric(report$kl_by_tier),
               c(sum(expected_kl[seq_len(fx$N)]),
                 sum(expected_kl[fx$N + seq_len(fx$N)]),
                 sum(expected_kl[2L * fx$N + seq_len(fx$n_cluster)])),
               tolerance = 1e-12)
  expect_equal(report$kl_by_unit, expected_kl[seq_len(fx$N)], tolerance = 1e-12)

  ## Autodiff over the whole ragged block, not just the value.
  analytic <- as.numeric(obj$gr(obj$par))
  numeric_gr <- vapply(seq_along(obj$par), function(j) {
    h <- 1e-6 * max(1, abs(obj$par[j]))
    plus <- minus <- obj$par
    plus[j] <- plus[j] + h
    minus[j] <- minus[j] - h
    (obj$fn(plus) - obj$fn(minus)) / (2 * h)
  }, numeric(1))
  expect_lt(max(abs(analytic - numeric_gr) / pmax(1, abs(numeric_gr))), 1e-5)
})

test_that("R3 trait-diagonal tiers realise Proposition 2's 2T saving structurally", {
  ## Design 106 Prop. 2: for a per-trait tier, the block-diagonal q is EXACTLY
  ## optimal (Fischer's inequality), so the saving is free. Running such a tier
  ## through the dense code path at d = T would still converge to the same
  ## answer -- which is precisely why it has to be checked STRUCTURALLY. The
  ## claim is that the parameters are never allocated, not that they end small.
  for (T in c(3L, 6L, 26L)) {
    N <- 5L
    layout <- .va_r3_tier_layout(
      .va_r3_build_tiers(rep(seq_len(N) - 1L, each = T), N = N, T = T, q = 2L,
                         n_obs = N * T, want_psi = TRUE),
      T = T, N = N, q = 2L, n_obs = N * T
    )
    expect_identical(layout$kind, c("dense", "diagonal"))
    ## 2T per level, not T + T(T+1)/2. At T = 26 that is 52 against 377.
    expect_identical(layout$variational_per_level[2L], 2L * T)
    expect_gt((T + T * (T + 1L) / 2L) / layout$variational_per_level[2L], 1)
    ## The mechanism: a diagonal tier allocates NO off-diagonal Cholesky
    ## entries at all, so total_off is the dense tier's alone.
    expect_identical(layout$off_per_level[2L], 0L)
    expect_identical(layout$total_off, as.integer(N * 2L * (2L - 1L) / 2L))
  }

  ## And the measured ratio at Ayumi's T, which is the number Design 106 s4.2
  ## quotes: 377 / 52 = 7.25x, free rather than approximate.
  expect_equal((26 + 26 * 27 / 2) / (2 * 26), 7.25, tolerance = 1e-12)

  ## The same claim, read off a CONSTRUCTED objective rather than the layout,
  ## so a template that quietly demanded dense storage would fail here too.
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  N <- 4L; T <- 6L; q <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  set.seed(51)
  y <- as.numeric(stats::rbinom(N * T, 4L, 0.5))
  validated <- .va_r3_validate_data(
    y = y, n_trials = rep(4L, N * T), X = X, unit_id = unit,
    trait_id = trait, q = q, unique = TRUE
  )
  obj <- .va_r3_make_objective(validated, H = 15L, eval_method = "gh")
  nm <- names(obj$par)
  ## m and log_L_diag carry N*q (tier 1) + N*T (tier 2); L_off carries the
  ## dense tier's N*q(q-1)/2 and NOTHING for the diagonal tier.
  expect_identical(sum(nm == "m"), as.integer(N * q + N * T))
  expect_identical(sum(nm == "log_L_diag"), as.integer(N * q + N * T))
  expect_identical(sum(nm == "L_off"), as.integer(N * q * (q - 1L) / 2L))
  expect_identical(sum(nm == "log_sd_tier"), T)
  ## Total variational cost = N*(2q + q(q-1)/2) + N*2T, i.e. the Prop. 2 count.
  expect_identical(
    sum(nm %in% c("m", "log_L_diag", "L_off")),
    as.integer(N * (2L * q + q * (q - 1L) / 2L) + N * 2L * T)
  )
})

test_that("R3 K=1 stays byte-identical to the pre-Stage-6 single-tier path", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## Stage 6 turned three PARAMETER_MATRIXes into flat PARAMETER_VECTORs. The
  ## flat layout is column-major within a tier, which IS as.vector() of the old
  ## matrix, so the K = 1 parameter vector must be unchanged element for
  ## element -- names, order and values. The pinned objective below was
  ## recorded from the pre-Stage-6 template on this exact fixture.
  set.seed(11)
  N <- 5L; T <- 4L; q <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  y <- as.numeric(stats::rbinom(N * T, 4L, 0.4))
  validated <- .va_r3_validate_data(
    y = y, n_trials = rep(4L, N * T), X = X, unit_id = unit,
    trait_id = trait, q = q
  )
  expect_identical(validated$tier_layout$n_tiers, 1L)

  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <-
    c(0.7, -0.2, 0.3, 0.45, 0.5, -0.4, 0.25)[seq_len(.va_r3_theta_length(T, q))]
  matrix_pars <- list(
    beta = c(-0.2, 0.1, 0.3, -0.05),
    theta_rr = .va_r3_pack_theta_rr(Lambda),
    m = matrix(seq(-0.4, 0.4, length.out = N * q), N, q),
    log_L_diag = matrix(log(seq(0.7, 1.2, length.out = N * q)), N, q),
    L_off = matrix(seq(-0.2, 0.2, length.out = N), N, 1L)
  )
  ## Hand-built parameter lists written against the pre-Stage-6 MATRIX
  ## signature must still work, and must give the same objective as the flat
  ## vectors they are equivalent to.
  flat_pars <- matrix_pars
  flat_pars$m <- as.numeric(matrix_pars$m)
  flat_pars$log_L_diag <- as.numeric(matrix_pars$log_L_diag)
  flat_pars$L_off <- as.numeric(matrix_pars$L_off)

  obj_matrix <- .va_r3_make_objective(validated, H = 15L,
                                      parameters = matrix_pars,
                                      eval_method = "gh")
  obj_flat <- .va_r3_make_objective(validated, H = 15L, parameters = flat_pars,
                                    eval_method = "gh")
  expect_identical(names(obj_matrix$par), names(obj_flat$par))
  expect_identical(unname(obj_matrix$par), unname(obj_flat$par))
  expect_identical(obj_matrix$fn(obj_matrix$par), obj_flat$fn(obj_flat$par))
  expect_identical(as.numeric(obj_matrix$gr(obj_matrix$par)),
                   as.numeric(obj_flat$gr(obj_flat$par)))

  ## The pre-Stage-6 parameter-name contract, unchanged.
  expect_identical(unique(names(obj_matrix$par)),
                   c("beta", "theta_rr", "m", "log_L_diag", "L_off"))
  expect_identical(sum(names(obj_matrix$par) == "m"), as.integer(N * q))
  expect_identical(sum(names(obj_matrix$par) == "log_L_diag"), as.integer(N * q))
  expect_identical(sum(names(obj_matrix$par) == "L_off"), as.integer(N))
  ## No diagonal tier, so log_sd_tier contributes nothing at all.
  expect_identical(sum(names(obj_matrix$par) == "log_sd_tier"), 0L)

  ## Value recorded from the pre-Stage-6 template on this fixture. The
  ## tolerance is 1e-10 rather than 0 only because the H = 15 nodes come from
  ## eigen(); everything else in the path is exact arithmetic.
  expect_equal(obj_matrix$fn(obj_matrix$par), 36.49217556751487,
               tolerance = 1e-10)

  ## Reported quantities keep their single-tier meaning exactly.
  report <- obj_matrix$report(obj_matrix$par)
  expect_identical(report$n_tiers, 1L)
  expect_equal(report$kl_by_unit, as.numeric(report$kl_by_level),
               tolerance = 0)
  expect_equal(report$total_kl, sum(report$kl_by_unit), tolerance = 1e-14)
  expect_true(is.matrix(report$Sigma_B))
  expect_identical(dim(report$Sigma_B), c(T, T))
})

test_that("R3 tier registry agrees with the layout the engine actually builds", {
  ## The data-driven analogue of the family-registry guard above. The registry
  ## is the DECLARED per-kind cost contract; the layout is what the engine
  ## allocates. Adding a tier kind without wiring its costs -- or changing one
  ## side's arithmetic -- fails here rather than silently.
  N <- 5L; T <- 4L; q <- 2L
  unit0 <- rep(seq_len(N) - 1L, each = T)
  for (entry in .va_r3_tier_registry) {
    expect_true(entry$kind_code %in% c(0L, 1L))
    expect_identical(.va_r3_tier_entry(entry$kind)$kind_code, entry$kind_code)

    d <- if (identical(entry$kind, "diagonal")) T else q
    ## variational_per_level must be exactly means + log-diagonals + off.
    expect_identical(entry$variational_per_level(d, T),
                     as.integer(2L * d + entry$off_per_level(d, T)))
    ## Prop. 2 holds for exactly the kinds that declare it.
    expect_identical(entry$block_diagonal_exact,
                     identical(entry$off_per_level(d, T), 0L))

    tiers <- .va_r3_build_tiers(unit0, N = N, T = T, q = q, n_obs = N * T,
                                extra_tiers = list(list(
                                  kind = entry$kind, dim = d,
                                  level_id = unit0, n_levels = N)))
    layout <- .va_r3_tier_layout(tiers, T = T, N = N, q = q, n_obs = N * T)
    expect_identical(layout$kind_code[2L], entry$kind_code)
    expect_identical(layout$variational_per_level[2L],
                     entry$variational_per_level(d, T))
    expect_identical(layout$off_per_level[2L], entry$off_per_level(d, T))
    expect_identical(layout$loading_length[2L], entry$loading_length(d, T))
    ## Offsets must tile the flat vectors exactly -- no gap, no overlap.
    expect_identical(layout$total_mean, as.integer(sum(layout$n_levels * layout$dim)))
    expect_identical(layout$total_off,
                     as.integer(sum(layout$n_levels * layout$off_per_level)))
    expect_identical(layout$m_offset, c(0L, as.integer(N * q)))
  }
  ## An unregistered kind is an error, not a silent default.
  expect_error(.va_r3_tier_entry("mean_field"), "no tier-registry entry")
})

test_that("R3 refuses tier specifications it cannot honour", {
  N <- 4L; T <- 3L; q <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  base <- list(y = as.numeric(rep(1L, N * T)), n_trials = rep(4L, N * T),
               X = X, unit_id = unit, trait_id = trait, q = q)
  bad <- function(spec) {
    do.call(.va_r3_validate_data, c(base, list(extra_tiers = list(spec))))
  }
  ## A trait-diagonal tier has one field per trait by definition.
  expect_error(bad(list(kind = "diagonal", dim = 2L, level_id = unit)),
               "dim must be T")
  expect_error(bad(list(kind = "dense", dim = T + 1L, level_id = unit)),
               "1 <= dim <= T")
  expect_error(bad(list(kind = "dense", dim = 1L, level_id = unit[-1L])),
               "one entry per response row")
  ## A declared level nothing loads on would carry a free variational block.
  expect_error(bad(list(kind = "dense", dim = 1L, level_id = unit,
                        n_levels = N + 1L)),
               "must be used by at least one row")
  expect_error(bad(list(level_id = unit)), "`kind` and `level_id`")
  ## Non-logical unique/psi are a mistake, not a truthy request.
  expect_error(do.call(.va_r3_validate_data, c(base, list(unique = "yes"))),
               "must be TRUE or FALSE")
})

test_that("R3 multi-tier fixed-information fails closed rather than guessing", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## H_vv is block diagonal by UNIT only while a unit's observations touch one
  ## tier. Nothing in the parameter names distinguishes a Psi companion (still
  ## per-unit) from a `cluster` tier (not). A Schur complement built on the
  ## wrong partition would be a number, not an error, so the multi-tier case
  ## must refuse. Design 108 Stage 14 owns this surface.
  fx <- .va_r3_tier_fixture()
  obj <- .va_r3_make_objective(fx$validated, H = 15L,
                               parameters = fx$parameters, eval_method = "gh")
  for (route in c("auto", "blocked", "dense")) {
    info <- .va_r3_fixed_information(obj, obj$par, route = route)
    expect_identical(info$status, "va_multi_tier_fixed_information_unsupported")
    expect_null(info$se_profile)
    expect_null(info$se_conditional)
    expect_false(info$pd_hessian)
    expect_false(info$calibrated)
  }
  expect_identical(
    .va_r3_fixed_information_blocked(obj, obj$par, N = fx$N, q = fx$q)$status,
    "va_multi_tier_fixed_information_unsupported"
  )
})

test_that("Stage 6 does NOT open the public variational route to Psi", {
  ## The research engine now admits a Psi tier. The PUBLIC route must not, and
  ## this arc changed nothing in R/integration-fence.R. The reason is evidence,
  ## not capability: no VA recovery study exists for a multi-tier or diag(psi)
  ## model, and the fence is where that gate lives.
  expect_error(
    .gllvmTMB_check_integration_fence("va", family = "poisson", link = "log",
                                      q = 2L, p = 4L, n = 100L, unique = TRUE),
    "Psi"
  )
  ## Same model without Psi still passes the fence, so the refusal above is
  ## about Psi specifically and not about the fixture.
  expect_invisible(
    .gllvmTMB_check_integration_fence("va", family = "poisson", link = "log",
                                      q = 2L, p = 4L, n = 100L, unique = FALSE)
  )
})

test_that("R3 refuses fixed_global on a multi-tier model rather than half-fixing it", {
  ## fixed_global names beta and theta_rr only. With a second tier there are
  ## global parameters it does not name -- the extra loadings and log_sd_tier --
  ## so honouring it would fix some and leave the rest free: a different model
  ## than the caller asked for, fitted successfully and reported as theirs.
  N <- 4L; T <- 3L; q <- 1L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  set.seed(31)
  y <- as.numeric(stats::rbinom(N * T, 4L, 0.5))
  fg <- list(beta = rep(0, T), theta_rr = rep(0.5, T))
  expect_error(
    .va_r3_fit(y, rep(4L, N * T), X, unit, trait, q = q, unique = TRUE,
               n_starts = 1L, fixed_global = fg),
    "single-tier model only"
  )
  ## The same call without the extra tier is still accepted, so the refusal is
  ## about the tier count and not about the fixture.
  validated <- .va_r3_validate_data(
    y = y, n_trials = rep(4L, N * T), X = X, unit_id = unit,
    trait_id = trait, q = q
  )
  expect_no_error(
    .va_r3_make_objective(validated, H = 15L, fixed_global = fg,
                          eval_method = "gh")
  )
})

test_that("R3 template refuses an inconsistent tier declaration loudly", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## The R adapter computes the tier offsets, so these guards can only be
  ## tripped by a caller building on the template directly -- which
  ## test-va-probit-adsafety.R does, deliberately. The template therefore
  ## RECOMPUTES the offsets from (tier_kind, tier_dim, tier_n_levels) instead
  ## of trusting R's, so an R/C++ disagreement fails a length check rather than
  ## reading across a tier boundary and returning a plausible wrong number.
  dll <- .va_r3_load_dll()
  rule <- .va_r3_gh_rule(15L)
  probe <- function(mutate) {
    base <- list(
      dat = list(y = 1, n_trials = 4, X = matrix(1, 1L, 1L), unit_id = 0L,
                 trait_id = 0L, is_y_observed = 1L, N = 1L, T = 1L, q = 1L,
                 gh_nodes = rule$nodes, gh_weights = rule$weights,
                 family = 1L, eval_method = 0L,
                 ## ac2_threshold (Design 108 Gate A Stage 5) is read
                 ## unconditionally regardless of eval_method; this probe
                 ## builds `dat` directly rather than through
                 ## .va_r3_make_objective(), so it must supply the field
                 ## itself. eval_method = 0L (gh) never reads it.
                 ac2_threshold = 1.0,
                 n_tiers = 1L, tier_kind = 0L,
                 tier_dim = 1L, tier_n_levels = 1L,
                 level_id = matrix(0L, 1L, 1L),
                 ## Stage 7's structured-prior DATA. The base probe declares
                 ## the tier UNSTRUCTURED, so the precision slots are the
                 ## placeholders the template never reads.
                 tier_structured = 0L,
                 Ainv_struct = Matrix::sparseMatrix(i = integer(0),
                                                    j = integer(0),
                                                    x = numeric(0),
                                                    dims = c(1L, 1L)),
                 diag_Ainv_struct = 0, log_det_A_struct = 0),
      par = list(beta = 0, theta_rr = 1, log_sd_tier = numeric(0), m = 0,
                 log_L_diag = 0, L_off = numeric(0), log_phi = 0,
                 log_sigma = 0)
    )
    z <- mutate(base)
    tryCatch({
      TMB::MakeADFun(z$dat, z$par, DLL = dll$DLL, silent = TRUE)
      NA_character_
    }, error = function(e) conditionMessage(e))
  }
  ## The unmutated probe must build, or the negatives below prove nothing.
  expect_true(is.na(probe(identity)))

  expect_match(probe(function(z) { z$dat$tier_kind <- 1L; z }),
               "tier 0 must be the dense ordinary latent tier")
  expect_match(probe(function(z) { z$dat$tier_dim <- 2L; z }),
               "tier 0 must be the dense ordinary latent tier")
  expect_match(probe(function(z) {
    z$dat$n_tiers <- 2L
    z$dat$tier_kind <- c(0L, 1L)
    z$dat$tier_dim <- c(1L, 3L)          # T is 1, so 3 is not a trait-diagonal
    z$dat$tier_n_levels <- c(1L, 1L)
    z$dat$tier_structured <- c(0L, 0L)
    z$dat$level_id <- matrix(0L, 1L, 2L)
    z$par$log_sd_tier <- 0
    z$par$m <- rep(0, 4L)
    z$par$log_L_diag <- rep(0, 4L)
    z
  }), "trait-diagonal tier must have tier_dim = T")
  ## Stage 7's own guards, probed the same way. Each is a declaration the R
  ## adapter cannot produce, so the template has to catch it itself.
  expect_match(probe(function(z) { z$dat$tier_structured <- c(0L, 0L); z }),
               "tier_structured must have length n_tiers")
  expect_match(probe(function(z) { z$dat$tier_structured <- 1L; z }),
               "tier 0 is the ordinary latent tier and must be unstructured")
  expect_match(probe(function(z) {
    ## Two tiers, the second structured against a 3x3 precision while
    ## declaring 1 level: the level set and the matrix disagree.
    z$dat$n_tiers <- 2L
    z$dat$tier_kind <- c(0L, 0L)
    z$dat$tier_dim <- c(1L, 1L)
    z$dat$tier_n_levels <- c(1L, 1L)
    z$dat$tier_structured <- c(0L, 1L)
    z$dat$level_id <- matrix(0L, 1L, 2L)
    z$dat$Ainv_struct <- Matrix::sparseMatrix(i = 1:3, j = 1:3, x = rep(1, 3),
                                              dims = c(3L, 3L))
    z$dat$diag_Ainv_struct <- rep(1, 3)
    z$par$m <- rep(0, 2L)
    z$par$log_L_diag <- rep(0, 2L)
    z$par$theta_rr <- c(1, 1)
    z
  }), "one level per row of Ainv_struct")
  expect_match(probe(function(z) {
    z$dat$n_tiers <- 2L
    z$dat$tier_kind <- c(0L, 0L)
    z$dat$tier_dim <- c(1L, 1L)
    z$dat$tier_n_levels <- c(1L, 1L)
    z$dat$tier_structured <- c(0L, 1L)
    z$dat$level_id <- matrix(0L, 1L, 2L)
    ## A COVARIANCE where a precision belongs would still be square and
    ## symmetric; a non-positive diagonal is the cheap, always-available tell.
    z$dat$Ainv_struct <- Matrix::sparseMatrix(i = 1L, j = 1L, x = -1,
                                              dims = c(1L, 1L))
    z$dat$diag_Ainv_struct <- -1
    z$par$m <- rep(0, 2L)
    z$par$log_L_diag <- rep(0, 2L)
    z$par$theta_rr <- c(1, 1)
    z
  }), "finite and strictly positive")
  expect_match(probe(function(z) { z$dat$level_id <- matrix(3L, 1L, 1L); z }),
               "level_id is out of range")
  expect_match(probe(function(z) { z$dat$level_id <- matrix(0L, 1L, 2L); z }),
               "level_id must be n_obs x n_tiers")
  expect_match(probe(function(z) { z$par$m <- c(0, 0); z }),
               "variational parameter dimensions do not agree")
  expect_match(probe(function(z) { z$par$log_sd_tier <- 0; z }),
               "log_sd_tier must supply T entries per trait-diagonal tier")
})

test_that("R3 multi-tier path NESTS the single-tier path exactly", {
  # VA/EVA development is paused; these are prototype gates. Do not make
  # CRAN build a parked prototype's DLL. They still run under devtools::test().
  skip_on_cran()
  ## The strongest available statement that the K > 1 code path did not perturb
  ## the K = 1 one: a Psi tier whose loading sd -> 0 and whose variational
  ## block sits AT THE PRIOR (m = 0, S = I) contributes exactly zero to mu, to
  ## v and to the KL. The two-tier objective must therefore collapse onto the
  ## one-tier objective at the same tier-1 coordinates -- and it does so to
  ## exact zero, not to a tolerance, because every added term is an exact zero
  ## rather than a small number.
  set.seed(17)
  N <- 6L; T <- 4L; q <- 2L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  y <- as.numeric(stats::rbinom(N * T, 4L, 0.45))
  validate <- function(psi) {
    .va_r3_validate_data(y = y, n_trials = rep(4L, N * T), X = X,
                         unit_id = unit, trait_id = trait, q = q, unique = psi)
  }
  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <-
    c(0.7, -0.2, 0.3, 0.45, 0.5, -0.4, 0.25)[seq_len(.va_r3_theta_length(T, q))]
  base <- list(
    beta = c(-0.2, 0.1, 0.3, -0.05),
    theta_rr = .va_r3_pack_theta_rr(Lambda),
    m = as.numeric(matrix(seq(-0.4, 0.4, length.out = N * q), N, q)),
    log_L_diag = as.numeric(matrix(log(seq(0.7, 1.2, length.out = N * q)),
                                   N, q)),
    L_off = seq(-0.2, 0.2, length.out = N)
  )
  two_tier <- base
  two_tier$m <- c(base$m, rep(0, N * T))
  two_tier$log_L_diag <- c(base$log_L_diag, rep(0, N * T))
  two_tier$log_sd_tier <- rep(log(1e-12), T)

  one <- .va_r3_make_objective(validate(FALSE), H = 15L, parameters = base,
                               eval_method = "gh")
  two <- .va_r3_make_objective(validate(TRUE), H = 15L, parameters = two_tier,
                               eval_method = "gh")
  r1 <- one$report(one$par)
  r2 <- two$report(two$par)

  expect_identical(one$fn(one$par), two$fn(two$par))
  expect_identical(as.numeric(r1$mu_by_obs), as.numeric(r2$mu_by_obs))
  expect_identical(as.numeric(r1$v_by_obs), as.numeric(r2$v_by_obs))
  expect_identical(r1$total_kl, r2$total_kl)
  ## The added tier is genuinely inert here -- not merely small.
  expect_identical(as.numeric(r2$kl_by_tier[2L]), 0)
  ## ... and it really was a second tier, so the equality above is a nesting
  ## result and not a silently-dropped tier.
  expect_identical(r2$n_tiers, 2L)
  expect_identical(sum(names(two$par) == "log_sd_tier"), T)
})

## ---- The health gate's gradient bar is CALIBRATED, not assumed -------------
##
## Until 2026-08-03 the bar was a bare `1e-4` literal repeated in four places.
## It was ~130-200x too tight: the Step-0 coverage pilot got 0/30 healthy fits at
## BOTH primary cells (n=150, n=400) while all four starts agreed to 6+
## significant figures. `dev/va-speed/45-gradient-vs-objective-gap.R` measured the
## admissible/must-reject boundary directly by walking away from a converged
## optimum and recording max|gradient| against the objective gap.
##
## These tests pin the two properties the calibration rests on, so the constant
## cannot drift back without a failure. They are deliberately fit-free: the
## measurement lives in the dev-log, the INVARIANTS live here.

test_that("the health gradient bar sits inside its measured window", {
  bar <- gllvmTMB:::.VA_R3_HEALTH_GRADIENT_TOL

  ## Upper guard: the smallest max|gradient| ever observed with an objective gap
  ## >= the gate's own agreement_tolerance was 1.34e-02 (at n_obs = 3200). The bar
  ## must stay clear of it, or the gate starts admitting genuinely-wrong starts.
  expect_lt(bar, 1.34e-2)

  ## Lower guard: the largest max|gradient| observed on a genuinely CONVERGED
  ## start was 4.97e-03 (n=50, seed 20260803). A bar at or below that rejects
  ## converged fits -- the defect this replaced. A tighter 1e-3 was tried and
  ## took that cell from 4/4 healthy to 0/4.
  expect_gt(bar, 4.97e-3)
})

test_that("the polish target stays stricter than the health bar", {
  ## They are different jobs: the polish target is how hard to push, the health
  ## bar is the verdict. Polishing past the bar is cheap and yields better fits,
  ## so relaxing the effort knob to match the verdict would silently degrade
  ## every fit. Ordering is the invariant, not either value.
  expect_lt(
    gllvmTMB:::.VA_R3_POLISH_GRADIENT_TARGET,
    gllvmTMB:::.VA_R3_HEALTH_GRADIENT_TOL
  )
})

test_that("the reported gradient_tolerance is the one actually applied", {
  ## The reported value and the applied value were separate literals; they could
  ## drift apart with nothing to catch it. They are now one constant, and this
  ## asserts the report reflects it.
  set.seed(4242L)
  N0 <- 40L; T0 <- 4L; Q0 <- 1L
  lam <- matrix(stats::rnorm(T0 * Q0, 0, 0.8), T0, Q0)
  a <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
  eta <- a %*% t(lam)
  y <- stats::rbinom(N0 * T0, 1L, stats::plogis(as.vector(eta)))
  d <- data.frame(
    y = y,
    unit = rep(seq_len(N0), times = T0),
    trait = rep(seq_len(T0), each = N0)
  )
  X <- unname(stats::model.matrix(~ 0 + factor(trait), data = d))
  fit <- gllvmTMB:::.va_r3_fit(
    y = d$y, n_trials = rep(1L, nrow(d)), X = X,
    unit_id = d$unit, trait_id = d$trait, q = Q0,
    family = "binomial", link = "logit", H = 15L, n_starts = 4L
  )
  expect_identical(
    fit$health$gradient_tolerance,
    gllvmTMB:::.VA_R3_HEALTH_GRADIENT_TOL
  )
})
