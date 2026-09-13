test_that("the first temporal release refuses every static-source combination", {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, measurement = c("m1", "m2"),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- 0
  source_terms <- c(
    phylo = "phylo_indep(0 + trait | series, tree = tree)",
    animal = "animal_indep(0 + trait | series, A = A)",
    spatial = "spatial_indep(0 + trait | series, mesh = mesh)",
    kernel = "kernel_indep(series, K = K, name = 'deferred_kernel')"
  )

  for (source in source_terms) {
    formula <- stats::as.formula(paste0(
      "value ~ 0 + trait + ",
      "temporal_indep(0 + trait | series, time = occasion, replicate = measurement) + ",
      source
    ))
    expect_error(
      gllvmTMB(formula, data = dat, unit = "series", cluster = "series",
        family = gaussian(), silent = TRUE),
      "temporal-only covariance"
    )
  }
})
