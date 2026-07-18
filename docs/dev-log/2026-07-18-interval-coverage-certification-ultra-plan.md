# Ultra-plan — Certify the whole interval-coverage story (gllvmTMB)

**Date:** 2026-07-18 · **Owner:** new lane (Claude, solo) · **Branch:** cut off `claude/release-0.5.0` AFTER
the 2026-07-18 CARRIED-OVER commit lands (it carries the gate-5 fix this arc reuses). Maintainer-chosen
large arc (2026-07-18): *"Certify the whole interval-coverage story."*

## 🎯 GOAL (paste-and-go for the new lane)
```
Solo platform: CLAUDE (user-driven; branch off claude/release-0.5.0 after the 2026-07-18 commit lands).
Deliverable: take gllvmTMB interval coverage from "one gaussian cell certified (bootstrap)" to "the core
interval-coverage story CERTIFIED" on the RIGHT route. The 2026-07-15 grid proved the parametric bootstrap
UNDER-COVERS location variance components (near-unbiased point est, right-skew) — so the certificate path is
PROFILE likelihood / log-SD-Wald-with-t-df (Design 73, nominal-certified in drmTMB), NOT more bootstrap.
HEADLINE (Phase A, 0.6): wire a non-bootstrap ci_method into dev/m3-grid.R (reuse .profile_ci_total_variance,
already in confint(method="profile"), shipped dd80244a) → re-measure gaussian+binomial on the profile route →
n_sim>=5000 confirm of gaussian n>=150 → REML for the small-n (n=50) gaussian cell → restore the correlation
profile on Sigma_total → D-43 panel → promote CI-08/CI-10 for the EARNED cells only. Phase B (1.0, needs
maintainer sign-off — engine changes): AGHQ integration to un-fence BINOMIAL/ordinal + psi=0-boundary
coverage (Laplace is weakest for binary; too-narrow profile is the Laplace signature); nbinom2 disp_group
(shared/grouped phi, Design 82) to un-fence nbinom2 (the phi<->sigma ridge); nbinom2 phi-bias, Sigma_unit
off-diagonal coverage, broaden the grid. DISCIPLINE: smoke-first; compute Totoro/DRAC <=100 cores, results
LOCAL never GitHub artifacts (D-50); certificate defaults NOT-DONE (D-43) — Rose + a Fisher/Efron/Gelman
panel (>=2 NOT-DONE withholds) before ANY register/widget/NEWS flip; Wald-calibration-for-VCs is a NON-GOAL
(Shinichi 2026-07-16 — profile owns VC/rho intervals, Wald stays for well-identified fixed effects); Lane C
(multinomial) off-limits. Do NOT run another bootstrap coverage grid.
```

## Context — why this arc, and the doctrine it must obey
- **The bootstrap route is closed** (2026-07-15 n_sim=2000 grid, `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md`): gaussian ~0.91, binomial n=150 ~0.836–0.853; point est near-unbiased (Σ̂/truth 1.007) → the under-coverage is the small-sample **variance-component right-skew**, so the fix is the ROUTE, not more compute.
- **The certificate path is already built + validated at the package level** (2026-07-16): the genuine PROFILE on V_t / log-SD route hits ~nominal directly (gaussian 0.948–0.950, misses two-sided). Doctrine: `[[Small-sample variance-component interval corrections — cross-repo map]]`, `LEARNINGS-archive.md:38-39`, gllvmTMB#565, D-12, Design 73/75. Fix hierarchy: **(1) profile likelihood / log-SD (the star); (2) log-SD Wald + t-quantile (Satterthwaite/KR) df; (3) REML for residual centre bias.** Bootstrap/BCa is last resort.
- **Standing policy (Shinichi 2026-07-16):** calibrating Wald intervals for bounded quantities (VCs / correlations) is a **NON-GOAL** — profile owns them (Fisher-z for rho). Keep Wald for well-identified FIXED effects + keep sdreport/SE sound. **No "make Wald cover" slice.**
- **Fences:** nbinom2 (φ↔σ² dispersion ridge, ~0.5× truth), ordinal, binomial (Laplace-narrow at the psi=0 boundary), off-diagonal, n<150 are all currently fenced. This arc EARNS them one at a time or honestly leaves them fenced — never advertises ahead of evidence (the 2026-05-15 overpromise lesson; the register is the ledger).

## Phase A — the 0.6 certificate (release-gating; no engine change)

| # | Slice | Member · model+effort | Files / target | Dep |
|---|-------|----------------------|----------------|-----|
| A0 | **GROUND** — verify the profile machinery + the exact harness gap. Does `dev/m3-grid.R` (`m3_target_method()`, `m3_run_cell()`) already admit a non-bootstrap `ci_method` for `Sigma_unit_diag`, or must it be wired? Map `.profile_ci_total_variance` / `.total_variance_spec` / `confint(method="profile")` / Design 73 log-SD route. | Curie/Fisher · **Sonnet, med** (read-only; a Workflow "understand" agent) | `R/profile-derived.R`, `R/profile-route-matrix.R`, `confint.gllvmTMB`, `dev/m3-grid.R`, `docs/design/73*` → reuse map + slice list | — |
| A1 | **WIRE the profile ci_method into the harness** — compute the profile / log-SD-Wald-t-df CI for `Sigma_unit_diag` per cell, reusing the package machinery (no new stats). TDD: a smoke asserting a profile CI + `covered` flag is produced; the 6-gate `pilot_scale_gate_eval()` (incl. the new gate 5) reads it. | Gauss/Fisher · **Sonnet, high** | `dev/m3-grid.R` (+ `dev/m3-pilot-*`), new tests | A0 |
| A2 | **RE-MEASURE gaussian + binomial on the profile route** — the SAME core cells (d{1,2} × n{50,150} × signal{0.2,0.5}); pilot n_sim=200 to confirm direction, then adjudication. Expect gaussian ≈ nominal (0.948–0.950), binomial still narrow (~0.916 → motivates Phase B AGHQ). Totoro, LOCAL. | Ada+Claude(live) · **Sonnet, med** | `dev/m3-grid.R` cells → LOCAL rds | A1 |
| A3 | **n_sim≥5000 confirm** of the gaussian n≥150 certificate (Curie's precondition for a public flip; MCSE ≤ ~0.003). | Ada+Claude(live) · **Sonnet, med** | Totoro grid, LOCAL | A2 |
| A4 | **REML for the small-n (n=50) gaussian cell** — REML barely moves Σ̂ at n=150 (payoff is at n=50); certify or honestly fence n=50. | Fisher · **Sonnet, med** | REML profile path + a small Totoro cell | A2 |
| A5 | **Restore the withdrawn correlation profile on `Sigma_total`** — profile CIs for `rho:TIER:i,j` (currently only Fisher-z is public); unify the CI story on one estimand. Open-decision 0.6-vs-1.0 — decide up front. | Noether/Fisher · **Sonnet, high** | `R/profile-*`, `confint`, tests | A1 |
| A6 | **D-43 panel + register promotion** — Rose + Fisher/Efron/Gelman (default NOT-DONE, ≥2 NOT-DONE withholds) on the EARNED cells; promote CI-08/CI-10 for gaussian (+ correlation if A5 earns it) ONLY; honest-fence the rest; flip the public wording (roxygen/NEWS/widget) only for what cleared. | Rose(closer)+panel · **Opus, high** | `docs/design/35-*`, NEWS, capability-surface, after-task | A2,A3,A4,A5 |

**Phase A parallelism:** A0→A1 sequential; then {A2, A5} parallel; A3←A2, A4←A2; A6 barrier on {A2,A3,A4,A5}.
**Phase A estimate:** the profile route is far cheaper than n_boot=100 bootstrap (no refits) → the re-measure + confirm is hours, not the ~40h the bootstrap grid took. Fits a few focused sessions + Totoro background.

## Phase B — 1.0 depth (un-fence the hard families; ENGINE CHANGES → maintainer sign-off first)

| # | Slice | Note |
|---|-------|------|
| B1 | **AGHQ integration** — replace/augment Laplace with adaptive Gauss-Hermite quadrature for BINOMIAL / ordinal / psi=0-boundary coverage. Laplace is least accurate for binary; the too-narrow profile is the Laplace signature. The single biggest un-fencing. C++/TMB change → Discussion-Checkpoint sign-off. | Gauss/Noether · Opus for the derivation gate |
| B2 | **nbinom2 `disp_group`** (Design 82, `docs/dev-log/2026-07-17-shared-dispersion-nbinom2-design.md`) — shared/grouped φ so the dispersion stops stealing between-unit variance (the φ↔σ² ridge → Σ̂ ~0.5× truth). Recovery gate first (target ≈ known-φ 0.78–0.94), then coverage. Engine + API change → sign-off; identity-map byte-equivalence guard required. | Gauss · Sonnet/Opus |
| B3 | **nbinom2 φ-bias correction · Sigma_unit off-diagonal coverage · broaden the validated grid** (toward nominal 0.95, d>2, smaller n). | Fisher/Gauss |

Phase B is gated on Phase A landing AND explicit maintainer sign-off (AGHQ + disp_group touch `src/*.cpp` / `R/fit-multi.R` — the Discussion-Checkpoint high-risk set). Do NOT start B code before A ships and the sign-off is on record.

## Plan review (before A1 runs)
Fisher (does the profile / log-SD-Wald-t-df route match the drmTMB-certified estimand + the t-df choice? is A5's correlation profile the same estimand?) + Rose (scope/claim honesty; is the fence→earn ordering right; does A6 gate promotion correctly?). Cheap; catches a wrong slice before Totoro time.

## Verify / consolidate / fences
- **Verify:** every earned cell through the D-43 panel (default NOT-DONE); A1/A5 have local TDD; A2/A3 read the FIRST cell early and abort on empty/NA (smoke-first).
- **Consolidate:** register (CI-08/CI-10) promotion for earned cells only; Design 66 + Design 73 status; refresh Mission Control; after-task + handover per session.
- **Fences (standing):** no flip without the panel + maintainer; compute Totoro/DRAC, results LOCAL never GitHub artifacts (D-50); no Wald-VC-calibration slice; Lane C off-limits; **never run another bootstrap coverage grid** (route is closed).

## Rehydrate (new lane)
Read: this plan → `docs/dev-log/handover/2026-07-18-claude-handover.md` → `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md` → Design 73 + the `[[Small-sample variance-component interval corrections — cross-repo map]]` doctrine. LAND the 2026-07-18 commit first. Spawn Rose before any coverage claim.
