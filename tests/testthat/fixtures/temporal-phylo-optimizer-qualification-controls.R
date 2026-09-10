.temporal_phylo_optimizer_qualification_controls <- function() {
  list(
    retained_summary = file.path(
      "dev", "temporal-program", "results", "failed",
      "phylo-recovery-160-fir-59096255-20260910",
      "phylo-recovery-160-summary-20260909.csv"
    ),
    retained_phi = c(-.4, 0, .6),
    retained_passes = c(TRUE, FALSE, FALSE),
    injected_coordinate = "theta_rr_phy[2]",
    derivative_tolerance = 2e-5
  )
}

.temporal_phylo_optimizer_qualification_validate_controls <- function(controls) {
  roots <- character()
  root <- normalizePath(getwd(), mustWork = TRUE)
  for (i in 0:4) {
    roots <- c(roots, root)
    root <- dirname(root)
  }
  identical(controls$retained_phi, c(-.4, 0, .6)) &&
    identical(controls$retained_passes, c(TRUE, FALSE, FALSE)) &&
    identical(controls$injected_coordinate, "theta_rr_phy[2]") &&
    identical(controls$derivative_tolerance, 2e-5) &&
    any(file.exists(file.path(roots, controls$retained_summary)))
}
