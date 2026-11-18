## Private, no-fit G3P receipt identity contract.  Stable content and runtime
## identity are binding; loader paths are retained only for diagnosis.

g3p_required_source_names <- function() c("fit_multi", "isdm_fit", "tmb", "dll")

g3p_required_runtime_names <- function() c(
  "architecture", "r_version", "tmb_version", "package_version"
)

g3p_scalar_character <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

g3p_md5 <- function(x) {
  g3p_scalar_character(x) && grepl("^[0-9A-Fa-f]{32}$", x, perl = TRUE)
}

g3p_valid_identity <- function(x) {
  is.list(x) &&
    g3p_scalar_character(x$commit) &&
    g3p_md5(x$runner_md5) &&
    g3p_md5(x$fixture_md5) &&
    g3p_md5(x$packet_md5) &&
    is.character(x$source_md5) &&
    identical(names(x$source_md5), g3p_required_source_names()) &&
    all(vapply(unname(x$source_md5), g3p_md5, logical(1L))) &&
    is.list(x$runtime) &&
    identical(names(x$runtime), g3p_required_runtime_names()) &&
    all(vapply(x$runtime, g3p_scalar_character, logical(1L))) &&
    g3p_scalar_character(x$dll_path)
}

g3p_field_value <- function(x) {
  if (g3p_scalar_character(x)) x else NA_character_
}

g3p_list_field <- function(x, name) {
  if (is.list(x)) x[[name]] else NULL
}

g3p_identity_values <- function(x) {
  source_md5 <- g3p_list_field(x, "source_md5")
  runtime <- g3p_list_field(x, "runtime")
  c(
    commit = g3p_field_value(g3p_list_field(x, "commit")),
    runner_md5 = g3p_field_value(g3p_list_field(x, "runner_md5")),
    fixture_md5 = g3p_field_value(g3p_list_field(x, "fixture_md5")),
    packet_md5 = g3p_field_value(g3p_list_field(x, "packet_md5")),
    stats::setNames(vapply(g3p_required_source_names(), function(name) {
      g3p_field_value(source_md5[[name]])
    }, character(1L)), paste0("source_md5.", g3p_required_source_names())),
    stats::setNames(vapply(g3p_required_runtime_names(), function(name) {
      g3p_field_value(runtime[[name]])
    }, character(1L)), paste0("runtime.", g3p_required_runtime_names())),
    dll_path = g3p_field_value(g3p_list_field(x, "dll_path"))
  )
}

g3p_compare_identity <- function(expected, observed) {
  binding <- c("commit", "runner_md5", "fixture_md5", "packet_md5",
    paste0("source_md5.", g3p_required_source_names()),
    paste0("runtime.", g3p_required_runtime_names()))
  expected_values <- g3p_identity_values(expected)
  observed_values <- g3p_identity_values(observed)
  stopifnot(identical(names(expected_values), c(binding, "dll_path")),
    identical(names(observed_values), c(binding, "dll_path")))
  fields <- data.frame(
    field = c(binding, "dll_path"), expected = expected_values,
    observed = observed_values,
    equal = !is.na(expected_values) & !is.na(observed_values) & expected_values == observed_values,
    binding = c(rep(TRUE, length(binding)), FALSE), stringsAsFactors = FALSE
  )
  binding_mismatch <- fields$binding & !fields$equal
  path_only_difference <- !any(binding_mismatch) && !fields$equal[[nrow(fields)]]
  malformed <- !g3p_valid_identity(expected) || !g3p_valid_identity(observed)
  list(
    status = if (malformed || any(binding_mismatch)) "INVALID_PROVENANCE" else "MATCH",
    terminal = malformed || any(binding_mismatch),
    reason = if (malformed) "malformed_or_incomplete_identity" else if (any(binding_mismatch)) {
      "binding_identity_mismatch"
    } else if (path_only_difference) {
      "path_only_difference"
    } else "exact_identity_match",
    fields = fields
  )
}

g3p_required_execution_names <- function() c(
  "schema", "source_gate", "root_id", "attempt_id", "time_estimate", "time_limit_s"
)

g3p_compare_execution_context <- function(expected, observed) {
  fields <- g3p_required_execution_names()
  expected_values <- vapply(fields, function(field) g3p_field_value(expected[[field]]), character(1L))
  observed_values <- vapply(fields, function(field) g3p_field_value(observed[[field]]), character(1L))
  equal <- !is.na(expected_values) & !is.na(observed_values) & expected_values == observed_values
  table <- data.frame(
    field = fields, expected = expected_values, observed = observed_values,
    equal = equal, binding = TRUE, stringsAsFactors = FALSE
  )
  malformed <- anyNA(expected_values) || anyNA(observed_values)
  mismatch <- any(!equal)
  list(
    status = if (malformed || mismatch) "INVALID_PROVENANCE" else "MATCH",
    terminal = malformed || mismatch,
    reason = if (malformed) "malformed_or_incomplete_execution_context" else if (mismatch) {
      "execution_context_mismatch"
    } else "exact_execution_context_match",
    fields = table
  )
}
