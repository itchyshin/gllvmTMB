## dev/aghq-families/family_spec.R -- the 16-family evidence harness, Slice D.
##
## OWNERSHIP: this directory (dev/aghq-families/) is owned EXCLUSIVELY by
## Slice D. Do not edit src/gllvmTMB.cpp, R/fit-multi.R, R/aghq-report.R, or
## tests/testthat/test-aghq-surface.R from here.
##
## WHY THIS FILE EXISTS: the AGHQ quadrature kernel is family-agnostic BY
## CONSTRUCTION -- it reuses the single per-observation `obs_loglik` lambda
## verbatim (src/gllvmTMB.cpp:1994, call site :2592/:2595) -- so per-family
## correctness is an EVIDENCE question (does quadrature recover the true
## covariance better/worse/same as Laplace for THIS family's likelihood
## shape?), not a coding one. No per-family engine code exists or is written
## here; this file only builds simulate-and-fit cells.
##
## THE 16-FAMILY LIST, established from the SOURCE (not from memory):
##   1. R/enum.R (`.valid_family`, lines 5-23) lists family_id 0..16 (17
##      entries, including multinomial = 16).
##   2. `family_to_id()` in R/fit-multi.R (the `switch(f$family, ...)` at
##      line ~412) agrees byte-for-byte with R/enum.R's 17 ids.
##   3. src/gllvmTMB.cpp's `obs_loglik` lambda (line 1994) dispatches fid
##      0..15 as ordinary per-row log-densities. fid == 16 (multinomial)
##      explicitly `error()`s inside obs_loglik ("evaluated as a grouped
##      softmax at its anchor row, not per-row via obs_loglik" -- see
##      src/gllvmTMB.cpp around line 2310) and is never called through that
##      lambda at the AGHQ call site (src/gllvmTMB.cpp:2592). multinomial is
##      ALSO explicitly documented (R/families.R, `multinomial()` roxygen)
##      as fixed-effects only: no latent()/unique()/indep()/random-slope
##      support, so it could never satisfy the "z_B is the sole random
##      block" AGHQ eligibility gate (R/fit-multi.R's aghq_info$reason chain)
##      regardless of the obs_loglik dispatch.
##   => 16 families are AGHQ-eligible in principle: fid 0..15 inclusive.
##      Confirmed by literally reading the obs_loglik if/else chain
##      (src/gllvmTMB.cpp:2102-2312) and counting the branches: 16 (fid 0
##      through 15), plus the terminal fid==16 error branch and the
##      fid==unknown error() -- neither of which is a working family.
##
## EXCLUDED BY DESIGN (not part of the 16, and not put in this harness):
##   - multinomial (fid 16): see above.
##   - Every family R/families.R documents (around its `@details` block,
##     line ~146) as "exported for API continuity, but not admitted by the
##     current multivariate gllvmTMB() engine": gengamma(), the `_mix()`
##     one-part families, truncated_nbinom1(), censored_poisson(), and every
##     delta constructor other than delta_lognormal()/delta_gamma() (i.e.
##     delta_gengamma, delta_beta, delta_*_mix, delta_truncated_nbinom1/2,
##     delta_poisson_link_*). None of these has a family_to_id() switch
##     branch in R/fit-multi.R either -- fitting them errors before AGHQ
##     eligibility is even evaluated.
##
## THE SHARED DGP: every family in this harness fits the SAME model shape --
## the single-block, loadings-only latent factor (the "z_B" tier), because
## that is the ONLY shape the current AGHQ gate admits (R/fit-multi.R:
## "Stage 1a requires z_B as the only random block"; use_lv_B, mi(), and
## multinomial rows are all refused with a reason string). The long-format
## grammar and `latent(0 + trait | unit, d = q, unique = FALSE)` formula
## below is verified against tests/testthat/helper-aghq-golden.R (the E3
## golden-test harness) and tests/testthat/test-betabinomial-recovery.R /
## test-beta-recovery.R / test-matrix-ordinal-unit.R (established long-format
## per-family recovery tests already in the suite) -- not invented here.
##
##   eta[unit, trait] = b_true[trait] + Lambda_true[trait, ] %*% U[unit, ]
##
## Lambda_true (p x q) ~ N(0, lambda_sd^2), b_true (p) ~ N(b_mean, b_sd^2),
## U (n x q) ~ N(0, 1) (the LV has unit variance; Sigma_true = Lambda Lambda').
## Data are long format: one row per (unit, trait[, rep]) triple, matching
## the `individual = factor(rep(seq_len(n_ind), each = Tn))` layout used
## throughout tests/testthat/test-*-recovery.R.
##
## n_rep > 1 (ordinal_probit only) draws multiple independent replicate rows
## per (unit, trait) sharing the SAME eta, mirroring
## tests/testthat/test-matrix-ordinal-unit.R's N_REP = 4 -- ordinal responses
## carry much less information per row than a continuous response, and single-
## draw ordinal cells at n = 60 units do not identify the loadings cleanly
## (that file's own design note). This is a power choice, not a structural
## requirement; every other family here uses n_rep = 1.

## ---------------------------------------------------------------------
## Shared DGP builder
## ---------------------------------------------------------------------

## Build the shared (unit, trait[, rep]) grid and the true Lambda/b/U/Sigma.
## Returns a data.frame with columns `unit`, `trait`, `rep_idx`, `eta`
## (long, one row per unit x trait x rep) plus the true generating objects.
.aghq_fam_eta_grid <- function(seed, n, p, q, n_rep = 1L,
                               lambda_sd = 0.6, b_mean = 0.2, b_sd = 0.3) {
  set.seed(seed)
  Lambda_true <- matrix(stats::rnorm(p * q, 0, lambda_sd), p, q)
  b_true      <- stats::rnorm(p, b_mean, b_sd)
  U           <- matrix(stats::rnorm(n * q), n, q)
  eta_mat     <- sweep(U %*% t(Lambda_true), 2, b_true, "+")   # n x p
  trait_names <- paste0("t", seq_len(p))
  grid <- data.frame(
    unit     = factor(rep(seq_len(n), each = p * n_rep)),
    trait    = factor(rep(rep(trait_names, each = n_rep), times = n),
                       levels = trait_names),
    rep_idx  = rep(seq_len(n_rep), times = n * p),
    eta      = rep(as.vector(t(eta_mat)), each = n_rep)
  )
  list(grid = grid, Lambda_true = Lambda_true, b_true = b_true, U = U,
       Sigma_true = Lambda_true %*% t(Lambda_true), trait_names = trait_names)
}

## Formula shared by every family: the ordinary loadings-only rr_B latent
## term (`unique = FALSE` => no diag Psi companion), the ONE shape the AGHQ
## gate currently admits (Stage 1a: z_B the sole random block).
.aghq_fam_formula <- function(response_lhs, q) {
  stats::as.formula(sprintf(
    "%s ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
    response_lhs, q
  ))
}

## ---------------------------------------------------------------------
## Per-family simulators. Each takes the shared eta grid (already built by
## .aghq_fam_eta_grid) and returns list(df, response_lhs, aux_true).
## Support constraints (counts non-negative integer, beta strictly in
## (0, 1), Gamma positive, ordinal categorical, delta/hurdle two-stage,
## betabinomial needing a denominator, truncated forms excluding their
## truncation point) are handled per family below.
## ---------------------------------------------------------------------

.aghq_sim_gaussian <- function(g, sigma_eps = 0.3) {
  y <- g$grid$eta + stats::rnorm(nrow(g$grid), 0, sigma_eps)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(sigma_eps = sigma_eps))
}

.aghq_sim_binomial <- function(g) {
  p <- stats::plogis(g$grid$eta)
  y <- stats::rbinom(nrow(g$grid), 1L, p)
  list(df = data.frame(g$grid, y = y), response_lhs = "y", aux_true = list())
}

.aghq_sim_poisson <- function(g) {
  y <- stats::rpois(nrow(g$grid), exp(g$grid$eta))
  list(df = data.frame(g$grid, y = y), response_lhs = "y", aux_true = list())
}

.aghq_sim_lognormal <- function(g, sigma_eps = 0.3) {
  logy <- g$grid$eta + stats::rnorm(nrow(g$grid), 0, sigma_eps)
  y <- exp(logy)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(sigma_eps = sigma_eps))
}

.aghq_sim_gamma <- function(g, shape = 4) {
  mu <- exp(g$grid$eta)
  y <- stats::rgamma(nrow(g$grid), shape = shape, scale = mu / shape)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(shape = shape))
}

.aghq_sim_nbinom2 <- function(g, phi = 3) {
  mu <- exp(g$grid$eta)
  y <- stats::rnbinom(nrow(g$grid), size = phi, mu = mu)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(phi = phi))
}

.aghq_sim_tweedie <- function(g, phi = 1.5, p_pow = 1.5) {
  mu <- exp(g$grid$eta)
  y <- tweedie::rtweedie(nrow(g$grid), mu = mu, phi = phi, power = p_pow)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(phi = phi, p_pow = p_pow))
}

.aghq_sim_beta <- function(g, phi = 6) {
  mu <- stats::plogis(g$grid$eta)
  y <- stats::rbeta(nrow(g$grid), mu * phi, (1 - mu) * phi)
  ## Numerical safety: rbeta can return exact 0/1 in the tails; the family's
  ## own log-density clamps internally, but keep the SIMULATED response
  ## strictly interior so "beta strictly in (0,1)" is honoured at the DGP.
  y <- pmin(pmax(y, 1e-8), 1 - 1e-8)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(phi = phi))
}

.aghq_sim_betabinomial <- function(g, phi = 5, N = 8L) {
  mu <- stats::plogis(g$grid$eta)
  p_random <- stats::rbeta(nrow(g$grid), mu * phi, (1 - mu) * phi)
  succ <- stats::rbinom(nrow(g$grid), size = N, prob = p_random)
  fail <- N - succ
  list(df = data.frame(g$grid, succ = succ, fail = fail),
       response_lhs = "cbind(succ, fail)", aux_true = list(phi = phi, N = N))
}

.aghq_sim_student <- function(g, sigma_t = 0.3, df_t = 6) {
  y <- g$grid$eta + sigma_t * stats::rt(nrow(g$grid), df = df_t)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(sigma_t = sigma_t, df_t = df_t))
}

## Zero-truncated Poisson: rejection-sample away the zero cell (the family
## excludes y == 0 by construction; obs_loglik's fid-10 density conditions on
## y > 0). lambda values are kept modest by the shared eta scale so the
## rejection loop terminates quickly.
.aghq_sim_truncated_poisson <- function(g) {
  lambda <- exp(g$grid$eta)
  y <- stats::rpois(length(lambda), lambda)
  zero <- which(y == 0L)
  guard <- 0L
  while (length(zero) > 0L && guard < 100L) {
    y[zero] <- stats::rpois(length(zero), lambda[zero])
    zero <- zero[y[zero] == 0L]
    guard <- guard + 1L
  }
  list(df = data.frame(g$grid, y = y), response_lhs = "y", aux_true = list())
}

## Zero-truncated NB2: same rejection-sampling idea as truncated_poisson.
.aghq_sim_truncated_nbinom2 <- function(g, phi = 3) {
  mu <- exp(g$grid$eta)
  y <- stats::rnbinom(length(mu), size = phi, mu = mu)
  zero <- which(y == 0L)
  guard <- 0L
  while (length(zero) > 0L && guard < 100L) {
    y[zero] <- stats::rnbinom(length(zero), size = phi, mu = mu[zero])
    zero <- zero[y[zero] == 0L]
    guard <- guard + 1L
  }
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(phi = phi))
}

## delta_lognormal (hurdle): one shared eta drives BOTH the presence
## Bernoulli(invlogit(eta)) and, conditional on presence, log y ~
## Normal(eta, sigma_t) -- verbatim the fid-12 obs_loglik contract
## (src/gllvmTMB.cpp:2224-2238).
.aghq_sim_delta_lognormal <- function(g, sigma_t = 0.3) {
  n_row <- nrow(g$grid)
  pres <- stats::rbinom(n_row, 1L, stats::plogis(g$grid$eta))
  y <- numeric(n_row)
  on <- pres == 1L
  y[on] <- exp(stats::rnorm(sum(on), g$grid$eta[on], sigma_t))
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(sigma_t = sigma_t))
}

## delta_gamma (hurdle): shared eta drives presence; conditional on presence
## y ~ Gamma(shape = 1/phi^2, scale = mu * phi^2) -- fid-13
## (src/gllvmTMB.cpp:2239-2252).
.aghq_sim_delta_gamma <- function(g, phi = 0.5) {
  n_row <- nrow(g$grid)
  pres <- stats::rbinom(n_row, 1L, stats::plogis(g$grid$eta))
  y <- numeric(n_row)
  on <- pres == 1L
  mu <- exp(g$grid$eta[on])
  shape <- 1 / phi^2
  y[on] <- stats::rgamma(sum(on), shape = shape, scale = mu / shape)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(phi = phi))
}

## ordinal_probit: y* = eta + N(0,1); K = 4 categories at fixed cutpoints
## tau = (0, 0.7, 1.4) (tau_1 = 0 fixed for identifiability, matching
## tests/testthat/test-matrix-ordinal-unit.R's TRUE_TAUS exactly).
.aghq_sim_ordinal_probit <- function(g, taus = c(0, 0.7, 1.4)) {
  ystar <- g$grid$eta + stats::rnorm(nrow(g$grid))
  y <- 1L + (ystar > taus[1]) + (ystar > taus[2]) + (ystar > taus[3])
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(taus = taus))
}

.aghq_sim_nbinom1 <- function(g, phi = 2) {
  mu <- exp(g$grid$eta)
  size <- mu / phi   # Var = mu*(1+phi); R's rnbinom(mu,size) has Var = mu + mu^2/size
  y <- stats::rnbinom(length(mu), size = size, mu = mu)
  list(df = data.frame(g$grid, y = y), response_lhs = "y",
       aux_true = list(phi = phi))
}

## ---------------------------------------------------------------------
## family_spec(): the 16-row table. Each element is a list with
##   name, fid, family (a THUNK -- call it to get the family object; kept
##   as a thunk so constructors that emit a cli_inform (student()) don't
##   fire at spec-build time), n, p, q, n_rep, simulate (function(seed) ->
##   list(df, response_lhs, Sigma_true, aux_true)), notes.
## ---------------------------------------------------------------------

family_spec <- function() {
  mk <- function(name, fid, family_fn, sim_fn, n = 60L, p = 6L, q = 2L,
                 n_rep = 1L, notes = "") {
    list(
      name = name, fid = fid, family = family_fn,
      n = n, p = p, q = q, n_rep = n_rep,
      simulate = function(seed) {
        g <- .aghq_fam_eta_grid(seed, n = n, p = p, q = q, n_rep = n_rep)
        sim <- sim_fn(g)
        c(sim, list(Sigma_true = g$Sigma_true, Lambda_true = g$Lambda_true,
                    b_true = g$b_true))
      },
      notes = notes
    )
  }

  list(
    mk("gaussian",          0L, function() stats::gaussian(),
       .aghq_sim_gaussian),
    mk("binomial",          1L, function() stats::binomial(),
       .aghq_sim_binomial),
    mk("poisson",           2L, function() stats::poisson(),
       .aghq_sim_poisson),
    mk("lognormal",         3L, function() lognormal(),
       .aghq_sim_lognormal),
    ## `link = "log"` is REQUIRED here, not stylistic: stats::Gamma()'s own
    ## default is link = "inverse", which R/fit-multi.R's fid==4 link check
    ## (cli_abort("Gamma: only the log link is currently supported...")))
    ## rejects immediately. Calling bare `stats::Gamma()` (as
    ## dev/aghq-evidence/19-family-axis.R did) is exactly what produced that
    ## script's silent "Gamma | no usable fits" outcome: a plain, immediately
    ## R-caught link-mismatch error, not a crash -- see
    ## docs/dev-log/2026-07-29-aghq-family-harness-audit.md. Do not drop this
    ## argument.
    mk("Gamma",             4L, function() stats::Gamma(link = "log"),
       .aghq_sim_gamma),
    mk("nbinom2",           5L, function() nbinom2(),
       .aghq_sim_nbinom2),
    mk("tweedie",           6L, function() tweedie(),
       .aghq_sim_tweedie, n = 40L, p = 4L, q = 1L,
       notes = paste(
         "HIGH RISK (pre-flagged): the compound Poisson-Gamma series density",
         "is expensive per node and k^(q+1) quadrature multiplies that cost;",
         "kept at q = 1 / smaller n,p to bound wall clock.")),
    mk("Beta",              7L, function() Beta(),
       .aghq_sim_beta),
    mk("betabinomial",      8L, function() betabinomial(),
       .aghq_sim_betabinomial),
    mk("student",            9L, function() suppressMessages(student(df = NULL)),
       .aghq_sim_student),
    mk("truncated_poisson", 10L, function() truncated_poisson(),
       .aghq_sim_truncated_poisson),
    mk("truncated_nbinom2", 11L, function() truncated_nbinom2(),
       .aghq_sim_truncated_nbinom2),
    mk("delta_lognormal",   12L, function() delta_lognormal(),
       .aghq_sim_delta_lognormal, n = 80L, p = 4L, q = 1L,
       notes = paste(
         "HIGH RISK (pre-flagged): the shared-eta presence/absence boundary",
         "is the least quadratic conditional shape in the family list.")),
    mk("delta_gamma",       13L, function() delta_gamma(),
       .aghq_sim_delta_gamma, n = 80L, p = 4L, q = 1L,
       notes = "HIGH RISK (pre-flagged): same hurdle-boundary concern as delta_lognormal."),
    mk("ordinal_probit",    14L, function() ordinal_probit(),
       .aghq_sim_ordinal_probit, n = 60L, p = 4L, q = 1L, n_rep = 4L,
       notes = paste(
         "HIGH RISK (pre-flagged): discrete-category likelihood, the least",
         "smooth per-observation shape; n_rep = 4 mirrors",
         "tests/testthat/test-matrix-ordinal-unit.R's identifiability fix.")),
    mk("nbinom1",           15L, function() nbinom1(),
       .aghq_sim_nbinom1)
  )
}

## Look up one spec by name (convenience for interactive use / the driver).
family_spec_by_name <- function(name, specs = family_spec()) {
  hit <- Filter(function(s) identical(s$name, name), specs)
  if (length(hit) != 1L) stop("family_spec_by_name: no unique match for '", name, "'")
  hit[[1L]]
}
