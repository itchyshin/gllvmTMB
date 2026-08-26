## Pure fail-closed contract for the release-wide interval route census.

validate_interval_route_census <- function(census) {
  required <- c(
    "route_id", "ci_id", "public_route", "estimand", "method",
    "current_evidence", "terminal_state", "evidence_path"
  )
  if (!identical(names(census), required)) {
    stop("interval route census schema changed", call. = FALSE)
  }
  if (nrow(census) != 19L || anyDuplicated(census$route_id)) {
    stop("interval route census identities are incomplete or duplicated", call. = FALSE)
  }
  if (!setequal(unique(census$ci_id), sprintf("CI-%02d", 8:15))) {
    stop("interval route census does not cover CI-08 through CI-15", call. = FALSE)
  }
  allowed <- c("certified", "limited", "blocked", "refused")
  if (
    length(census$terminal_state) != nrow(census) ||
      anyNA(census$terminal_state) ||
      any(!census$terminal_state %in% allowed)
  ) {
    stop("interval route census contains an invalid terminal state", call. = FALSE)
  }
  expected_certified <- c(
    "CI13-loading-n150-d2",
    "CI13-loading-n400-d1",
    "CI13-loading-n400-d2"
  )
  observed_certified <- sort(
    census$route_id[census$terminal_state == "certified"]
  )
  if (!identical(observed_certified, sort(expected_certified))) {
    stop("interval route census changed the exact certified route set", call. = FALSE)
  }
  invisible(TRUE)
}
