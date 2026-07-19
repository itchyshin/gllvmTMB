# Handover — CI-11 cross-family interval certification: arms built, pilot + DRAC confirm LAUNCHED

**Meta:** 2026-07-18 · Claude→Claude/Codex · branch `claude/cross-family-ci11-20260718` (off `main`, PR #766
merged) · commit **`4bce0d65`** (full route×estimand arms). Plan: `~/.claude/plans/fluttering-squishing-stream.md`.
After-task: `docs/dev-log/after-task/2026-07-18-ci11-full-matrix-arms-and-pilot.md`.

## MISSION (unchanged, multi-session)
Earn the honest claim that **every interval route has validated coverage** on `extract_cross_correlations()`
— register **CI-11** — across the full route×estimand matrix. Two feeders, BOTH required: (1) Totoro→DRAC
coverage certification; (2) Ayumi real-data pass. **MEASURED-not-certified until a D-43 panel clears it.**

## The certifiable matrix (A0 finding — 5 cells, not 6)
| estimand \ method | wald | bootstrap | profile |
|---|---|---|---|
| multiple_r | ✅ | ✅ | ❌ **not_applicable** — un-profileable block functional (hard-fenced) |
| contrast_r | ✅ | ✅ (NEW arm) | ✅ |
Do NOT try to build profile→multiple_r; it is mathematically undefined.

## What is DONE (this session)
- **Phase A committed `4bce0d65`** — new **bootstrap→contrast_r** API arm (`bootstrap_Sigma` flattens the
  per-contrast list col → `contrast_r_<lvl>`; CI-10 attrition floor extended to contrast_r;
  `extract_cross_correlations` reads it back), harness measures all 5 cells per method, `xfc-aggregate.R` +
  `xfc_smoke` split by method. **Verified:** 5-cell test + 40 testthat pass; 3-lens Opus adversarial review
  **0 blockers**. man/ regenerated. roxygen honesty-only (no CI-11 claim); NEWS untouched.
- **Feeder-2 robustness audit + hardening committed `cb829b18`** — 8-agent adversarial audit (31 findings)
  of `extract_cross_correlations()`/`bootstrap_Sigma`/`profile_ci_correlation`; full prioritized map at
  `docs/dev-log/2026-07-18-cross-family-interval-hardening-map.md`. `dev/xfc-stress-test.R` (7 regimes × 3
  methods) confirms the code **survives all tested edge settings** (findings are latent defensive gaps, NOT
  active fires). Fixed the 2 clear ones (MASS-absent guard + contrast_r clamp — both no-ops on the cert grid,
  so the running super-sim stays valid; 40+25 testthat pass). **Remaining backlog** (family-allowlist stamp,
  Inf-strip, bootstrap-error surfacing, profile bracket, honest `nnc`, AUTO-scale truth assertion) → the
  hardening-map doc + a spawned task; the CI-11 disclosure items (single loading-ray, balanced/complete-case,
  correct-`d`, converged-only) go into the eventual claim wording.

## What is RUNNING / CARRIED-OVER (the next session finishes this)
1. **Totoro lean pilot — AGGREGATED** (19/20 shards, n_sim=200, n_boot=49, N≤150, all 5 methods; MEASURED,
   NOT certified). **Signal (mean coverage across 12 lean cells, target 0.95; conv 1.00, 0 ci-fail):**
   multiple_r bootstrap **0.883**, wald 0.971 · contrast_r bootstrap **0.893**, profile 0.940, wald 0.959.
   → **bootstrap UNDER-covers ~0.88–0.89 (too narrow at N≤150)**; wald over-covers (conservative); profile
   best-calibrated (~0.94). `AGGREGATED.rds` at `~/gtmb_work/xfam-intervals/pilot-results/`. The DRAC
   super-sim tightens these (n_sim=13000) + adds the N=500 cells the pilot omits.
   Aggregate: `ssh totoro`, then `cd ~/gtmb_work/xfam-intervals && export
   R_LIBS=/home/snakagaw/gtmb_work/xfam-lib:/home/snakagaw/R/lib && Rscript dev/xfc-aggregate.R pilot-results`.
2. **DRAC confirm — LAUNCHED (SUPER), job `49532634`** (fir, `--array=1-6500 --grid=certified --n-sim=13000
   --n-boot=499`, 962 shards running → ~3 days). FENCED super-simulation (MEASURED only; does NOT flip CI-11).
   Lib `/project/def-snakagaw/snakagaw/gtmb-xfam-lib` (fmesher relaxed). Monitor:
   `ssh fir 'squeue -u snakagaw -t running | wc -l; ls /project/def-snakagaw/snakagaw/gtmb-xfam-ci11-results/*.rds | wc -l'`.
   **Aggregate when the array finishes** (expect up to 6500 `.rds`): `ssh fir`, then `module load
   r/4.5.0 && export R_LIBS=/project/def-snakagaw/snakagaw/gtmb-xfam-lib:$HOME/R/lib && cd
   /project/def-snakagaw/snakagaw/gtmb-xfam-ci11 && Rscript dev/xfc-aggregate.R
   /project/def-snakagaw/snakagaw/gtmb-xfam-ci11-results`. Pull `AGGREGATED.rds` LOCAL (D-50). Right-size
   `--time` via `seff 49531428_<task>` after first tasks land; deepen to n-boot=499 if wanted.
3. **Certification gate (CI-11 flip) = a LATER session** — needs: DRAC confirm aggregate banked + **Rose** +
   a **D-43 panel** (default NOT-DONE, ≥2 NOT-DONE withholds) + **Ayumi clean real-data pass**. Only then
   flip CI-11 in the validation-debt register + NEWS + roxygen (the claim-change pattern, Design 39).

## Fences / discipline
- Every number: **"MEASURED, NOT certified — awaiting D-43 panel."** Conditional-on-convergence disclosed +
  worst-case sensitivity. Results LOCAL only (D-50). Totoro ≤100 cores (note: a profile-lane REML campaign
  already holds ~151 Totoro cores — keep new Totoro footprint modest).
- Ayumi monitor: **no new cross-family reports** as of 2026-07-18.
- MINOR follow-up (pre-deep-confirm): `xfc-aggregate.R` `n_nonconverged` is read off per-shard summaries; a
  shard with 0 converged reps contributes 0 → worst-case denominator slightly optimistic. Carry it at
  shard/meta level before trusting worst-case on low-convergence cells.

## Deferred menu (do NOT lose)
item-3 one-per-unit recovery certificate (Totoro `~/gtmb_work`, larger-N + D-43) · replication-aware
contrast-Ψ (engine change) · multiple-multinomial / structured cross-family (fenced) · pkgdown cross-refs.

## One-command resume (next session)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-18-claude-handover-ci11-pilot-confirm.md. Aggregate the Totoro lean pilot (pilot-results) and check the DRAC confirm array (fir job 49531428) — aggregate when done. Report per-(cell,estimand,method) coverage with the MEASURED-not-certified banner. Do NOT flip CI-11 / NEWS / roxygen — that needs the DRAC aggregate + Rose + a D-43 panel + Ayumi clean. Then the deferred menu."
```
