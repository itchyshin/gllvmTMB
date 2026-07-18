# Session Handoff — calibrated cross-family intervals: R build (Slices 1–4) SHIPPED + verified; NEXT = Slice 5 harness → Slice 6 Totoro campaign

**Meta:** 2026-07-18 · from Claude (Opus 4.8, ultracode) · **TARGET = Claude** (either tool can resume) · **isolated worktree** `../gllvmTMB-cross-family-intervals` on branch `claude/cross-family-intervals-20260718` (off `origin/main` @ #765). **Uncommitted, verified, safe on disk.** This is the multinomial lane's chosen next arc (handover `269832b4`); the profile-coverage MAIN lane is a *separate* lane (`claude/release-0.5.0`, Totoro `~/gllvm_work`) — do NOT touch its files.

## The plan (design of record)
`~/.claude/plans/do-we-need-to-functional-zebra.md` — read the **GOAL block**, the **v3 — Full-panel resolution** section (the binding decisions), and the Slice 1/3 locked designs. The plan went through a **full 5-lens W1 adversarial panel** (Fisher, Rose, Efron, Gelman, completeness) that produced **2 BLOCKERS + must-fixes**, all folded into v3 and all IMPLEMENTED below.

## What was accomplished (this session)
- **Plan v1→v3**, panel-reviewed. Route (maintainer-chosen): **extend `simulate` for the multinomial softmax draw + wire the withheld profile prototype**.
- **Step 0**: isolated worktree cut off `origin/main`; the MAIN lane's in-flight profile work restored (it was never actually reset — safe in the working copy AND redundantly in `stash@{0}`); Rose isolation check PASSED (`stash@{0}` touches `dev/m3-*.R`+`check-log.md`, **zero** hits on `R/profile-derived.R`).
- **Slice 1 — `R/methods-gllvmTMB.R`** (`.draw_y_per_family`): removed the `gllvmTMB_simulate_multinomial_unsupported` fence; `16L` added to `supported`; `else if (fid==16L)` skip in the per-row loop (so the terminal Gaussian fallback can't overwrite the one-hot — **panel Slice-1 fix**); grouped softmax pass (baseline pinned at 0, one categorical draw per `multinom_group_id`, one-hot write). **Unblocks the parametric bootstrap + ships a reusable engine capability.**
- **Slice 2 — `R/bootstrap-sigma.R` + `R/extract-correlations.R`**: `what="cross_corr"` added to `bootstrap_Sigma`; `tryCatch`-guarded branch in `.extract_summaries` stores `multiple_r_<lvl>` as a **plain named numeric of `multiple_r` ONLY** (contrast_r is profile-only, never through bootstrap); per-partner `n_effective` min-effective-B guard; `.summarise_draws` single-partner `dim()` fix; `boot_median` sanity comparator (**the delta comparator was CUT — no ADREPORT exists**). `extract_cross_correlations(method="bootstrap")` wires one `bootstrap_Sigma` call.
- **Slice 3 — `R/profile-derived.R` + `R/extract-correlations.R`**: `diag_resid` param on `profile_ci_correlation` = **Option (b) AUTO scale** (adds the compile-time-constant link residual to the i,j diagonals in BOTH `rho_hat` and `target_fn`, off-diagonal untouched → profiled quantity == AUTO-scale point est == truth; **panel BLOCKER 1**); reconstruction self-check (`gllvmTMB_profile_reconstruction_mismatch`, gated on `!is.null(fit$tmb_map[[diag_name]])` to skip the mocked route-matrix test — semantically exact); real code fences (`gllvmTMB_multiple_r_profile_undefined`, tier phy/spatial refused, latent guard, parameter-dependent-residual fence = any partner not gaussian/binomial).
- **Slice 4 — `R/extract-correlations.R`**: new signature `(fit, level, contrasts, link_residual, method=c("point","bootstrap","profile"), conf, nsim, seed)`; **per-estimand columns** `multiple_r_lower/upper/method/interval_status` (scalar) + `contrast_r_lower/upper/method/interval_status` (list-cols); interval_status via `.correlation_interval_status()` → all computed intervals carry **`target_specific_uncalibrated` (CI-11 pending)**; roxygen `@param method/conf/nsim/seed` + `@return` humility banner; `man/extract_cross_correlations.Rd` + `man/bootstrap_Sigma.Rd` regenerated.

- **Slice 5 — `dev/cross-family-coverage.R`** (728 lines, NEW; smoke-verified): the multi-seed coverage harness. Analytic `Σ_total_true` with a single coupling scalar `uniroot`-tuned so `multiple_r_true` hits each target (0.2/0.5/0.8) to 1e-4; contrast Ψ pinned to 0; hard truth-assertion (`extract_Sigma(…,"none")` == analytic latent Σ) aborts on mismatch; coverage = covered/converged (ci_failed=MISS) + worst-case sensitivity; both estimands (bootstrap `multiple_r`, profile `contrast_r` per contrast); rep-clustered MCSE + 2·MCSE-vs-0.94 gate + power-vs-0.95; 18 interior certified cells + 2 boundary diagnostics; pre-campaign inner-convergence gate; Path-2 `.check_simulate_unconditional` assert; by-hand freqs (no `nnet`). CLI: `--mode={gate,pilot,confirm} --n-sim --n-boot --shard --n-shards --seed-base`; results LOCAL `.rds` only. **Caught + fixed a real hazard:** `extract_Sigma` orders rows alphabetically by trait name, so partner position varies by family — truth is permuted to the fit's row order by name. **Smoke PASSED** end-to-end (truth-assertion pass; both estimands non-NA in-range; gate PROCEED).

**Verification (end-to-end, `NOT_CRAN=true`):** `test-simulate-multinomial.R` **4/4**, `test-cross-family-intervals.R` **7/7** (estimand-identity to 1e-6, bracketing, canary-silent, `multiple_r`+profile fails loud, self-check negative control, guards, bootstrap path), `test-profile-route-matrix.R` **20/20** regression. Independent large-n **chi-square GOF** confirms the softmax draw is distributionally correct (no baseline off-by-one). Adversarial diff-review of the 2 highest-risk files confirmed correctness.

## Current state / git ledger
| Artifact | Committed | State |
|---|---|---|
| Slices 1–4 (5 R files + 2 tests + 2 .Rd) in worktree | **n** | **VERIFIED, uncommitted** (safe on disk in the worktree) |

Files changed: `R/methods-gllvmTMB.R`, `R/bootstrap-sigma.R`, `R/extract-correlations.R`, `R/profile-derived.R`, `man/bootstrap_Sigma.Rd`, `man/extract_cross_correlations.Rd`; new `tests/testthat/test-simulate-multinomial.R`, `tests/testthat/test-cross-family-intervals.R`. **Commit held per the commit-only-when-asked rule** — maintainer decides. Suggested commit (on the worktree branch; do NOT auto-merge — engine + likelihood-adjacent = high-risk):
```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB-cross-family-intervals" && \
git add R/methods-gllvmTMB.R R/bootstrap-sigma.R R/extract-correlations.R R/profile-derived.R \
        man/bootstrap_Sigma.Rd man/extract_cross_correlations.Rd \
        tests/testthat/test-simulate-multinomial.R tests/testthat/test-cross-family-intervals.R && \
git commit -m "feat(cross-family): calibrated intervals on extract_cross_correlations() — simulate multinomial draw + bootstrap multiple_r + profile contrast_r (uncalibrated; CI-11 pending)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

## Totoro campaign — LIVE STATUS (W3 in progress)
- **Deployed:** worktree rsynced to Totoro `~/gtmb_work/xfam-intervals`; the NEW package installed to a **private lib** `~/gtmb_work/xfam-lib` (do NOT install to the shared `~/R/lib` — the main lane uses it). **Critical env:** the user's R env puts `~/R/lib` first, so you MUST run every harness invocation with `export R_LIBS=/home/snakagaw/gtmb_work/xfam-lib:/home/snakagaw/R/lib` (R_LIBS, not R_LIBS_USER — the latter is overridden) or `library(gllvmTMB)` loads the STALE 0.5.0 without the new code (this exact bug produced a false 0/8 gate).
- **Gate:** `--mode=gate` → **PROCEED** (gaussian + binomial, N=150, mr=0.5: outer convergence 1.00, inner-bootstrap survival 1.00). Per-fit ≈ 0.8s at N=150.
- **Pilot RUNNING (detached):** 90 `setsid nohup` shards launched 2026-07-18 12:55, `--mode=pilot --grid=certified --n-sim=200 --n-boot=99 --n-shards=90 --seed-base=20260718 --out-dir=pilot-results`, logs in `pilot-logs/`. Truth-assertions PASS. ETA ~1.5–2h. **Aggregate when 90 `.rds` land:** `cd ~/gtmb_work/xfam-intervals && export R_LIBS=/home/snakagaw/gtmb_work/xfam-lib:/home/snakagaw/R/lib && Rscript dev/xfc-aggregate.R pilot-results` (writes `pilot-results/AGGREGATED.rds` + prints the per-cell coverage table). Aggregator combines raw covered/ci_failed across shards + sums non-converged, re-runs `.xfc_summarise_series` (coverage=covered/converged, 2·MCSE-vs-0.94).
- **Confirm (NOT launched):** after the pilot validates, launch detached like the pilot but `--grid=both --n-sim=13000 --n-boot=499 --n-shards=~100` — this is a **multi-DAY** job (bootstrap-dominated ≈ tens of thousands of CPU-hours); it will NOT finish in one session. Results land later; aggregate the same way.
- **Pilot is plumbing-scale** (n_sim=200 ⇒ 2·MCSE≈0.03): it exercises the whole pipeline + gives a first coverage signal, but the 0.94 gate verdict is only trustworthy at confirm scale. Report pilot numbers with that caveat + the "MEASURED, NOT certified" banner.

## Next immediate steps (ordered)
1. **Slice 5 — `dev/cross-family-coverage.R`** (NEW file; the multi-seed certification harness). Design in the plan's "Coverage-study design" + v3 fixes. Load-bearing:
   - **Analytic `Σ_total_true = ΛΛᵀ + diag(ψ) + R_link`**; apply the estimator's OWN doubly-clamped functional (`sqrt(max(0,·))`, `min(·,1)`) to it. **Pin the mapped-off multinomial-contrast Ψ to ≈0** (the `.expand_mapped_diag` convention), NOT arbitrary DGP ψ. **Hard assertion:** `extract_Sigma(fit,'unit','total','none')` on a fitted truth fixture == analytic Σ to tolerance.
   - **Coverage = covered / converged reps** (panel BLOCKER 2); `ci_failed`/NA = MISS; exclude only pre-CI non-convergence + a worst-case sensitivity (non-converged = not-covered).
   - Operationalize BOTH estimands: `multiple_r` (bootstrap, one row per (nominal,partner,rep)) AND `contrast_r` (profile, one row per (nominal,partner,contrast k,rep); per-contrast MCSE).
   - Grid: certified interior cells N∈{50,150,500} × multiple_r∈{0.2,0.5,0.8} × partner∈{gaussian r=0 (keep σ_eps>0 small), binomial}; + non-certified boundary DIAGNOSTIC cells. rep-clustered MCSE; judge the **2·MCSE lower band vs 0.94**; **confirm at ~12k CONVERGED reps** (inflate attempts by attrition; report effective N + per-cell power vs 0.95).
   - **Pre-campaign inner-convergence gate**: measure the K=3 cross-family multinomial refit convergence rate on 1–2 pilot cells FIRST; if <~0.8, abort / lower-B / relax tolerance (don't burn the 12k campaign on a null).
   - Path-2 gate: assert `.check_simulate_unconditional(fit)$can_redraw` is TRUE before any bootstrap.
2. **Slice 6 — Totoro campaign** (multi-hour). **Deploy step first** (D-50: no GitHub artifacts, branch not pushed): rsync the worktree to Totoro `~/gtmb_work` (socket `~/.ssh/cm-*totoro*`, `cm-` prefix, ≤100 cores). Smoke-first (1 cell, abort on NA) → pilot n_sim=200 → confirm ~12k. Results LOCAL.
3. **Slice 7 — STOP + report** the MEASURED coverage with the "MEASURED, NOT certified — awaiting D-43 panel" banner; after-task; refresh this handover. **Register CI-11 flip + NEWS + the D-43 panel (W4) are DEFERRED** — Rose before any covered claim; ≥2 NOT-DONE withholds.

## Gotchas
- **`nnet` NOT in Suggests** — the coverage harness / any GOF must use by-hand expected freqs OR add `nnet` to Suggests + `skip_if_not_installed`.
- **Run tests with `NOT_CRAN=true`** or everything `skip_on_cran`s (silent all-skip — looks green but ran nothing).
- Cross-family gaussian+multinomial fits are **~15–20s each**; the bootstrap refit loop dominates — budget compute accordingly (this is exactly why Slice 6 goes to Totoro).
- **`multiple_r` is never profiled** (fails loud); **`contrast_r` never bootstrapped** (profile-only). Don't cross the wires.
- The **delta(atanh) comparator was CUT** (no `ADREPORT(Sigma_B)` in `src/gllvmTMB.cpp`). Do not re-add it without a C++ recompile slice.
- Do NOT edit `dev/m3-grid.R` / the main lane's files. Register row is **CI-11** (new), NOT CI-08/CI-10 (the main lane's).

## How to resume
```
claude "Rehydrate from docs/dev-log/handover/2026-07-18-claude-handover-cross-family-intervals-build.md in the worktree ../gllvmTMB-cross-family-intervals. Slices 1–4 are VERIFIED (uncommitted). Build Slice 5 (dev/cross-family-coverage.R) per the plan v3 (~/.claude/plans/do-we-need-to-functional-zebra.md), then run the Totoro campaign (Slice 6). Coverage = covered/converged; pin the mapped-off contrast Ψ in the truth; inner-convergence gate before the 12k run; measured-not-certified, D-43 deferred."
```
