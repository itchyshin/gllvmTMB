# Remove the three package-check blockers found during issue 1496 verification

## Goal and contract

Repair the three observed full-suite blockers separately from the cbind/bootstrap and CV changes. No likelihood, family, formula grammar, fitting default, native code or inference calculation changes. The loading wrapper now defaults to the documented scalar unit tier; explicit unit, unit_obs, B and W choices remain available. The warm test fixture selects a single start so its mocks exercise the warm candidate. Julia help retains the combined object/x description once.

## Files and examples

Changed R/loading-ci.R and generated man/flag_unreliable_loadings.Rd; R/julia-bridge.R and generated man/gllvmTMB_julia-methods.Rd; tests/testthat/test-warm-nlminb-restart.R; new loading-level-default and julia-methods-rd-arguments tests; NEWS and check-log plus this report. No example code changed. Existing examples in both help topics remain valid. README, vignettes, keyword grid, roadmap, grammar and validation-debt statuses are unchanged because no new model or capability is admitted. Roadmap tick: N/A.

## Evidence and tests of the tests

Original failure logs and diagnostics remain under dev/issue-1496; no evidence overwritten. Heavy1 had 22 failed assertions caused by the SVD-start call preceding the warm candidate. Heavy3 had one scalar-level forwarding error. Heavy2/4 failed the duplicate-x Rd warning. This follow-up preserves every acceptance, rejection, rollback, accounting, and provenance assertion; default SVD behavior remains covered by test-svd-start-1331.R.

New narrow tests on the old source: 3 failures, 10 passes, no errors/warnings/skips. They catch the default vector reaching the loading consumer and duplicate parsed documentation arguments. Explicit alias forwarding is also pinned. The original real-fit loading test checks the full inference route. An initial test version produced a secondary undefined-result error after its expected default failure; that test was corrected before the clean red run.

## Checks and limitations

Roxygen regeneration passed with compile=FALSE; unrelated generated sigma-registration spelling drift was restored to the exact prior NAMESPACE. pkgdown check passed (Pandoc mathml deprecation notices), both generated topics rendered with Rd2HTML, R parsing and Actions-boundary/reader-surface checks passed. Local tests use the existing unchanged native DLL; fresh builds and complete standard/heavy checks are CI gates. Targeted core tests passed 214 assertions with zero failures/errors/warnings/skips (35.8 seconds); existing shard selection passed 188 assertions. The broader loading/profile file is still running locally; its outcome and CI IDs are recorded in the PR body and dev/issue-1496-blockers receipts after they complete; this committed report describes pre-publication validation.

## Consistency audit

Exact scan: rg 'flag_unreliable_loadings\(|level *= *c\("unit", *"unit_obs"\)' R/loading-ci.R man/flag_unreliable_loadings.Rd README.md vignettes NEWS.md. No stale vector default remains in the wrapper/help; related calls remain valid. No article parsing, package version, API export or native rebuild was introduced.

## Review and learning

Fisher/Curie perspective: independent reviewer checked that selecting a single-start fixture restores the intended mocked warm candidate and keeps every behavioral assertion. The public SVD default is untouched and separately tested. The missing integration test after SVD selection remains optional future coverage, not a relaxed acceptance condition.

Rose/Grace perspective: independent reviewer confirmed scalar default and generated usage agree, and combined object/x documentation remains complete. Check policy, runtime limits, shard helper and test skips were preserved. Roxygen changes must be assessed separately from generator-version-only NAMESPACE drift.

Shannon perspective: this branch is stacked on the exact cbind/CV head, with original drafts preserved. Active documentation PR1567 touches loading help examples; this fix changes the function default and generated usage only, so eventual integration must preserve that separate work. Main remains at the original aec24e base at intake. User authorization now includes merging only task-related PRs after passing review/checks and verifying final main.

## Issue ledger and next action

Refs #1496 and historical PR1478. No issue comments or closures made during repair. No third-party contact. Complete exact-head standard/four-heavy verification, merge related PRs in dependency order under merge-when-green, then verify final main CI. No release, security settings change or Xcode-license acceptance/bypass.
