# After-task: extend phylo_dep(1 + x | sp) slope to non-Gaussian families (PHY-18)

- Date: 2026-06-02
- Branch: `claude/dep-slope-nongaussian-families`
- Builds on: #422 (GAP-B1 poisson VALIDATION cell + guard relaxation to `c(0L, 2L)`).

## Scope

Extend the GAP-B1 `phylo_dep(1 + x | species)` non-Gaussian slope pattern
from poisson to the remaining five families — nbinom2 (family_id 5),
Gamma (4), Beta (7), ordinal_probit (14), binomial (1, multi-trial) — in
one PR, behind real recovery cells (the #388 discipline: a family joins
the `R/fit-multi.R` guard allowlist only after its VALIDATION cell passes
non-skipped in CI).

## Changes

- `tests/testthat/test-matrix-slope-phylo-dep.R`: five new `*_VALIDATION`
  cells mirroring the poisson cell exactly — same interleaved `C = 4`
  `Sigma_b_true` (`.dep_pois_Ltrue`), `n_sp = 300`, `n_rep = 10`, real
  public API, slope variances read from `fit$report$Sigma_b_dep` diag
  positions 2 and 4, family-appropriate DGP, inherited band. Binomial uses
  multi-trial `cbind(succ, fail)` with `size = 12`. Shared helpers
  `.make_dep_eta_fixture()` and `.run_dep_validation_family()` factor out
  the tree/`Sigma_b`/fit/recovery machinery.
- `R/fit-multi.R` (~849): `phylo_dep` slope family guard allowlist relaxed
  from `c(0L, 2L)` toward `c(0L, 1L, 2L, 4L, 5L, 7L, 14L)`; comment and
  abort message updated. Final allowlist trims any family whose cell did
  not pass in CI.
- `.github/workflows/dep-slope-poisson-recovery.yaml`: added a `paths:`
  filter (only runs on PRs touching `R/fit-multi.R`, `src/gllvmTMB.cpp`,
  the dep test file, or the workflow itself); kept `workflow_dispatch`;
  added an explicit "Skipped cells" listing to the run summary.
- `docs/design/35-validation-debt-register.md`: PHY-18 row updated.

## Per-family CI outcome

| family | family_id | passed? | n_sp used | slope-var ratios (cols 2,4) | in final allowlist? |
|--------|-----------|---------|-----------|------------------------------|---------------------|
| poisson (inherited #422) | 2 | yes | 150 | (see #422) | yes |
| nbinom2 | 5 | _pending CI_ | 300 | _pending_ | _pending_ |
| Gamma | 4 | _pending CI_ | 300 | _pending_ | _pending_ |
| Beta | 7 | _pending CI_ | 300 | _pending_ | _pending_ |
| ordinal_probit | 14 | _pending CI_ | 300 | _pending_ | _pending_ |
| binomial (multi-trial) | 1 | _pending CI_ | 300 (size 12) | _pending_ | _pending_ |

(Updated with the `dep-slope-poisson-recovery` log results before merge.)

## Checks

- No R available locally; validation is via the `dep-slope-poisson-recovery`
  GitHub Actions workflow (`GLLVMTMB_HEAVY_TESTS=1`, real public API). A
  family is VALIDATED only if its cell does NOT appear in the "Skipped
  cells" list AND the suite reports 0 failed / 0 errored.

## Follow-up

- Any family still skipping at the largest tried `n_sp` (escalation
  300 -> 600 -> 1200; binomial size 12 -> 20) is removed from the allowlist
  and left reserved fail-loud, noted in the table above.
- The seven legacy `sd_b`-channel honest-skip cells stay partial (they read
  the 2-vector channel incompatible with the dep engine).

https://claude.ai/code/session_01E83SkoXEaWMo1WRxj2Hud4
