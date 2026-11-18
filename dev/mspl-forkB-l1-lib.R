## ---------------------------------------------------------------------------
## L1 local coverage smoke -- shared library (Design 125 / ADEMP P1-P3, P5).
##
## Pure functions only: fixture construction, refusal typing, refusal-priced
## coverage arithmetic, Wilson bands, and the frozen L1 gate. No fitting, no
## package state, no I/O. `dev/mspl-forkB-l1-coverage-smoke.R` sources this to
## run the campaign; `tests/testthat/test-zz-mspl-forkB-l1-gate.R` sources it to
## test the arithmetic without fitting anything.
##
## Scope fences carried by this file (do not weaken to go green):
##   * Nothing here constructs an interval. The interval comes from the fork-B
##     L0 door, which is a SEPARATE lane (`cursor/mspl-forkB-l0-20260818`).
##   * `calibrated` is never set TRUE anywhere in this lane.
##   * No public `confint` / `vcov` / `se = TRUE`; no `TMB::sdreport()`.
##   * Refusals price INTO the coverage denominator (ADEMP P1, SIGNED default) --
##     this is the anti-gaming rule from Design 118 DEV-11/DEV-12 and removing
##     it would let a door that refuses every hard cell report as calibrated.
## ---------------------------------------------------------------------------

`%||%` <- function(x, y) if (is.null(x)) y else x

isTRUE_vec <- function(x) !is.na(x) & x

## ---- frozen L1 gate numbers (ADEMP P5, G4d THRESHOLDS-SIGN-NOW) -----------
##
## L1 (local, frozen): cov_eff Wilson band not entirely below 0.80;
## availability >= 0.90; refusal <= 0.15.
## The 0.10 anchor usability floor (P3) is reported as a secondary flag, not
## as the L1 pass condition. T* (Totoro) numbers are NOT frozen and this file
## must not invent them.
L1_GATE <- list(
  cov_eff_wilson_upper_min = 0.80,
  availability_min = 0.90,
  refusal_max = 0.15,
  usability_floor_secondary = 0.10,
  level = 0.95,
  n_rep_min = 50L,
  n_rep_max = 100L
)

## ---- refusal taxonomy (ADEMP P3) ------------------------------------------
##
## Every replicate x estimand ends in exactly one of these states. "returned"
## is the only non-refusal. A refusal is never silently replaced by a Wald or
## bootstrap interval.
L1_REFUSAL_CODES <- c(
  "R-SAT",    # response-column saturation / separation screen fired
  "R-PIN",    # penalty-determined / pinned coordinate (Design 118 A1b class)
  "R-NAVL",   # profile path unavailable: no finite TWO-SIDED interval
  "R-Q0",     # Q_0 not PD / SE not finite (Wald arm only; never unblocks profile)
  "R-ENV",    # outside the named envelope, incl. target the door does not admit
  "R-FIT",    # the MSPL point fit itself failed or did not converge
  "R-DOOR"    # the fork-B door errored in an untyped way
)

l1_is_refusal <- function(code) !identical(code, "returned")

## ---- frozen DGP cells (ADEMP D, local smoke envelope) ---------------------
##
## Bernoulli logit, ordinary latent(d = 1, unique = FALSE), complete,
## unweighted, single-trial. n_site in {40, 80}, T in {4, 8}, q = 1.
## `anchor` is the largest local n at pi ~ 0.5 and is THE L1 gate cell.
## Loading truths are set with Lambda[1] > 0 so the E2 sign anchor
## (see `l1_sign_anchor`) never has to consult the truth.
l1_cells <- function() {
  list(
    anchor = list(
      name = "anchor", n_site = 80L, n_trait = 8L, q = 1L,
      link = "logit", role = "L1 gate cell (largest local n, pi ~ 0.5)",
      beta = c(0.00, 0.25, -0.25, 0.10, 0.15, -0.15, 0.05, -0.05),
      Lambda = c(0.90, -0.60, 0.45, 0.70, -0.50, 0.55, -0.40, 0.65)
    ),
    small = list(
      name = "small", n_site = 40L, n_trait = 4L, q = 1L,
      link = "logit", role = "cheap interior cell (timing / triage)",
      beta = c(0.00, 0.25, -0.25, 0.10),
      Lambda = c(0.90, -0.60, 0.45, 0.70)
    ),
    ## Declared here so L2 does not get to choose its tail cell after seeing
    ## L1. NOT part of the L1 gate; `--cells` must name it explicitly.
    neartail = list(
      name = "neartail", n_site = 80L, n_trait = 8L, q = 1L,
      link = "logit", role = "near-tail cell (L2 material, not an L1 gate cell)",
      beta = c(-2.00, -1.80, -2.20, -1.90, -2.10, -1.70, -2.30, -1.85),
      Lambda = c(0.90, -0.60, 0.45, 0.70, -0.50, 0.55, -0.40, 0.65)
    )
  )
}

## Fresh seed block. NOT Design 118 campaign seeds -- ADEMP D forbids reusing
## those as fitting data.
l1_seeds <- function(n_rep) {
  stopifnot(is.numeric(n_rep), length(n_rep) == 1L, n_rep >= 1L)
  as.integer(818000L + seq_len(as.integer(n_rep)))
}

l1_simulate <- function(cell, seed) {
  set.seed(as.integer(seed))
  n_site <- as.integer(cell$n_site)
  n_trait <- as.integer(cell$n_trait)
  stopifnot(length(cell$beta) == n_trait, length(cell$Lambda) == n_trait)
  stopifnot(cell$Lambda[[1L]] > 0)  # E2 sign anchor precondition
  site <- factor(rep(sprintf("s%03d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  eta <- cell$beta[as.integer(trait)] +
    z[as.integer(site)] * cell$Lambda[as.integer(trait)]
  y <- stats::rbinom(length(eta), 1L, stats::plogis(eta))
  list(
    data = data.frame(site = site, trait = trait, y = y),
    beta = cell$beta,
    Lambda = cell$Lambda,
    prevalence = mean(y),
    trait_prevalence = as.numeric(tapply(y, trait, mean)),
    seed = as.integer(seed)
  )
}

## R-SAT pre-fit screen: a trait column that is all-0 or all-1 carries no
## information about its own intercept, so its coordinate intervals are refused
## before fitting rather than after a fit that will not converge.
l1_saturated_traits <- function(dat) {
  p <- tapply(dat$y, dat$trait, mean)
  names(p)[p <= 0 | p >= 1]
}

## E2 sign anchor. d = 1 identifies Lambda only up to a global sign; the DGP
## fixes Lambda[1] > 0, so "flip the whole vector if the fitted first loading
## is negative" is a rule that never looks at the truth. Flipping an interval
## negates and swaps its endpoints.
l1_sign_anchor <- function(estimate, lower, upper, first_loading) {
  flip <- is.finite(first_loading) && first_loading < 0
  if (!flip) {
    return(list(estimate = estimate, lower = lower, upper = upper, flipped = FALSE))
  }
  list(estimate = -estimate, lower = -upper, upper = -lower, flipped = TRUE)
}

## ---- mock door (REHEARSAL ONLY) -------------------------------------------
##
## A synthetic stand-in for the fork-B L0 door, so the campaign loop, the
## refusal typing, the sign anchor, and the TSV/verdict plumbing can all be
## exercised end to end BEFORE L0 lands. It is deliberately not a model of
## anything: it returns a fixed-width interval around the point estimate and
## refuses on a fixed schedule.
##
## Two safeguards keep a rehearsal from ever becoming evidence:
##   * `objective_source` says so in words, and
##   * the runner suppresses the L1 verdict entirely whenever a mock is in use.
## Never widen this into "an approximate fork B" -- an approximation of the
## thing under test is the one thing a harness must not contain.
l1_mock_door <- function(half_width = 3, refuse_every = 10L,
                         refusal_code = "R-NAVL") {
  counter <- 0L
  function(fit, which, level = L1_GATE$level, ...) {
    counter <<- counter + 1L
    est <- as.numeric(fit$opt$par[[which]])
    if (refuse_every > 0L && counter %% as.integer(refuse_every) == 0L) {
      return(list(
        centre_status = "matched", lower_status = "truncated",
        upper_status = "truncated",
        lower_endpoint = NA_real_, upper_endpoint = NA_real_,
        calibrated = FALSE, public_confint = "refused", coverage_claim = "none",
        objective_source = "MOCK REHEARSAL DOOR (not an estimator)"
      ))
    }
    list(
      centre_status = "matched", lower_status = "crossed",
      upper_status = "crossed",
      lower_endpoint = est - half_width, upper_endpoint = est + half_width,
      calibrated = FALSE, public_confint = "refused", coverage_claim = "none",
      objective_source = "MOCK REHEARSAL DOOR (not an estimator)"
    )
  }
}

l1_is_mock_source <- function(src) {
  isTRUE(is.character(src) && any(grepl("MOCK", src, fixed = TRUE)))
}

## ---- coverage arithmetic (ADEMP P1) ---------------------------------------

l1_wilson <- function(k, n, level = L1_GATE$level) {
  if (!is.finite(k) || !is.finite(n) || n <= 0 || k < 0 || k > n) {
    return(c(lower = NA_real_, upper = NA_real_))
  }
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- k / n
  d <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / d
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / d
  c(lower = max(0, centre - half), upper = min(1, centre + half))
}

l1_mcse <- function(p, n) {
  if (!is.finite(p) || !is.finite(n) || n <= 0) return(NA_real_)
  sqrt(p * (1 - p) / n)
}

## `rows` is one row per replicate for a single (cell x estimand x coordinate
## set) unit, with columns:
##   outcome   -- "returned" or a code in L1_REFUSAL_CODES
##   covered   -- logical, only meaningful when outcome == "returned"
##   two_sided -- logical, TRUE iff a finite two-sided interval was produced
##
## Returns conditional coverage, refusal rate (overall and by code), effective
## (refusal-priced) coverage, availability, and Wilson bands on both coverage
## flavours. A refusal is non-coverage for the claim -- ADEMP P1 SIGNED
## default, fail-closed.
l1_summarise <- function(rows, level = L1_GATE$level) {
  n <- nrow(rows)
  if (is.null(n) || n == 0L) {
    return(list(
      n = 0L, n_returned = 0L, n_refused = 0L, n_covered = 0L,
      cov_ret = NA_real_, cov_ret_wilson = c(lower = NA_real_, upper = NA_real_),
      cov_eff = NA_real_, cov_eff_wilson = c(lower = NA_real_, upper = NA_real_),
      refusal = NA_real_, availability = NA_real_,
      refusal_by_code = setNames(integer(0), character(0)),
      mcse_ret = NA_real_, mcse_eff = NA_real_,
      structurally_unevaluable = FALSE, dominant_refusal = NA_character_
    ))
  }
  returned <- rows$outcome == "returned"
  n_returned <- sum(returned)
  n_refused <- n - n_returned
  n_covered <- sum(returned & isTRUE_vec(rows$covered))

  cov_ret <- if (n_returned > 0L) n_covered / n_returned else NA_real_
  cov_eff <- n_covered / n            # refusals priced as non-coverage
  refusal <- n_refused / n

  ## Availability (P2): two-sided interval among non-R-SAT replicates.
  ## R-SAT is a property of the DATA, not of the profile path, so a saturated
  ## column must not be scored against the path's availability -- but it is
  ## still priced into coverage above.
  non_sat <- rows$outcome != "R-SAT"
  availability <- if (sum(non_sat) > 0L) {
    sum(isTRUE_vec(rows$two_sided) & non_sat) / sum(non_sat)
  } else {
    NA_real_
  }

  by_code <- table(rows$outcome[!returned])
  ## Anti-gaming guard, and the ONLY route to "not evaluable": a unit is
  ## structurally unevaluable when the door refused every single replicate
  ## with ONE structural code (R-ENV = target the door does not admit). Any
  ## mixture of codes, or any returned interval, means the unit is evaluated
  ## and its refusals price in. Without this restriction a door could dodge a
  ## FAIL by refusing everything.
  dominant <- if (length(by_code)) names(by_code)[which.max(by_code)] else NA_character_
  structurally_unevaluable <- n_returned == 0L &&
    length(by_code) == 1L && identical(dominant, "R-ENV")

  list(
    n = n, n_returned = n_returned, n_refused = n_refused, n_covered = n_covered,
    cov_ret = cov_ret,
    cov_ret_wilson = l1_wilson(n_covered, n_returned, level),
    cov_eff = cov_eff,
    cov_eff_wilson = l1_wilson(n_covered, n, level),
    refusal = refusal,
    availability = availability,
    refusal_by_code = by_code,
    mcse_ret = l1_mcse(cov_ret, n_returned),
    mcse_eff = l1_mcse(cov_eff, n),
    structurally_unevaluable = structurally_unevaluable,
    dominant_refusal = dominant
  )
}

## A replicate contributes one coordinate-outcome per trait, and those share a
## fit, so the Wilson band over all coordinate-replicates can be optimistically
## narrow. This resamples whole replicates to get a band that respects the
## clustering, and reports the design effect so the naive band can be judged
## rather than assumed. Cheap: it resamples stored outcomes, it does not refit.
l1_cluster_bootstrap <- function(rows, B = 2000L, level = L1_GATE$level,
                                 seed = 20260818L) {
  if (is.null(rows$rep) || !nrow(rows)) {
    return(list(mean = NA_real_, lower = NA_real_, upper = NA_real_,
                design_effect = NA_real_, n_clusters = NA_integer_))
  }
  covered <- isTRUE_vec(rows$covered) & rows$outcome == "returned"
  split_cov <- split(covered, rows$rep)
  reps <- names(split_cov)
  if (length(reps) < 2L) {
    return(list(mean = mean(covered), lower = NA_real_, upper = NA_real_,
                design_effect = NA_real_, n_clusters = length(reps)))
  }
  old <- if (exists(".Random.seed", .GlobalEnv)) get(".Random.seed", .GlobalEnv) else NULL
  set.seed(seed)
  on.exit(if (!is.null(old)) assign(".Random.seed", old, .GlobalEnv), add = TRUE)
  draws <- vapply(seq_len(as.integer(B)), function(i) {
    mean(unlist(split_cov[sample(reps, length(reps), replace = TRUE)]))
  }, numeric(1))
  a <- (1 - level) / 2
  p <- mean(covered)
  naive_se <- sqrt(p * (1 - p) / length(covered))
  list(
    mean = mean(draws),
    lower = unname(stats::quantile(draws, a)),
    upper = unname(stats::quantile(draws, 1 - a)),
    design_effect = if (naive_se > 0) stats::sd(draws) / naive_se else NA_real_,
    n_clusters = length(reps)
  )
}

## The frozen L1 decision. Returns PASS / FAIL / NOT-EVALUABLE plus the three
## component verdicts, so a report can never state a verdict without the
## reasons. `NOT-EVALUABLE` is not a pass and must never be reported as one.
l1_gate <- function(summary, gate = L1_GATE) {
  if (isTRUE(summary$structurally_unevaluable)) {
    return(list(
      verdict = "NOT-EVALUABLE",
      cov_ok = NA, avail_ok = NA, refusal_ok = NA,
      reason = paste(
        "the door structurally refused every replicate with R-ENV",
        "(target not admitted); no coverage was measured, and this is",
        "NOT a pass"
      )
    ))
  }
  cov_ok <- is.finite(summary$cov_eff_wilson[["upper"]]) &&
    summary$cov_eff_wilson[["upper"]] >= gate$cov_eff_wilson_upper_min
  avail_ok <- is.finite(summary$availability) &&
    summary$availability >= gate$availability_min
  refusal_ok <- is.finite(summary$refusal) && summary$refusal <= gate$refusal_max
  reasons <- c(
    if (!isTRUE(cov_ok)) sprintf(
      "cov_eff Wilson band entirely below %.2f (upper = %s)",
      gate$cov_eff_wilson_upper_min,
      format(summary$cov_eff_wilson[["upper"]], digits = 4)
    ),
    if (!isTRUE(avail_ok)) sprintf(
      "availability %s < %.2f", format(summary$availability, digits = 4),
      gate$availability_min
    ),
    if (!isTRUE(refusal_ok)) sprintf(
      "refusal %s > %.2f", format(summary$refusal, digits = 4), gate$refusal_max
    )
  )
  list(
    verdict = if (isTRUE(cov_ok) && isTRUE(avail_ok) && isTRUE(refusal_ok)) {
      "PASS"
    } else {
      "FAIL"
    },
    cov_ok = cov_ok, avail_ok = avail_ok, refusal_ok = refusal_ok,
    usability_floor_ok = is.finite(summary$refusal) &&
      summary$refusal <= gate$usability_floor_secondary,
    reason = if (length(reasons)) paste(reasons, collapse = "; ") else "all three L1 conditions met"
  )
}
