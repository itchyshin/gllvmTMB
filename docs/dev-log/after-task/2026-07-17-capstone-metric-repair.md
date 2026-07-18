# After-task — Capstone metric-repair (Design 66 / #349 / #346)

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` (stacked on #750; no merge to `main`) ·
**Platform:** Claude (solo, user-driven) · **Status:** code repair DONE + PROVEN; 48-cell pilot in flight.

## 1. Scope

Repair the coverage/power capstone decision surface so the Design-66 pilot can gate the `n_sim=2000`
confirmatory grid (which gates CRAN + the methods paper). Entry framing (from the #750 handover): the
2026-06-23 scaling gate's four "metric repairs" — CI-08/CI-10 rows, binary-harness mislabelling,
ordinal-probit rows, MCSE/fit-health denominators.

## 2. The reframing (the load-bearing finding)

An ultra-plan **plan-review gate** (Rose + Fisher, independent Opus reviewers) plus direct code reading
**inverted the entry premise.** The #750 handover restated the *stale 2026-06-23* framing; the
**2026-07-13 Design-66 amendment + A0 punch-list are code-verified** and the repair was ~90 % already
landed:

- `pilot_scale_gate_eval()` (`dev/m3-pilot-report.R:224`) already exists, is tested
  (`dev/test-pilot-scale-gate.R`, 6 cases), and is **already wired into the real campaign driver**
  (`dev/totoro-coverage-grid.sh:85`). It already carries MCSE, fit-health denominators, the true-probit
  logit-HALT (Repair #1), core-family exclusion via `PILOT_CORE_CONFIRMATORY` (Repair #2), and the
  signal-split (Repair #3).
- The bare `pilot_status()` (`dev/m3-pilot-launch.R:1422`) the plan targeted is a **progress reporter,
  not the gate** — re-wiring it would fork a second, divergent CRAN-gating verdict (a correctness hazard).
- **S2** (edit `PILOT_CORE4`) was a hazard, not work: exclusion is already correct at the gate; editing
  the grid would break the locked 48-cell pilot (Design 66 §12 L-b). Verified no-op.
- **S3** (true-probit ingest assertion) was redundant with the gate's logit-HALT. Verified no-op.

**The one genuine gap** (Fisher, confirmed in code): Design 66 §6's **sixth quality gate — "no one-sided
miss (≥80 % of misses on one side)" — was absent** from `pilot_scale_gate_eval()`. Without it, S7 could
not honestly claim all six gates. The miss-side *computation* already existed in the audit reducer
(`m3-pilot-report.R:942-956`, ≥0.80 flag at `:1120`); it was simply not connected to the gate.

## 3. What changed

- **R2 (headline)** — connected the one-sided-miss gate. `pilot_collect_cell()` now emits
  `miss_below/miss_above/miss_total/one_sided_miss_share` (reusing the audit reducer's `miss_side`
  semantics on the usable primary rows); `pilot_scale_gate_eval()` now checks gate #5 with a documented
  **≥5-miss floor** (a "pattern" needs enough misses; below that a lopsided share is Monte-Carlo noise)
  and folds it into the verdict, a distinct `gate_miss_ok` per-cell column, and a specific reason. Raw
  `one_sided_miss_share`/`miss_total` are surfaced per cell so a reviewer can adjudicate a borderline
  pattern the gate lets through. File: `dev/m3-pilot-report.R`.
- **R3** — fixed two compute-lane bugs in `dev/totoro-coverage-grid.sh`: the ControlMaster socket path
  (`~/.ssh/cm/…` subdir → the correct `cm-` **prefix**, resolved robustly via glob; verified live), and
  an RLIB pointing at a non-existent DRAC `/project/def-snakagaw/…` path → the Totoro home library
  `/home/snakagaw/gllvm_work/Rlib`. Also excluded `.claude/` (≈10 worktrees) from the deploy rsync, and
  surfaced `one_sided_miss_share`/`gate_miss_ok` in the operator's grid-verdict print.
- Tests: `dev/test-pilot-scale-gate.R` extended with r7 (one-sided → HOLD) and r8 (below-floor → PASS);
  `mkcell` gained miss columns (default NA, so cases 1–6 unchanged).

## 4. Verification (evidence)

- **Gate logic:** `Rscript dev/test-pilot-scale-gate.R` → **ALL PASS** (14 checks; the 6 originals + the
  regression + the 2 new gate-5 cases).
- **Reducer emission:** integration check — `pilot_collect_cell()` on a synthetic grid with real
  `miss_side` values emits `one_sided_miss_share=1.0`, `miss_total=2` (2 misses both below). Green.
- **End-to-end on Totoro (real bootstrap):** a `n_sim=5, n_boot=10` real-CI smoke over 6 cells →
  `pilot_collect` populated `coverage_primary`/`coverage_mcse`/`miss_total`/`one_sided_miss_share`, and
  the repaired gate returned **HOLD**, reason *"2 CORE cell(s) show a one-sided miss pattern (≥80 % of
  ≥5 misses on one side; Design 66 §6 gate 5)"* — the previously-missing gate firing on real data.
  (The HOLD is a smoke artifact at n_sim=5, where coverage is pure noise; the point was to prove the
  chain + gate fire.)
- **Plumbing smoke:** `--mode=audit-mini-run` (4 cells) `n_errored=0`; parallel chunk/shard path
  micro-smoked (self-builds its manifest).

## 5. Pilot result — VERDICT: HOLD (48/48 cells, `n_errored=0`, wall ~63 min)

48-cell pilot (`n_sim=200, n_boot=25`, 48 shards, ≤48 cores) completed 2026-07-18T02:05Z. The repaired
gate returned **HOLD** with all three gate types firing:
- 2 CORE cells fail a health gate (nbinom2 `d2 n50`, fit-failure 0.195/0.205 > 0.20);
- **17 CORE cells show a one-sided miss pattern** (the NEW gate 5 — working on the real grid);
- 20 CORE cells below the provisional coverage floor.

**HOLD is correct and expected — the pilot is a smoke/sizing instrument (Design 66 §L-a), not the
adjudication.** But it did its Design-66 job of *surfacing gross miscalibration before cluster time*, and
the coverage pattern is more than smoke noise (mean coverage over 24 core cells, by family × n):

| family | n=50 | n=150 |
|---|---|---|
| binomial_probit | 0.922 | 0.823 |
| gaussian | 0.863 | 0.874 |
| nbinom2 | 0.841 | **0.541** |

Two red flags that are NOT the small-n under-coverage story:
1. **gaussian is flat ~0.87** across n — the baseline family should be well-calibrated; it isn't.
2. **coverage WORSENS with n** for nbinom2 (0.84→0.54) and binomial (0.92→0.82) — a correct interval
   improves or holds with n. Coverage collapsing as CIs shrink is the signature of estimator bias or a
   truth/estimand mismatch, not a finite-sample artifact.

**Confounds to rule out before any alarm (do NOT overclaim a method failure):**
- **`n_boot=25`** (the M3 pilot default) is far below the capstone's `n_boot=100` target — too few
  bootstrap refits gives systematically NARROW percentile CIs → uniform under-coverage. This likely
  explains much of the *level*, though not the *worsening-with-n pattern*.
- **`n_sim=200`** is smoke-grade (MCSE ~0.025) — but 0.54 is ~13 MCSE below 0.94, so the nbinom2
  under-coverage is real signal, not noise.
- nbinom2 also has elevated fit-failure (0.10–0.21), entangling its coverage with convergence health.

**This is a genuine finding, not a pass.** Next step is NOT the `n_sim=2000` grid — it is a diagnosis of
the under-coverage (n_boot sensitivity sweep + the worsening-with-n pattern + nbinom2 fit health) under
the D-43 adversarial panel (Rose + Fisher/Efron/Gelman, default NOT-DONE). Artefacts local:
`dev/pilot-gate-verdict.rds`, `dev/m3-pilot-results/` on Totoro (D-50).

## 5b. CRITICAL RECONCILIATION — the campaign already ran (handover desync)

The brain (per Shinichi: *"it's all there"*) + `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md`
reveal that **the entire capstone coverage campaign already ran on 2026-07-13 → 2026-07-15**, more
thoroughly than this session's pilot. The #750 handover I rehydrated from pointed at "capstone
metric-repair" as if unstarted — a stale/desynced pointer. The actual prior state:

- **A2 pilot (2026-07-13):** n_sim=200, **n_boot=100** (vs my n_boot=25), core-4, → HOLD. Same findings.
- **gaussian DGP bug FOUND + FIXED** (`m3_simulate_response`/`m3_sample_truth`): was 0.54 (broken) → ~0.91 (fixed, improving with n).
- **nbinom2 DIAGNOSED + FENCED:** the NB-dispersion(φ) ↔ latent/unique-variance ridge. Free per-trait φ is near-redundant with ψ as an overdispersion source, collapses toward the Poisson limit (φ̂→∞), starves ψ, drags `Sigma_unit_diag` to **~0.5× truth**. n-ladder FLAT ~0.45–0.52 from n=150→800 (identifiability, NOT power). Known-φ diagnostic (PR #214): fixing φ lifts Σ̂/truth 0.5–0.7 → 0.78–0.94. Fix = shared/grouped dispersion (`disp_group`, Design 82), **DEFERRED to 1.0** (maintainer 2026-07-17). My pilot independently REPRODUCED this: Σ̂/truth 0.51–0.57.
- **n_sim=2000 GRID RAN (2026-07-15):** gaussian+binomial (core-2, nbinom2 fenced), n_boot=100, ~40h, MCSE~0.006 (adjudication-grade), `~/gllvm_work/grid2000/`. → **HOLD**: nominal-0.95 certificate NOT earned (gaussian ~0.91, binomial n=150 high-signal 0.836–0.853 genuinely under-cover).
- **DEFINITIVE interpretation (2026-07-15):** the point estimate is near-unbiased (Σ̂/truth 1.007 ML), so this is the **small-sample variance-component right-skew**, and **the parametric bootstrap is the WRONG route**. The certificate path is already decided + implemented: **(1) profile likelihood / log-SD route (Design 73, nominal-certified in drmTMB); (2) log-SD Wald + t-df; (3) REML.** Bootstrap/BCa is last resort. **Next coverage run = re-measure the SAME cells on the profile / log-SD-Wald route — NOT another bootstrap grid.**

**Honest impact on this session:** the metric-repair + pilot + grid were already done; my 48-cell pilot
re-derived known results (with a weaker n_boot=25 config) — a prior-work-sweep miss (I planned off the
A0 punch-list, not the A2 execution note). What this session DID add and keeps: **R2 (the one-sided-miss
gate #5 was genuinely missing from `pilot_scale_gate_eval` — added, tested, proven; it matters for the
profile-route re-measurement too)** and **R3 (the socket/RLIB compute-lane bugfix)**, plus an independent
fresh-seed confirmation of the nbinom2 ~0.5 identifiability finding.

## 6. Fences honoured / follow-ups

- **No public flip, no register promotion.** CI-08/CI-10 (Design 35) stay `partial`; PASS_TO_SCALE only
  *unblocks* the `n_sim=2000` grid, which stays behind the **adversarial coverage verdict** (Rose +
  Fisher/Efron/Gelman, default NOT-DONE, ≥2 NOT-DONE withholds) per D-43.
- **Compute on Totoro, results LOCAL** (D-50); Lane C (multinomial) untouched.
- **Not committed** — working-tree only (deployed to Totoro for the run); commit is the maintainer's call.
- **Open decision for the maintainer:** the gate-5 **miss-count floor (=5)** and threshold (=0.80) are
  parameters; Fisher should sanity-check them at the pilot/grid review (they match Design 66 §6 + the
  existing in-repo flag).

## 7. Files touched

`dev/m3-pilot-report.R` (R2: reducer emit + gate #5) · `dev/test-pilot-scale-gate.R` (r7/r8) ·
`dev/totoro-coverage-grid.sh` (R3: socket + RLIB + rsync exclude + print) · new scratch runner
`dev/run-48cell-pilot.sh` (deployed to Totoro). Plan-review artefacts in scratchpad
(`rose-plan-review.md`, `fisher-plan-review.md`).
