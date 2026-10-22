## The temporal programme's retained fixtures and remote envelopes are dev
## artefacts. They exist in a checkout but not in an R CMD check tarball.
.temporal_program_repo_root <- function() {
  dir <- tryCatch(testthat::test_path(), error = function(e) NA_character_)
  if (is.na(dir) || !nzchar(dir) || !dir.exists(dir)) return(NULL)
  dir <- normalizePath(dir, mustWork = FALSE)
  for (i in seq_len(8L)) {
    if (file.exists(file.path(dir, "DESCRIPTION")) &&
        dir.exists(file.path(dir, "dev", "temporal-program"))) return(dir)
    parent <- dirname(dir)
    if (identical(parent, dir)) break
    dir <- parent
  }
  NULL
}
