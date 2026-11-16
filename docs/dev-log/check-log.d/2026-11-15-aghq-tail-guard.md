# Check log: q2 golden-oracle tail guard

Goal: Stop the q2 test oracle from returning a log likelihood when the standard-normal prior tail outside its fixed window is too large relative to its computed in-window integral.

Command:

    Rscript --vanilla -e 'source("tests/testthat/helper-aghq-golden.R"); testthat::test_file("tests/testthat/test-aghq-golden-tail.R", reporter="summary", stop_on_failure=TRUE)'

Result: Nine expectations passed locally. The tests cover a regular analytic case, the reported rare-event case on each latent coordinate, two sides of the relative-tail threshold, and invalid response encodings.

The existing AGHQ golden suite and the new guard tests passed on Totoro on source `5d16be354912021be22bc7e63deee7a5c6a994cb` in 71.18 seconds, using `devtools::test(filter="aghq-golden", reporter="summary", stop_on_failure=TRUE)` with one thread. The source-after manifest matched.

Not yet run: The full package checks and hosted CI.

Claim boundary: For plain binary data, the standard-normal union bound controls the omitted tail relative to the computed in-window result. This is conditional on the in-window quadrature being accurate; it does not certify the fixed-rule fallback. The guard refuses a rare case instead of calculating its full likelihood and does not change model-fitting code.
