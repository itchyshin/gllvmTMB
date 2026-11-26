## Diagnostic for issue #872 — flat two-tier Laplace surface at large response scale.
##
## Split from #851: start values are scale-aware, but a nested B+W gaussian fit can
## still stop with a scaled gradient that looks tight while a strictly lower nll
## exists one k = 1 re-parameterisation away. This is a measurement-only gate on
## main until the owner chooses polish vs convergence-rule change (refs #872).

test_that("two-tier gaussian oracle gap at k = 5000 (refs #872 diagnostic)", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)

  probe <- .issue_872_oracle_probe(k = 5000)

  expect_equal(probe$convergence_k1, 0L)
  expect_gt(probe$nll_gap, 0.001)
  expect_lt(probe$nll_gap, 0.05)
  expect_lt(probe$rel_par_dist, 0.05)
  expect_lt(probe$max_grad_oracle, 1e-3)
})