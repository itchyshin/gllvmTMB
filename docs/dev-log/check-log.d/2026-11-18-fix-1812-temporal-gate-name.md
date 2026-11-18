# Check-log: temporal gate messages name the keyword used (#1812)

**Goal:** Confirm the three post-parse temporal gates in `gllvmTMB()` name `temporal_indep()` or `temporal_dep()`, and that a `temporal_latent()` family refusal still says `temporal_latent()`.

**Commands:**

    Rscript -e 'testthat::test_file("tests/testthat/test-fix-1812-temporal-gate-name.R")'

R is not installed on this machine (`Rscript: command not found`). The command was not run. CI on the draft PR is the check.

**Results:** Not run locally.

**Claim boundary:** Message text only. The Gaussian, Laplace, and single-provider rules are unchanged. Parser refusals from the earlier marker_name change are untouched.
