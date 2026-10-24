## #1349: ?latent must state the identifiable range of d for the default
## Sigma = Lambda Lambda^T + Psi fit. The code only guards d <= n_traits,
## which reads like the full rule; the help page has to say it is not.
## Reads the roxygen source (R/brms-sugar.R) and, when present, the generated
## Rd, so the check works from a source checkout and fails if either is stale.

test_that("?latent argument d states the (T - d)^2 >= T + d identifiable range (#1349)", {
  src <- testthat::test_path("..", "..", "R", "brms-sugar.R")
  testthat::skip_if_not(file.exists(src), "not a source checkout")
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
  rd <- testthat::test_path("..", "..", "man", "latent.Rd")
  testthat::skip_if_not(file.exists(rd), "not a source checkout")
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

test_that("the three teaching vignettes state the identifiable range of d (#1349)", {
  vigs <- c(
    "gllvmTMB.Rmd",
    file.path("articles", "covariance-correlation.Rmd"),
    file.path("articles", "model-selection-latent-rank.Rmd")
  )
  for (v in vigs) {
    p <- testthat::test_path("..", "..", "vignettes", v)
    testthat::skip_if_not(file.exists(p), "not a source checkout")
    txt <- gsub("\\s+", " ", paste(readLines(p, warn = FALSE), collapse = " "))
    expect_match(txt, "(T - d)^2 \\ge T + d", fixed = TRUE, info = v)
    expect_match(txt, "d <= n_traits", fixed = TRUE, info = v)
  }
  ## The rank article must say d = 3 with T = 5 is not identified, not only overfit.
  rk <- testthat::test_path("..", "..", "vignettes", "articles", "model-selection-latent-rank.Rmd")
  txt <- gsub("\\s+", " ", paste(readLines(rk, warn = FALSE), collapse = " "))
  expect_match(txt, "not only overfit", fixed = TRUE)
  expect_match(txt, "is not identified", fixed = TRUE)
})
