# After-task: MSPL Poisson Phase-4 prep (planned only)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-point-programme-continue`
**Worktree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`
**Arc:** B1

## Scope

Phase-4 *prep* for Poisson LA-MSPL: symbolic information/coercivity
note, pure-R oracles, and `planned` registry rows. Not admission.

## Outcome

- Research note
  `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`
  (Jeffreys-shaped \(W=\mathrm{diag}(\mu)\) atom sketch; all-zero /
  near-zero mechanisms; exposure ≠ information size; kill list for
  Bernoulli Jeffreys/`V_loading` and Gaussian Hirose).
- Oracles
  `tests/testthat/test-mspl-poisson-phase4-oracles.R` (E1–E7; no live
  Poisson MSPL fit).
- Registry: `poisson:log:ordinary:q1` and `q2` → `status="planned"`,
  `evidence="phase4_prep"`; removed the old excluded poisson row;
  NB2 remains excluded. Prepare fence unchanged
  (`family_id %in% {0,1}` only).

## Checks

```sh
OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-mspl-registry.R")          # PASS 26
testthat::test_file("tests/testthat/test-mspl-poisson-phase4-oracles.R")  # PASS 40
testthat::test_file("tests/testthat/test-mspl-gaussian-heywood-oracles.R") # PASS 75
git diff --stat -- src/ R/mspl.R   # empty
```

## Non-claims / OPEN GATE

- No C++ tape; no `estimator="mspl"` on Poisson; no NEWS covered.
- **OPEN GATE:** Shinichi + smoke before `planned` → `admitted`;
  Poisson loading-atom coercivity under Laplace still OPEN in the note.

## Commits (B1)

- `c85f3f19` docs(mspl): Poisson Phase-4 prep derivation note
- `294efe1f` feat(mspl): add planned Poisson Phase-4 registry rows
