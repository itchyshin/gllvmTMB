# D-139 pre-run test, truncated_poisson — RE-RUN WITH THE GATE LIFTED: **PASS**

**Date:** 2026-08-18 · **Authorised by:** Shinichi (explicit, this session)
**Supersedes:** the ABORT recorded in `dev/prerun-truncated-poisson-RESULTS.md`, which was
blocked and could not measure the fit. That document's *findings* stand; its ABORT verdict
is now resolved.

## What was blocking it

Design 128 §4's spec cannot execute against stock `main`: `truncated_poisson` is
`family_id` 10, deliberately absent from `.augmented_slope_family_contract()`
(`R/fit-multi.R:453`), so the #388 fence hard-errors at
`.augmented_slope_family_allowed()` (`R/fit-multi.R:2023`) before TMB is reached.
An earlier session's attempt to lift the gate was additionally blocked by the Claude Code
auto-mode permission classifier. **With Shinichi's explicit authorisation this session, the
gate-removal run executed.**

## Method

Isolated worktree off `origin/main` @ `7187b7d2`. `family_id` 10 added to the contract table
(`link_0 = TRUE`, `admission_basis = "D139_TEMPORARY_MEASUREMENT_ONLY"`) as clearly-marked
scaffolding, the §4 cell run verbatim, then **the patch reverted**.

**Verified after revert:** `git diff origin/main -- R/fit-multi.R` → empty; working tree
clean; `.augmented_slope_family_contract()` back to 11 rows with `10L %in% family_id` FALSE.
**No admission was made. The fence is intact on every branch.**

## Result — PASS on every §4 criterion

| Criterion | Threshold | Observed | |
|---|---|---|---|
| Elapsed | abort if > ~5 min | **20.352 s** | ✅ |
| `fit$opt$convergence` | must be 0 | **0** | ✅ |
| `fit$sd_report$pdHess` | (added; today's lesson) | **TRUE** | ✅ |
| `fit$report$sd_b` finite & positive | required | all 6 finite, all positive | ✅ |
| Pooled slope-SD ratio | C1 band 0.5–1.7 | **1.0473** | ✅ |

```
sd_b            : 0.7155 0.5782 0.5760 0.7885 0.5299 0.4158
slope_sd_hat    : 0.5782 0.7885 0.4158
true slope SD   : 0.5477 0.7071 0.4472
```

## What this DOES establish

- **The §4 timing gate is cleared.** `truncated_poisson` fits the augmented `phylo_indep(1 + x | species)`
  route at `n_sp = 250` in ~20 s, converged, with a positive-definite Hessian.
- **The campaign is viable and cheap.** At 20 s a fit, the full multi-seed acceptance cell
  Design 128 §2.1 specifies is a **minutes-scale** run, locally. D-50/D-143 do not bind;
  no Totoro.
- The earlier `poisson` proxy (9.2 s at N=250) was a good predictor: truncated is ~2.2×
  slower, inside the 1.2–2× band that was reasoned rather than measured — slightly over,
  so the reasoning was marginally optimistic.

## What this does NOT establish

- **NOT an admission.** `truncated_poisson` remains absent from the contract table. Per the
  #388 rule at `R/fit-multi.R:2044` a family joins only after its recovery cell **passes** —
  that cell must be written into `tests/testthat/`, run multi-seed, and reviewed.
- **SINGLE SEED.** One draw at one N. The 1.0473 ratio is a sanity signal, not recovery
  evidence, and says nothing about seed-to-seed variability.
- **The slope-vs-intercept indexing in the script is an ASSUMPTION**, not verified: it takes
  `sd_b` as interleaved (odd = intercept, even = slope). Given that an indexing error in
  `theta_dep_chol` was caught in adversarial review *earlier the same day* — and had already
  been explained away as sampling noise — **this assumption must be verified against the
  packing before any recovery claim rests on it.**
- No interval, coverage, or calibration claim (D-112; Design 80 Bar 3 belongs to the
  REML/AGHQ arc).
- Says nothing about `truncated_nbinom2` or `tweedie`. Tweedie remains a documented ~44%
  slope-SD bias that survives p-fixing — a research slice, not a campaign cell.

## Next step

Write the acceptance cell into `tests/testthat/`, multi-seed, verifying the indexing
assumption first. Only then may `family_id` 10 join the contract table — in a reviewed PR
that lands the test and the admission together.
