# Regression test for the family-label map omitting nbinom1 id 15 (#603).

test_that(".gllvmTMB_family_label_from_id maps nbinom1 (id 15) (#603)", {
  lab <- gllvmTMB:::.gllvmTMB_family_label_from_id(c(0L, 2L, 5L, 14L, 15L))
  expect_equal(
    lab,
    c("gaussian", "poisson", "nbinom2", "ordinal_probit", "nbinom1")
  )
  # Genuinely unknown ids still fall through to the sentinel label.
  expect_match(
    gllvmTMB:::.gllvmTMB_family_label_from_id(99L),
    "family_id_99"
  )
})
