test_that("temporal defers source pairs apart from qualified dependent-spatial", {
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
  temporal_terms <- c(
    indep = "temporal_indep(0 + trait | series, time = occasion, replicate = measurement)",
    dep = "temporal_dep(0 + trait | series, time = occasion, replicate = measurement)",
    latent = "temporal_latent(0 + trait | series, time = occasion, replicate = measurement, d = 1, unique = FALSE)"
  )

  for (temporal_name in names(temporal_terms)) {
    temporal <- temporal_terms[[temporal_name]]
    for (source_name in names(source_terms)) {
      source <- source_terms[[source_name]]
      if (identical(temporal_name, "dep") && identical(source_name, "spatial")) next
      formula <- stats::as.formula(paste0(
        "value ~ 0 + trait + ", temporal, " + ", source
      ))
      expect_error(
        gllvmTMB(formula, data = dat, unit = "series", cluster = "series",
          family = gaussian(), silent = TRUE),
        "temporal-only covariance"
      )
    }
  }
})
