# After-task: betabinomial C1 slope admission (D-113 track 6 / Rung 1)

**Branch:** `claude/slope-per-family-20260801`  
**Worktree:** `/private/tmp/gllvmtmb-slope-per-family-20260801`  
**Date:** 2026-08-01  
**Roles:** Curie (build/verify) · Rose (register/scope) · Ada (lane)

## Goal

Admit `betabinomial` (`family_id` 8, logit) to the structured augmented-slope runtime contract under #388, with a multi-trial `phylo_indep(1 + x | species)` C1 recovery cell. Zero new C++.

## Outcome

- Gap ledger: `docs/dev-log/after-task/2026-08-01-slope-per-family-gap-ledger.md`
- Contract: `.augmented_slope_family_contract()` now includes `8L` as `c1_partial` (logit / `link_0` only); scope text names `betabinomial()`
- Test: `tests/testthat/test-family-slope-recovery.R` — multi-trial DGP + large-N cell (`n_sp = 200`, trials = 15, seed = 7)
- Policy: `test-augmented-slope-family-policy.R` updated for id 8
- Register: FAM-05 / RE-02 / RE-14 notes; capability-surface Rand. slope = partial (C1)
- Probe (local): `dev/probe-betabinomial-slope.R` — n_sp=90 fails conv; n_sp=120/200 clear (Shinichi: large-N principle)

## Checks (log, not exit code alone)

```
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
  Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-augmented-slope-family-policy.R")'
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 28 ]

NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
  Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-family-slope-recovery.R")'
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 15 ]
```

## What this does NOT cover

- Tweedie slope admission (still gated)
- Route-specific phylo_dep / phylo_latent / spatial recovery for betabinomial
- Interval calibration / coverage (D-112)
- Missing-data #336–#338; EVA / AGHQ / #750 / SEPARABLE
- Replicated-seed or Hessian/gradient health for the C1 cell

## Arc actuals

- Recommended ~2.5–3.5 h; large-N probe added ~2 min wall after first fail
- Repair: fixture escalated from n_sp=90 to n_sp=200 after conv=1
- Melissa: N/A — small admission slice

## Next

- Remaining D-113 slope gaps from ledger: tweedie campaign; truncated_*; delta_* (fenced)
- Programme: missing-data #332 / #336 as separate arc
