test_that("ordinary latent lv desugars but source-specific lv fails loudly", {
  A <- diag(4)
  rownames(A) <- colnames(A) <- paste0("u", 1:4)

  ordinary <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
  )
  parsed <- gllvmTMB:::parse_multi_formula(ordinary)
  lv_terms <- which(vapply(
    parsed$covstructs,
    function(cs) !is.null(cs$extra[["lv_formula"]]),
    logical(1L)
  ))
  expect_length(lv_terms, 1L)
  expect_identical(
    as.character(parsed$covstructs[[lv_terms]]$extra$lv_formula),
    c("~", "x")
  )

  unsupported <- list(
    phylo_latent = value ~
      0 + trait + phylo_latent(unit, d = 1, vcv = A, lv = ~x),
    phylo_unique = value ~
      0 + trait + phylo_unique(unit, vcv = A, lv = ~x),
    animal_latent = value ~
      0 + trait + animal_latent(unit, d = 1, A = A, lv = ~x),
    animal_unique = value ~
      0 + trait + animal_unique(unit, A = A, lv = ~x),
    spatial_latent = value ~
      0 +
      trait +
      spatial_latent(
        0 + trait | unit,
        d = 1,
        coords = c("lon", "lat"),
        lv = ~x
      ),
    spatial_generic = value ~
      0 +
      trait +
      spatial(
        0 + trait | unit,
        mode = "latent",
        d = 1,
        coords = c("lon", "lat"),
        lv = ~x
      ),
    kernel_latent = value ~
      0 + trait + kernel_latent(unit, K = A, d = 1, lv = ~x),
    kernel_unique = value ~
      0 + trait + kernel_unique(unit, K = A, lv = ~x)
  )

  for (keyword in names(unsupported)) {
    expect_error(
      suppressWarnings(gllvmTMB:::desugar_brms_sugar(unsupported[[keyword]])),
      regexp = "ordinary `latent\\(\\)` only|LV-07|does not support",
      info = keyword
    )
  }
})
