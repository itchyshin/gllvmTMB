# Prior table: separate deferred MSPL multiplier

Shinichi directed the prior-table integration to set aside MSPL development. This candidate restores the pre-multiplier versions of the three R/TMB production files and removes the multiplier-only test file. The private multiplier work remains in commit 540be304 and the separate MSPL pull request #981. The Psi prior refusal test was retained in test-prior-table-unique-variance.R. No prior-table likelihood code was changed.

Validation of the new candidate is recorded in the pull request and its external evidence receipts. The prior full-suite evidence for commit 9d74123 applies to matching production files; the prior run's residual-replay caveat remains.
