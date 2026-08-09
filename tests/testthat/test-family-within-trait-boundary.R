test_that("family/link scale may not vary within one trait", {
  expect_invisible(.gllvmTMB_validate_family_scale_by_trait(
    family_id_vec = c(2L, 2L, 1L, 1L),
    link_id_vec = c(0L, 0L, 0L, 0L),
    trait_labels = c("poisson_trait", "poisson_trait", "binary_trait", "binary_trait")
  ))

  expect_error(
    .gllvmTMB_validate_family_scale_by_trait(
      family_id_vec = c(2L, 1L, 2L, 1L),
      link_id_vec = c(0L, 0L, 0L, 1L),
      trait_labels = c("species_a", "species_a", "species_b", "species_b")
    ),
    "cannot currently vary across rows within a trait",
    class = "gllvmTMB_family_within_trait_unsupported"
  )
})

test_that("the public mixed-family path enforces the within-trait fence", {
  dat <- expand.grid(
    unit = factor(sprintf("u%02d", seq_len(8L))),
    trait = factor("species_a")
  )
  dat$family_selector <- rep(c("poisson", "binomial"), length.out = nrow(dat))
  dat$value <- rep(c(0, 1), length.out = nrow(dat))
  families <- list(poisson = poisson(), binomial = binomial())
  attr(families, "family_var") <- "family_selector"

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | unit),
      data = dat,
      family = families,
      unit = "unit"
    ),
    "cannot currently vary across rows within a trait",
    class = "gllvmTMB_family_within_trait_unsupported"
  )
})
