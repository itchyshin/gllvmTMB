## Resolve vignette sources under a dev tree or R CMD check (00_pkg_src).
## pkgdown articles live in vignettes/articles/, which .Rbuildignore excludes
## from the built tarball, so those files are often absent under check (#1772).

gllvmTMB_vignette_rel_roots <- function() {
  list(
    c("..", ".."),
    c("..", "..", "00_pkg_src", "gllvmTMB"),
    c("..", "..", "..", "00_pkg_src", "gllvmTMB")
  )
}

gllvmTMB_vignette_source_candidates <- function(...) {
  under_vignettes <- do.call(file.path, list(...))
  rel <- file.path("vignettes", under_vignettes)
  vapply(
    gllvmTMB_vignette_rel_roots(),
    function(segs) {
      do.call(testthat::test_path, c(as.list(segs), list(rel)))
    },
    character(1)
  )
}

gllvmTMB_vignette_source_path <- function(...) {
  candidates <- gllvmTMB_vignette_source_candidates(...)
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

gllvmTMB_latent_d_teaching_vignette_paths <- function(vigs) {
  stats::setNames(
    vapply(
      vigs,
      function(v) {
        gllvmTMB_vignette_source_path(v)
      },
      character(1)
    ),
    vigs
  )
}

gllvmTMB_skip_if_latent_d_teaching_vignettes_absent <- function() {
  vigs <- c(
    "gllvmTMB.Rmd",
    file.path("articles", "covariance-correlation.Rmd"),
    file.path("articles", "model-selection-latent-rank.Rmd")
  )
  paths <- gllvmTMB_latent_d_teaching_vignette_paths(vigs)
  if (any(is.na(paths))) {
    testthat::skip(
      paste(
        "pkgdown article vignettes (vignettes/articles/) are absent from this",
        "test context (.Rbuildignore excludes them from the built tarball);",
        "the full teaching-vignette scan runs only when those sources are present"
      )
    )
  }
  paths
}
