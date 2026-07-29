## The `||` support set is enumerated in one place (R/brms-sugar.R). The
## rejection message used to restate it by hand and had drifted -- it omitted
## kernel_indep, kernel_dep, spatial_indep and spatial_dep, understating the
## package's own support to the user who hit it. The message is now built from
## the same vectors as the guard, and these tests pin that agreement.

test_that("an unsupported `||` keyword stops rather than silently correlating", {
  f <- value ~ 0 + trait + kernel_latent(1 + x || g, K = K, d = 2)
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(f),
    "not yet supported"
  )
})

test_that("the `||` rejection message lists every supported keyword", {
  f <- value ~ 0 + trait + kernel_latent(1 + x || g, K = K, d = 2)
  msg <- tryCatch(
    gllvmTMB:::rewrite_canonical_aliases(f),
    error = function(e) paste(conditionMessage(e), collapse = " ")
  )

  ## The four that the hand-written message had dropped.
  expect_match(msg, "kernel_indep")
  expect_match(msg, "kernel_dep")
  expect_match(msg, "spatial_indep")
  expect_match(msg, "spatial_dep")
  ## ... and a representative of the ones it did list.
  expect_match(msg, "phylo_latent")
})

test_that("supported `||` keywords are not rejected", {
  ## kernel_indep is the control: the article claims `||` works for it, and a
  ## fix to the article's kernel_latent exception is only right if this passes.
  expect_no_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + kernel_indep(1 + x || g, K = K)
    )
  )
})
