.temporal_phylo_optimizer_qualification_controls <- function() {
  list(
    retained_summary = file.path(
      "dev", "temporal-program", "results", "failed",
      "phylo-recovery-160-fir-59096255-20260910",
      "phylo-recovery-160-summary-20260909.csv"
    ),
    retained_summary_md5 = "143cfc5e5572136e7945ebe9de86ca58",
    retained_phi = c(-.4, 0, .6),
    retained_passes = c(TRUE, FALSE, FALSE),
    injected_coordinate = "theta_rr_phy[2]",
    derivative_tolerance = 2e-5
  )
}

.temporal_phylo_optimizer_qualification_validate_summary <- function(path,
                                                                       expected_md5) {
  if (!is.character(path) || length(path) != 1L || !file.exists(path) ||
      !is.character(expected_md5) || length(expected_md5) != 1L ||
      !identical(unname(tools::md5sum(path)), expected_md5)) {
    return(FALSE)
  }
  x <- tryCatch(utils::read.csv(path, check.names = FALSE), error = function(e) NULL)
  required <- c("phi", "attempts", "strict_successes", "passes")
  if (!is.data.frame(x) || !all(required %in% names(x)) || nrow(x) != 3L) {
    return(FALSE)
  }
  x <- x[match(c(-.4, 0, .6), x$phi), required, drop = FALSE]
  identical(as.numeric(x$phi), c(-.4, 0, .6)) &&
    identical(as.integer(x$attempts), c(10L, 10L, 10L)) &&
    identical(as.integer(x$strict_successes), c(10L, 9L, 8L)) &&
    identical(as.logical(x$passes), c(TRUE, FALSE, FALSE))
}

.temporal_phylo_optimizer_qualification_validate_controls <- function(controls) {
  roots <- tryCatch({
    if (exists(".temporal_program_repo_root", mode = "function", inherits = TRUE)) {
      .temporal_program_repo_root()
    } else {
      NULL
    }
  }, error = function(e) NULL)
  roots <- roots[!is.na(roots) & nzchar(roots) & dir.exists(roots)]
  root <- normalizePath(getwd(), mustWork = TRUE)
  for (i in 0:4) {
    roots <- c(roots, root)
    root <- dirname(root)
  }
  summary_paths <- unique(unlist(lapply(roots, function(root) c(
    file.path(root, controls$retained_summary),
    file.path(root, "00_pkg_src", "gllvmTMB", controls$retained_summary)
  )), use.names = FALSE))
  identical(controls$retained_summary,
    .temporal_phylo_optimizer_qualification_controls()$retained_summary) &&
    identical(controls$retained_summary_md5,
      .temporal_phylo_optimizer_qualification_controls()$retained_summary_md5) &&
    identical(controls$retained_phi, c(-.4, 0, .6)) &&
    identical(controls$retained_passes, c(TRUE, FALSE, FALSE)) &&
    identical(controls$injected_coordinate, "theta_rr_phy[2]") &&
    identical(controls$derivative_tolerance, 2e-5) &&
    any(vapply(summary_paths, function(path) {
      .temporal_phylo_optimizer_qualification_validate_summary(
        path, controls$retained_summary_md5
      )
    }, logical(1)))
}
