# After-Task Report: COE-04 Moderate-Edge Boundary Cell

Date: 2026-06-18 15:43 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## 1. Task

Add a tested claim-boundary cell for the harder moderate-overlap edge in the
Paper 2 two-kernel coevolution path.

This slice does not promote Paper 2, close `COE-04`, estimate `rho`, provide
intervals, prove non-Gaussian recovery, or make release/bridge/scientific
coverage claims.

## 2. Files Touched

- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-coe04-moderate-edge-boundary.md`

## 3. What Changed

The heavy moderate-overlap test now includes a third, harder cell:

- `non_association_blend = 0.40`
- `seed = 2403`
- overlap class `moderate`
- full two-kernel model convergence
- phy-only and non-only comparator convergence
- full model beating the best one-component comparator by more than 50
  log-likelihood units
- `Gamma_non` recovery above 0.95
- `Gamma_phy` recovery below 0.95
- `Gamma_phy` versus `Gamma_non` cross-match above 0.25

That combination is deliberate: it proves the model still detects signal, but
the component-specific separation evidence is too weak to promote at that
harder moderate edge.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file = "tests/testthat/test-coevolution-two-kernel.R")); cat("parse ok\n")'`
  -> pass.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 9 | PASS 67`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 233`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 12 | PASS 171`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 362`.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> pass.

## 5. Evidence Interpretation

IN: `COE-04` now has two promoted moderate-overlap recovery cells
(`non_association_blend = 0.30` and `0.35`) and one tested harder
moderate-edge boundary cell (`0.40`) that converges and detects signal but
fails strict component-separation criteria.

PARTIAL: this is not broad moderate-overlap calibration. It narrows the claim
boundary and prevents the 0.40 edge from being silently treated as success.

NOT CLAIMED: high-overlap truth recovery, null Type-I calibration, interval
coverage, in-engine `rho`, non-Gaussian recovery, mixed-family Paper 2
coverage, explicit multi-kernel Psi, bridge completion, release readiness, and
scientific coverage.

## 6. Review Roles

Fisher: the new cell is inferential boundary evidence. It says "signal is
visible, component separation is not strong enough."

Curie: the boundary is test-backed with a deterministic seed and comparator
fits; it does not widen the recovery claim.

Rose: validation row `COE-04`, Design 65, NEWS, dashboard, and check-log all
carry the same boundary language.

Boole: no formula grammar changed.

Gauss/Noether: no TMB likelihood or parameterisation changed.

Grace: focused and aggregate non-heavy/heavy kernel-coevolution tests passed;
JSON validated.

## 7. Next Safest Coevolution Actions

1. Decide whether the next `COE-04` slice should be a broader moderate-overlap
   grid, a broader high-overlap failure/recovery grid, or a non-Gaussian
   recovery gate.
2. Keep `profile_cross_rho()` fixed-grid only until an explicit in-engine
   `rho` design and validation row exist.
3. Keep Paper 2 public promotion blocked until the remaining recovery,
   interval, null, and family gates move with evidence.
