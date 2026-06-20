# Focused tests for the two salvaged coevolution exports
# (extract_coevolution_modules, diagnose_kernel_separability) ported from the
# dirty codex/r-bridge-grouped-dispersion working tree onto main.
#
# diagnose_kernel_separability is pure-R (dense kernels) and is covered fully
# here. extract_coevolution_modules requires a fitted gllvmTMB_multi 2-kernel
# coevolution model; its full fit-based recovery test lives in
# test-coevolution-two-kernel.R on the dirty tree and must be ported before this
# PR merges — here we only exercise its input guard.

test_that("diagnose_kernel_separability separates orthogonal kernels", {
  K_phy <- outer(1:4, 1:4, function(i, j) 0.7^abs(i - j))   # AR(1)-like, structured
  K_tip <- diag(4)                                          # identity, orthogonal-ish
  res <- diagnose_kernel_separability(phy = K_phy, tip = K_tip)

  expect_s3_class(res, "gllvmTMB_kernel_separability")
  expect_equal(dim(res$similarity), c(2L, 2L))
  expect_equal(diag(res$similarity), c(phy = 1, tip = 1))
  expect_true(isSymmetric(unname(res$similarity)))
  expect_equal(nrow(res$pairs), 1L)
  expect_true(all(c("level_1", "level_2", "similarity", "overlap_class",
                    "recommendation") %in% names(res$pairs)))
  # structured vs identity should not be highly overlapping
  expect_lt(res$pairs$similarity, 0.70)
})

test_that("diagnose_kernel_separability flags high overlap for duplicate kernels", {
  K <- outer(1:5, 1:5, function(i, j) 0.6^abs(i - j))
  res <- diagnose_kernel_separability(a = K, b = K)
  expect_equal(res$similarity[1L, 2L], 1, tolerance = 1e-8)
  expect_identical(res$pairs$overlap_class, "high")
})

test_that("diagnose_kernel_separability needs at least two kernels", {
  expect_error(
    diagnose_kernel_separability(only = diag(3)),
    "at least two kernel"
  )
})

test_that("diagnose_kernel_separability rejects mismatched dimensions", {
  expect_error(
    diagnose_kernel_separability(a = diag(3), b = diag(4)),
    "same dimensions"
  )
})

test_that("extract_coevolution_modules guards on non-multi input", {
  expect_error(
    extract_coevolution_modules(
      list(x = 1), level = "phy",
      row_traits = c("t1", "t2"), col_traits = c("t1", "t2")
    ),
    "Provide a fit returned by"
  )
})

# Fit-based recovery test for extract_coevolution_modules on the shipped
# cross-lineage coevolution example (no .c3_* fixture needed — uses the same
# on-main fit pattern as test-example-coevolution-kernel.R).
test_that("extract_coevolution_modules recovers module structure on the shipped example", {
  skip_on_cran()
  path <- system.file("extdata", "examples", "coevolution-kernel-example.rds",
                      package = "gllvmTMB")
  skip_if(!nzchar(path) || !file.exists(path), "coevolution kernel example not installed")
  ex <- readRDS(path)

  K_star <- ex$K_star                       # the kernel term references K_star from the env
  ctl <- gllvmTMBcontrol(se = FALSE)
  environment(ex$formula_wide) <- environment()
  fit <- suppressMessages(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    cluster = ex$fit_args$cluster,
    family = ex$fit_args$family,
    control = ctl
  ))
  expect_equal(fit$opt$convergence, 0L)

  ht <- ex$truth$host_traits
  pt <- ex$truth$partner_traits
  mods <- extract_coevolution_modules(fit, level = "cross", row_traits = ht, col_traits = pt)

  # structure
  expect_s3_class(mods, "gllvmTMB_coevolution_modules")
  expect_true(is.matrix(mods$R))
  expect_equal(dim(mods$R), c(length(ht), length(pt)))
  expect_equal(rownames(mods$R), ht)
  expect_equal(colnames(mods$R), pt)
  expect_true(all(is.finite(mods$R)))
  expect_s3_class(mods$modules, "data.frame")
  expect_true(all(c("component", "module", "singular_value", "squared_share") %in%
                    names(mods$modules)))
  expect_gte(nrow(mods$modules), 1L)
  # sensible decomposition: nonneg singular values, ordered descending, shares in [0,1]
  expect_true(all(mods$modules$singular_value >= -1e-8))
  expect_false(is.unsorted(rev(mods$modules$singular_value)))
  expect_true(all(mods$modules$squared_share >= -1e-8 & mods$modules$squared_share <= 1 + 1e-8))

  # recovery: the cross-block structure aligns with the simulated truth Gamma
  expect_gt(abs(stats::cor(as.vector(mods$R), as.vector(ex$truth$Gamma))), 0.5)
})
