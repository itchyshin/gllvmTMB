## Lane B: opt-in maximum softly penalised Laplace likelihood --------------
##
## This file owns the small R-side contract shared by the public API,
## fit assembly, and S3 methods.  The numerical Jeffreys log-determinant and
## loading penalty live in the TMB template; R resolves the fixed-effect map,
## fences the admitted model surface, and labels the resulting point estimate.

.gllvmTMB_is_mspl <- function(x) {
  estimator <- tryCatch(x$estimator, error = function(e) NULL)
  inherits(x, "gllvmTMB_mspl") ||
    identical(toupper(estimator %||% ""), "MSPL")
}

.gllvmTMB_mspl_abort <- function(
  message,
  ...,
  class = "gllvmTMB_mspl_unsupported"
) {
  cli::cli_abort(c(message, ...), class = class, .envir = parent.frame())
}

## Frozen V8 Jeffreys atom: 0 = OK_DOUBLE_CERTIFIED, 1 = OK_MP_CERTIFIED.
## Both are valid certified results. Codes >= 10 are failures.
.gllvmTMB_mspl_jeffreys_atom_ok <- function(atom_status) {
  status <- as.integer(atom_status)
  length(status) == 1L && !is.na(status) && status %in% c(0L, 1L)
}

## Ferrari–Cribari-Neto logit GLM-outer weight: I(β) diagonal.
## Matches src/gllvmTMB.cpp family_id 7 (φ² form, not FCN's inner W).
.gllvmTMB_mspl_beta_jeffreys_weight <- function(eta, phi) {
  eta <- as.numeric(eta)
  phi <- as.numeric(phi)
  if (length(phi) == 1L) {
    phi <- rep(phi, length(eta))
  }
  mu <- stats::plogis(eta)
  a <- mu * phi
  b <- (1 - mu) * phi
  (phi^2) * (mu * (1 - mu))^2 * (trigamma(a) + trigamma(b))
}

.gllvmTMB_mspl_inference_abort <- function(what) {
  cli::cli_abort(
    c(
      "{.fn {what}} is not available for an {.code estimator = \"mspl\"} fit.",
      "i" = "LA-MSPL is an experimental point estimator; repeated-sampling inference is not yet calibrated.",
      ">" = "Use {.fn coef}, {.fn predict}, or the covariance extractors for point estimates, and fit {.code estimator = \"ml\"} when likelihood-based inference is required."
    ),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
}

.gllvmTMB_mspl_assert_inference <- function(x, what) {
  if (.gllvmTMB_is_mspl(x)) {
    .gllvmTMB_mspl_inference_abort(what)
  }
  invisible(x)
}

## Thin, mockable wrapper around stats::nlminb() -- exists so tests can
## simulate a transient optimizer failure at one specific profile point
## without touching the stats namespace (repo convention: mock private
## gllvmTMB helpers, see e.g. test-confint-lambda.R).
.gllvmTMB_mspl_nlminb <- function(start, objective, gradient, control) {
  stats::nlminb(start, objective = objective, gradient = gradient,
                control = control)
}

## ---------------------------------------------------------------------------
## Internal LA-MSPL profile COMPUTABILITY probe (availability only).
##
## Private feasibility instrument only.  This is intentionally separate from the
## public profile/confint dispatch: a finite trace establishes neither
## calibrated standard errors nor confidence-interval coverage.
##
## Scope, stated once: this instrument answers "can a finite penalised-profile
## bracket be computed at this fit?" and nothing else.  It is NOT a confidence
## interval, NOT calibrated, and NOT a public route -- `vcov()`, `confint()` and
## `se = TRUE` remain fail-closed via `.gllvmTMB_mspl_assert_inference()`, and
## `MSPL-04` stays `blocked`.  Endpoints are named `*_endpoint` /
## `diagnostic_*`, never `conf.low` / `conf.high`, so no tidier can lift them as
## an interval.  Non-crossing / non-finite / optimiser failures stay typed; no
## repair, no clipping, no widening beyond the caller's explicit request.
##
## `level` selects the chi-square_1 LR threshold used to bracket; it confers NO
## coverage at that or any level.  See the Kosmidis & Firth note below.
##
## Family fence (computability probe only; not admission): binomial +
## logit/probit/cloglog.  The public MSPL door admits six families, but the only
## evidence here -- and the only authority cited below -- is binomial.
##
## Admission gate: DELIBERATELY NOT IMPLEMENTED.  The softness-ratio /
## N2'-curvature / separation admission conditions belong to the parked
## calibrated construction (D-157; Design 125), not to this probe.  Their
## absence is a scope decision, not an omission.
##
## Why the fence is not merely conventional: Kosmidis & Firth (2021, Biometrika
## 108(1), s2.2 p.5) state that under a finiteness penalty Wald intervals "or
## confidence regions in general, will fail to cover regardless of the nominal
## level alpha", and that this "is also true when the penalized likelihood is
## profiled".  So a finite bracket here is evidence of computability only.  That
## paper is binomial-response only, which is the second reason for the family
## fence above.
##
## Provenance AND its constraint: ported from `claude/mspl-b0-prereqs` (PR #981,
## still open), which itself ported it from
## `codex/lane-b-mspl-interval-feasibility` (commit e2055c7b) -- a branch marked
## PROTECTED ("No absorb/rebase/merge") in
## docs/dev-log/handover/2026-07-25-active-lane-split.md, and D-149 names Codex
## Lane B the binomial SE owner ("Do not rebuild, reassign, or absorb it").
## Landing this therefore requires an explicit maintainer G0; do not re-port it
## further without one.  R-side only -- deliberately WITHOUT that branch's
## `src/` `mspl_c_n_multiplier` hook, which these functions do not use (they
## read only `obj$env$data$estimator_id`).
##
## Relation to Design 125 (UPDATED 2026-08-18, fork G0 SIGNED): `objective`
## selects the tape.  `tape` is the existing Q_P / Q_0 synonym so the
## parallel L0 / L1 callers keep working.
##
##   "penalised"   / tape "Q_P" -- fork **A**: walk `fit$tmb_obj` (the
##                    penalised LA-MSPL objective), re-optimising the nuisance
##                    coordinates at each target.  Default; retained as the
##                    **ablation** arm.
##   "unpenalized" / tape "Q_0" -- fork **B**: walk
##                    `fit$mspl$unpenalized_tmb_obj` (the ordinary Laplace
##                    objective, `estimator_id = 2`) with the nuisance
##                    coordinates HELD FIXED at the MSPL point estimate
##                    \tilde\theta.  This is the arm Design 125's G4c picked.
##
## Fork B is the signed construction; fork A stays available so the two can be
## measured against each other on the same fit.  Neither is calibrated: the
## Kosmidis & Firth caveat above bites fork A directly, and fork B's slice is a
## *fixed-nuisance* one-dimensional curve, not a profile in the nuisance-maximised
## sense -- so its threshold crossing is a computability observable, not a
## coverage statement.  Both arms keep `calibrated = FALSE`,
## `public_confint = "refused"`, `coverage_claim = "none"`; both are internal and
## unexported; `MSPL-04` stays `blocked`.
##
## Three honest asymmetries of fork B, each surfaced as a returned field:
##   1. `reference_is_maximum = FALSE` -- the MSPL point maximises Q_P, not Q_0,
##      so `objective_delta` is not an LR statistic.
##   2. `nuisance_treatment = "fixed_at_mspl"` -- `nlminb` is never called.
##   3. `centre_status = "matched"` is true by construction on this tape.
## ---------------------------------------------------------------------------
.gllvmTMB_mspl_resolve_profile_selector <- function(
  objective,
  tape,
  objective_supplied = FALSE
) {
  map_objective <- function(value) {
    if (identical(value, "unpenalized")) "Q_0" else "Q_P"
  }
  map_tape <- function(value) {
    if (identical(value, "Q_0")) "unpenalized" else "penalised"
  }
  if (!is.null(tape)) {
    if (!is.character(tape) || !length(tape)) {
      .gllvmTMB_mspl_abort(
        "The internal MSPL profile probe requires {.arg tape} to be {.val Q_P} or {.val Q_0}.",
        class = "gllvmTMB_mspl_profile_tape"
      )
    }
    tape <- tape[[1L]]
    if (!(tape %in% c("Q_P", "Q_0"))) {
      .gllvmTMB_mspl_abort(
        "The internal MSPL profile probe requires {.arg tape} to be {.val Q_P} or {.val Q_0}.",
        "x" = "Received {.val {tape}}.",
        "i" = "{.val Q_P} is the penalised profile (Design 125 fork A); {.val Q_0} is the unpenalized Laplace tape at fixed MSPL nuisance (fork B). Fork C is not implemented.",
        class = "gllvmTMB_mspl_profile_tape"
      )
    }
    mapped <- map_tape(tape)
    if (isTRUE(objective_supplied)) {
      if (!is.character(objective) || !length(objective)) {
        .gllvmTMB_mspl_abort(
          "The internal MSPL profile probe requires {.arg objective} to be {.val penalised} or {.val unpenalized}.",
          class = "gllvmTMB_mspl_profile_objective"
        )
      }
      explicit <- objective[[1L]]
      if (explicit %in% c("penalised", "unpenalized") &&
          !identical(explicit, mapped)) {
        .gllvmTMB_mspl_abort(
          "The internal MSPL profile probe received disagreeing {.arg objective} and {.arg tape} selectors.",
          "x" = "{.arg objective} = {.val {explicit}}; {.arg tape} = {.val {tape}}.",
          class = "gllvmTMB_mspl_profile_objective"
        )
      }
    }
    return(list(objective = mapped, tape = tape))
  }
  if (!is.character(objective) || !length(objective)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe requires {.arg objective} to be {.val penalised} or {.val unpenalized}.",
      class = "gllvmTMB_mspl_profile_objective"
    )
  }
  objective <- objective[[1L]]
  if (!(objective %in% c("penalised", "unpenalized"))) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe requires {.arg objective} to be {.val penalised} or {.val unpenalized}.",
      "x" = "Received {.val {objective}}.",
      "i" = "{.val penalised} is Design 125 fork A; {.val unpenalized} is fork B. The {.arg tape} synonyms are {.val Q_P} and {.val Q_0}.",
      class = "gllvmTMB_mspl_profile_objective"
    )
  }
  list(objective = objective, tape = map_objective(objective))
}

.gllvmTMB_mspl_profile_feasibility <- function(
  fit,
  which = 1L,
  step = 0.5,
  max_steps = 6L,
  level = 0.95,
  control = list(eval.max = 100L, iter.max = 100L),
  refinement_steps = 12L,
  bracket_tolerance = 1.25e-4,
  max_widen_rounds = 0L,
  objective = c("penalised", "unpenalized"),
  tape = NULL
) {
  objective_supplied <- !missing(objective)
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_profile_input"
    )
  }
  resolved <- .gllvmTMB_mspl_resolve_profile_selector(
    objective, tape, objective_supplied = objective_supplied
  )
  objective <- resolved$objective
  tape <- resolved$tape
  nuisance_fixed <- identical(objective, "unpenalized")
  ## Family fence, enforced not merely documented -- mirrors
  ## `.gllvmTMB_mspl_curvature_pin()`.  Binomial only: it is the only family with
  ## evidence here, and the Kosmidis & Firth authority cited in the header is
  ## binomial-response only, so on a gaussian or Poisson fit the returned
  ## `coverage_claim = "none"` would rest on a citation that does not apply.
  fl <- .gllvmTMB_mspl_pin_family_link(fit)
  if (!(identical(fl$family, "binomial") &&
        fl$link %in% c("logit", "probit", "cloglog"))) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile computability probe is fenced to binomial logit, probit, or cloglog fits.",
      "x" = "Resolved family {.val {fl$family}}, link {.val {fl$link}}.",
      "i" = "This is a computability probe, not an admission gate and not an interval route.",
      class = "gllvmTMB_mspl_profile_family"
    )
  }
  if (
    !is.numeric(which) ||
      length(which) != 1L ||
      which %% 1 != 0 ||
      which < 1L ||
      which > length(fit$opt$par) ||
      names(fit$opt$par)[which] != "b_fix"
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe requires one resolved {.field b_fix} coordinate.",
      class = "gllvmTMB_mspl_profile_target"
    )
  }
  if (
    !is.numeric(step) ||
      length(step) != 1L ||
      !is.finite(step) ||
      step <= 0 ||
      !is.numeric(max_steps) ||
      length(max_steps) != 1L ||
      max_steps < 1L ||
      max_steps %% 1 != 0 ||
      !is.numeric(level) ||
      length(level) != 1L ||
      !is.finite(level) ||
      level <= 0 ||
      level >= 1 ||
      !is.numeric(refinement_steps) ||
      length(refinement_steps) != 1L ||
      refinement_steps < 0L ||
      refinement_steps %% 1 != 0 ||
      !is.numeric(bracket_tolerance) ||
      length(bracket_tolerance) != 1L ||
      !is.finite(bracket_tolerance) ||
      bracket_tolerance <= 0 ||
      !is.numeric(max_widen_rounds) ||
      length(max_widen_rounds) != 1L ||
      max_widen_rounds < 0L ||
      max_widen_rounds %% 1 != 0
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile grid requires positive finite grid and refinement controls, with {.arg level} in (0, 1).",
      class = "gllvmTMB_mspl_profile_grid"
    )
  }

  penalised <- fit$tmb_obj
  penalty_off <- fit$mspl$unpenalized_tmb_obj
  ## The penalised tape is verified in BOTH forks: fork B's centre value and
  ## its fixed nuisance coordinates are read off the MSPL fit, so a fit whose
  ## penalised tape cannot be identified is not a usable fork-B origin either.
  if (
    is.null(penalised) ||
      identical(penalised, penalty_off) ||
      !identical(as.integer(penalised$env$data$estimator_id), 1L)
  ) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe could not verify the active penalised TMB objective.",
      class = "gllvmTMB_mspl_profile_objective"
    )
  }
  if (nuisance_fixed && (
    is.null(penalty_off) ||
      !identical(as.integer(penalty_off$env$data$estimator_id), 2L)
  )) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile probe could not verify the unpenalized Laplace TMB objective.",
      "i" = "{.code objective = \"unpenalized\"} (Design 125 fork B) needs {.field fit$mspl$unpenalized_tmb_obj} with {.code estimator_id = 2}.",
      class = "gllvmTMB_mspl_profile_objective"
    )
  }
  obj <- if (nuisance_fixed) penalty_off else penalised
  checkpoint <- .gllvmTMB_profile_tmb_checkpoint(obj)
  on.exit(.gllvmTMB_restore_profile_tmb_checkpoint(obj, checkpoint), add = TRUE)

  mle_par <- as.numeric(fit$opt$par)
  ## Fork A compares against the penalised optimum already recorded by the
  ## fitter.  Fork B must compare against the UNPENALIZED objective evaluated at
  ## the same \tilde\theta -- `fit$opt$objective` is the penalised value and
  ## would put the centre off its own curve by the whole penalty.
  mle_objective <- if (nuisance_fixed) {
    centre_value <- tryCatch(as.numeric(obj$fn(mle_par)), error = identity)
    if (inherits(centre_value, "error") || !is.finite(centre_value)) {
      .gllvmTMB_mspl_abort(
        "The internal MSPL profile probe could not evaluate the unpenalized objective at the MSPL estimate.",
        class = "gllvmTMB_mspl_profile_objective"
      )
    }
    centre_value
  } else {
    as.numeric(fit$opt$objective)
  }
  nuisance_index <- setdiff(seq_along(mle_par), as.integer(which))
  threshold <- stats::qchisq(level, df = 1L) / 2

  ## Fork B (`objective = "unpenalized"`): the nuisance coordinates stay pinned
  ## at \tilde\theta, so there is no inner optimisation -- the walk is a plain
  ## evaluation of the unpenalized objective along one coordinate.  Recorded as
  ## `nuisance_reoptimized = FALSE`, which is what distinguishes this slice from
  ## a nuisance-maximised profile in any stored trace.
  evaluate_fixed <- function(target, start, side, stage) {
    par <- mle_par
    par[as.integer(which)] <- target
    value <- tryCatch(as.numeric(obj$fn(par)), error = identity)
    if (inherits(value, "error")) {
      return(list(
        row = data.frame(
          target = target, objective = NA_real_, objective_delta = NA_real_,
          convergence = NA_integer_, message = conditionMessage(value),
          finite = FALSE, nuisance_reoptimized = FALSE, side = side,
          stage = stage, stringsAsFactors = FALSE
        ),
        nuisance = start
      ))
    }
    finite <- length(value) == 1L && is.finite(value)
    list(
      row = data.frame(
        target = target,
        objective = if (finite) value else NA_real_,
        objective_delta = if (finite) value - mle_objective else NA_real_,
        convergence = if (finite) 0L else NA_integer_,
        message = "", finite = finite,
        nuisance_reoptimized = FALSE, side = side, stage = stage,
        stringsAsFactors = FALSE
      ),
      nuisance = start
    )
  }

  evaluate_reoptimized <- function(target, start, side, stage) {
    objective <- function(nuisance) {
      par <- mle_par
      par[nuisance_index] <- nuisance
      par[which] <- target
      obj$fn(par)
    }
    gradient <- function(nuisance) {
      par <- mle_par
      par[nuisance_index] <- nuisance
      par[which] <- target
      obj$gr(par)[nuisance_index]
    }
    run_nlminb <- function(start_par) {
      tryCatch(
        .gllvmTMB_mspl_nlminb(start_par, objective = objective,
                               gradient = gradient, control = control),
        error = identity
      )
    }
    converged <- function(ans) {
      !inherits(ans, "error") && is.finite(ans$objective) &&
        identical(as.integer(ans$convergence), 0L)
    }
    ans <- run_nlminb(start)
    ## Fix (2): a single nlminb non-convergence is not fatal -- retry once
    ## from the joint-MLE nuisance start, a point already known to be a
    ## well-converged optimum, before recording this point as a failure.
    if (!converged(ans)) {
      retry <- run_nlminb(mle_par[nuisance_index])
      if (converged(retry)) ans <- retry
    }
    if (inherits(ans, "error")) {
      return(list(
        row = data.frame(
          target = target, objective = NA_real_, objective_delta = NA_real_,
          convergence = NA_integer_, message = conditionMessage(ans),
          finite = FALSE, nuisance_reoptimized = FALSE, side = side,
          stage = stage, stringsAsFactors = FALSE
        ),
        nuisance = start
      ))
    }
    finite <- is.finite(ans$objective)
    list(
      row = data.frame(
        target = target,
        objective = if (finite) as.numeric(ans$objective) else NA_real_,
        objective_delta = if (finite) as.numeric(ans$objective) - mle_objective else NA_real_,
        convergence = as.integer(ans$convergence),
        message = ans$message %||% "", finite = finite,
        nuisance_reoptimized = identical(as.integer(ans$convergence), 0L),
        side = side, stage = stage, stringsAsFactors = FALSE
      ),
      nuisance = as.numeric(ans$par)
    )
  }

  evaluate_point <- if (nuisance_fixed) evaluate_fixed else evaluate_reoptimized

  successful <- function(point) {
    is.list(point) && is.data.frame(point$row) &&
      isTRUE(point$row$finite[[1L]]) &&
      identical(point$row$convergence[[1L]], 0L) &&
      is.finite(point$row$objective_delta[[1L]])
  }

  centre_point <- evaluate_point(
    mle_par[which], mle_par[nuisance_index], "centre", "centre"
  )
  centre <- centre_point$row
  centre_tolerance <- 1e-7 * (1 + abs(mle_objective))
  centre_status <- if (!centre$finite) {
    "nonfinite"
  } else if (centre$convergence != 0L) {
    "optimizer_failed"
  } else if (abs(centre$objective_delta) > centre_tolerance) {
    "centre_mismatch"
  } else {
    "matched"
  }

  walk_side <- function(direction) {
    points <- list()
    previous_success <- centre_point
    start <- centre_point$nuisance
    bracket <- NULL
    origin <- mle_par[which]
    current_step <- step
    widen_round <- 0L
    repeat {
      values <- origin + direction * current_step * seq_len(as.integer(max_steps))
      round_points <- list()
      for (target in values) {
        point <- evaluate_point(
          target, start, if (direction < 0) "lower" else "upper", "grid"
        )
        points[[length(points) + 1L]] <- point
        round_points[[length(round_points) + 1L]] <- point
        if (successful(point)) {
          start <- point$nuisance
          if (successful(previous_success) &&
              previous_success$row$objective_delta[[1L]] < threshold &&
              point$row$objective_delta[[1L]] >= threshold) {
            bracket <- list(inside = previous_success, outside = point)
            break
          }
          previous_success <- point
        }
        ## Fix (1): do NOT discard `previous_success` on a failed grid point.
        ## The old code set it to NULL here, so a single transient
        ## non-convergence permanently erased the last known sub-threshold
        ## reference -- if the very next point already crossed the threshold,
        ## the bracket was silently missed and the walk ran out its budget
        ## reporting "truncated"/"optimizer_failed" instead of "crossed".
        ## Leaving `previous_success` unchanged means a later successful
        ## point is still correctly bracketed against it (over a wider, but
        ## still valid, interval).
      }
      if (!is.null(bracket)) break

      ## Design 118 s7.2, second half ("widen the ... bracket to thresholds
      ## [0.354, 3.317]"): 0d6de305 ported the two root-finder fixes above
      ## but left the walk's reach fixed at step*max_steps, which the
      ## default (0.5, 6) does not always cover for the wider registered
      ## threshold range (level up to 0.99, i.e. threshold 3.317). When a
      ## round finishes CLEANLY (no nonfinite/optimizer_failed point) but
      ## simply never reaches `threshold`, and the caller opted in via
      ## `max_widen_rounds > 0`, continue the walk from the last known-good
      ## point with a 4x larger step instead of reporting "truncated".
      ## `max_widen_rounds = 0L` (the default) makes this loop run exactly
      ## once, reproducing the pre-existing trace byte-for-byte for every
      ## caller that does not pass the new argument -- see
      ## test-mspl-api.R's `max_steps = 1L` truncation test, unchanged.
      round_rows <- do.call(rbind, lapply(round_points, `[[`, "row"))
      clean_round <- !any(!round_rows$finite) && !any(round_rows$convergence != 0L)
      if (!clean_round || widen_round >= as.integer(max_widen_rounds) ||
          !successful(previous_success)) {
        break
      }
      widen_round <- widen_round + 1L
      origin <- previous_success$row$target[[1L]]
      current_step <- current_step * 4
    }

    if (is.null(bracket)) {
      rows <- do.call(rbind, lapply(points, `[[`, "row"))
      status <- if (any(!rows$finite)) {
        "nonfinite"
      } else if (any(rows$convergence != 0L)) {
        "optimizer_failed"
      } else {
        "truncated"
      }
      return(list(
        status = status, points = points, endpoint = NA_real_,
        bracket = c(NA_real_, NA_real_), refinement_iterations = 0L
      ))
    }

    iterations <- 0L
    while (abs(bracket$outside$row$target - bracket$inside$row$target) >
           bracket_tolerance && iterations < as.integer(refinement_steps)) {
      iterations <- iterations + 1L
      target <- mean(c(
        bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
      ))
      point <- evaluate_point(
        target, bracket$inside$nuisance,
        if (direction < 0) "lower" else "upper", "refinement"
      )
      points[[length(points) + 1L]] <- point
      if (!successful(point)) {
        return(list(
          status = "refinement_failed", points = points, endpoint = NA_real_,
          bracket = c(
            bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
          ), refinement_iterations = iterations
        ))
      }
      if (point$row$objective_delta[[1L]] >= threshold) {
        bracket$outside <- point
      } else {
        bracket$inside <- point
      }
    }

    width <- abs(bracket$outside$row$target - bracket$inside$row$target)
    if (width > bracket_tolerance) {
      return(list(
        status = "refinement_truncated", points = points, endpoint = NA_real_,
        bracket = c(
          bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
        ), refinement_iterations = iterations
      ))
    }
    endpoint <- mean(c(
      bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
    ))
    list(
      status = "crossed", points = points, endpoint = endpoint,
      bracket = c(
        bracket$inside$row$target[[1L]], bracket$outside$row$target[[1L]]
      ), refinement_iterations = iterations
    )
  }

  lower <- walk_side(-1)
  upper <- walk_side(1)
  trace <- rbind(
    do.call(rbind, lapply(lower$points, `[[`, "row")),
    centre,
    do.call(rbind, lapply(upper$points, `[[`, "row"))
  )

  list(
    trace = trace,
    target_index = as.integer(which),
    target_name = names(fit$opt$par)[which],
    mle = mle_par[which],
    mle_objective = mle_objective,
    threshold = threshold,
    centre_status = centre_status,
    lower_status = lower$status,
    upper_status = upper$status,
    lower_endpoint = lower$endpoint,
    upper_endpoint = upper$endpoint,
    lower_bracket = lower$bracket,
    upper_bracket = upper$bracket,
    lower_refinement_iterations = lower$refinement_iterations,
    upper_refinement_iterations = upper$refinement_iterations,
    bracket_tolerance = bracket_tolerance,
    finite_stable = identical(centre_status, "matched") &&
      identical(lower$status, "crossed") &&
      identical(upper$status, "crossed"),
    objective_source = if (nuisance_fixed) {
      "fit$mspl$unpenalized_tmb_obj (unpenalized Laplace at fixed MSPL nuisance)"
    } else {
      "fit$tmb_obj (penalised LA-MSPL)"
    },
    objective = objective,
    tape = tape,
    design_125_fork = if (nuisance_fixed) "B" else "A",
    nuisance_treatment = if (nuisance_fixed) "fixed_at_mspl" else "reoptimized",
    reference_is_maximum = !nuisance_fixed,
    ## Computability != coverage.  These fields exist so that no caller, and no
    ## future reader of a stored probe, can mistake a finite bracket for a
    ## calibrated interval.  Kosmidis & Firth (2021, Biometrika 108(1), s2.2
    ## p.5) state that the coverage failure of Wald intervals under a
    ## finiteness penalty "is also true when the penalized likelihood is
    ## profiled for the construction of confidence intervals": the mechanism is
    ## that the penalised estimator takes finitely many finite values while the
    ## parameter is unbounded, so profiling changes the interval's shape and not
    ## the boundedness of what it is built from.  See
    ## docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md.
    calibrated = FALSE,
    public_confint = "refused",
    coverage_claim = "none"
  )
}

## Private profile candidate only. The feasibility helper supplies endpoints
## from a bounded bisection of a finite, converged bracket -- on the penalised
## objective (fork A) or on the unpenalized Laplace objective at fixed MSPL
## nuisance (fork B). These are not confidence-interval endpoints under either
## fork.
.gllvmTMB_mspl_profile_sources <- c(
  "fit$tmb_obj (penalised LA-MSPL)",
  "fit$mspl$unpenalized_tmb_obj (unpenalized Laplace at fixed MSPL nuisance)"
)

.gllvmTMB_mspl_profile_threshold_diagnostic <- function(probe) {
  if (!is.list(probe) ||
      !isTRUE(probe$objective_source %in% .gllvmTMB_mspl_profile_sources)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile-threshold diagnostic requires an MSPL profile probe.",
      "i" = "Admitted objective sources are the penalised tape (fork A) and the unpenalized Laplace tape at fixed MSPL nuisance (fork B).",
      class = "gllvmTMB_mspl_profile_threshold_input"
    )
  }
  required <- c(
    "trace", "mle", "threshold", "centre_status", "lower_status",
    "upper_status", "lower_endpoint", "upper_endpoint", "lower_bracket",
    "upper_bracket", "objective", "tape", "nuisance_treatment",
    "reference_is_maximum"
  )
  if (!all(required %in% names(probe)) || !is.data.frame(probe$trace)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL profile-threshold diagnostic received an incomplete probe.",
      class = "gllvmTMB_mspl_profile_threshold_input"
    )
  }

  list(
    target_index = probe$target_index,
    target_name = probe$target_name,
    estimate = probe$mle,
    threshold = probe$threshold,
    centre_status = probe$centre_status,
    lower_status = probe$lower_status,
    upper_status = probe$upper_status,
    diagnostic_lower = probe$lower_endpoint,
    diagnostic_upper = probe$upper_endpoint,
    lower_bracket = probe$lower_bracket,
    upper_bracket = probe$upper_bracket,
    objective_source = probe$objective_source,
    objective = probe$objective,
    tape = probe$tape,
    design_125_fork = probe$design_125_fork,
    nuisance_treatment = probe$nuisance_treatment,
    reference_is_maximum = probe$reference_is_maximum,
    calibrated = FALSE,
    public_confint = "refused",
    coverage_claim = "none"
  )
}

## Resolve b_fix = b_fixed + K gamma and return X_* = X_fix K.  TMB maps use
## factor levels to represent shared free parameters and NA to represent pinned
## coordinates.  The present public Xcoef_fixed surface only pins zeros, but
## handling ties here makes the derivative-design construction agree with TMB's
## general map semantics rather than relying on that temporary API restriction.
.gllvmTMB_mspl_fixed_design <- function(X_fix, b_map = NULL) {
  X_fix <- as.matrix(X_fix)
  if (!is.numeric(X_fix) || any(!is.finite(X_fix))) {
    .gllvmTMB_mspl_abort(
      "LA-MSPL requires a finite numeric fixed-effect design matrix.",
      "x" = "The resolved {.field X_fix} contains a non-finite value."
    )
  }

  n_beta <- ncol(X_fix)
  if (is.null(b_map)) {
    K <- diag(n_beta)
    if (n_beta == 0L) K <- matrix(numeric(0), 0L, 0L)
  } else {
    map_code <- as.integer(b_map)
    if (length(map_code) != n_beta) {
      .gllvmTMB_mspl_abort(
        "Internal LA-MSPL map mismatch.",
        "x" = "The {.field b_fix} map has {length(map_code)} entries for {n_beta} design columns.",
        class = "gllvmTMB_mspl_internal_map"
      )
    }
    n_free <- if (all(is.na(map_code))) 0L else max(map_code, na.rm = TRUE)
    K <- matrix(0, nrow = n_beta, ncol = n_free)
    keep <- which(!is.na(map_code))
    if (length(keep)) K[cbind(keep, map_code[keep])] <- 1
  }

  X_mspl <- unname(X_fix %*% K)
  p_beta <- ncol(X_mspl)
  if (p_beta < 1L) {
    .gllvmTMB_mspl_abort(
      "LA-MSPL requires at least one free fixed-effect coefficient.",
      "i" = "An interceptless or fully pinned fixed-effect model is outside the current LA-MSPL contract."
    )
  }

  singular_values <- svd(X_mspl, nu = 0L, nv = 0L)$d
  rank_tol <- max(dim(X_mspl)) * max(singular_values) * .Machine$double.eps
  rank_x <- sum(singular_values > rank_tol)
  if (rank_x != p_beta) {
    .gllvmTMB_mspl_abort(
      c(
        "The resolved LA-MSPL fixed-effect design is rank deficient.",
        "x" = "Numerical rank is {rank_x}; {p_beta} free coefficient{?s} remain after maps and ties.",
        ">" = "Remove aliased fixed effects or pin a redundant coefficient with {.arg Xcoef_fixed} before fitting."
      ),
      class = "gllvmTMB_mspl_rank_deficient"
    )
  }

  list(
    X = X_mspl,
    K = K,
    p_beta = as.integer(p_beta),
    rank = as.integer(rank_x),
    rank_tolerance = rank_tol
  )
}

.gllvmTMB_mspl_tau_representatives <- function(log_tau, tau_map = NULL) {
  n_tau <- length(log_tau)
  if (n_tau < 1L) {
    .gllvmTMB_mspl_abort(
      "Spatial-independent LA-MSPL requires at least one free spatial scale.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  if (is.null(tau_map)) {
    return(as.integer(seq_len(n_tau) - 1L))
  }

  map_code <- as.integer(tau_map)
  if (length(map_code) != n_tau) {
    .gllvmTMB_mspl_abort(
      "Internal LA-MSPL spatial-scale map mismatch.",
      class = "gllvmTMB_mspl_internal_map"
    )
  }
  free_levels <- sort(unique(map_code[!is.na(map_code)]))
  if (!length(free_levels)) {
    .gllvmTMB_mspl_abort(
      "Spatial-independent LA-MSPL requires a free spatial scale.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  as.integer(vapply(
    free_levels,
    function(level) which(map_code == level)[1L] - 1L,
    integer(1L)
  ))
}

.gllvmTMB_mspl_spde_r0 <- function(mesh) {
  if (is.null(mesh) || is.null(mesh$loc_xy)) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL requires a resolved {.fn make_mesh} object.",
      class = "gllvmTMB_mspl_internal_surface"
    )
  }
  locations <- unique(as.matrix(mesh$loc_xy))
  if (
    !is.numeric(locations) ||
      ncol(locations) != 2L ||
      nrow(locations) < 2L ||
      any(!is.finite(locations))
  ) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL requires at least two distinct finite observed locations."
    )
  }
  centred <- sweep(locations, 2L, colMeans(locations), FUN = "-")
  r0 <- sqrt(mean(rowSums(centred^2)))
  if (length(r0) != 1L || !is.finite(r0) || r0 <= 0) {
    .gllvmTMB_mspl_abort(
      "The spatial LA-MSPL reference distance is not positive and finite."
    )
  }
  unname(r0)
}

## Preflight the deliberately narrow point-estimator surface.  This runs
## after maps and the random-effect vector have been resolved, so admission is
## based on the model TMB will actually see rather than formula spelling.
.gllvmTMB_mspl_prepare <- function(
  X_fix,
  b_map,
  y,
  n_trials,
  is_y_observed,
  family_id_vec,
  link_id_vec,
  offset_vec,
  random,
  use_rr_B,
  use_lv_B,
  use_rr_B_slope,
  use_diag_B,
  diag_B_all_skipped,
  d_B,
  theta_rr_B,
  theta_diag_B = NULL,
  lambda_constraint,
  use_spde,
  is_spatial_indep,
  is_spatial_scalar,
  is_spatial_latent,
  is_spatial_dep,
  use_spde_latent_diag,
  use_spde_slope,
  use_spde_latent_slope,
  d_spde_lv,
  theta_rr_spde_lv,
  log_tau_spde,
  log_tau_spde_map,
  mesh,
  use_mi_predictor,
  integration,
  engine,
  REML,
  ridge_explicit,
  unit_id = NULL,
  trait_id = NULL,
  sigma_eps_mapped = FALSE
) {
  if (isTRUE(REML)) {
    .gllvmTMB_mspl_abort(
      "{.code estimator = \"mspl\"} cannot be combined with {.code REML = TRUE}."
    )
  }
  if (!identical(engine, "tmb") || !identical(integration, "laplace")) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL currently requires the native TMB Laplace route.",
      "x" = "Received engine {.val {engine}} and integration {.val {integration}}."
    ))
  }
  if (isTRUE(ridge_explicit)) {
    .gllvmTMB_mspl_abort(c(
      "Do not combine {.code estimator = \"mspl\"} with an explicit loading ridge.",
      "i" = "MSPL and {.arg loading_ridge} (or its compatibility spelling {.arg aghq_ridge}) are different penalties; combining them would define an unvalidated hybrid estimator."
    ))
  }

  fam_ids <- unique(as.integer(family_id_vec))
  ## 7 = Beta-logit planned door (#1045 atom is FCN K_bb).
  ## Public door stays closed for Tweedie. The probe env is a
  ## timeout-bounded hang check only — not a user-facing door and
  ## not an admit. Keep the public `%in%` literal intact for the
  ## Gamma / lognormal / hurdle source pins. Default unset: family 6
  ## still aborts here.
  probe_tweedie <- identical(Sys.getenv("GLLVMTMB_MSPL_TWEEDIE_PROBE"), "1") &&
    identical(fam_ids, 6L)
  if (!isTRUE(probe_tweedie) && (length(fam_ids) != 1L || !fam_ids %in% c(0L, 1L, 2L, 5L, 7L, 15L))) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL supports a single gaussian, bernoulli, Poisson, nbinom1, nbinom2, or Beta response family only.",
      "i" = "Tweedie and mixed-family MSPL remain deferred at the public door."
    ))
  }
  is_gaussian <- identical(fam_ids, 0L)
  is_bernoulli <- identical(fam_ids, 1L)
  is_poisson <- identical(fam_ids, 2L)
  is_nbinom2 <- identical(fam_ids, 5L)
  is_nbinom1 <- identical(fam_ids, 15L)
  is_nbinom <- is_nbinom1 || is_nbinom2
  is_tweedie <- identical(fam_ids, 6L)
  is_beta <- identical(fam_ids, 7L)
  is_planned_glm <- is_poisson || is_nbinom || is_tweedie || is_beta

  if (is_bernoulli) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec %in% 0:2)) {
      .gllvmTMB_mspl_abort(c(
        "LA-MSPL requires one common supported binary link.",
        "i" = "Use {.code binomial(link = \"logit\")}, {.code \"probit\"}, or {.code \"cloglog\"}."
      ))
    }
    if (!all(n_trials == 1) || !all(y %in% c(0, 1))) {
      .gllvmTMB_mspl_abort(c(
        "LA-MSPL requires single-trial Bernoulli observations.",
        "i" = "Grouped and weighted binomial MSPL is deferred."
      ))
    }
  } else if (is_gaussian) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL requires the identity link.",
        "i" = "Use {.code gaussian(link = \"identity\")}."
      ))
    }
    if (any(!is.finite(y))) {
      .gllvmTMB_mspl_abort("Gaussian LA-MSPL requires finite responses.")
    }
  } else if (is_poisson) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Poisson LA-MSPL requires the log link.",
        "i" = "Use {.code poisson(link = \"log\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y < 0)) {
      .gllvmTMB_mspl_abort(
        "Poisson LA-MSPL requires finite non-negative counts."
      )
    }
  } else if (is_nbinom) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "nbinom1/nbinom2 LA-MSPL requires the log link.",
        "i" = "Use {.code nbinom1(link = \"log\")} or {.code nbinom2(link = \"log\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y < 0)) {
      .gllvmTMB_mspl_abort(
        "nbinom1/nbinom2 LA-MSPL requires finite non-negative counts."
      )
    }
  } else if (is_tweedie) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Tweedie LA-MSPL requires the log link.",
        "i" = "Use {.code tweedie(link = \"log\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y < 0)) {
      .gllvmTMB_mspl_abort(
        "Tweedie LA-MSPL requires finite non-negative responses."
      )
    }
  } else if (is_beta) {
    if (length(unique(link_id_vec)) != 1L || !all(link_id_vec == 0L)) {
      .gllvmTMB_mspl_abort(c(
        "Beta LA-MSPL requires the logit link.",
        "i" = "Use {.code Beta(link = \"logit\")}."
      ))
    }
    if (any(!is.finite(y)) || any(y <= 0) || any(y >= 1)) {
      .gllvmTMB_mspl_abort(
        "Beta LA-MSPL requires finite responses strictly inside (0, 1)."
      )
    }
  }
  if (!all(is_y_observed == 1L)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires complete responses.",
      "i" = "FIML-MSPL and retained response masks are deferred."
    ))
  }
  if (any(!is.finite(offset_vec))) {
    .gllvmTMB_mspl_abort("LA-MSPL requires finite known offsets.")
  }
  if (any(offset_vec != 0)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires an all-zero offset vector.",
      "i" = "Nonzero offsets remain outside the frozen validation campaign."
    ))
  }
  ordinary <- isTRUE(use_rr_B) && !isTRUE(use_spde)
  spatial_indep <- !isTRUE(use_rr_B) &&
    isTRUE(use_spde) &&
    isTRUE(is_spatial_indep) &&
    !isTRUE(is_spatial_scalar) &&
    !isTRUE(is_spatial_latent) &&
    !isTRUE(is_spatial_dep)
  spatial_latent <- !isTRUE(use_rr_B) &&
    isTRUE(use_spde) &&
    isTRUE(is_spatial_latent) &&
    !isTRUE(is_spatial_dep)

  if (is_gaussian) {
    if (!isTRUE(ordinary) || isTRUE(spatial_indep) || isTRUE(spatial_latent)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL admits only ordinary {.fn latent} with {.arg unique = TRUE}.",
        "i" = "Spatial and other structures are deferred."
      ))
    }
  } else if (is_planned_glm) {
    if (!isTRUE(ordinary) || isTRUE(spatial_indep) || isTRUE(spatial_latent)) {
      .gllvmTMB_mspl_abort(c(
        if (is_poisson) {
          "Poisson LA-MSPL admits only ordinary {.fn latent}."
        } else if (is_nbinom) {
          "nbinom1/nbinom2 LA-MSPL admits only ordinary {.fn latent}."
        } else if (is_tweedie) {
          "Tweedie LA-MSPL admits only ordinary {.fn latent}."
        } else {
          "Beta LA-MSPL admits only ordinary {.fn latent}."
        },
        "i" = "Spatial and other structures are deferred."
      ))
    }
  } else if (sum(c(ordinary, spatial_indep, spatial_latent)) != 1L) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL requires exactly one admitted covariance structure.",
      "i" = "Use ordinary {.fn latent}, standalone {.fn spatial_indep}, or standalone {.fn spatial_latent} with rank 1 or 2."
    ))
  }

  if (
    ordinary &&
      (!d_B %in% c(1L, 2L) || isTRUE(use_lv_B) || isTRUE(use_rr_B_slope))
  ) {
    .gllvmTMB_mspl_abort(c(
      "Ordinary LA-MSPL supports one intercept-only {.fn latent} block with {.arg d} equal to 1 or 2.",
      "i" = "Predictor-informed latent means, latent slopes, and q > 2 are deferred."
    ))
  }
  if (
    spatial_latent &&
      (!d_spde_lv %in% c(1L, 2L) ||
        isTRUE(use_spde_latent_diag))
  ) {
    .gllvmTMB_mspl_abort(c(
      "Spatial-latent LA-MSPL supports {.fn spatial_latent} with {.arg d} equal to 1 or 2 and no unique companion.",
      "i" = "Free spatial Psi coordinates and q > 2 are deferred."
    ))
  }
  if (!ordinary && (isTRUE(use_diag_B) || isTRUE(use_rr_B_slope))) {
    .gllvmTMB_mspl_abort(
      "Spatial LA-MSPL cannot be combined with an ordinary latent or Psi block."
    )
  }
  if (isTRUE(use_spde_slope) || isTRUE(use_spde_latent_slope)) {
    .gllvmTMB_mspl_abort(
      "Spatial random slopes are outside the current LA-MSPL contract."
    )
  }
  if (
    is_bernoulli &&
      ordinary &&
      isTRUE(use_diag_B) &&
      !isTRUE(diag_B_all_skipped)
  ) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL does not estimate a Bernoulli Psi companion.",
      "i" = "The automatic Bernoulli Psi may remain in the parsed formula only when every coordinate is mapped off."
    ))
  }
  if (is_gaussian) {
    if (!isTRUE(use_diag_B) || isTRUE(diag_B_all_skipped)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL requires free unique Psi.",
        "i" = "Use {.code latent(..., unique = TRUE)} on ordinary complete data so Q7 pins {.code sigma_eps}."
      ))
    }
    if (!isTRUE(sigma_eps_mapped)) {
      .gllvmTMB_mspl_abort(c(
        "Gaussian LA-MSPL requires {.code sigma_eps} mapped off (pick C / Q7).",
        "i" = "The Hirose atom targets {.code sd_B^2} only when residual SD is not a free share."
      ))
    }
  }
  expected_random <- if (is_gaussian) {
    c("z_B", "s_B")
  } else if (ordinary) {
    "z_B"
  } else if (spatial_indep) {
    "omega_spde"
  } else {
    "omega_spde_lv"
  }
  if (!identical(as.character(random), expected_random)) {
    .gllvmTMB_mspl_abort(c(
      "LA-MSPL admits exactly one structure-specific Laplace-random block.",
      "x" = "Expected {.val {expected_random}}; resolved {.val {random}}.",
      "i" = "Additional random effects and structured covariance tiers are deferred."
    ))
  }
  if (isTRUE(use_mi_predictor)) {
    .gllvmTMB_mspl_abort(
      "Modelled missing predictors are outside the current LA-MSPL contract."
    )
  }
  if (
    !is.null(lambda_constraint) &&
      length(Filter(Negate(is.null), lambda_constraint))
  ) {
    .gllvmTMB_mspl_abort(c(
      "Confirmatory loading constraints are outside the current LA-MSPL contract.",
      "i" = "Fit the exploratory lower-triangular ordinary latent model without {.arg lambda_constraint}."
    ))
  }

  fixed <- .gllvmTMB_mspl_fixed_design(X_fix, b_map)
  structure <- if (ordinary) {
    "ordinary"
  } else if (spatial_indep) {
    "spatial_indep"
  } else {
    "spatial_latent"
  }
  tau_representative <- as.integer(-1L)
  spde_r0 <- 1
  p_psi <- 0L
  mspl_S_diag <- 0
  mspl_N_units <- 0L
  if (ordinary) {
    p_loading <- length(theta_rr_B)
    p_covariance <- 0L
    expected_outer <- c("b_fix", "theta_rr_B")
    if (is_gaussian) {
      p_psi <- length(theta_diag_B)
      if (!is.finite(p_psi) || p_psi < 1L) {
        .gllvmTMB_mspl_abort(
          "Gaussian LA-MSPL requires a free {.code theta_diag_B} Psi block."
        )
      }
      expected_outer <- c(expected_outer, "theta_diag_B")
      if (is.null(unit_id) || is.null(trait_id)) {
        .gllvmTMB_mspl_abort(
          "Internal Gaussian LA-MSPL missing unit/trait ids for S."
        )
      }
      mspl_S_diag <- .gllvmTMB_mspl_S_diag(y, trait_id, unit_id)
      mspl_N_units <- length(unique(as.integer(unit_id)))
    } else if (is_nbinom2) {
      ## Free per-trait phi is an outer block. C++ p_free still excludes it
      ## (Jeffreys-on-phi DROPPED; rate uses data-plugin I_NB2, not c=1).
      expected_outer <- c(expected_outer, "log_phi_nbinom2")
    } else if (is_nbinom1) {
      expected_outer <- c(expected_outer, "log_phi_nbinom1")
    } else if (is_tweedie) {
      ## Free per-trait phi and power. C++ p_free still excludes them
      ## (Jeffreys rate is unpinned c=1; not an nbinom transplant).
      expected_outer <- c(expected_outer, "log_phi_tweedie", "logit_p_tweedie")
    } else if (is_beta) {
      expected_outer <- c(expected_outer, "log_phi_beta")
    }
  } else if (spatial_indep) {
    tau_representative <- .gllvmTMB_mspl_tau_representatives(
      log_tau_spde,
      log_tau_spde_map
    )
    p_loading <- 0L
    p_covariance <- length(tau_representative) + 1L
    expected_outer <- c("b_fix", "log_tau_spde", "log_kappa_spde")
    spde_r0 <- .gllvmTMB_mspl_spde_r0(mesh)
  } else {
    p_loading <- length(theta_rr_spde_lv)
    p_covariance <- 1L
    expected_outer <- c("b_fix", "theta_rr_spde_lv", "log_kappa_spde")
    spde_r0 <- .gllvmTMB_mspl_spde_r0(mesh)
  }
  p_free <- fixed$p_beta + p_loading + p_covariance + p_psi
  N_eff <- if (is_bernoulli) {
    sum(n_trials)
  } else {
    length(y)
  }
  if (!is.finite(N_eff) || N_eff <= 0) {
    .gllvmTMB_mspl_abort("LA-MSPL requires a positive effective sample size.")
  }

  family_name <- if (is_gaussian) {
    "gaussian"
  } else if (is_poisson) {
    "poisson"
  } else if (is_nbinom2) {
    "nbinom2"
  } else if (is_nbinom1) {
    "nbinom1"
  } else if (is_tweedie) {
    "tweedie"
  } else if (is_beta) {
    "Beta"
  } else {
    "binomial"
  }
  link_name <- .gllvmTMB_mspl_family_link_name(fam_ids, unique(link_id_vec))
  if (is.na(link_name)) {
    .gllvmTMB_mspl_abort("LA-MSPL could not resolve the family/link cell.")
  }
  q_cell <- if (identical(structure, "ordinary")) {
    as.integer(d_B)
  } else if (identical(structure, "spatial_latent")) {
    as.integer(d_spde_lv)
  } else {
    NA_integer_
  }
  registry_row <- .gllvmTMB_mspl_registry_lookup(
    family = family_name,
    link = link_name,
    structure = structure,
    q = q_cell
  )
  if (is.null(registry_row)) {
    .gllvmTMB_mspl_abort(
      c(
        "LA-MSPL resolved a surface that is not a registry cell.",
        "x" = "family {.val {family_name}}, link {.val {link_name}}, structure {.val {structure}}, q {.val {q_cell}}."
      ),
      class = "gllvmTMB_mspl_registry_miss"
    )
  }
  ## Bernoulli: admitted only. Gaussian ordinary: planned allowed during
  ## implement smoke; flip to admitted after se=FALSE smoke (point only —
  ## SE/intervals remain PROTECTED on codex/lane-b-mspl-interval-feasibility).
  ok_status <- if (is_gaussian || is_planned_glm) {
    registry_row$status %in% c("admitted", "planned")
  } else {
    identical(registry_row$status, "admitted")
  }
  if (!isTRUE(ok_status)) {
    .gllvmTMB_mspl_abort(
      c(
        "LA-MSPL resolved a surface that is not an admitted registry cell.",
        "x" = "family {.val {family_name}}, link {.val {link_name}}, structure {.val {structure}}, q {.val {q_cell}}, status {.val {registry_row$status}}."
      ),
      class = "gllvmTMB_mspl_registry_miss"
    )
  }

  ## Poisson c_P uses event count. nbinom uses a family data-plugin
  ## information size (not N_rows, not sum(y), not c = 1).
  rate <- if (is_gaussian) {
    sqrt(2 / mspl_N_units)
  } else if (is_poisson) {
    .gllvmTMB_mspl_poisson_rate(
      p_free,
      .gllvmTMB_mspl_poisson_event_count(y)
    )
  } else if (is_nbinom2) {
    if (is.null(trait_id)) {
      .gllvmTMB_mspl_abort(
        "nbinom2 LA-MSPL rate requires trait ids for the data-plugin information size."
      )
    }
    .gllvmTMB_mspl_nbinom2_rate(p_free, y, trait_id)
  } else if (is_nbinom1) {
    if (is.null(trait_id)) {
      .gllvmTMB_mspl_abort(
        "nbinom1 LA-MSPL rate requires trait ids for the data-plugin information size."
      )
    }
    .gllvmTMB_mspl_nbinom1_rate(p_free, y, trait_id)
  } else if (is_tweedie || is_beta) {
    1
  } else {
    2 * sqrt(p_free / N_eff)
  }

  list(
    estimator_id = 1L,
    family = family_name,
    X_mspl = fixed$X,
    N_eff = as.numeric(N_eff),
    p_beta = fixed$p_beta,
    p_loading = as.integer(p_loading),
    p_covariance = as.integer(p_covariance),
    p_psi = as.integer(p_psi),
    p_free = as.integer(p_free),
    rate = rate,
    mspl_S_diag = as.numeric(mspl_S_diag),
    mspl_N_units = as.integer(mspl_N_units),
    fixed_design = fixed,
    structure = structure,
    expected_outer = expected_outer,
    expected_random = expected_random,
    spde_r0 = spde_r0,
    tau_representative = tau_representative,
    registry_cell = registry_row$cell_id,
    registry_status = registry_row$status,
    registry_evidence = registry_row$evidence,
    scope = if (is_gaussian) {
      paste0(
        "complete gaussian identity; ordinary latent(unique=TRUE) q=",
        d_B,
        "; Hirose pick C; Laplace"
      )
    } else if (is_poisson) {
      paste0(
        "complete poisson log; ordinary latent q=",
        d_B,
        "; GLM-outer W=diag(mu) candidate (not I_LA(beta)); ",
        "c_P=2*sqrt(p_free/max(sum(y),1)); event-weighted loading atom; ",
        "planned tape, not admitted; Laplace"
      )
    } else if (is_nbinom2) {
      paste0(
        "complete nbinom2 log; ordinary latent q=",
        d_B,
        "; GLM-outer W=mu*phi/(phi+mu) candidate (not I_LA(beta)); ",
        "c_NB2=2*sqrt(p_free/max(I_NB2,1)) data-plugin tr(W); ",
        "information-weighted loading atom; Jeffreys-on-phi dropped; ",
        "planned tape, not admitted; Laplace"
      )
    } else if (is_nbinom1) {
      paste0(
        "complete nbinom1 log; ordinary latent q=",
        d_B,
        "; GLM-outer PMF-summed exact I (not quasi W=mu/(1+phi)); ",
        "c_NB1=2*sqrt(p_free/max(I_NB1,1)) data-plugin exact I_eta; ",
        "information-weighted loading atom; planned tape, not admitted; Laplace"
      )
    } else if (is_tweedie) {
      paste0(
        "complete tweedie log; ordinary latent q=",
        d_B,
        "; GLM-outer working logistic W_* (true W=mu^{2-p}/phi rewards phi->0; not I_LA(beta)); ",
        "Huber on log_phi and logit(p-1); unpinned c=1; planned tape, not admitted; Laplace"
      )
    } else if (is_beta) {
      paste0(
        "complete Beta logit; ordinary latent q=",
        d_B,
        "; GLM-outer Jeffreys I_mu (not coercive at 0/1; not I_LA(beta)); ",
        "unpinned c=1; planned tape, not admitted; Laplace"
      )
    } else {
      paste0(
        "complete Bernoulli; ",
        structure,
        if (structure == "spatial_latent") {
          paste0("(q=", d_spde_lv, ")")
        } else if (structure == "ordinary") {
          paste0("(q=", d_B, ")")
        } else {
          ""
        },
        "; Laplace; one common logit/probit/cloglog link"
      )
    }
  )
}
