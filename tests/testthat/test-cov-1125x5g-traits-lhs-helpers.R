## Coverage (cursor-cloud-1125x5g): traits() LHS detection and RHS expand helpers.

test_that("traits() is a no-op invisible export", {
  expect_invisible(traits(t1 = "y1", t2 = "y2"))
})

test_that("is_traits_lhs() detects traits(...) on the LHS", {
  f_ok <- traits(y1, y2) ~ 1 + latent(1 | unit, d = 1)
  expect_true(gllvmTMB:::is_traits_lhs(f_ok))
  expect_false(gllvmTMB:::is_traits_lhs(y ~ x))
  expect_false(gllvmTMB:::is_traits_lhs(quote(traits())))
  expect_false(gllvmTMB:::is_traits_lhs(as.formula("~ x")))
})

test_that(".traits_is_one() and .traits_is_zero() recognise literals", {
  expect_true(gllvmTMB:::.traits_is_one(1))
  expect_true(gllvmTMB:::.traits_is_one(quote(1)))
  expect_false(gllvmTMB:::.traits_is_one(0))
  expect_true(gllvmTMB:::.traits_is_zero(0))
  expect_false(gllvmTMB:::.traits_is_zero(1))
})

test_that(".traits_call_name() extracts the leading call symbol", {
  call <- quote(latent(1 | unit, d = 2))
  expect_equal(gllvmTMB:::.traits_call_name(call), "latent")
  expect_null(gllvmTMB:::.traits_call_name(quote(trait)))
  expect_null(gllvmTMB:::.traits_call_name(3))
})

test_that(".traits_contains_symbol() walks nested calls", {
  rhs <- quote(1 + latent(1 | unit) + indep(1 | unit))
  expect_true(gllvmTMB:::.traits_contains_symbol(rhs, "latent"))
  expect_false(gllvmTMB:::.traits_contains_symbol(rhs, "banana"))
  expect_true(gllvmTMB:::.traits_contains_symbol(quote(trait), "trait"))
})

test_that(".traits_expand_bar_lhs() rewrites intercept one to 0 + trait", {
  bar <- quote(1 | unit)
  out <- gllvmTMB:::.traits_expand_bar_lhs(bar)
  expect_true(is.call(out[[2L]]))
  expect_equal(as.character(out[[2L]][[1L]]), "+")
  expect_equal(gllvmTMB:::.traits_expand_bar_lhs(quote(x | y)), quote(x | y))
})

test_that(".traits_expand_covstruct_call() expands bar on covstruct keywords", {
  latent_bar <- quote(latent(1 | unit, d = 1))
  expanded <- gllvmTMB:::.traits_expand_covstruct_call(latent_bar)
  expect_true(is.call(expanded[[2L]]))
  plain <- quote(indep(1 | unit))
  expanded_plain <- gllvmTMB:::.traits_expand_covstruct_call(plain)
  expect_true(is.call(expanded_plain[[2L]]))
  expect_equal(as.character(expanded_plain[[1L]]), "indep")
  pass <- quote(x + y)
  expect_identical(gllvmTMB:::.traits_expand_covstruct_call(pass), pass)
})

test_that(".traits_is_re_int_term() spots (a | g) random intercept syntax", {
  expect_true(gllvmTMB:::.traits_is_re_int_term(quote((1 | unit))))
  expect_false(gllvmTMB:::.traits_is_re_int_term(quote(latent(1 | unit))))
  expect_false(gllvmTMB:::.traits_is_re_int_term(quote(1)))
})

test_that(".traits_expand_rhs() maps shorthand intercepts and preserves zeros", {
  expect_equal(
    deparse(gllvmTMB:::.traits_expand_rhs(quote(1))),
    deparse(gllvmTMB:::.traits_trait_term())
  )
  expect_identical(gllvmTMB:::.traits_expand_rhs(quote(0)), quote(0))
  nested <- quote(1 + shared(latent(1 | unit, d = 1)))
  expanded <- gllvmTMB:::.traits_expand_rhs(nested, shared_marker = TRUE)
  expect_false(identical(expanded, nested))
})

test_that(".traits_has_column_slope() flags slope helpers in the tree", {
  expect_true(gllvmTMB:::.traits_has_column_slope(quote(slope(x))))
  expect_true(
    gllvmTMB:::.traits_has_column_slope(
      quote(phylo_slope(1 | trait, tree = tr))
    )
  )
  expect_false(gllvmTMB:::.traits_has_column_slope(quote(latent(1 | unit))))
})