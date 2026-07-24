#!/usr/bin/env Rscript
# Control-only G1--G3 gate runner.  It has no frozen-fixture or real-run path.
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) {
  i <- match(flag, d99_args)
  if (is.na(i)) default else d99_args[[i + 1L]]
}
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "numerics.R", "charts.R", "aghq.R", "fixture.R", "optimizers.R", "independent-oracle.R")) {
  source(file.path(d99_here, "R", f))
}

root <- d99_arg("--output-root")
if (is.null(root)) stop("--output-root is required", call. = FALSE)
receipt <- file.path(root, "mechanical-gates.json")
if (file.exists(receipt)) stop("Mechanical-gate receipt already exists", call. = FALSE)

d99_run_gate_file <- function(path, testthat = FALSE) {
  old <- setwd(normalizePath(file.path(d99_here, "..", ".."), mustWork = TRUE))
  on.exit(setwd(old), add = TRUE)
  command <- if (testthat) {
    expression <- sprintf(
      "testthat::test_file(%s, reporter = 'summary')",
      encodeString(normalizePath(path), quote = "'")
    )
    c("--vanilla", "-e", shQuote(expression))
  } else {
    c("--vanilla", normalizePath(path))
  }
  out <- system2(file.path(R.home("bin"), "Rscript"), command,
                 stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status"))) {
    stop("Mechanical gate failed: ", basename(path), "\n", paste(out, collapse = "\n"), call. = FALSE)
  }
  list(file = basename(path), output_sha256 = d99_sha256_raw(charToRaw(paste(out, collapse = "\n"))))
}

d99_fixed_coordinate_oracles <- function() {
  # This is deliberately a different small deterministic fixture, never the
  # approved fixture seed or a scientific output root.
  set.seed(991L)
  y <- matrix(rbinom(96L * 6L, 1L, rep(c(.35, .65), each = 3L)), ncol = 6L)
  counts <- d99_pattern_counts(y)
  gh <- d99_gh_rule(31L)
  truth <- d99_truth()
  coordinates <- list()
  for (chart in c("C12", "C34")) for (cap in c(4, 8)) {
    coordinates[[paste(chart, cap, "truth", sep = "-")]] <-
      d99_chart_pack(truth$beta, truth$Lambda, chart, cap)
    coordinates[[paste(chart, cap, "stress", sep = "-")]] <-
      d99_stress_coordinates(chart, cap)
  }
  checks <- lapply(names(coordinates), function(label) {
    fields <- strsplit(label, "-", fixed = TRUE)[[1L]]
    chart <- fields[[1L]]
    cap <- as.numeric(fields[[2L]])
    value <- d99_chart_unpack(coordinates[[label]], chart, cap)
    agh <- d99_aghq_eval(counts, value$beta, value$Lambda, gh, need_score = TRUE)
    observed <- which(counts > 0)
    J <- d99_chart_jacobian(coordinates[[label]], chart, cap)
    if (!identical(dim(J), c(18L, 17L))) stop("Fixed-coordinate chart Jacobian must be 18 by 17", call. = FALSE)
    comparators <- lapply(observed, function(index) {
      d99_oracle_fixed_coordinate_comparator(
        d99_pattern_matrix()[index, ], value$beta, value$Lambda, J
      )
    })
    weights <- counts[observed]
    aggregate_backend <- function(side) {
      result <- lapply(comparators, `[[`, side)
      weighted <- function(field) {
        Reduce(`+`, Map(function(x, weight) x[[field]] * weight, result, weights)) / sum(weights)
      }
      list(
        result = result,
        loglik = sum(vapply(result, `[[`, numeric(1), "log_prob") * weights),
        log_prob = vapply(result, `[[`, numeric(1), "log_prob"),
        chart_score = weighted("chart_score"),
        chart_score_lower = weighted("chart_score_lower"),
        chart_score_upper = weighted("chart_score_upper")
      )
    }
    nested <- aggregate_backend("nested")
    cube <- aggregate_backend("cubature")
    agh_chart_score <- d99_fisher_chart_score(coordinates[[label]], counts, chart, cap, gh)
    backend_success <- all(vapply(comparators, function(x) {
      isTRUE(x$success) && isTRUE(x$cubature$success) && isTRUE(x$nested$success) &&
        isTRUE(x$cubature$backend_status$success) && identical(x$cubature$backend_status$return_code, 0L) &&
        isTRUE(x$nested$backend_status$success) && identical(x$nested$backend_status$message, "OK") &&
        x$nested$backend_status$checked_results > 19L
    }, logical(1)))
    tail_error_bounds <- all(vapply(comparators, function(x) {
      results <- list(x$cubature, x$nested)
      all(vapply(results, function(result) {
        all(is.finite(c(result$chart_numerical_error, result$chart_tail_bounds,
                        result$chart_score_lower, result$chart_score_upper,
                        result$denominator_interval))) &&
          all(result$chart_numerical_error >= 0) && all(result$chart_tail_bounds >= 0) &&
          max(result$chart_tail_bounds) < 5e-7 &&
          result$denominator_interval[["lower"]] > 0
      }, logical(1)))
    }, logical(1)))
    agh_inside_nested <- all(nested$chart_score_lower <= agh_chart_score & agh_chart_score <= nested$chart_score_upper)
    agh_inside_cubature <- all(cube$chart_score_lower <= agh_chart_score & agh_chart_score <= cube$chart_score_upper)
    intervals_overlap <- all(pmax(nested$chart_score_lower, cube$chart_score_lower) <=
                               pmin(nested$chart_score_upper, cube$chart_score_upper))
    metrics <- c(
      agh_nested_loglik = abs(agh$loglik - nested$loglik) / sum(counts),
      agh_cubature_loglik = abs(agh$loglik - cube$loglik) / sum(counts),
      nested_cubature_loglik = abs(nested$loglik - cube$loglik) / sum(counts),
      agh_nested_score = max(abs(agh_chart_score - nested$chart_score)),
      agh_cubature_score = max(abs(agh_chart_score - cube$chart_score)),
      nested_cubature_score = max(abs(nested$chart_score - cube$chart_score)),
      agh_nested_pattern = max(abs(agh$log_prob[observed] - nested$log_prob[observed])),
      agh_cubature_pattern = max(abs(agh$log_prob[observed] - cube$log_prob[observed])),
      nested_cubature_pattern = max(abs(nested$log_prob[observed] - cube$log_prob[observed]))
    )
    ok <- all(is.finite(metrics)) && max(metrics[grep("loglik", names(metrics))]) < 1e-8 &&
      max(metrics[grep("score", names(metrics))]) < 5e-6 &&
      max(metrics[grep("pattern", names(metrics))]) < 1e-7 && backend_success &&
      tail_error_bounds && agh_inside_nested && agh_inside_cubature && intervals_overlap
    list(label = label, passed = ok, metrics = as.list(metrics),
         certification = list(backend_success = backend_success,
           tail_error_bounds = tail_error_bounds, agh_inside_nested = agh_inside_nested,
           agh_inside_cubature = agh_inside_cubature, intervals_overlap = intervals_overlap))
  })
  if (!all(vapply(checks, `[[`, logical(1), "passed"))) {
    stop("Fixed-coordinate quadrature/oracle gate failed", call. = FALSE)
  }
  checks
}

test_mode <- "--mock-pass" %in% d99_args
failure_sentinel <- "--inject-fixed-coordinate-failure" %in% d99_args
if (failure_sentinel && !test_mode) stop("The fixed-coordinate failure sentinel is test-only", call. = FALSE)
if (failure_sentinel) stop("Fixed-coordinate certified-interval failure sentinel", call. = FALSE)
gate_files <- file.path(d99_here, "tests", c(
  "test-gate1-charts.R", "test-gate1-numerics.R", "test-gate2-optimizer.R",
  "test-gate3-infrastructure.R", "test-gate3-runtime-wiring.R"
))
outcome <- if (test_mode) {
  list(gates = lapply(basename(gate_files), function(x) list(file = x, mocked = TRUE)),
       fixed_coordinate = list(mocked = TRUE))
} else {
  uses_testthat <- grepl("test-gate[13]-(numerics|infrastructure|runtime-wiring)\\.R$", gate_files)
  list(gates = Map(d99_run_gate_file, gate_files, uses_testthat), fixed_coordinate = d99_fixed_coordinate_oracles())
}
d99_write_exclusive_json(receipt, c(list(
  schema = "d99-mechanical-gates-v1", status = "PASS", mode = "NON_EVIDENCE",
  test_mode = test_mode, created_at = d99_now(), approved_fixture_seed_used = FALSE,
  fixed_coordinate_failure_sentinel = list(armed = FALSE, passed = TRUE),
  output_root = normalizePath(root, mustWork = FALSE)
), outcome))
cat("Design-99 mechanical gates: PASS (NON_EVIDENCE)\n")
