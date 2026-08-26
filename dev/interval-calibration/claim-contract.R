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
  expected_states <- c(
    "CI08-PV-profile" = "limited",
    "CI08-PV-n150-d1" = "limited",
    "CI08-PV-n150-d2" = "limited",
    "CI08-PVT02-n400-d2" = "blocked",
    "CI08-bootstrap-comparator" = "limited",
    "CI09-fisher-z" = "blocked",
    "CI10-profile-mixed" = "blocked",
    "CI10-wald-mixed" = "limited",
    "CI10-bootstrap-multiple-r" = "limited",
    "CI10-profile-contrast-r" = "limited",
    "CI11-nonlinear-profile" = "refused",
    "CI12-nonlinear-profile" = "refused",
    "CI13-standardized-loading" = "limited",
    "CI13-loading-n150-d2" = "certified",
    "CI13-loading-n400-d1" = "certified",
    "CI13-loading-n400-d2" = "certified",
    "CI14-ordinary-slope-sd" = "blocked",
    "CI15-phylo-slope-sd" = "blocked",
    "CI15-loadings-only-slope-sd" = "blocked"
  )
  observed_states <- stats::setNames(
    census$terminal_state,
    census$route_id
  )
  observed_states <- observed_states[sort(names(observed_states))]
  expected_states <- expected_states[sort(names(expected_states))]
  if (!identical(observed_states, expected_states)) {
    stop("interval route census changed the exact route/state map", call. = FALSE)
  }
  invisible(TRUE)
}
