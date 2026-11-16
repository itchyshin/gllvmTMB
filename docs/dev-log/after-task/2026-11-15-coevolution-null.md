# Coevolution null test correction

The block-diagonal null kernel makes host-partner covariance zero. It does not force the separate loading product returned by `extract_Gamma()` to zero. The previous assertion required both and failed in the release heavy shard.

The test now checks the retained kernel, loading product and predicted cross-covariance separately, with a nonzero alternative as a positive control. A small deterministic test demonstrates the distinction without a fit. The focused heavy test passed; the full suites remain release gates. See the accompanying check log for source identity and evidence.
