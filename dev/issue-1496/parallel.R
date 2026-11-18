library(gllvmTMB)
for (e in parse("tests/testthat/test-bootstrap-binomial-response.R")) {
  if (
    is.call(e) &&
      identical(e[[1]], as.name("<-")) &&
      identical(e[[2]], as.name(".bootstrap_binomial_fixture"))
  ) {
    eval(e)
  }
}
fit <- .bootstrap_binomial_fixture(quote(cbind(s, n - s)), policy = "include")
a <- suppressWarnings(bootstrap_Sigma(
  fit,
  n_boot = 3,
  conf = .5,
  seed = 1496,
  level = "unit",
  what = "Sigma",
  keep_draws = TRUE,
  progress = FALSE,
  n_cores = 1
))
b <- suppressWarnings(bootstrap_Sigma(
  fit,
  n_boot = 3,
  conf = .5,
  seed = 1496,
  level = "unit",
  what = "Sigma",
  keep_draws = TRUE,
  progress = FALSE,
  n_cores = 2
))
stopifnot(
  a$n_failed == 0L,
  b$n_failed == 0L,
  isTRUE(all.equal(a$draws, b$draws, tolerance = 1e-7))
)
cat(
  "PARALLEL_CBIND_PASS: 3/3 refits succeeded; sequential/parallel draws agree\n"
)
cat("Installed source:", find.package("gllvmTMB"), "\n")
