## =====================================================================
## dev/test-xfc-methods.R  --  quick harness-level check that
## .xfc_one_rep() (dev/cross-family-coverage.R) returns rows for all 5
## wired (estimand, method) cells with a `method` column:
##   multiple_r x {bootstrap, wald}
##   contrast_r x {profile, wald, bootstrap}
##
## This is a dev-only sanity script (NOT part of `devtools::test()` / R CMD
## check) -- the harness itself is dev-only and env-guarded (XFC_MAIN). Run
## interactively after devtools::load_all():
##   source("dev/test-xfc-methods.R"); xfc_test_methods()
## =====================================================================

xfc_test_methods <- function() {
  Sys.unsetenv("XFC_MAIN")
  suppressMessages(source("dev/cross-family-coverage.R"))
  .xfc_ensure_pkg()

  fail <- function(msg) stop("[xfc_test_methods] FAIL: ", msg, call. = FALSE)
  ok <- function(msg) cat("[xfc_test_methods] ok: ", msg, "\n", sep = "")

  truth <- .xfc_build_truth(target_mr = 0.5, partner_family = "gaussian")

  rep_res <- .xfc_one_rep(truth, N = 60L, reps = 4L, seed = 909090L, n_boot = 12L,
                          estimands = c("multiple_r", "contrast_r"), conf = 0.95)
  if (!isTRUE(rep_res$converged)) {
    fail("fixture rep did not converge -- cannot check the 5-cell matrix")
  }

  ## (a) multiple_r: exactly 2 rows, method %in% c("bootstrap", "wald").
  mr <- rep_res$multiple_r
  if (is.null(mr) || !("method" %in% names(mr))) fail("multiple_r rows missing a method column")
  if (!setequal(mr$method, c("bootstrap", "wald"))) {
    fail(sprintf("multiple_r methods = {%s}, expected {bootstrap, wald}",
                paste(sort(unique(mr$method)), collapse = ", ")))
  }
  ok("multiple_r x {bootstrap, wald} both present")

  ## (b) contrast_r: method %in% c("profile", "wald", "bootstrap"), x 2 contrasts.
  cr <- rep_res$contrast_r
  if (is.null(cr) || !("method" %in% names(cr))) fail("contrast_r rows missing a method column")
  if (!setequal(cr$method, c("bootstrap", "profile", "wald"))) {
    fail(sprintf("contrast_r methods = {%s}, expected {bootstrap, profile, wald}",
                paste(sort(unique(cr$method)), collapse = ", ")))
  }
  if (!setequal(cr$contrast, truth$blk_names)) {
    fail("contrast_r rows do not cover both contrasts")
  }
  ok("contrast_r x {profile, wald, bootstrap} all present, both contrasts")

  ## (c) exactly the 5 wired cells: 2 (multiple_r) + 3*2 (contrast_r) = 8 rows total
  ## (contrast_r has 2 contrasts per method).
  n_mr <- nrow(mr); n_cr <- nrow(cr)
  if (n_mr != 2L) fail(sprintf("expected 2 multiple_r rows, got %d", n_mr))
  if (n_cr != 6L) fail(sprintf("expected 6 contrast_r rows (3 methods x 2 contrasts), got %d", n_cr))
  ok(sprintf("row counts as expected (multiple_r=%d, contrast_r=%d)", n_mr, n_cr))

  cat("[xfc_test_methods] ALL CHECKS PASSED  [", XFC_BANNER, "]\n", sep = "")
  invisible(TRUE)
}

if (identical(Sys.getenv("XFC_TEST_METHODS_MAIN"), "1")) {
  xfc_test_methods()
}
