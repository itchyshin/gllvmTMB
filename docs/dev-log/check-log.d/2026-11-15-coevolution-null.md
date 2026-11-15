# Check log: coevolution null covariance

This corrects the null assertion exposed by the heavy release check for PR #1794.

On Totoro, the `coevolution-recovery` tests were run with `NOT_CRAN=true`, `GLLVMTMB_HEAVY_TESTS=true` and one BLAS and OpenMP thread using `devtools::test(filter = "coevolution-recovery", stop_on_failure = TRUE)`. The source was release candidate `2dbfb8f0742abb7066f47afd35735c7042c32e9b`, with this test file substituted. Its SHA-256 was `c5e3a7bbf74743309f71785085d4efe6299a908c2cb9c1e2598e37a9a26d79d7`; hashes of that file and the three relevant engine files matched before and after the run. The focused run passed in 58 seconds. The retained log SHA-256 is `2c75e8d0ee1e7cdbfcfe3c834943fafc373e0811084bcc9290b92b5c42375095`.

An independently written dense rotation example changed the loading product while leaving the observed covariance and likelihood unchanged. The fitted null's largest loading-product entry was 0.09697657, while all 10,368 predicted host-partner covariances were zero.

The full package and heavy suites have not been run on this correction. The focused result does not certify the release or other coevolution models.
