# After-task — CI-11 full route×estimand arms + Totoro pilot + DRAC confirm launch (2026-07-18)

**Status banner:** every coverage number in this arc is **"MEASURED, NOT certified — awaiting D-43 panel."**
Nothing promotes CI-11 / NEWS / roxygen. Certification is **multi-session**.

## 1. Scope
Validate the cross-family interval/SE machinery on `extract_cross_correlations()` toward register **CI-11**
("all interval routes have validated coverage"), across the **full route×estimand matrix**
{wald, bootstrap, profile} × {multiple_r, contrast_r} (Design 75 method-axis). Branch
`claude/cross-family-ci11-20260718` off `main` (PR #766 merged). Platform: Claude, driving live Totoro + DRAC.

## 2. What was done (this session)
- **A0 feasibility** — the certifiable matrix is **5 cells, not 6**: `profile→multiple_r` is mathematically
  undefined (a Σ-block functional has no single profile parameter) and stays fenced/`not_applicable`. The one
  genuine addition was **bootstrap→contrast_r**; wald was already API-wired.
- **A1/A2 build (commit `4bce0d65`)** — new **bootstrap→contrast_r** arm: `bootstrap_Sigma()` flattens the
  per-contrast list column into plain named scalars `contrast_r_<lvl>` and the CI-10 min-effective-B
  attrition floor is extended to `contrast_r`; `extract_cross_correlations()` reads them back. The coverage
  harness (`dev/cross-family-coverage.R`) refits ONCE per rep and measures every wired (estimand, method)
  cell; `dev/xfc-aggregate.R` + `xfc_smoke` split/assert per (estimand, method[, contrast]). roxygen updated
  (uncalibrated framing only); `man/` regenerated for the 2 touched functions.
- **A3 verify** — 5-cell harness test PASSED; **40 testthat tests pass**; local `load_all` smoke green.
- **A4 adversarial review** — 3 diverse-lens Opus reviewers (math / API-key-consistency / coverage-
  accounting): **0 blockers, 0 changes-needed**. Confirmed: Fisher-z correct; bootstrap→contrast_r round-trip
  safe (`.summarise_draws` names from `point_est` + positional stacking — keys cannot desync); attrition
  floor genuinely covers `contrast_r`; a failed bootstrap → NA → `ci_failed` (never silent false coverage);
  no method mislabel. Two MINOR findings applied/deferred (see §5).
- **Totoro** — lib rebuilt into `~/gtmb_work/xfam-lib`; smoke `five_cell_ok=TRUE`; **gate PROCEED** (worst
  outer convergence 1.00, threshold 0.80); **lean pilot LAUNCHED** (20 shards, `--grid=lean --n-sim=200
  --n-boot=49`, N≤150, all 5 methods) — truth-assertion PASS at scale. (Modest footprint: the profile-lane
  REML campaign already holds ~151 Totoro cores.)
- **DRAC (fir)** — package rsynced to `/project/def-snakagaw/snakagaw/gtmb-xfam-ci11`; dep-install +
  lib-build IN PROGRESS; `dev/xfc-coverage-slurm.sh` confirm array drafted (`--array=1-100 --n-sim=13000
  --n-boot=499`, both estimands).

## 3. Certifiable matrix (5 cells)
| estimand \ method | wald | bootstrap | profile |
|---|---|---|---|
| multiple_r | ✅ measured | ✅ measured | ❌ not_applicable (un-profileable block functional) |
| contrast_r | ✅ measured | ✅ measured (NEW arm) | ✅ measured |

## 4. State at session close (RUNNING / CARRIED-OVER)
- **Totoro lean pilot — AGGREGATED** (19/20 shards, `--grid=lean --n-sim=200 --n-boot=49`, N≤150; MEASURED,
  NOT certified; `AGGREGATED.rds` in `~/gtmb_work/xfam-intervals/pilot-results/`). Mean coverage across 12
  lean cells (target 0.95; conv 1.00, 0 ci-fail): **multiple_r** bootstrap **0.883** / wald 0.971;
  **contrast_r** bootstrap **0.893** / profile 0.940 / wald 0.959. **Signal: bootstrap UNDER-covers
  (~0.88–0.89, too narrow at N≤150); wald over-covers (conservative); profile best-calibrated (~0.94).**
  Per-cell 2·MCSE≈0.03 (noisy per-cell; 12-cell means resolve to ~0.006). The DRAC super-sim (n_sim=13000)
  tightens these + adds the N=500 cells the pilot omits.
- **DRAC confirm — LAUNCHED (SUPER spec, maintainer-chosen)** (fir, `def-snakagaw`): job **49532634**,
  `--array=1-6500` (2 reps/shard), `--grid=certified --n-sim=13000 --n-boot=499 --time=18:00:00`, out-dir
  `/project/def-snakagaw/snakagaw/gtmb-xfam-ci11-results`. **962 shards running concurrently** → ~3 days wall.
  (Superseded the first 5000/199 launch job 49531428, cancelled young with 0 `.rds` lost.) Lib at
  `/project/def-snakagaw/snakagaw/gtmb-xfam-lib` (built with `fmesher` relaxed — spatial-only, unused by
  harness). SLURM+lib smoke-verified (1-shard job 49530573 COMPLETED, non-empty .rds, 287MB RSS). This is a
  FENCED super-simulation: pure MEASURED evidence, does NOT flip CI-11. Aggregate LATER: `module load r/4.5.0 && export
  R_LIBS=/project/def-snakagaw/snakagaw/gtmb-xfam-lib:$HOME/R/lib && cd
  /project/def-snakagaw/snakagaw/gtmb-xfam-ci11 && Rscript dev/xfc-aggregate.R
  /project/def-snakagaw/snakagaw/gtmb-xfam-ci11-results`. Monitor: `squeue -u snakagaw`; right-size --time
  via `seff <jobid>_<task>` after the first tasks land; escalate n-boot→499 for a deeper confirm if wanted.
- **CI-11 flip / NEWS / roxygen** — BLOCKED until: DRAC confirm aggregate banked + Rose + a D-43 panel
  (default NOT-DONE, ≥2 NOT-DONE withholds) + Ayumi clean real-data pass.
- **Ayumi monitor** — no new cross-family / `extract_cross_correlations` bug reports since 2026-07-18
  (checked itchyshin/gllvmTMB + Ayumi-495/{urbanisation_map,avian_trait_scales}).

## 5. Follow-ups
- MINOR (applied): `needed_methods` now gated by requested estimands (no wasted refit on estimand-scoped runs).
- MINOR (deferred, pre-confirm hardening): `xfc-aggregate.R` sums `n_nonconverged` off per-shard summaries;
  a shard with zero converged reps contributes 0 → worst-case denominator slightly optimistic. Carry
  `n_nonconverged` at shard/meta level before the DRAC confirm aggregate if any cell shows low convergence.
- DRAC pre-launch: verify `module load r/4.5.0`, pre-create the SLURM `logs/` dir (SLURM won't), 1-shard smoke.

## 6. Checks
- 40 testthat pass; 5-cell harness test pass; 3-lens adversarial 0-blockers; Totoro gate PROCEED (conv 1.00);
  Totoro smoke five_cell_ok=TRUE + truth-assertion PASS at pilot scale.

## 6b. Plan-vs-actual reconcile (Melissa; material deviations, all ADAPTIVE/justified)
- **Pilot scope:** plan = "full pilot on Totoro"; actual = **lean pilot** (N≤150, 20 cores) — the profile-lane
  REML campaign (~151 cores) congested Totoro over the ≤100 cap, so the full-cell certification was routed to
  DRAC instead. (justified, recorded)
- **DRAC confirm depth:** plan = n-sim=5000/n-boot=199; actual = **13000/499 "super"** — maintainer-chosen.
- **Scope expansion (user ultracode):** added the wald arm to the matrix, the Feeder-2 robustness audit +
  hardening, and the AUTO-scale truth verification — beyond the plan's Phase A/B/C. (user-driven)
- **Phase-A workflow stalled** on a sub-agent permission denial → re-run as a verify-only workflow. (lesson §7)
- **Safety gates ALL held:** MEASURED banner on every number; CI-11/NEWS/roxygen fenced; D-43 pending; results
  LOCAL (D-50). No unjustified drift.

## 7. Lesson
The first Phase-A workflow **stalled 50 min** because a build sub-agent's R self-check hit a permission
denial and then waited indefinitely. Fix pattern: keep the correctness-critical BUILD single-threaded
(orchestrator or a tightly-scoped agent) and reserve the workflow fan-out for the **adversarial verify**
(read-only, cannot stall on a compile/permission gate). Re-run as a lean verify-only workflow succeeded.
