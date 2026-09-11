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
      !is.character(expected_md5) || length(expected_md5) != 1L) {
    return(FALSE)
  }
  raw_md5 <- unname(tools::md5sum(path))
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  normalized <- charToRaw(gsub("\\r\\n?", "\\n", rawToChar(bytes), perl = TRUE))
  normalized_path <- tempfile("temporal-phylo-summary-", fileext = ".csv")
  on.exit(unlink(normalized_path), add = TRUE)
  writeBin(normalized, normalized_path)
  normalized_md5 <- unname(tools::md5sum(normalized_path))
  if (!identical(raw_md5, expected_md5) && !identical(normalized_md5, expected_md5)) {
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

.temporal_phylo_optimizer_qualification_installed_summary <- function() {
  ## `dev/` is intentionally absent from installed packages.  Preserve the
  ## immutable three-row receipt here so the installed-package control verifies
  ## the same failure record rather than silently losing its evidence check.
  lines <- c(
    '"phi","attempts","strict_successes","mean_phi_absolute_error","median_phi_absolute_error","median_temporal_1_relative_error","median_temporal_2_relative_error","median_temporal_3_relative_error","median_phylo_1_relative_error","median_phylo_2_relative_error","median_phylo_3_relative_error","mean_fixed_effect_error","passes"',
    '-0.4,10,10,0.0096902597297317,0.00901689598924349,0.0214603156240379,0.0398014024819387,0.0269024800505128,0.0654820642541633,0.0794342177339947,0.0723851634791718,0.0986865792012925,TRUE',
    '0,10,9,0.0108098419140769,0.0130218510695404,0.0119397010828196,0.0284081698341212,0.0204392613599043,0.0896558046313798,0.0944745206344529,0.0679073160281122,0.10199048495348,FALSE',
    '0.6,10,8,0.00626076816168523,0.00589527148851754,0.00701719996550428,0.0431202953446174,0.0242815926002243,0.154469018044702,0.140039804249406,0.134245983920956,0.0937981217336855,FALSE'
  )
  path <- tempfile("temporal-phylo-installed-summary-", fileext = ".csv")
  writeLines(lines, path, useBytes = TRUE)
  path
}

.temporal_phylo_optimizer_qualification_validate_controls <- function(controls) {
  source_root <- tryCatch({
    if (exists(".temporal_program_repo_root", mode = "function", inherits = TRUE)) {
      .temporal_program_repo_root()
    } else {
      NULL
    }
  }, error = function(e) NULL)
  source_path <- if (is.character(source_root) && length(source_root) == 1L &&
      !is.na(source_root) && nzchar(source_root)) {
    file.path(source_root, controls$retained_summary)
  } else {
    NA_character_
  }
  retained_summary_ok <- if (!is.na(source_path) && file.exists(source_path)) {
    ## A source checkout has an authoritative campaign receipt. Restrict this
    ## lookup to the explicit repository root: walking R CMD check's temporary
    ## directories can find an unrelated, line-ending-transformed copy on
    ## Windows and incorrectly suppress the installed-package control.
    .temporal_phylo_optimizer_qualification_validate_summary(
      source_path, controls$retained_summary_md5
    )
  } else {
    installed_path <- .temporal_phylo_optimizer_qualification_installed_summary()
    on.exit(unlink(installed_path), add = TRUE)
    .temporal_phylo_optimizer_qualification_validate_summary(
      installed_path, controls$retained_summary_md5
    )
  }
  identical(controls$retained_summary,
    .temporal_phylo_optimizer_qualification_controls()$retained_summary) &&
    identical(controls$retained_summary_md5,
      .temporal_phylo_optimizer_qualification_controls()$retained_summary_md5) &&
    identical(controls$retained_phi, c(-.4, 0, .6)) &&
    identical(controls$retained_passes, c(TRUE, FALSE, FALSE)) &&
    identical(controls$injected_coordinate, "theta_rr_phy[2]") &&
    identical(controls$derivative_tolerance, 2e-5) &&
    retained_summary_ok
}
