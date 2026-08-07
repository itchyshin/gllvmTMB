# Arc 0 inventory — VA Arc-1 merge/fence (C)

**Date:** 2026-08-07  
**Lane:** `cursor/va-arc1-merge-fence-20260807`  
**Worktree:** `/private/tmp/gllvmtmb-va-arc1-merge-fence`  
**Base:** `origin/main` @ `5bf18ab3`  
**Donor tip (read-only archive):** `/private/tmp/gllvmtmb-va-gh-all-families` · `codex/va-gh-all-families` @ `b16f0599` (evidence tip; B done @ `98839853`)

## Pins

| Pin | SHA | Role |
| --- | --- | --- |
| Arc-1 public closeout | `537e6da4` | Primary path source for code / tests / man / design / pkgdown / article |
| Pre-PoisG (stationary + Gate E TMB) | `4435cd1e` (= `b53be434^`) | `R/va-r3-proto.R`, `tests/testthat/test-va-r3-prototype.R`, **`inst/tmb/gllvmTMB_va_r3.cpp`** — includes `b972b897` + Arc-1 parameter rename (`log_phi_*`), excludes PoisG |
| NEWS honesty | `98839853` | Thin Arc-2 mixed-results honesty paragraph (no soft-PASS) |
| PoisG feat | `b53be434` | **OUT of first PR** |

**Correction (Arc 0):** the plan's "no `src/` delta" is true for `src/gllvmTMB.cpp`, but Arc-1 **does** change `inst/tmb/gllvmTMB_va_r3.cpp` (+495/−72 vs `origin/main`). Omitting it leaves main's legacy `PARAMETER_VECTOR(log_phi)` and breaks every compiled VA cell.

## CODE — transplant into first PR

Path-scoped from pins above. No `src/` delta vs `origin/main` on the Arc-1 closeout surface.

### TMB (1 — required)

- `inst/tmb/gllvmTMB_va_r3.cpp` ← **`4435cd1e`** (per-family `log_phi_*` / Gate E H7 surface; no PoisG cloglog closed-form)

### R (21)

- `R/approximation-engine.R`
- `R/bootstrap-lv-effects.R`
- `R/bootstrap-sigma.R`
- `R/extract-cutpoints.R`
- `R/extractors.R`
- `R/families.R`
- `R/fit-multi.R`
- `R/gllvmTMB.R` ← closeout `537e6da4` (pre-PoisG identical)
- `R/integration-fence.R`
- `R/methods-gllvmTMB.R`
- `R/output-methods.R`
- `R/profile-ci.R`
- `R/profile-derived.R`
- `R/re-uncertainty.R`
- `R/standard-errors.R`
- `R/va-intervals.R`
- `R/va-methods.R`
- `R/va-r3-proto.R` ← **`4435cd1e`** (stationary fix; no PoisG)
- `R/va-routing.R`
- `R/vcov-coef.R`
- `R/z-confint-gllvmTMB.R`

### Tests (21 + helper)

- `tests/testthat/helper-va-all-family-oracles.R`
- `tests/testthat/test-approximation-engine.R`
- `tests/testthat/test-integration-fence.R`
- `tests/testthat/test-predict-se.R`
- `tests/testthat/test-profile-ci-total-variance-export.R`
- `tests/testthat/test-re-uncertainty.R`
- `tests/testthat/test-standard-errors.R`
- `tests/testthat/test-student-recovery.R`
- `tests/testthat/test-va-ac2-expectation.R`
- `tests/testthat/test-va-all-family-compiled.R`
- `tests/testthat/test-va-all-family-light-fits.R`
- `tests/testthat/test-va-all-family-oracles.R`
- `tests/testthat/test-va-control-exposure.R` ← closeout (no PoisG)
- `tests/testthat/test-va-intervals.R`
- `tests/testthat/test-va-mixed-family.R`
- `tests/testthat/test-va-ordination.R`
- `tests/testthat/test-va-probit-adsafety.R`
- `tests/testthat/test-va-r3-ai-collapse.R`
- `tests/testthat/test-va-r3-prototype.R` ← **`4435cd1e`**
- `tests/testthat/test-va-r3-warm-psi.R`
- `tests/testthat/test-va-routing-oracle.R`

### Man / package surface

- `NAMESPACE`
- `NEWS.md` ← **`98839853`** (Arc-2 honesty)
- `_pkgdown.yml`
- `man/extract_cutpoints.Rd`
- `man/extract_ordination.Rd`
- `man/getLV.Rd`
- `man/getREsd.Rd`
- `man/gllvmTMB.Rd`
- `man/gllvmTMB_multi-vcov.Rd`
- `man/gllvmTMB_va-methods.Rd`
- `man/gllvmTMBcontrol.Rd`
- `man/predict.gllvmTMB_multi.Rd`
- `man/standard_errors.Rd`
- `docs/design/108-va-parity-programme.md`
- `docs/design/110-va-gh-h7-all-scalar-families.md`
- `docs/design/35-validation-debt-register.md`
- `vignettes/articles/validation-oracles.Rmd`

### Lane coordination (this C lane only; not product claim)

- `docs/dev-log/handover/2026-08-07-cursor-handover-va-arc1-merge-fence.md`
- `docs/dev-log/plan-actual/2026-08-07-va-arc1-merge-fence-arc.md`
- `docs/dev-log/plan-actual/2026-08-07-va-arc1-merge-fence-inventory.md` (this file)
- `docs/dev-log/audits/2026-08-07-va-series-synthesis.md` (working-position lock cite)
- `docs/dev-log/after-task/2026-08-06-va-gh-h7-arc1-public-closeout.md`
- lane-split row refresh in `docs/dev-log/handover/2026-07-25-active-lane-split.md`

## DOCS — leave on fat tip / optional later PR

- Bulk `docs/dev-log/audits/2026-08-07-va-*` n-ladders and Totoro ledgers
- `lanes/*/` campaign kits and `lanes/*/results/`
- Series LOOP under `lanes/va-series-synthesis/`
- Arc-2 Totoro adjudication dumps
- Older same-day diagnosis handover `2026-08-07-cursor-handover.md` (superseded for next action)

## LEAVE-BEHIND — never stage into C PR

| Item | Why |
| --- | --- |
| `tests/testthat/test-va-poisg-expectation.R` | PoisG opt-in; out of first PR |
| `tests/testthat/test-va-gh-h7-campaign.R` | Campaign harness; not on closeout |
| PoisG delta on `inst/tmb/gllvmTMB_va_r3.cpp` / cloglog closed-form | PoisG feat `b53be434` — use pre-PoisG cpp instead |
| Dirty probes `dev/va-gh-h7-campaign/probe-*.R` | Research; CARRIED-OVER |
| `lanes/*/results/`, `/private/tmp/va-*` | D-50 local |
| Fat tip as merge vehicle | ~173 commits; review-hostile |

## Locked product claims (must hold after transplant)

1. `calibrated = FALSE` retained
2. Laplace remains package default
3. VA opt-in; 18 scalar cells; H = 7; `auto → gh`
4. JJ explicit logit-only; multinomial out
5. NEWS states Arc-2 mixed results without soft-PASS / without promoting VA default
6. PoisG cloglog closed-form **not** in this PR

## Focused verify set (after transplant)

```r
testthat::test_file("tests/testthat/test-integration-fence.R")
testthat::test_file("tests/testthat/test-va-routing-oracle.R")
testthat::test_file("tests/testthat/test-va-control-exposure.R")
testthat::test_file("tests/testthat/test-va-all-family-oracles.R")
testthat::test_file("tests/testthat/test-va-all-family-compiled.R")
testthat::test_file("tests/testthat/test-va-all-family-light-fits.R")
```

## Status

| Step | Classification |
| --- | --- |
| Scaffold worktree | **DONE** |
| Arc 0 inventory | **DONE** (this file) |
| Path transplant | **DONE** (incl. `inst/tmb/gllvmTMB_va_r3.cpp` @ `4435cd1e`) |
| Focused tests | **DONE** — fence / routing / control / oracles / compiled / light-fits all green (18/18 healthy) |
| Rose claim-fence | **DONE** — `calibrated=FALSE`, Laplace default, Arc-2 mixed honesty, no soft-PASS, PoisG out, no register codes on NEWS/man |
| Open code PR (no merge) | **OWED** |
| Docs-evidence PR / merge G0 / calibrated=TRUE / PoisG / #947/#948 | **DEFER** |
