# After Task: Tweedie MSPL hang — working W_* + BFGS skip

**Branch**: `cursor/mspl-tweedie-hang`
**Date**: `2026-08-16`
**Roles (engaged)**: Fisher / Gauss / Curie / Rose / Grace

## 1. Goal

Diagnose the `#999` 8×3 Tweedie live MSPL hang against the W_*
two-sided rule, then either unstick that cell with a fenced working-W
change or document BLOCKED. No public door, no admit, no `se=TRUE`,
no NEWS covered.

## 2. Implemented

True Tweedie `W = μ^{2-p}/φ` is one-sided (`0 / +∞`) and rewards
`φ → 0`. The live C++ tape uses working logistic `W_*` on `η` plus
Huber on `log φ` and `logit(p-1)`.

The residual hang after that tape change was **not** first-eval AD
cost. Staged probe: `MakeADFun` and each `fn()`/`gr()` were
milliseconds; the process then sat in the MSPL BFGS rescue
(`optim(..., maxit = 5000)` from `par_init`), written for spatial
Bernoulli. Family 6 now skips that rescue. Huber
`mspl_dispersion_nll` is included in the penalty-off decomposition
sum (without it the cell aborted in 4.5 s with residual 38.68).

Default-nlminb probe:

```
PROBE_OK class=gllvmTMB_mspl/... registry=planned elapsed=1.549s
optimizer=nlminb
```

Public prepare still rejects family 6. Hang fuse is `FALSE`.
`#999` live pins still skip on the closed door.

## 3. Files Changed

- `src/gllvmTMB.cpp` — working `W_*` + Huber extras
- `R/mspl.R` — probe-only env; provenance string
- `R/mspl-registry.R` — planned notes name working `W_*`
- `R/fit-multi.R` — skip BFGS rescue for family 6; count
  `mspl_dispersion_nll` in the penalty-off sum
- `tests/testthat/test-mspl-fenced-family-tapes.R`
- `tests/testthat/test-mspl-tweedie-phase4-oracles.R` (E11)
- `tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R`
- `dev/mspl-tweedie-hang-probe.R`
- `dev/mspl-tweedie-hang-stages.R`
- `docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`
- `docs/dev-log/after-task/2026-08-16-mspl-tweedie-hang-wstar.md`
- `docs/dev-log/check-log.md`

No `NEWS.md`, no register `covered`, no allow-list door.

## 3a. Decisions and Rejected Alternatives

- **Decision:** keep working `W_*` even after the hang was shown to
  be the BFGS rescue. **Rationale:** true W still fails the
  two-sided test. **Rejected:** revert C++ to true W.
- **Decision:** skip BFGS rescue for Tweedie only, not for
  Bernoulli. **Rationale:** the rescue earned its keep on spatial
  Bernoulli. **Rejected:** delete the rescue globally.
- **Decision:** do not open family 6 on the public allow-list.
  Probe env only. **Rejected:** planned door like #1014.

## 4. Checks Run

```sh
pkgload::load_all(...)
# ML 8x3: ~0.7 s
# Staged MSPL iter.max=1: fn 0.005 s; then hung in BFGS rescue
# After skip + dispersion bookkeeping:
# PROBE_OK elapsed=1.549s optimizer=nlminb
```

Targeted files after `load_all` (probe env unset unless named):

- oracles / fenced tapes / `#999` zz (CI path: door skip)

Not run: `devtools::test()`, `--as-cran`, pkgdown.

## 5. Tests of the Tests

- E11 fails if working W does not vanish at both infinities.
- Fenced-door test unsets the probe env.
- BFGS-skip test fails if family 6 re-enters the rescue.
- `#999` hang fuse is `FALSE`; CI still cannot start a public live
  fit because prepare rejects family 6.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| live C++ atom is working logistic | held |
| public allow-list excludes 6 | held; probe env is extra |
| BFGS rescue skips `family_id == 6` | held |
| `admitted` Tweedie | absent |
| NEWS covered | not touched |

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No new issue. `#999` SE pin remains planned-only behind a closed
door.

## 8. What Did Not Go Smoothly

The first sitting treated a 180 s timeout as "W_* did not unstick
the cell" and marked BLOCKED. The staged probe showed the timeout
was the Bernoulli BFGS rescue. Do not treat an OS kill after
`PROBE_START_FIT` as a W-atom result.

## 9. Team Learning

**Fisher:** two-sided vanishing correctly indicts true Tweedie W.
It does not identify a post-`nlminb` rescue hang.

**Gauss:** `dtweedie` series cost is the expensive region the
rescue walked into, not the first `fn()`.

**Curie:** instrument `MakeADFun` / `fn` / `nlminb` / `optim`
separately. One `iter.max=1` fit is enough to split the layers.

**Rose:** keep the true-W `rewards` comment after the tape change.

**Grace:** no public door. Hang fuse off. CI skips on the closed
door, not on a residual hang.

## 10. Known Limitations And Next Actions

- Public door stays closed. No admit. No public `se=TRUE`.
- `#999` live curvature pin still needs a later planned door, not
  this hang slice.
- Do not transplant the BFGS skip onto Bernoulli.
