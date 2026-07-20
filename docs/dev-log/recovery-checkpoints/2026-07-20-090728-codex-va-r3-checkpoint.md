# Recovery checkpoint — VA R3 pre-compute admission

## Branch and status

Branch: `codex/va-r3-prototype-20260720`, based on `origin/main` at
`0ae825fe`.

```text
 M docs/design/85-highdim-nongaussian-va-formal-contract.md
 M docs/dev-log/after-task/2026-07-20-va-r2-mathematical-closure.md
 M docs/dev-log/audits/2026-07-20-va-r2-mathematical-closure-gate.md
?? R/va-r3-proto.R
?? docs/dev-log/research/2026-07-20-va-r3-symbolic-implementation-map.md
?? inst/tmb/gllvmTMB_va_r3.cpp
?? tests/testthat/test-va-r3-prototype.R
?? tools/va-r3-pilot.R
```

## Completed commands and outcomes

- `NOT_CRAN=true devtools::test(filter = "va-r3-prototype", stop_on_failure = TRUE)`:
  124 PASS, 0 FAIL, 0 WARN, 0 SKIP.
- The suite covers the frozen H=61 scalar-oracle grid, q>1 projected
  covariance and KL, small-variance continuity and threshold sensitivity,
  analytic Gaussian posterior and gradients, byte-identical complete q=1/q=2
  ML/O3/VA cells, same-coordinate 15/25/61 ladders, and landed O3 anchors.
- Independent Noether/Rose re-review: PASS for bounded local pilot and
  conditional PASS for Totoro.
- The condition was implemented: results fail closed when any projected
  variance exceeds the certified `v <= 4` domain.
- `git diff --check`: PASS.
- No generated object or shared-library file is present under `inst/tmb`.

## Still required

1. Commit this exact source so `source_commit` becomes non-missing and remote
   receipts are reproducible.
2. Re-run the one-seed local pilot from the committed source.
3. Run the predeclared 25-seed q=1/q=2 pilot on Totoro with local, resumable
   receipts. Do not start q=4/q=6 unless the reference pilot is healthy.
4. Aggregate with attempted denominators, then request Fisher/Noether/Grace/
   Rose admission before any GO/NO-GO statement.

## Next safest action

Commit the exact internal prototype, tests, formal-contract amendment, and
pilot runner; verify `source_commit` resolves to that commit; then run one
local seed before copying the committed branch to Totoro.

## Boundaries

No public VA/AGHQ API, likelihood claim, non-Gaussian REML claim, interval
claim, NEWS/README/pkgdown promotion, or release claim is authorised. CI-11,
multinomial/tier-2a, Ayumi, Bartlett, and the entangled `check-log.md` worktree
remain untouched.
