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

test_that("deprecated/internal covariance aliases cannot carry lv silently", {
  A <- diag(4)
  rownames(A) <- colnames(A) <- paste0("u", 1:4)
  data <- data.frame(
    unit = factor(rep(paste0("u", 1:4), each = 2L), levels = paste0("u", 1:4)),
    trait = factor(rep(c("t1", "t2"), times = 4L), levels = c("t1", "t2")),
    value = seq_len(8L) / 10,
    x = rep(c(-1, 0, 1, 2), each = 2L),
    stringsAsFactors = FALSE
  )

  raw_allowed <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + rr(0 + trait | unit, d = 1, lv = ~x)
  )
  parsed_allowed <- gllvmTMB:::parse_multi_formula(raw_allowed)
  lv_terms <- which(vapply(
    parsed_allowed$covstructs,
    function(cs) {
      !is.null(cs$extra[["lv_formula"]]) || !is.null(cs$extra[["lv"]])
    },
    logical(1L)
  ))
  expect_length(lv_terms, 1L)
  expect_identical(parsed_allowed$covstructs[[lv_terms]]$kind, "rr")
  expect_identical(
    as.character(gllvmTMB:::gll_lv_formula(parsed_allowed$covstructs[[lv_terms]])),
    c("~", "x")
  )
  allowed_setup <- gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = parsed_allowed,
    data = data,
    trait = "trait",
    site = "unit",
    family_id_vec = rep(0L, nrow(data)),
    link_id_vec = rep(0L, nrow(data))
  )
  expect_true(isTRUE(allowed_setup$enabled))
  expect_equal(dim(allowed_setup$X_lv_B), c(4L, 1L))

  raw_rejected <- list(
    diag = value ~ 0 + trait + diag(0 + trait | unit, lv = ~x),
    phylo_rr = value ~ 0 + trait + phylo_rr(unit, d = 1, vcv = A, lv = ~x),
    spde = value ~
      0 + trait + spde(0 + trait | unit, coords = c("lon", "lat"), lv = ~x)
  )

  for (keyword in names(raw_rejected)) {
    expect_error(
      suppressWarnings({
        f <- gllvmTMB:::desugar_brms_sugar(raw_rejected[[keyword]])
        p <- gllvmTMB:::parse_multi_formula(f)
        gllvmTMB:::gll_prepare_lv_predictor_setup(
          parsed = p,
          data = data,
          trait = "trait",
          site = "unit",
          family_id_vec = rep(0L, nrow(data)),
          link_id_vec = rep(0L, nrow(data))
        )
      }),
      regexp = "ordinary unit-tier|ordinary `latent\\(\\)` only|does not support|LV-07",
      info = keyword
    )
  }
})
