test_that("source *_latent() rejects invalid d during desugar (#1762)", {
  latent_d_re <- "d.*latent.*whole number >= 1"
  K <- diag(2)
  rownames(K) <- colnames(K) <- paste0("s", seq_len(2))
  A <- diag(2)

  expect_latent_d_abort <- function(f, envir = parent.frame()) {
    f <- stats::as.formula(f, env = envir)
    expect_error(
      gllvmTMB:::desugar_brms_sugar(f, envir = envir),
      regexp = latent_d_re
    )
  }

  bad_cases <- list(
    TRUE,
    -1L,
    quote(-1),
    quote(1 - 2),
    NA,
    quote(c(1, 2)),
    0,
    2.9
  )

  for (d_rhs in bad_cases) {
    expect_latent_d_abort(
      substitute(
        value ~ 0 + trait + phylo_latent(species, d = DRHS),
        list(DRHS = d_rhs)
      )
    )
    expect_latent_d_abort(
      substitute(
        value ~ 0 + trait + animal_latent(species, A = A, d = DRHS),
        list(DRHS = d_rhs)
      ),
      envir = environment()
    )
    expect_latent_d_abort(
      substitute(
        value ~ 0 + trait + kernel_latent(species, K = K, d = DRHS, name = "k"),
        list(DRHS = d_rhs)
      ),
      envir = environment()
    )
    expect_latent_d_abort(
      substitute(
        value ~ 0 + trait + spatial_latent(0 + trait | coords, d = DRHS),
        list(DRHS = d_rhs)
      )
    )
  }

  k_bad <- -1L
  expect_latent_d_abort(
    value ~ 0 + trait + phylo_latent(species, d = k_bad),
    envir = environment()
  )
  expect_latent_d_abort(
    value ~ 0 + trait + animal_latent(species, A = A, d = k_bad),
    envir = environment()
  )
  expect_latent_d_abort(
    value ~ 0 + trait + kernel_latent(species, K = K, d = k_bad, name = "k"),
    envir = environment()
  )
  expect_latent_d_abort(
    value ~ 0 + trait + spatial_latent(0 + trait | coords, d = k_bad),
    envir = environment()
  )

  expect_latent_d_abort(
    value ~ 0 + trait + phylo_latent(1 + x | species, d = TRUE),
    envir = environment()
  )
})

test_that("source *_latent() keeps valid d spellings during desugar (#1762)", {
  K <- diag(2)
  rownames(K) <- colnames(K) <- paste0("s", seq_len(2))
  A <- diag(2)
  k_ok <- 2L

  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_latent(species, d = 2)
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_latent(species, d = 2L)
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_latent(species, d = 2.0)
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_latent(species, d = k_ok),
      envir = environment()
    )
  )

  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + animal_latent(species, A = A, d = 2),
      envir = environment()
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + animal_latent(species, A = A, d = k_ok),
      envir = environment()
    )
  )

  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + kernel_latent(species, K = K, d = 2, name = "k"),
      envir = environment()
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + kernel_latent(species, K = K, d = k_ok, name = "k"),
      envir = environment()
    )
  )

  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + spatial_latent(0 + trait | coords, d = 2)
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + spatial_latent(0 + trait | coords, d = k_ok),
      envir = environment()
    )
  )

  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_latent(1 + x | species, d = 2),
      envir = environment()
    )
  )
})
