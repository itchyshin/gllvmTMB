# Check log: truncated shared-only fixture

The heavy release test generated a shared factor with no diagonal component, but its bare `latent()` formula also fitted diagonal variation. The resulting `near_zero_sd_B` flag was valid. This change specifies `unique = FALSE` for the shared-only fits and asserts that the diagonal component is absent.

On Totoro, the focused command was `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript --no-init-file -e 'devtools::test(filter="matrix-truncated", stop_on_failure=TRUE)'`. The source was release candidate `2dbfb8f0742abb7066f47afd35735c7042c32e9b` with the coevolution correction and this test file substituted. The test file SHA-256 was `884a90653d0fd92da91f45e1df16896f7e923b5fb87237510edecf3cc0a80bf9`. The run reported FAIL 0, WARN 0, SKIP 2, PASS 29 in 16.73 seconds. Both skipped tests concern unavailable finite profile bounds. The retained log SHA-256 is `ec539437ecba04619c405e164473507ccfa9a9da40e97740054e1c0bc62eb03b`.

A separate same-data comparison found the default fit flagged `near_zero_sd_B`; the explicitly shared-only fit had no boundary flag. The test keeps its convergence, Hessian, boundary and recovery requirements. Full package checks remain outstanding, and this result does not establish profile interval coverage.
