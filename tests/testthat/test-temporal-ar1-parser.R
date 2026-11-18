## Migration fixture for the pre-release AR1 prototype.  The public contract
## is now the sixth temporal source; these checks prevent its old consecutive-
## occasion and IID-Psi interpretations from returning through compatibility.
test_that("AR1 migration fixture retains gaps and OU remains a distinct API", {
  dat <- expand.grid(series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  dat$value <- seq_len(nrow(dat))
  ar1 <- gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion,
      unique = TRUE), dat, trait_col = "trait")
  expect_equal(ar1$spec$pair_table$time[ar1$spec$pair_table$series == "a"],
    c(1, 3, 7))
  expect_identical(ar1$spec$structure, "ar1")
  dat$elapsed <- c(0, 1.5, 5)[match(dat$occasion, c(1L, 3L, 7L))]
  ou <- gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = elapsed,
      structure = "ou"), dat, trait_col = "trait")
  expect_identical(ou$spec$structure, "ou")
  expect_error(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = elapsed),
    dat, trait_col = "trait"), "integer-valued")
})

test_that("temporal constructors and parser keep the prior boundary checks", {
  term <- temporal_latent(0 + trait | series, time = occasion, d = 1)
  expect_s3_class(term, "gllvmTMB_temporal_latent")
  expect_equal(term$d, 1L)
  expect_equal(term$structure, "ar1")
  expect_error(
    temporal_latent(0 + trait | series, time = occasion, d = 2),
    "rank one"
  )
  expect_error(
    temporal_indep(0 + trait | series, time = occasion + 1),
    "bare column"
  )
  base <- expand.grid(
    series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  base$value <- seq_len(nrow(base))
  expect_error(gllvmTMB(
    value ~ 0 + trait + temporal_latent(1 | series, time = occasion),
    data = base, unit = "series", family = gaussian()
  ), "trait-intercept block")
  expect_error(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    base[-1L, ], trait_col = "trait"
  ), "complete trait panel")
  expect_error(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    rbind(base, base[1L, ]), trait_col = "trait"
  ), "replicate")
})
