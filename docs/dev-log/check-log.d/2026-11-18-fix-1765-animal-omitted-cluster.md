# Check-log: omitted cluster adopts an animal grouping column (#1765)

**Goal:** Confirm `animal_latent(individual, A = A)` and `animal_indep(0 + trait | individual, A = A)` fit when `cluster` is omitted, matching `cluster = "individual"`. A missing `individual` column is named. An explicit `cluster = "trait"` is not rewritten.

**Commands:**

    Rscript -e 'testthat::test_file("tests/testthat/test-fix-1765-animal-omitted-cluster.R")'

R is not installed on this machine (`Rscript: command not found`). The command was not run. CI on the draft PR is the check.

**Results:** Not run locally.

**Claim boundary:** No likelihood or relatedness-matrix change. An explicit `cluster` is unchanged.
