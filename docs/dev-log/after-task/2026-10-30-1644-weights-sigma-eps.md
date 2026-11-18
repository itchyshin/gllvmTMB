# After Task: drop flaky weighted sigma_eps recovery assertion

**Branch**: `claude/cloud-1602-simulate-seed-restore`
**Date**: `2026-10-30`
**Roles (engaged)**: Curie, Fisher, Grace

## 1. Goal

PR #1644 restores the caller's RNG after `simulate_site_trait(seed =)`.
That change made `test-lme4-style-weights.R` Test 4 fail on CI shard 3
because the test drew heteroscedastic noise from leftover simulator
RNG and then asserted that a weighted Gaussian fit recovers `sigma_eps`
better than the unweighted fit. Pinning a post-simulate seed (previous
commit) made the failure deterministic: weighted error 0.58 vs
unweighted 0.46. Totoro already measured that comparison at 10/20
(30 sites) to 18/20 (1000 sites). This slice removes the false
recovery claim and keeps a consumption check.

## 2. Implemented

The heteroscedastic test still builds its own RNG stream after the
simulator restore. It now checks convergence, finite `sigma_eps`, and
that weights move `sigma_eps`. It no longer claims the weighted
estimate is closer to 1.

## 3. Files Changed

- `tests/testthat/test-lme4-style-weights.R`
- `docs/dev-log/check-log.d/2026-10-30-1644-weights-sigma-eps.md`
- `docs/dev-log/after-task/2026-10-30-1644-weights-sigma-eps.md`

## 3a. Decisions and Rejected Alternatives

- **Decision:** drop the single-seed "weighted closer to truth"
  assertion. **Rationale:** CI reproduced the Totoro finding; keeping
  the claim would be seed-luck. **Rejected:** pick another seed that
  happens to pass (the PR body already called that option (a) and it
  failed at 42). **Rejected:** multi-seed campaign on Actions (D-50).
  **Confidence:** high.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-10-30-1644-weights-sigma-eps.md`.
No local TMB compile; evidence is the failed CI log plus the rg
scans. Full shard re-run is the next CI on this push.

## 5. Tests of the Tests

The old assertion failed on CI (`0.58 >= 0.46`). The new assertions
would fail if weights were silently ignored (`sigma_eps` identical)
or if either fit failed to converge. They would still pass if the
weighted estimate were worse than the unweighted one, which is the
point.

## 6. Consistency Audit

- `rg -n "weighted fit improves sigma recovery"` in
  `tests/testthat/test-lme4-style-weights.R`: 0 hits.
- `rg -n "expect_lt\\(abs\\(rep_w\\$sigma_eps"` same file: 0 hits.
- No NEWS / README / article claim of weighted residual-SD recovery
  was added.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

- #1602: still the intended close of this PR; not closed here.
- Weighted `sigma_eps` recovery: receipt comment on
  https://github.com/itchyshin/gllvmTMB/pull/1644 (no new issue).

## 8. What Did Not Go Smoothly

`set.seed(42L)` after the simulator was not enough. That was option
(a) in the PR body, and seed 42 is one of the failing cells.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Curie:** a recovery comparison at n=30 next to `latent(d = 1)` is
  not a CI pin.
- **Fisher:** 10/20 to 18/20 is a measurement, not a green test.
- **Grace:** shard 3 of run 41133205539 is the evidence; do not merge
  on a rewritten seed.

## 10. Known Limitations And Next Actions

Weighted Gaussian `sigma_eps` next to a latent term remains unclaimed.
If Shinichi wants an issue, file it after merge from the #1644
comment. Next: wait for the new 4-shard run, then Ready-comment if
green.
