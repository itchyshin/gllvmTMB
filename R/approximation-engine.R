## Private adapter for the sealed VA-R3 and EVA Gate-1 research engines.
##
## This is deliberately not connected to gllvmTMB(), its fitted-object class,
## or likelihood-based model-comparison methods.  The result is a small common
## research contract, not a package fitting API.

.approximation_engine_regime <- function(engine) {
  switch(engine,
    va_r3 = list(
      family = "binomial or Poisson",
      trials = "complete cells (binomial: integer n_trials >= 1; Poisson: no trials)",
      link = "logit or log",
      ## Stage 6: `unique = TRUE` is admitted as a trait-diagonal Psi tier,
      ## which Design 106 Proposition 2 makes exact rather than approximate.
      ## The description is a string rather than FALSE because the honest
      ## answer is no longer a single flag.
      unique = "FALSE, or TRUE as an exact trait-diagonal Psi tier (Design 106 Prop. 2)",
      covariance = "unstructured tiers only: ordinary latent loadings, optionally plus dense or trait-diagonal extra tiers; no structured (phylo/SPDE) prior"
    ),
    eva = list(
      family = "binomial, Poisson, or Gaussian (identity, test-only)",
      trials = "complete cells (binomial: integer n_trials >= 1; Poisson: no trials)",
      link = "logit, log, or identity (Gaussian test anchor)",
      unique = FALSE,
      covariance = "ordinary latent loadings only",
      fixture_only = FALSE,
      legacy_fixture_evaluation_available = TRUE
    )
  )
}

.approximation_engine_result <- function(engine, objective_type, diagnostics,
                                         provenance, score, fixed = list(),
                                         fitted = list(), status = NA_character_,
                                         evaluation = list(),
                                         engine_result = NULL) {
  structure(list(
    engine = engine,
    objective_type = objective_type,
    research_only = TRUE,
    admitted_regime = .approximation_engine_regime(engine),
    diagnostics = diagnostics,
    provenance = provenance,
    score = score,
    fixed = fixed,
    fitted = fitted,
    status = status,
    evaluation = evaluation,
    engine_result = engine_result
  ), class = "gllvmTMB_approximation_result")
}

.approximation_engine_scalar_character <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(name, " must be one non-missing character string.", call. = FALSE)
  }
  x
}

.approximation_engine_va_r3_fit <- function(
    y, n_trials, X, unit_id, trait_id, q,
    N = NULL, T = NULL, family = "binomial", link = "logit",
    unique = FALSE, psi = FALSE, structured = FALSE, provider = NULL,
    lv = FALSE, missing = FALSE, H = 61L,
    rank_source = c("fixed_fixture", "ml_bic"), fixed_global = NULL,
    source = NULL, rebuild = FALSE,
    control = list(eval.max = 2000L, iter.max = 2000L), silent = TRUE,
    eval_method = c("auto", "jj", "gh"),
    is_y_observed = NULL,
    family_codes = NULL,
    extra_tiers = NULL) {
  eval_method <- match.arg(eval_method)
  ## Design 108 Gate A Stage 6 lifted the `unique` refusal here IN LOCKSTEP
  ## with .va_r3_validate_data() (R/va-r3-proto.R). Two copies of one gate that
  ## disagree is worse than either: this adapter would refuse a model the
  ## engine admits, or -- after the engine relaxed -- admit one silently by a
  ## different route. `unique`/`psi` now travel through to the validator, which
  ## turns them into a trait-diagonal Psi tier; `structured`, `provider`, `lv`
  ## and `missing` are still refused there, unchanged.
  ##
  ## This does NOT open the public route. R/integration-fence.R still refuses
  ## `unique = TRUE` under `integration = "va"`, and nothing in this arc
  ## touched it: there is no VA recovery evidence for a multi-tier or diag(psi)
  ## model, and the fence is where that evidence gate lives.
  if (is.null(family_codes)) {
    family <- .approximation_engine_scalar_character(family, "family")
    link <- .approximation_engine_scalar_character(link, "link")
    expected_link <- switch(family,
      binomial = "logit", poisson = "log",
      gaussian = "identity", gaussian_anchor = "identity",
      NA_character_
    )
    if (is.na(expected_link) || !identical(link, expected_link)) {
      stop(
        "VA-R3 admits dense binomial-logit, Poisson-log, or Gaussian-identity data.",
        call. = FALSE
      )
    }
    if (identical(eval_method, "jj") && !identical(family, "binomial")) {
      stop(
        "eval_method = \"jj\" (Jaakkola-Jordan/PG bound) is only defined for the binomial family.",
        call. = FALSE
      )
    }
  } else {
    family_codes <- as.integer(family_codes)
    if (identical(eval_method, "jj") && !all(family_codes == 1L)) {
      stop(
        "eval_method = \"jj\" (Jaakkola-Jordan/PG bound) is only defined for pure-binomial VA fits.",
        call. = FALSE
      )
    }
  }

  ## Validate before .va_r3_fit() can construct a quadrature objective.
  .va_r3_validate_data(
    y = y, n_trials = n_trials, X = X, unit_id = unit_id,
    trait_id = trait_id, q = q, N = N, T = T,
    family = family, link = link, unique = unique,
    psi = psi, structured = structured, provider = provider, lv = lv,
    missing = missing, is_y_observed = is_y_observed,
    family_codes = family_codes, extra_tiers = extra_tiers
  )
  started <- proc.time()[["elapsed"]]
  raw <- .va_r3_fit(
    y = y, n_trials = n_trials, X = X, unit_id = unit_id,
    trait_id = trait_id, q = q, N = N, T = T,
    family = family, link = link, unique = unique,
    psi = psi, structured = structured, provider = provider, lv = lv,
    missing = missing, H = H, rank_source = rank_source,
    fixed_global = fixed_global, source = source, rebuild = rebuild,
    control = control, silent = silent, eval_method = eval_method,
    is_y_observed = is_y_observed, family_codes = family_codes,
    extra_tiers = extra_tiers
  )
  elapsed <- proc.time()[["elapsed"]] - started
  best <- raw$best %||% list()

  .approximation_engine_result(
    engine = "va_r3",
    objective_type = raw$objective_type %||% "ELBO_GH",
    diagnostics = list(
      status = raw$status %||% NA_character_,
      convergence = best$convergence %||% NA_integer_,
      max_abs_gradient = best$max_abs_gradient %||% NA_real_,
      runtime_seconds = elapsed,
      health = raw$health %||% NULL
    ),
    provenance = list(
      implementation = "R/va-r3-proto.R",
      source_commit = raw$source_commit %||% NA_character_,
      source_checksum = raw$source_checksum %||% NA_character_,
      rank_source = raw$rank_source %||% NA_character_,
      eval_method = raw$eval_method %||% NA_character_
    ),
    score = list(
      negative_elbo_gh = best$objective %||% NA_real_,
      direction = "minimize",
      model_selection_comparable = FALSE
    ),
    fixed = list(global = raw$fixed_global %||% FALSE),
    fitted = list(
      q = raw$q %||% q,
      parameters = best$par %||% NULL,
      objective_constructed = raw$objective_constructed %||% !is.null(raw$objective)
    ),
    status = raw$status %||% NA_character_,
    engine_result = raw
  )
}

.approximation_engine_eva_helpers <- function() {
  required <- c(".eva_fixture", ".eva_make_objective", ".eva_evaluate")
  present <- vapply(required, exists, logical(1), envir = environment(),
                    inherits = TRUE)
  if (!all(present)) {
    stop(
      "The sealed EVA Gate-1 helpers are unavailable; EVA cannot construct an objective.",
      call. = FALSE
    )
  }
  mget(required, envir = environment(), inherits = TRUE)
}

.approximation_engine_validate_eva_fixture <- function(x) {
  required <- c("y", "X", "unit_id", "trait_id", "N", "T", "q")
  if (!is.list(x) || !all(required %in% names(x))) {
    stop("EVA requires a complete sealed Gate-1 fixture.", call. = FALSE)
  }
  N <- x$N
  T <- x$T
  if (length(N) != 1L || length(T) != 1L || !is.finite(N) || !is.finite(T) ||
      N != as.integer(N) || T != as.integer(T) || N < 1L || T < 1L ||
      !is.numeric(x$y) || any(!is.finite(x$y)) || any(!(x$y %in% c(0, 1))) ||
      !is.matrix(x$X) || !is.numeric(x$X) || any(!is.finite(x$X)) ||
      nrow(x$X) != length(x$y) || length(x$unit_id) != length(x$y) ||
      length(x$trait_id) != length(x$y)) {
    stop("EVA admits only complete Bernoulli-logit Gate-1 fixture data.", call. = FALSE)
  }
  unit <- as.integer(x$unit_id)
  trait <- as.integer(x$trait_id)
  cell <- unit * as.integer(T) + trait
  if (length(x$y) != as.integer(N) * as.integer(T) ||
      any(!is.finite(unit)) || any(!is.finite(trait)) ||
      !identical(sort(cell), 0:(as.integer(N) * as.integer(T) - 1L))) {
    stop("EVA admits only one complete Bernoulli observation per unit-trait cell.",
         call. = FALSE)
  }
  invisible(x)
}

.approximation_engine_eva_fit_fixture <- function(
    fixture = c("bernoulli", "bernoulli_q2"), family = "bernoulli",
    link = "logit", unique = FALSE, rebuild = FALSE, silent = TRUE) {
  fixture <- match.arg(fixture)
  family <- .approximation_engine_scalar_character(family, "family")
  link <- .approximation_engine_scalar_character(link, "link")
  if (!identical(family, "bernoulli") || !identical(link, "logit") ||
      !identical(unique, FALSE)) {
    stop(
      "EVA admits only complete Bernoulli-logit data with unique = FALSE.",
      call. = FALSE
    )
  }
  helpers <- .approximation_engine_eva_helpers()
  x <- helpers[[".eva_fixture"]](fixture)
  .approximation_engine_validate_eva_fixture(x)

  ## The sealed Gate-1 driver is evaluation-only: no optimisation or Gate-2R.
  started <- proc.time()[["elapsed"]]
  objective <- helpers[[".eva_make_objective"]](
    fixture = fixture, rebuild = rebuild, silent = silent
  )
  evaluated <- helpers[[".eva_evaluate"]](objective, gradient = TRUE)
  elapsed <- proc.time()[["elapsed"]] - started
  provenance <- attr(objective, "eva_provenance") %||% list()
  report <- objective$report(objective$par)

  .approximation_engine_result(
    engine = "eva",
    objective_type = provenance$objective_type %||% "EVA_TAYLOR2",
    diagnostics = list(
      status = "evaluated_fixed_gate1_fixture",
      convergence = NA_integer_,
      max_abs_gradient = max(abs(evaluated$gradient)),
      runtime_seconds = elapsed
    ),
    provenance = c(
      list(implementation = "R/eva-proto.R", fixture = fixture),
      provenance
    ),
    score = list(
      negative_ell_eva_taylor2 = evaluated$value,
      direction = "minimize",
      model_selection_comparable = FALSE
    ),
    fixed = list(parameters = objective$par, fixture = x),
    fitted = list(
      available = FALSE,
      reason = "EVA Gate-1 is a fixed-coordinate evaluation, not a fitted result."
    ),
    status = "evaluated_fixed_gate1_fixture",
    evaluation = list(
      negative_ell_eva_taylor2 = evaluated$value,
      max_abs_gradient = max(abs(evaluated$gradient)),
      report = report
    ),
    engine_result = list(objective = objective, evaluation = evaluated)
  )
}

## Data-accepting EVA fit, mirroring .approximation_engine_va_r3_fit()'s
## contract shape. Dispatch on `fixture`: when a fixture name is supplied,
## the legacy fixed-coordinate Gate-1 evaluation path above still runs
## unchanged; otherwise this constructs and optimises an EVA objective from
## caller-supplied data via R/eva-proto.R's .eva_fit().
.approximation_engine_eva_fit <- function(
    y = NULL, n_trials = NULL, X = NULL, unit_id = NULL, trait_id = NULL,
    q = NULL, N = NULL, T = NULL, family = NULL, link = NULL,
    unique = FALSE, gaussian_sd = 1, fixture = NULL, source = NULL,
    rebuild = FALSE, control = list(eval.max = 2000L, iter.max = 2000L),
    silent = TRUE) {
  if (!is.null(fixture)) {
    return(.approximation_engine_eva_fit_fixture(
      fixture = fixture, family = family %||% "bernoulli",
      link = link %||% "logit", unique = unique, rebuild = rebuild,
      silent = silent
    ))
  }

  family <- .approximation_engine_scalar_character(family %||% "binomial", "family")
  link <- .approximation_engine_scalar_character(
    link %||% switch(family, binomial = "logit", poisson = "log",
                     gaussian_anchor = "identity", "logit"),
    "link"
  )
  expected_link <- switch(family, binomial = "logit", poisson = "log",
                          gaussian_anchor = "identity", NA_character_)
  if (is.na(expected_link) || !identical(link, expected_link) ||
      !identical(unique, FALSE)) {
    stop(
      "EVA admits only complete binomial-logit, Poisson-log, or Gaussian-identity data with unique = FALSE.",
      call. = FALSE
    )
  }

  started <- proc.time()[["elapsed"]]
  raw <- .eva_fit(
    y = y, n_trials = n_trials, X = X, unit_id = unit_id, trait_id = trait_id,
    q = q, N = N, T = T, family = family, link = link, unique = FALSE,
    gaussian_sd = gaussian_sd, source = source, rebuild = rebuild,
    control = control, silent = silent
  )
  elapsed <- proc.time()[["elapsed"]] - started
  best <- raw$best %||% list()

  .approximation_engine_result(
    engine = "eva",
    objective_type = raw$objective_type %||% "EVA_TAYLOR2",
    diagnostics = list(
      status = raw$status %||% NA_character_,
      convergence = best$convergence %||% NA_integer_,
      max_abs_gradient = best$max_abs_gradient %||% NA_real_,
      runtime_seconds = elapsed
    ),
    provenance = list(
      implementation = "R/eva-proto.R",
      source_commit = raw$source_commit %||% NA_character_,
      source_checksum = raw$source_checksum %||% NA_character_
    ),
    score = list(
      negative_ell_eva_taylor2 = best$objective %||% NA_real_,
      direction = "minimize",
      model_selection_comparable = FALSE
    ),
    fixed = list(),
    fitted = list(
      q = raw$q %||% q,
      parameters = best$par %||% NULL,
      objective_constructed = !is.null(raw$objective)
    ),
    status = raw$status %||% NA_character_,
    engine_result = raw
  )
}

.approximation_engine_fit <- function(engine = c("va_r3", "eva"), ...) {
  engine <- match.arg(engine)
  switch(engine,
    va_r3 = .approximation_engine_va_r3_fit(...),
    eva = .approximation_engine_eva_fit(...)
  )
}
