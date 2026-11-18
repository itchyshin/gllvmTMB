## Resolve vignette sources under a dev tree or R CMD check (00_pkg_src).
## pkgdown articles live in vignettes/articles/, which .Rbuildignore excludes
## from the built tarball, so those files are often absent under check (#1770).
## The skip gate covers only the article block; gllvmTMB.Rmd is in the tarball
## and the main-vignette scan must hard-fail if that file is missing.
##
## Live lookups use testthat::test_path(). Planted *.Rcheck trees use the
## matching `_from` helpers with an explicit testthat directory, because
## test_path() ignores the working directory while testthat is running.

gllvmTMB_vignette_rel_roots <- function() {
  list(
    c("..", ".."),
    c("..", "..", "00_pkg_src", "gllvmTMB"),
    c("..", "..", "..", "00_pkg_src", "gllvmTMB")
  )
}

gllvmTMB_vignette_source_candidates_from <- function(testthat_dir, ...) {
  under_vignettes <- do.call(file.path, list(...))
  rel <- file.path("vignettes", under_vignettes)
  vapply(
    gllvmTMB_vignette_rel_roots(),
    function(segs) {
      do.call(file.path, c(list(testthat_dir), as.list(segs), list(rel)))
    },
    character(1)
  )
}

gllvmTMB_vignette_source_candidates <- function(...) {
  gllvmTMB_vignette_source_candidates_from(testthat::test_path(), ...)
}

gllvmTMB_vignette_source_path_from <- function(testthat_dir, ...) {
  candidates <- gllvmTMB_vignette_source_candidates_from(testthat_dir, ...)
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

gllvmTMB_vignette_source_path <- function(...) {
  gllvmTMB_vignette_source_path_from(testthat::test_path(), ...)
}

gllvmTMB_latent_d_teaching_vignette_paths_from <- function(testthat_dir, vigs) {
  stats::setNames(
    vapply(
      vigs,
      function(v) {
        gllvmTMB_vignette_source_path_from(testthat_dir, v)
      },
      character(1)
    ),
    vigs
  )
}

gllvmTMB_latent_d_teaching_vignette_paths <- function(vigs) {
  gllvmTMB_latent_d_teaching_vignette_paths_from(testthat::test_path(), vigs)
}

gllvmTMB_skip_if_latent_d_teaching_vignettes_absent <- function(testthat_dir = testthat::test_path()) {
  vigs <- c(
    "gllvmTMB.Rmd",
    file.path("articles", "covariance-correlation.Rmd"),
    file.path("articles", "model-selection-latent-rank.Rmd")
  )
  paths <- gllvmTMB_latent_d_teaching_vignette_paths_from(testthat_dir, vigs)
  ## Skip only the pkgdown-article block. gllvmTMB.Rmd is in the built
  ## tarball and must be scanned even when vignettes/articles/ is absent.
  article_rel <- vigs[-1L]
  if (any(is.na(paths[article_rel]))) {
    testthat::skip(
      paste(
        "pkgdown article vignettes (vignettes/articles/) are absent from this",
        "test context (.Rbuildignore excludes them from the built tarball);",
        "the article identifiable-range scan runs only when those sources are present"
      )
    )
  }
  paths
}
