## Strand 0 (Design 79 RE-surface arc): kernel keywords must FAIL LOUD on a
## random-slope bar rather than silently mis-parse it. Before this guard,
## `kernel_indep(1 + x | g, K = K)` was passed straight to `phylo_rr`, which
## garbled it into `lhs = 0 + (1 + x | g)`, `group = trait` with no error.
## The kernel random-slope engine (B1) is not yet wired; until then the bar form
## is rejected clearly.

test_that("kernel keywords reject a random-slope bar with a clear error", {
  K <- diag(3)
  for (kw in c("kernel_indep", "kernel_dep", "kernel_latent")) {
    f <- stats::as.formula(sprintf("y ~ %s(1 + x | g, K = K)", kw))
    expect_error(
      gllvmTMB:::rewrite_canonical_aliases(f),
      regexp = "random-slope bar",
      info = kw
    )
  }
})

test_that("intercept-only kernel keywords still route (no regression)", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  K <- diag(3)
  txt <- paste(deparse(
    gllvmTMB:::rewrite_canonical_aliases(y ~ kernel_indep(unit, K = K))
  ), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, ".kernel_mode = \"indep\"", fixed = TRUE)
})
