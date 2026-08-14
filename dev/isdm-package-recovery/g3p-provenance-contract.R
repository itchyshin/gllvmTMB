## Private, no-fit G3P receipt identity contract.  Stable content and runtime
## identity are binding; loader paths are retained only for diagnosis.

g3p_required_source_names <- function() c("fit_multi", "isdm_fit", "tmb", "dll")

g3p_required_runtime_names <- function() c(
  "architecture", "r_version", "tmb_version", "package_version"
)

g3p_scalar_character <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

g3p_valid_identity <- function(x) {
  is.list(x) &&
    g3p_scalar_character(x$commit) &&
    g3p_scalar_character(x$runner_md5) &&
    g3p_scalar_character(x$fixture_md5) &&
    g3p_scalar_character(x$packet_md5) &&
    is.character(x$source_md5) &&
    identical(names(x$source_md5), g3p_required_source_names()) &&
    all(vapply(unname(x$source_md5), g3p_scalar_character, logical(1L))) &&
    is.list(x$runtime) &&
    identical(names(x$runtime), g3p_required_runtime_names()) &&
    all(vapply(x$runtime, g3p_scalar_character, logical(1L))) &&
    g3p_scalar_character(x$dll_path)
}

g3p_compare_identity <- function(expected, observed) {
  if (!g3p_valid_identity(expected) || !g3p_valid_identity(observed)) {
    return(list(
      status = "INVALID_PROVENANCE", terminal = TRUE,
      reason = "malformed_or_incomplete_identity",
      fields = data.frame(field = "identity", expected = NA_character_, observed = NA_character_,
        equal = FALSE, binding = TRUE, stringsAsFactors = FALSE)
    ))
  }

  binding <- c("commit", "runner_md5", "fixture_md5", "packet_md5",
    paste0("source_md5.", g3p_required_source_names()),
    paste0("runtime.", g3p_required_runtime_names()))
  expected_values <- c(
    commit = expected$commit, runner_md5 = expected$runner_md5,
    fixture_md5 = expected$fixture_md5, packet_md5 = expected$packet_md5,
    stats::setNames(expected$source_md5, paste0("source_md5.", names(expected$source_md5))),
    stats::setNames(unlist(expected$runtime, use.names = FALSE), paste0("runtime.", names(expected$runtime)))
  )
  observed_values <- c(
    commit = observed$commit, runner_md5 = observed$runner_md5,
    fixture_md5 = observed$fixture_md5, packet_md5 = observed$packet_md5,
    stats::setNames(observed$source_md5, paste0("source_md5.", names(observed$source_md5))),
    stats::setNames(unlist(observed$runtime, use.names = FALSE), paste0("runtime.", names(observed$runtime)))
  )
  stopifnot(identical(names(expected_values), binding), identical(names(observed_values), binding))
  fields <- data.frame(
    field = c(binding, "dll_path"), expected = c(expected_values, expected$dll_path),
    observed = c(observed_values, observed$dll_path),
    equal = c(expected_values == observed_values, identical(expected$dll_path, observed$dll_path)),
    binding = c(rep(TRUE, length(binding)), FALSE), stringsAsFactors = FALSE
  )
  binding_mismatch <- fields$binding & !fields$equal
  path_only_difference <- !any(binding_mismatch) && !fields$equal[[nrow(fields)]]
  list(
    status = if (any(binding_mismatch)) "INVALID_PROVENANCE" else "MATCH",
    terminal = any(binding_mismatch),
    reason = if (any(binding_mismatch)) "binding_identity_mismatch" else if (path_only_difference) {
      "path_only_difference"
    } else "exact_identity_match",
    fields = fields
  )
}
