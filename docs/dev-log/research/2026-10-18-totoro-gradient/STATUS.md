# Totoro reaction-norm gradient repair

Current branch: `codex/totoro-gradient-fixture-20261018`, based on main `2020ef25a2854b254f681d5323863d47dddb66f9`. The primary Dropbox checkout and other lanes remain untouched.

The baseline BFGS fixture stops with optimiser code zero, objective 24.942173471238448 and maximum raw gradient 0.018166713881886367. Its existing diagnostic correctly warns at the unchanged 0.01 threshold. BFGS uses a relative objective stopping rule, not this gradient rule; the package forwards `optArgs$control` directly to `stats::optim`.

The candidate sets `reltol = 1e-10` in both test helper calls and explicitly keeps `loading_ridge = Inf`. No package source or default changes. It adds a wide-format diagnostic assertion, direct finite-gradient checks below 0.01 in both formats, and checks that the gradients are unpenalised. Existing likelihood agreement and recovery assertions remain intact.

## Retained evidence

The corrected standalone test runner records four assertion failures and 69 passes before the control change (`test-red-clean.log`), then 73 passes without failures, errors, warnings or skips (`test-green.log`). `test-red.log` retains an earlier harness cleanup error after the same four real assertion failures. It was superseded by the clean runner, not hidden.

With `reltol = 1e-10`, long and wide raw gradients are 0.00023625510337466486 and their parameter vectors match exactly. Their objective is 24.618624883267103. A `1e-12` cross-check gives 24.618624882864196, a difference of about 4.03e-10. The fitted unit-slope covariance changes by 0.573% in relative Frobenius norm from the early-stopped baseline. These are point-estimate and stationarity checks, not Hessian or interval-coverage evidence.

An independent reviewer inspected the diff and these receipts, found no blocker, and confirmed that no neighbouring runtime change is needed.

## Full check checkpoint

Fresh source tarball: `gllvmTMB_0.8.0.9000.tar.gz`, SHA256 `ba34f02436646225b88d990d817525a5e8862702ce26ef09e0b8728f7f978ce8`.

Full `devtools::check(document = FALSE, args = "--no-manual")` restarted on Totoro at 19:27:57 UTC, PID 4115799, with a 30-minute timeout. Its startup probe confirms Pandoc 3.1.11.1. The first attempt at 19:23:20 stopped during vignette building because the Pandoc path named its parent directory; `package-build-pandoc-error.log` retains that failure. The corrected path ends in `tools/pandoc/bin`. Numerical libraries use one thread and compilation uses two processes. The private directory is `/home/snakagaw/gllvmtmb_gradient_fix_20261018`. The original failing check directory remains unchanged.

Completed at 19:56:18 UTC: full package check passed in 1,701.08 seconds with zero errors, zero warnings and two existing notes. The full test tally is FAIL 0, WARN 60, SKIP 1259, PASS 26641. `check-receipt.json`, `00check.log`, `package-check.log` and `full-testthat.Rout` retain the results. The original full check had one failing gradient assertion; that assertion now passes.

The neighbouring article's default nlminb fit was also checked on the frozen data: its raw gradient is about 0.0007743 and its standard-error calculation succeeds and its Hessian is positive definite. No article edit is needed.

Next: publish the verified, test-only repair through a PR with exact-head green checks required before merge, then verify main. No push, new PR or merge had occurred at this local verification checkpoint.
