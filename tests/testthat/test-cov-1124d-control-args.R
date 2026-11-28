# Coverage gap: gllvmTMBcontrol() argument checks and the family-name
# resolver. These paths abort or return before any model is fit.

test_that("gllvmTMBcontrol() rejects a non-odd or too-small va_H", {
  expect_error(gllvmTMBcontrol(va_H = 4), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = 1), "odd integer")
  expect_error(gllvmTMBcontrol(va_H = NA_real_), "odd integer")
  expect_identical(gllvmTMBcontrol(va_H = 5)$va_H, 5L)
})

test_that("gllvmTMBcontrol() rejects a fractional or zero optimizer_passes", {
  expect_error(gllvmTMBcontrol(optimizer_passes = 1.5), "whole-number")
  expect_error(gllvmTMBcontrol(optimizer_passes = 0), "whole-number")
  expect_error(gllvmTMBcontrol(optimizer_passes = NA_integer_), "whole-number")
  expect_identical(gllvmTMBcontrol(optimizer_passes = 2)$optimizer_passes, 2L)
})

test_that("gllvmTMBcontrol() rejects non-logical se and svd_start", {
  expect_error(gllvmTMBcontrol(se = NA), "se")
  expect_error(gllvmTMBcontrol(se = 1), "TRUE")
  expect_error(gllvmTMBcontrol(svd_start = NA), "svd_start")
  expect_error(gllvmTMBcontrol(svd_start = "no"), "svd_start")
  off <- gllvmTMBcontrol(svd_start = FALSE)
  expect_false(off$svd_start)
  expect_true(off$svd_start_explicit)
  expect_false(gllvmTMBcontrol()$svd_start_explicit)
})

test_that("gllvmTMBcontrol() refuses AGHQ together with the VA route", {
  expect_error(
    gllvmTMBcontrol(integration = "va", aghq = 3L),
    "cannot be combined"
  )
  expect_error(gllvmTMBcontrol(integration = "eva"), "should be one of")
})

test_that("gllvmTMBcontrol() names a bad aghq value and a bad flag", {
  expect_error(gllvmTMBcontrol(aghq = "nine"), "aghq")
  expect_error(gllvmTMBcontrol(aghq = 1.5), "aghq")
  expect_error(gllvmTMBcontrol(warn_runaway = "yes"), "warn_runaway")
  expect_error(gllvmTMBcontrol(aghq_continuation = c(TRUE, FALSE)), "aghq_continuation")
  auto <- gllvmTMBcontrol(aghq = TRUE)
  expect_identical(auto$aghq, "auto")
  expect_true(auto$aghq_explicit)
  expect_identical(gllvmTMBcontrol(aghq_grad_tol_rel = 0)$aghq_grad_tol_rel, 0)
})

test_that("gllvmTMBcontrol() rejects a negative tolerance and a negative audit threshold", {
  expect_error(gllvmTMBcontrol(aghq_grad_tol_rel = -1), "aghq_grad_tol_rel")
  expect_error(gllvmTMBcontrol(aghq_f_tol = 0), "aghq_f_tol")
  expect_error(gllvmTMBcontrol(laplace_warn_thresh = -1), "laplace_warn_thresh")
  expect_error(gllvmTMBcontrol(init_strategy = "banana"), "should be one of")
  expect_error(gllvmTMBcontrol(va_eval_method = "ac"), "should be one of")
})

test_that("VA optimiser controls abort before a fit is built", {
  expect_error(
    gllvmTMBcontrol(
      integration = "va",
      optArgs = list(control = list(iter.max = 10L))
    ),
    "explicit"
  )
  expect_error(
    gllvmTMBcontrol(
      integration = "va",
      optimizer = "nlminb",
      optArgs = list(1)
    ),
    "uniquely named"
  )
  expect_error(
    gllvmTMBcontrol(
      integration = "va",
      optimizer = "optim",
      optArgs = list(method = "CG")
    ),
    "BFGS"
  )
  expect_error(
    gllvmTMBcontrol(
      integration = "va",
      optimizer = "nlminb",
      optArgs = list(hessian = TRUE)
    ),
    "nlminb"
  )
})

test_that("a character family name resolves to the matching family object", {
  gauss <- gllvmTMB:::.gllvmTMB_family_from_character("gaussian")
  expect_s3_class(gauss, "family")
  expect_identical(gauss$family, "gaussian")

  pois <- gllvmTMB:::.gllvmTMB_family_from_character("poisson")
  expect_identical(pois$family, "poisson")

  nb <- gllvmTMB:::.gllvmTMB_family_from_character("nbinom2")
  expect_s3_class(nb, "family")
  expect_identical(nb$family, "nbinom2")

  hurdle <- gllvmTMB:::.gllvmTMB_family_from_character("delta_lognormal")
  expect_s3_class(hurdle, "family")

  expect_error(
    gllvmTMB:::.gllvmTMB_family_from_character("not_a_family"),
    "Unsupported family"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_family_from_character("screen_control"),
    "Unsupported family"
  )
})

test_that("an uncalled family constructor is called, and a non-family is refused", {
  from_fn <- gllvmTMB:::.gllvmTMB_resolve_family_constructors(stats::gaussian)
  expect_s3_class(from_fn, "family")
  expect_identical(from_fn$family, "gaussian")

  from_name <- gllvmTMB:::.gllvmTMB_resolve_family_constructors("binomial")
  expect_identical(from_name$family, "binomial")

  already <- gaussian()
  expect_identical(
    gllvmTMB:::.gllvmTMB_resolve_family_constructors(already)$family,
    "gaussian"
  )

  paired <- gllvmTMB:::.gllvmTMB_resolve_family_constructors(
    list(a = stats::gaussian, b = stats::poisson)
  )
  expect_named(paired, c("a", "b"))
  expect_identical(paired[[1L]]$family, "gaussian")
  expect_identical(paired[[2L]]$family, "poisson")

  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_family_constructors(function() 1),
    class = "gllvmTMB_family_constructor"
  )
})
