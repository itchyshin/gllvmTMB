# block_V() must honour its documented positive-definite contract:
# a compound-symmetric m x m block is PD only when rho > -1/(m-1) (#656, #657).

test_that("block_V() enforces the positive-definite rho bound (#656/#657)", {
  s3 <- factor(rep("s1", 3))
  sv3 <- c(0.04, 0.05, 0.06)

  # Valid rho -> genuinely positive-definite.
  V <- block_V(s3, sv3, rho_within = 0.4)
  expect_true(all(eigen(V, symmetric = TRUE, only.values = TRUE)$values > 0))

  # rho below the -1/(m-1) bound was silently indefinite; now aborts.
  expect_error(
    block_V(s3, sv3, rho_within = -0.9),
    regexp = "positive-definite"
  )
  # Boundary rho = -1/(3-1) = -0.5 is only PSD -> also aborts.
  expect_error(
    block_V(s3, sv3, rho_within = -0.5),
    regexp = "positive-definite"
  )

  # 4-row block: bound is -1/3; -0.3 is PD, -0.5 is not.
  s4 <- factor(rep("s1", 4))
  sv4 <- rep(0.05, 4)
  expect_true(
    all(
      eigen(
        block_V(s4, sv4, rho_within = -0.3),
        symmetric = TRUE,
        only.values = TRUE
      )$values >
        0
    )
  )
  expect_error(
    block_V(s4, sv4, rho_within = -0.5),
    regexp = "positive-definite"
  )

  # Singleton studies are unaffected (no correlation block).
  s_mix <- factor(c("a", "b", "b", "b"))
  expect_error(
    block_V(s_mix, rep(0.05, 4), rho_within = -0.9),
    regexp = "positive-definite"
  )
})
