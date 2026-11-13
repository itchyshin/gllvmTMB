## #1349: ?latent must state the identifiable range of d for the default
## Sigma = Lambda Lambda^T + Psi fit. The code only guards d <= n_traits,
## which reads like the full rule; the help page has to say it is not.
## Reads the roxygen source (R/brms-sugar.R), the generated Rd, and the
## teaching vignettes. A missing file is an error, including under R CMD check.

test_that("?latent argument d states the (T - d)^2 >= T + d identifiable range (#1349)", {
  src <- gllvmTMB_pkg_file("R", "brms-sugar.R")
  lines <- readLines(src, warn = FALSE)
  start <- grep("^#' @param d Integer; number of latent factors\\. ", lines)
  expect_length(start, 1L)
  end <- grep("^#' @param unique ", lines)
  end <- end[end > start][1]
  txt <- gsub("\\s+", " ", paste(sub("^#'\\s?", "", lines[start:(end - 1L)]), collapse = " "))
  expect_match(txt, "(T - d)^2 \\ge T + d", fixed = TRUE)
  expect_match(txt, "d <= n_traits", fixed = TRUE)
  expect_match(txt, "T = 5", fixed = TRUE)
  expect_match(txt, "unique = FALSE", fixed = TRUE)
  expect_match(txt, "not identified", fixed = TRUE)
})

test_that("man/latent.Rd carries the same identifiable-range statement (#1349)", {
  rd <- gllvmTMB_pkg_file("man", "latent.Rd")
  txt <- gsub("\\s+", " ", paste(readLines(rd, warn = FALSE), collapse = " "))
  expect_match(txt, "(T - d)^2 \\ge T + d", fixed = TRUE)
  expect_match(txt, "not identified", fixed = TRUE)
})

test_that("the stated bound matches the moment count it is derived from (#1349)", {
  ## (T - d)^2 >= T + d  <=>  T(T+1)/2 >= T*d - d(d-1)/2 + T
  for (T in 3:12) for (d in 1:T) {
    expect_identical(
      (T - d)^2 >= T + d,
      T * (T + 1) / 2 >= T * d - d * (d - 1) / 2 + T
    )
  }
  maxd <- function(T) max(Filter(function(d) (T - d)^2 >= T + d, 1:T))
  expect_identical(vapply(c(3, 4, 5, 10), maxd, numeric(1)), c(1, 1, 2, 6))
})

test_that("the main teaching vignette states the identifiable range of d (#1349)", {
  v <- "gllvmTMB.Rmd"
  p <- gllvmTMB_vignette_source_path(v)
  if (is.na(p)) {
    stop(
      "vignettes/gllvmTMB.Rmd is required for the identifiable-range scan and is missing from this test context"
    )
  }
  txt <- gsub("\\s+", " ", paste(readLines(p, warn = FALSE), collapse = " "))
  expect_match(txt, "(T - d)^2 \\ge T + d", fixed = TRUE, info = v)
  expect_match(txt, "d <= n_traits", fixed = TRUE, info = v)
})

test_that("the teaching articles state the identifiable range of d (#1349)", {
  vigs <- c(
    file.path("articles", "covariance-correlation.Rmd"),
    file.path("articles", "model-selection-latent-rank.Rmd")
  )
  resolved <- gllvmTMB_skip_if_latent_d_teaching_vignettes_absent()
  for (v in vigs) {
    p <- resolved[[v]]
    txt <- gsub("\\s+", " ", paste(readLines(p, warn = FALSE), collapse = " "))
    expect_match(txt, "(T - d)^2 \\ge T + d", fixed = TRUE, info = v)
    expect_match(txt, "d <= n_traits", fixed = TRUE, info = v)
  }
  ## The rank article must say d = 3 with T = 5 is not identified, not only overfit.
  rk <- resolved[[file.path("articles", "model-selection-latent-rank.Rmd")]]
  txt <- gsub("\\s+", " ", paste(readLines(rk, warn = FALSE), collapse = " "))
  expect_match(txt, "not only overfit", fixed = TRUE)
  expect_match(txt, "is not identified", fixed = TRUE)
})
