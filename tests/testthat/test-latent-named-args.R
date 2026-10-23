test_that("latent() rejects unknown named arguments during desugar (#1415)", {
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, D = 2)
    ),
    regexp = "Unknown argument.*D.*latent"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, rank = 2)
    ),
    regexp = "Unknown argument.*rank.*latent"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2, uniq = FALSE)
    ),
    regexp = "Unknown argument.*uniq.*latent"
  )
})

test_that("latent() rejects fractional d during desugar (#1415)", {
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2.9)
    ),
    regexp = "d.*latent.*whole number"
  )
})
