# Check-log: omitted cluster adopts a phylo grouping column (#1766)

**Goal:** Confirm `phylo_latent(taxon, vcv = K)` and `phylo_indep(0 + trait | taxon, vcv = K)` fit when `cluster` is omitted, matching an explicit `cluster = "taxon"`, and that a missing `taxon` column is named. A `species` column with a bad matrix must still say `phylo_vcv`.

**Commands:**

    Rscript -e 'testthat::test_file("tests/testthat/test-fix-1766-phylo-omitted-cluster.R")'

R is not installed on this machine (`Rscript: command not found`). The command was not run. CI on the draft PR is the check.

**Results:** Not run locally.

**Claim boundary:** No likelihood or phylogenetic covariance change. An explicit `cluster`, and the default name `species` when that column is absent, keep their existing messages.
