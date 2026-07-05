# Regression: the deprecation scanner (Pass 0) and the canonical-alias
# desugar walk must not crash when a model formula contains a
# namespace-qualified call such as `pkg::fn(...)`. For a `::` call the
# head `e[[1L]]` is itself a call (`+(::, pkg, fn)`), so the previous
# `as.character(e[[1L]])` produced a length-3 vector and the subsequent
# `if (fn == "...")` errored with "the condition has length > 1" under
# `_R_CHECK_LENGTH_1_CONDITION_`. The fix guards the head extraction with
# `is.name(e[[1L]])`. Discovered while implementing #354 / PR #367, where
# tests had to hoist `pkg::fn()` to a local to dodge this crash.

test_that("scan_for_deprecated does not crash on namespace-qualified (::) calls", {
  withr::local_envvar(c("_R_CHECK_LENGTH_1_CONDITION_" = "true"))
  rhs <- quote(
    0 + trait + phylo_unique(0 + trait | sp, vcv = gllvmTMB::pedigree_to_A(ped))
  )
  expect_no_error(gllvmTMB:::scan_for_deprecated(rhs))
})

test_that("scan_for_deprecated walks into the args of a :: call", {
  withr::local_envvar(c("_R_CHECK_LENGTH_1_CONDITION_" = "true"))
  # A deprecated keyword (`diag`) nested inside a `::`-qualified call's
  # arguments must still be reached by the recursion: the `::` head itself
  # is not matched as a keyword, but its arguments are walked. Detection is
  # signalled via cli_inform() gated by a once-per-session tracker, so reset
  # the `diag` entry first to make the message deterministic across test
  # ordering.
  seen <- gllvmTMB:::.gllvmTMB_deprecation_seen
  if (exists("diag", envir = seen, inherits = FALSE)) {
    rm("diag", envir = seen)
  }
  rhs <- quote(foo(some::wrapper(diag(0 + trait | g))))
  expect_message(
    gllvmTMB:::scan_for_deprecated(rhs),
    "diag",
    fixed = TRUE
  )
})

test_that("deprecated keyword messages point to replacement-specific help", {
  seen <- gllvmTMB:::.gllvmTMB_deprecation_seen
  if (exists("phylo_rr", envir = seen, inherits = FALSE)) {
    rm("phylo_rr", envir = seen)
  }
  msg <- character()
  withCallingHandlers(
    gllvmTMB:::scan_for_deprecated(quote(phylo_rr(species, d = 2))),
    message = function(cnd) {
      msg <<- c(msg, conditionMessage(cnd))
      invokeRestart("muffleMessage")
    }
  )
  msg <- paste(msg, collapse = "\n")

  expect_match(msg, "phylo_latent", fixed = TRUE)
  expect_match(msg, "?phylo_latent", fixed = TRUE)
  expect_no_match(msg, "?diag_re", fixed = TRUE)
})

test_that("desugar_brms_sugar does not crash on namespace-qualified (::) calls", {
  withr::local_envvar(c("_R_CHECK_LENGTH_1_CONDITION_" = "true"))
  # End-to-end of the pure-AST path: scan (Pass 0) + canonical-alias
  # rewrite + legacy desugar walk, all on a formula carrying a `::` call.
  # Must reach the end without the length>1 / "length = 3" coercion crash.
  f <- y ~ 0 + trait +
    phylo_unique(0 + trait | sp, vcv = gllvmTMB::pedigree_to_A(ped))
  expect_no_error(suppressWarnings(gllvmTMB:::desugar_brms_sugar(f)))
})
