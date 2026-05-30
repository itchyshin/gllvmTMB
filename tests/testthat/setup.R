# Heavy-test gate for the fast/slow CI split.
#
# `R CMD check` sets NOT_CRAN=true, so `skip_on_cran()` does not fire on CI and
# every TMB fit would run on routine PRs. To keep routine PR CI fast we gate the
# slow recovery/matrix/profile/bootstrap tests behind an explicit env flag.
#
# Routine PR CI (R-CMD-check.yaml) leaves GLLVMTMB_HEAVY_TESTS unset -> the
# heavy tests skip and only the fast suite runs. The nightly / pre-release
# full-check.yaml workflow sets GLLVMTMB_HEAVY_TESTS=1 -> the full suite runs
# across all three OSes.
#
# This file is sourced automatically by testthat before any test file
# (files matching ^setup are run as setup, in addition to helper*.R).
skip_if_not_heavy <- function() {
  testthat::skip_if(
    Sys.getenv("GLLVMTMB_HEAVY_TESTS") == "",
    "Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run"
  )
}
