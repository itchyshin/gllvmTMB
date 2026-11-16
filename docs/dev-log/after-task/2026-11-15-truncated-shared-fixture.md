# Match the truncated-count shared fixture

The shared-only truncated-count fixture generates one latent factor without diagonal variation. The test now asks `latent()` for that same structure, because its default includes a diagonal component. The existing boundary and recovery checks remain in place, with an additional assertion that the diagonal component is absent.

The focused heavy test passed with two profile-interval skips. The full suite remains a release gate. Source and diagnostic details are in the accompanying check log.
