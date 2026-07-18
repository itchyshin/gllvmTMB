# Handover — Claude → Claude/Codex: capstone coverage is FURTHER ALONG than the chain said; next = PROFILE route

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` (stacked on #750) · **From/To:** Claude → next session

## 🎯 One-command resume
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-claude-handover-capstone-reconciliation.md.
The capstone coverage campaign ALREADY RAN through the n_sim=2000 grid (2026-07-15) and concluded the
parametric BOOTSTRAP is the WRONG route for Sigma_unit_diag; the certificate path is PROFILE / log-SD-Wald
(Design 73). Do NOT run another bootstrap grid. NEXT = re-measure the SAME core cells (gaussian+binomial)
on the profile route, and propagate the 07-15 completion into Design 66 + the register. nbinom2 stays
FENCED (phi<->sigma identifiability; disp_group Design 82 deferred to 1.0). D-43 default NOT-DONE."
```

## 🔴 Read-first — the handover desync this corrects
The #750 handover (`2026-07-17-claude-handover-750-spatial-done.md`) named the NEXT arc as the "capstone
metric-repair" with the stale 2026-06-23 scaling-gate framing. **That was doubly stale:** (1) the decision
surface was already built (`pilot_scale_gate_eval()` in `dev/m3-pilot-report.R`, wired into
`dev/totoro-coverage-grid.sh`); (2) **the pilot AND the n_sim=2000 grid had already RUN (2026-07-13 →
07-15)** and reached a definitive conclusion. A session (this one) rehydrating off that pointer re-ran the
48-cell pilot and re-derived already-known results. **Lesson: ground off the A2 EXECUTION note
(`docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md`), not the A0 punch-list (the plan).**

## The TRUE state of the capstone coverage campaign (committed repo notes)
Source: `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md` (authoritative; committed).
- **Pilot (07-13):** n_sim=200, n_boot=100, core-4 → **HOLD**. Coverage worsens with n.
- **gaussian DGP bug FOUND + FIXED** (`m3_simulate_response`/`m3_sample_truth`): 0.54 (broken) → ~0.91 (fixed, improves with n at scale).
- **nbinom2 DIAGNOSED + FENCED** — the **NB-dispersion(φ) ↔ latent/unique-variance ridge**: free per-trait φ is near-redundant with ψ as an overdispersion source, collapses toward the Poisson limit (φ̂→∞), starves ψ, drags `Sigma_unit_diag` to **~0.5× truth**, **flat with n** (n-ladder n=150→800). Point estimate is family-specifically biased here. Fixing φ at truth lifts recovery to **0.78–0.94** (M3.3a known-φ diagnostic, PR #214). **NOT an AGHQ/Laplace-quality issue** — Laplace is adequate for NB2; the lever is φ estimation. Fix = shared/grouped dispersion (`disp_group`, `docs/dev-log/2026-07-17-shared-dispersion-nbinom2-design.md` = Design 82), **DEFERRED to 1.0** (maintainer 2026-07-17).
- **n_sim=2000 GRID RAN (07-15):** gaussian+binomial (core-2, nbinom2 fenced), n_boot=100, ~40h, MCSE~0.006 (adjudication-grade), `~/gllvm_work/grid2000/` (Totoro; local, D-50). → **HOLD**: nominal-0.95 certificate NOT earned. gaussian ~0.91 (fixed, improving with n, mildly under nominal); binomial n=150 high-signal 0.836–0.853 genuinely under-cover.
- **DEFINITIVE interpretation (07-15):** point estimate near-unbiased (Σ̂/truth **1.007 ML**, 1.014 REML) ⇒ this is the **small-sample variance-component right-skew**, and **the parametric bootstrap is the WRONG route**. `Sigma_unit_diag = ΛΛ' + Ψ` is a pure LOCATION-axis variance component; the fix hierarchy is decided + implemented: **(1) profile likelihood / log-SD route (Design 73, nominal-certified in drmTMB); (2) log-SD Wald + t-quantile (Satterthwaite/KR) df; (3) REML for residual centre bias.** Bootstrap/BCa is last resort.

## NEXT ARC (the real one) — profile-route coverage re-measurement
Re-measure interval coverage for the SAME core cells (**gaussian + binomial_probit**; nbinom2 fenced,
ordinal excluded) on the **profile / log-SD-Wald-with-t-df** route instead of the parametric bootstrap.
- **Reuse:** `.profile_ci_total_variance` / `.total_variance_spec` (already wired into
  `confint(parm="Sigma_unit", method="profile")` — the shipped Sigma_unit certificate, `dd80244a`),
  Design 73 log-SD route. **[VERIFY the exact reuse + harness gap]:** does `dev/m3-grid.R` support a
  non-bootstrap `ci_method` for `Sigma_unit_diag` (`m3_target_method()`), or must a profile ci_method be
  wired into the harness? That is the likely code slice. (A grounding pass was blocked by a transient
  tool-classifier outage this session; confirm before scoping compute.)
- **Then** re-run the same-cell coverage on Totoro (profile route is cheaper than n_boot=100 bootstrap),
  score with the (now 6-gate) `pilot_scale_gate_eval()`, and take any coverage CLAIM through the D-43
  adversarial panel (Rose + Fisher/Efron/Gelman, default NOT-DONE) before any register/widget/NEWS flip.

## This session's durable additions (uncommitted — verify parse, then commit)
On `claude/release-0.5.0`, working-tree only:
- **R2** — `pilot_scale_gate_eval()` was missing Design 66 §6 **gate 5 (no one-sided miss ≥80%)**. Added:
  `pilot_collect_cell()` now emits `miss_below/above/total` + `one_sided_miss_share` (reusing the audit
  reducer's `miss_side`); the gate checks it with a documented ≥5-miss floor. Tests `dev/test-pilot-scale-gate.R`
  r7/r8 + reducer integration + a real Totoro gate-fire — **all green** (14 checks). Matters for the
  profile-route re-measurement too. File: `dev/m3-pilot-report.R`.
- **R3** — `dev/totoro-coverage-grid.sh`: socket path `cm/`→`cm-` (verified live), RLIB DRAC→Totoro path,
  `.claude` rsync exclude, surfaced the miss columns in the grid print.
- **R1** — `pilot_status()` now SURFACES the calibrated `pilot_scale_gate()` verdict (calls the reducer,
  no forked path) — closes the literal "wire the driver through the reducer" item. File: `dev/m3-pilot-launch.R`.
  **[Parse-verify pending]** — `Rscript dev/test-pilot-scale-gate.R` + source all three harness files;
  blocked this session by a transient Bash-classifier outage. R1 is display-only + off the gate's critical path.
- After-task: `docs/dev-log/after-task/2026-07-17-capstone-metric-repair.md` (full record incl. §5b reconciliation).
- Scratch runner `dev/run-48cell-pilot.sh` (reproducible sharded pilot driver).

## Propagation still TODO (do with the maintainer or in the next session)
- **Design 66** (`docs/design/66-capstone-power-study.md`): add a status note that the pilot + n_sim=2000
  grid RAN (07-15), verdict HOLD, bootstrap = wrong route, certificate path = profile (Design 73), nbinom2
  fenced — so the "2026-06-23 scaling gate blocks the grid" framing no longer misleads.
- **Register** (`docs/design/35-validation-debt-register.md`, rows CI-08/CI-10): note the bootstrap-route
  HOLD + that the profile route is the certificate path. **Do NOT promote** (needs the D-43 panel).

## Fences (standing)
nbinom2 FENCED (point-only; disp_group deferred to 1.0). No coverage certificate claimed (bootstrap HOLD).
No public/register flip without the D-43 panel + maintainer. Compute Totoro/DRAC, results LOCAL, never
GitHub artifacts (D-50). Lane C (multinomial) off-limits.
