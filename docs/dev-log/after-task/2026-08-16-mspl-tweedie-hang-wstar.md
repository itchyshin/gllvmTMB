# After Task: Tweedie MSPL hang vs working W_*

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
`φ → 0`. That matches the hang note from #1014 (ML on the same cell
is fast; MSPL was not). The live C++ tape now uses working logistic
`W_*` on `η` plus `gll_mspl_pseudohuber` on `log φ` and
`logit(p-1)`. Public prepare still rejects family 6. `#999` hang
fuse stays `TRUE` and is now a named flip.

**BLOCKED as a hang-fix.** Timeout-bounded probe of the known cell
with the new tape did not return in 180 s. Do not fake a door.

## 3. Files Changed

- `src/gllvmTMB.cpp` — working `W_*` + Huber extras; REPORT
  `mspl_V_dispersion` / `mspl_dispersion_nll`
- `R/mspl.R` — probe-only env; provenance string
- `R/mspl-registry.R` — planned notes name working `W_*`
- `tests/testthat/test-mspl-fenced-family-tapes.R`
- `tests/testthat/test-mspl-tweedie-phase4-oracles.R` (E11)
- `tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R`
- `dev/mspl-tweedie-hang-probe.R`
- `docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`
- `docs/dev-log/after-task/2026-08-16-mspl-tweedie-hang-wstar.md`
- `docs/dev-log/check-log.md`

No `NEWS.md`, no register `covered`, no allow-list door.

## 3a. Decisions and Rejected Alternatives

- **Decision:** keep working `W_*` on the fenced tape even though
  the hang remains. **Rationale:** true W fails the two-sided test
  and is the wrong existence penalty. **Rejected:** revert C++ and
  docs-only BLOCKED — would leave the hostile atom as the live
  tape. **Confidence:** high on the W classification; medium that
  a later inner-loop cap will be the hang fix.
- **Decision:** do not open family 6 on the public allow-list.
  **Rejected:** planned door like #1014. CI must not hang.
- **Decision:** named hang fuse, not `skip_if(TRUE)` literal.
  Lift later by flipping `.mspl_se_tweedie_live_hangs` after a
  returning probe.

## 4. Checks Run

```sh
pkgbuild::compile_dll(...)                 # DONE, Eigen unused-var only
R CMD INSTALL --library=$TMPLIB            # DONE
# ML same 8x3 cell, se=FALSE, n_init=1
# ML_OK elapsed=0.786s
# MSPL probe GLLVMTMB_MSPL_TWEEDIE_PROBE=1, OS timeout
# 90s timeout; 180s PROBE_START_FIT then kill. No return.
testthat::test_file("tests/testthat/test-mspl-tweedie-phase4-oracles.R")
# E11 PASS; E10 FAIL only when package not loaded (registry helper)
```

Targeted files after install (temp lib, probe env unset):

- oracles 72 PASS
- fenced tapes 20 PASS
- registry 61 PASS
- prepare-fence 2 PASS
- `#999` zz 8 PASS / 4 SKIP (Tweedie hang fuse + Beta atom)

Not run: `devtools::test()`, `--as-cran`, pkgdown.

rg:

```
rg -n "working logistic|rewards phi|GLLVMTMB_MSPL_TWEEDIE_PROBE|mspl_se_tweedie_live_hangs" \
  src/gllvmTMB.cpp R/mspl.R R/mspl-registry.R tests/testthat
```

## 5. Tests of the Tests

- E1–E10 still document true-W hostility (would fail if someone
  rewrote those oracles to working W and called it a repair).
- E11 fails if working W does not vanish at both infinities or if
  true W stops rewarding `φ → 0`.
- Fenced-door test unsets the probe env; would fail if family 6
  entered the public allow-list.
- `#999` hang fuse stays on; CI cannot start the live fit.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `W=mu^{2-p}/phi` as the *live* atom in C++ return | gone; comment only |
| `working logistic` in C++ / registry / provenance | present |
| public allow-list `c(0L, 1L, 2L, 5L, 15L)` | held; probe env is extra |
| `admitted` Tweedie | absent |
| NEWS covered | not touched |

## 7. Roadmap Tick

N/A. No ROADMAP row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. The hang is the
known `#999` / `#1014` cell, recorded in the research note.

## 8. What Did Not Go Smoothly

Working `W_*` was the predicted hang fix. The 180 s probe refuted
"W-reward is sufficient". A second mechanism (Tweedie series ×
Laplace AD, or a long `nlminb` path) is still live. Do not treat
CI silence as green.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Fisher:** the two-sided vanishing test correctly indicts true
Tweedie W. It does not by itself prove the optimiser will return.

**Gauss:** `dtweedie` + Laplace AD can dominate even after the
penalty stops rewarding `φ → 0`. ML 0.8 s vs MSPL >180 s is the
measurement.

**Curie:** OS `timeout` / process kill, not `setTimeLimit`.

**Rose:** keep the hostility comment (`rewards`) so the true-W
bug stays named after the tape change.

**Grace:** no public door; hang fuse on; CI must not compile-loop
this cell.

## 10. Known Limitations And Next Actions

- Hang fuse stays `TRUE`. Public door stays closed.
- Next hang slice: instrument one MSPL `fn()` vs ML `fn()` on this
  cell (AD cost), then consider an eval cap — not a door.
- Do not admit. Do not public `se=TRUE`. Do not lift `#999` until
  a timeout-bounded probe prints `PROBE_OK`.
