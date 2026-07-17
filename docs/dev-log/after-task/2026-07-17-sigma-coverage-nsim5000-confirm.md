# After-task — Sigma_unit coverage n_sim=5000 gaussian confirm + D-43 re-audit

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` · **Register:** DEV-ONLY (no public flip)
**Disposition:** **WITHHELD.** The scoped gaussian n≥150 `profile_total` diagonal certificate is
**not** granted for 0.6. d1-n150 is certify-grade; d2-n150 is hardware-marginal under the committed
conservative MCSE. Concrete lift path recorded below.

## Scope
Confirm (or not) the gaussian `Sigma_unit_diag` interval-coverage certificate on the genuine
`profile_total` route (χ²₁ profile on total variance V_t + log-SD delta-Wald), at n_sim=5000, and
adjudicate it under the D-43 adversarial discipline. binomial + nbinom2 + ordinal stay FENCED
throughout; off-diagonal Sigma stays bootstrap.

## What ran
- **Totoro:** full n_sim=5000, n_boot=100 grid (gaussian+binomial × d∈{1,2} × n∈{50,150}), 96
  rep-shards/cell, seed_base=1 (nested with the n_sim=1000 baseline). Completed 768/768.
- **rorqual (DRAC):** the same grid as an independent 768-task job array (fresh build of gllvmTMB
  on the cluster). INCOMPLETE — 165 tasks TIMEOUT at `--time=3h` (heavy d2/binomial-n150 cells);
  gaussian d1-n150 complete (96/96), d2-n150 partial (47/96). **Same seeds as Totoro** → corroborates
  but adds no independent MC precision.
- Two adversarial D-43 workflows (`coverage-d43-panel[.v2].workflow.js`); an exclusion diagnosis and
  a clustered-MCSE analysis (`analyze_exclusion_mcse.R`, `diagnose_exclusion.R`).

## Results — gaussian `Sigma_unit_diag`, profile_total (conditional on convergence)
| cell | coverage | committed MCSE (rep-level ~0.0032) | band = cov − 2·MCSE | gate 0.94 |
|---|---|---|---|---|
| d1 n150 (Totoro) | 0.9482 | 0.0032 | 0.9418 | ✓ |
| d1 n150 (rorqual)| 0.9481 | 0.0032 | 0.9417 | ✓ |
| d2 n150 (Totoro) | 0.9473 | 0.0032 | 0.9409 | ✓ (thin, +0.0009) |
| d2 n150 (rorqual)| 0.9462 | 0.0032 | 0.9398 | ✗ |
| d1/d2 n50 | 0.9411 / 0.9416 | — | — | (below the n≥150 range) |

- n-direction n50 (0.9414) < n150 (0.9478) ✓. bootstrap under-covers (n150 ~0.924); wald_t_logsd agrees.
- **MCSE correction (honesty):** an earlier draft headlined MCSE 0.0014–0.0015 (trait-level /
  empirical DEFF≈1.1). The **committed** convention (`m3-pilot-report.R:554`, deliberate per :1362) is
  the conservative rep-level `sqrt(p(1−p)/n_sim)` ≈ **0.0032**. The adversarial audit caught this; the
  table above uses the committed number.

## Exclusion diagnosis (was the audit's central worry) — RESOLVED
The reps absent from `profile_total` are **non-converged optimizer fits**, not degenerate CIs:
d1-n150 128/5000 (2.56%; conv rate 97.4%), d2-n150 41 (0.82%; 99.2%), d1-n50 19 (0.38%). ALL have
`converged=FALSE`, `ci_available=FALSE`. The **emitted** CIs are 100% clean (0 Inf, 0 NA of 24,360 /
24,795). So the profile route is sound — it correctly declines a CI on a non-converged fit (user gets
a warning, not a wrong interval). Coverage is therefore honestly **conditional on convergence** with
a disclosed rate — standard practice, and the first audit's "all-excluded-are-misses → 0.924"
worst-case is too harsh (non-results, not silent misses).

## Adjudication (two D-43 adversarial panels, default WITHHOLD, refuters)
- **Audit 1** (pre-diagnosis): WITHHELD 0/3, on an adverse-exclusion assumption later shown false.
- **Audit 2** (post-diagnosis, reframed as convergence-conditional): **WITHHELD 0/3.** 2 lenses
  certified but were refuted 2/2; statistical-correctness withheld on the committed-MCSE finding.
  Verdict stands. (Note: one lens ran during a safety-classifier outage; its load-bearing
  `m3-pilot-report.R:554` claim was independently verified — correct.)

## Reproducibility
- Nesting bit-for-bit vs the n_sim=1000 baseline, same hardware (79,316 rows, max|Δ|=0, covered
  agreement 1.0).
- Cross-hardware (rorqual vs Totoro): seeded DGP identical (truth Δ 2.7e-15); per-rep **fits differ**
  (max|estimate Δ|=0.19, some CIs → Inf; expected FP/optimizer non-determinism); the coverage
  **conclusion reproduces** (~0.948). So the number is hardware-robust; the fits are not bit-identical.

## Verdict + path to lift
**WITHHELD.** d1-n150 is certify-grade under the conservative committed MCSE on both clusters;
**d2-n150 is too thin** (Totoro +0.0009, rorqual −0.0002). To earn the full n≥150 certificate:
1. **Tighten the MCSE with FRESH-seed reps** (e.g. n_sim→10–20k with independent seeds, NOT same-seed
   refits) so d2-n150 clears 0.94 with margin. This is the primary lift.
2. Keep coverage reported **conditional-on-convergence with the rate disclosed**; the qualifier must
   travel with the number on every surface (leakage fence).
3. (Optional) add an **n=300** cell to close the single-interior-n extrapolation — non-gating, since
   non-convergence and coverage both improve with n; a 0.6 confirmation item, not a blocker.
Do NOT restate the number as unconditional or nominal-0.95 coverage; the gate is `coverage ≥ 0.94`.

## Fences honored
No public surface flipped (widget / NEWS / confint help / roxygen unchanged). binomial/nbinom2/ordinal
FENCED. Off-diagonal stays bootstrap. Lane B (X_lv) / Lane C files untouched; no interacting
`phylo_latent(lv=~x)` built; default optimizer for non-Gaussian unchanged. DRAC results kept LOCAL
(D-50). Public flip remains the maintainer's decision — and now has a precise reason to wait.

## Artifacts
Totoro grid `~/gllvm_work/profile_rescore` (768/768). rorqual build `~/gllvm_rescore/gllvmTMB`
(reusable DRAC recipe: `StdEnv/2023 gcc/12.3 r/4.4.0 gdal/3.9.1 udunits`; exclude Mac `*.o/*.so`;
`--time` ≥6h for heavy cells). Scripts/logs: session scratchpad `drac/` + `INTERIM-progress-nsim5000.md`.

## Follow-up / next arc
This arc is CLOSED as WITHHELD. Next: the maintainer chooses (A) invest the fresh-seed MCSE-tightening
run to earn d2-n150 for 0.6, or (B) accept recovery-only framing for 0.6 and defer the certificate to
1.0 (consistent with the 0.5-is-cover-everything strategy). Separately: 0.6 methods backlog (shared-
dispersion for nbinom2 un-fencing; unconditional RE redraw; correlation profile).
