root <- normalizePath(file.path(getwd()), mustWork = TRUE)
if (!file.exists(file.path(root, "R", "charts.R"))) {
  root <- normalizePath(
    file.path(root, "dev", "design99-exact-reference"),
    mustWork = TRUE
  )
}
source(file.path(root, "R", "numerics.R"))
source(file.path(root, "R", "aghq.R"))
source(file.path(root, "R", "charts.R"))
source(file.path(root, "R", "fixture.R"))
source(file.path(root, "R", "optimizers.R"))

near <- function(x, y, tolerance, label) {
  error <- max(abs(x - y))
  if (!is.finite(error) || error > tolerance) {
    stop(
      sprintf("%s: %.17g > %.17g", label, error, tolerance),
      call. = FALSE
    )
  }
}

synthetic <- list(
  beta = c(-.40, -.15, .05, .20, .35, .50),
  Lambda = rbind(
    c(.50, .10),
    c(.20, .45),
    c(-.30, .25),
    c(.20, -.55),
    c(.30, .35),
    c(-.25, -.30)
  )
)
theta0 <- d99_chart_pack(
  synthetic$beta,
  synthetic$Lambda,
  "C12",
  4
)
counts <- rep.int(0L, 64L)
counts[c(1L, 6L, 19L, 34L, 52L, 64L)] <- c(2L, 1L, 2L, 1L, 2L, 1L)

# Tiny real-AGHQ route smoke: no frozen seed, fixture, or scientific output.
gh3 <- d99_gh_rule(3L)
real_evaluation <- d99_eval_chart(
  theta0,
  counts,
  "C12",
  4,
  gh3,
  need_score = TRUE
)
real_finite <- d99_finite_rule_gradient(
  theta0,
  counts,
  "C12",
  4,
  gh3
)
real_fisher <- d99_fisher_chart_score(
  theta0,
  counts,
  "C12",
  4,
  gh3
)
if (
  !is.finite(real_evaluation$loglik) ||
    any(!is.finite(c(real_finite, real_fisher)))
) {
  stop(
    "Tiny synthetic AGHQ route smoke produced non-finite values.",
    call. = FALSE
  )
}
if (length(real_finite) != 17L || length(real_fisher) != 17L) {
  stop(
    "Tiny synthetic AGHQ route smoke returned malformed scores.",
    call. = FALSE
  )
}

real_aghq_eval <- d99_aghq_eval
target_value <- d99_chart_unpack(theta0, "C12", 4)
target <- list(beta = target_value$beta, Lambda = target_value$Lambda)
healthy_mode <- list(
  u = c(0, 0),
  Q = diag(2),
  gradient_inf = 0,
  decrement = 0,
  min_eigenvalue = 1,
  iterations = 0L,
  steps = numeric()
)

# Cheap deterministic objective used to test the full certification and route
# control plumbing without treating the smoke as scientific evidence.
d99_aghq_eval <- function(
  counts,
  beta,
  Lambda,
  gh,
  need_score = TRUE,
  all_patterns = TRUE
) {
  delta <- c(beta - target$beta, as.vector(t(Lambda - target$Lambda)))
  n <- sum(counts)
  pattern_score <- matrix(rep(-delta, each = 64L), nrow = 64L)
  list(
    loglik = -0.5 * n * sum(delta^2),
    log_prob = rep(-log(64), 64L),
    prob = rep(1 / 64, 64L),
    score = if (need_score) -n * delta else NULL,
    score_by_pattern = if (need_score) {
      pattern_score
    } else {
      matrix(NA_real_, 64L, 18L)
    },
    modes = rep(list(healthy_mode), 64L),
    quadrature = gh
  )
}

gh21 <- list(order = 21L, nodes = c(-1, 0, 1), weights = c(.25, .5, .25))
gh31 <- list(order = 31L, nodes = c(-1, 0, 1), weights = c(.25, .5, .25))
certificate <- d99_certify_endpoint(
  theta0,
  counts,
  "C12",
  4,
  gh21,
  gh31
)
if (!isTRUE(certificate$healthy)) {
  stop(
    paste(
      "Synthetic certification unexpectedly failed:",
      paste(certificate$failed_checks, collapse = ", ")
    ),
    call. = FALSE
  )
}

original_fake <- d99_aghq_eval
d99_aghq_eval <- function(
  counts,
  beta,
  Lambda,
  gh,
  need_score = TRUE,
  all_patterns = TRUE
) {
  value <- original_fake(
    counts,
    beta,
    Lambda,
    gh,
    need_score,
    all_patterns
  )
  if (identical(gh$order, 21L)) {
    value$loglik <- value$loglik + 1e-4 * sum(counts)
    value$log_prob <- value$log_prob + 1e-4
  }
  value
}
bad_quadrature <- d99_certify_endpoint(
  theta0,
  counts,
  "C12",
  4,
  gh21,
  gh31
)
if (
  isTRUE(bad_quadrature$checks[["loglik"]]) ||
    isTRUE(bad_quadrature$checks[["pattern_log_probability"]])
) {
  stop(
    "Certification did not reject an explicit H21/H31 discrepancy.",
    call. = FALSE
  )
}
d99_aghq_eval <- original_fake

bad_interior <- theta0
bad_interior[1L] <- 20
interior_certificate <- d99_certify_endpoint(
  bad_interior,
  counts,
  "C12",
  4,
  gh21,
  gh31
)
if (isTRUE(interior_certificate$checks[["interiority"]])) {
  stop(
    "Certification did not reject a non-interior raw coordinate.",
    call. = FALSE
  )
}

starts <- c("fixed", "spectral", "truth")
guards <- c("cap4", "cap8")
endpoints <- lapply(guards, function(guard) {
  lapply(starts, function(start) {
    list(
      healthy = TRUE,
      start = start,
      guard = guard,
      certification = certificate
    )
  })
})
endpoints <- unlist(endpoints, recursive = FALSE)
selection <- d99_select_cell_endpoint(endpoints)
if (
  !isTRUE(selection$healthy) ||
    !identical(selection$selected$guard, "cap4") ||
    !identical(selection$selected$start, "fixed")
) {
  stop("Deterministic all-six tie selection is incorrect.", call. = FALSE)
}
representatives <- d99_compare_representatives(endpoints[1:2])
if (!isTRUE(representatives$healthy)) {
  stop("Identical representative endpoints did not agree.", call. = FALSE)
}

d99_aghq_eval <- real_aghq_eval
identification <- d99_pattern_probability_jacobian(
  theta0,
  "C12",
  4,
  gh3,
  step = 1e-5
)
if (identification$richardson_relative_error >= 1e-6) {
  stop("Symmetric and Richardson pattern Jacobians disagree.", call. = FALSE)
}
if (
  !identical(dim(identification$scaled_jacobian), c(63L, 17L)) ||
    length(identification$singular_values) != 17L
) {
  stop("Identification spectrum has the wrong shape.", call. = FALSE)
}
if (
  isTRUE(identification$verdict$healthy) ||
    !identical(
      identification$verdict$terminal,
      "WEAK_OR_NONIDENTIFIED_REFERENCE"
    ) ||
    !"counts_supplied" %in% identification$verdict$failed_checks
) {
  stop(
    "Identification without counts did not fail closed.",
    call. = FALSE
  )
}

profile_pass <- lapply(
  c(0, -.25, .25, -.5, .5, -1, 1, -2, 2),
  function(displacement) {
    list(
      displacement = displacement,
      valid = TRUE,
      delta_per_unit = if (displacement == 0) 0 else 2e-8
    )
  }
)
diagnostics_pass <- list(
  rank = c(`1e-06` = 17L, `1e-08` = 17L, `1e-10` = 17L),
  reciprocal_condition = 1e-4,
  richardson_relative_error = 1e-8,
  profile = profile_pass,
  observed_information = list(
    scaled_matrix = diag(17L),
    condition = 10
  )
)
verdict_pass <- d99_identification_verdict(diagnostics_pass)
if (
  !isTRUE(verdict_pass$healthy) ||
    !identical(verdict_pass$terminal, "PASS") ||
    length(verdict_pass$failed_checks)
) {
  stop("Healthy identification diagnostics did not pass.", call. = FALSE)
}

diagnostics_rank <- diagnostics_pass
diagnostics_rank$rank[["1e-08"]] <- 16L
verdict_rank <- d99_identification_verdict(diagnostics_rank)
if (
  isTRUE(verdict_rank$healthy) ||
    !"rank_1e8" %in% verdict_rank$failed_checks
) {
  stop("Rank-16 identification sentinel did not fail.", call. = FALSE)
}

diagnostics_rcond <- diagnostics_pass
diagnostics_rcond$reciprocal_condition <- 1e-8
verdict_rcond <- d99_identification_verdict(diagnostics_rcond)
if (
  isTRUE(verdict_rcond$healthy) ||
    !"reciprocal_condition" %in% verdict_rcond$failed_checks
) {
  stop(
    "Reciprocal-condition identification sentinel did not fail.",
    call. = FALSE
  )
}

diagnostics_condition <- diagnostics_pass
diagnostics_condition$observed_information$condition <- 1e8
verdict_condition <- d99_identification_verdict(diagnostics_condition)
if (
  isTRUE(verdict_condition$healthy) ||
    !"information_condition" %in% verdict_condition$failed_checks
) {
  stop(
    "Observed-information condition sentinel did not fail.",
    call. = FALSE
  )
}

diagnostics_profile <- diagnostics_pass
diagnostics_profile$profile[[2L]]$delta_per_unit <- 1e-9
verdict_profile <- d99_identification_verdict(diagnostics_profile)
if (
  isTRUE(verdict_profile$healthy) ||
    !"profile_rise" %in% verdict_profile$failed_checks
) {
  stop("Weak-profile identification sentinel did not fail.", call. = FALSE)
}

diagnostics_mechanical <- diagnostics_pass
diagnostics_mechanical$richardson_relative_error <- 1e-4
verdict_mechanical <- d99_identification_verdict(diagnostics_mechanical)
if (!identical(verdict_mechanical$terminal, "MECHANICAL_STOP")) {
  stop("Richardson sentinel did not trigger mechanical stop.", call. = FALSE)
}

# Exercise the complete counts-supplied production path cheaply. The synthetic
# evaluator has a flat pattern-probability map, so the verdict must reject it.
d99_aghq_eval <- original_fake
identification_counts <- d99_pattern_probability_jacobian(
  theta0,
  "C12",
  4,
  gh3,
  counts = counts,
  step = 1e-5
)
d99_aghq_eval <- real_aghq_eval
if (
  is.null(identification_counts$observed_information) ||
    isTRUE(identification_counts$verdict$healthy) ||
    !"rank_1e8" %in% identification_counts$verdict$failed_checks
) {
  stop(
    "Counts-supplied identification path did not fail closed.",
    call. = FALSE
  )
}

cat("gate2-optimizer: PASS (synthetic NON_EVIDENCE only)\n")
