## Private adapter for the sealed VA-R3 and EVA Gate-1 research engines.
##
## This is deliberately not connected to gllvmTMB(), its fitted-object class,
## or likelihood-based model-comparison methods.  The result is a small common
## research contract, not a package fitting API.

.approximation_engine_regime <- function(engine) {
  switch(engine,
    va_r3 = list(
      family = "binomial",
      trials = "complete multi-trial (integer n_trials >= 2)",
      link = "logit",
      unique = FALSE,
      covariance = "ordinary latent loadings only"
    ),
    eva = list(
      family = "bernoulli",
      trials = "complete one-trial Gate-1 fixture",
      link = "logit",
      unique = FALSE,
      covariance = "ordinary latent loadings only",
      fixture_only = TRUE
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
    control = list(eval.max = 2000L, iter.max = 2000L), silent = TRUE) {
  family <- .approximation_engine_scalar_character(family, "family")
  link <- .approximation_engine_scalar_character(link, "link")
  if (!identical(family, "binomial") || !identical(link, "logit") ||
      !identical(unique, FALSE)) {
    stop(
      "VA-R3 admits only complete multi-trial binomial-logit data with unique = FALSE.",
      call. = FALSE
    )
  }

  ## Validate before .va_r3_fit() can construct a quadrature objective.
  .va_r3_validate_data(
    y = y, n_trials = n_trials, X = X, unit_id = unit_id,
    trait_id = trait_id, q = q, N = N, T = T,
    family = "binomial", link = "logit", unique = FALSE,
    psi = psi, structured = structured, provider = provider, lv = lv,
    missing = missing
  )
  started <- proc.time()[["elapsed"]]
  raw <- .va_r3_fit(
    y = y, n_trials = n_trials, X = X, unit_id = unit_id,
    trait_id = trait_id, q = q, N = N, T = T,
    family = "binomial", link = "logit", unique = FALSE,
    psi = psi, structured = structured, provider = provider, lv = lv,
    missing = missing, H = H, rank_source = rank_source,
    fixed_global = fixed_global, source = source, rebuild = rebuild,
    control = control, silent = silent
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
      rank_source = raw$rank_source %||% NA_character_
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

.approximation_engine_eva_fit <- function(
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

.approximation_engine_fit <- function(engine = c("va_r3", "eva"), ...) {
  engine <- match.arg(engine)
  switch(engine,
    va_r3 = .approximation_engine_va_r3_fit(...),
    eva = .approximation_engine_eva_fit(...)
  )
}
