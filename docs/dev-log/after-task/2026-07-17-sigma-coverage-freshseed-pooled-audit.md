# After-task — Sigma_unit coverage: fresh-seed lift pooled to N≈15k + re-audit

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` · **Register:** DEV-ONLY (no public flip)
**Disposition:** **DECISION PENDING (Shinichi).** The fresh-seed lift approved in the WITHHELD
after-task is complete and pooled. Under the committed rep-level MCSE both gaussian n150 cells now
clear the 0.94 gate on their 2·MCSE lower band — d1 comfortably, **d2 thinly**. Rose's independent
re-audit is the D-43 gate; the earn-vs-defer call is Shinichi's. No public surface touched.

## Scope
Continue the WITHHELD arc (`2026-07-17-sigma-coverage-nsim5000-confirm.md`): confirm the Totoro
fresh-seed lift finished, POOL the fresh disjoint-seed reps with the original run to shrink the MCSE,
and re-audit the gaussian `Sigma_unit_diag` `profile_total` certificate under the **committed** MCSE.
binomial/nbinom2/ordinal FENCED; off-diagonal stays bootstrap; Lane B/C files untouched.

## What ran (compute already complete — no new heavy run launched)
- **Fresh-seed run** `~/gllvm_work/profile_rescore_freshseed_A/` (Totoro): gaussian n150 only, reps
  **5001–15000** (10,000 fresh disjoint-seed reps), seed_base=1, n_boot=100, 96 shards/cell.
  **DONE exit=0**, 192 shards (96 d1 + 96 d2). (Note: this `_A` run — 10k reps / n_boot=100 —
  superseded the handover's draft plan of 15k reps / n_boot=10; the named `profile_rescore_freshseed`
  dir was abandoned empty.)
- **Pooling** (this session): rbind the gaussian-n150 shards from the original run
  `~/gllvm_work/profile_rescore/` (reps 1–5000) + the fresh run, filtered to `n_units_cell == 150`,
  verified rep-index overlap = 0, → `m3_summarise`. Saved `pooled-N15k-{collected,summary}.rds` in the
  fresh dir. Pooled cell N: d1 14,562 reps, d2 14,898 reps.
- **Rose** (independent verification sub-agent, Opus): recomputes the pool from raw shards, runs the
  batch-heterogeneity test, returns EARNED/MARGINAL/DEFER. Audit → `docs/dev-log/2026-07-17-rose-pooled-coverage-reaudit.md`.

## Results — gaussian `Sigma_unit_diag`, profile_total (conditional on convergence)
| cell | pooled coverage (N≈15k) | committed MCSE = √(p(1−p)/N) | band = cov − 2·MCSE | gate 0.94 |
|---|---|---|---|---|
| d1 n150 | 0.9477 | 0.00185 | **0.9440** | ✓ (+0.0040) |
| d2 n150 | 0.9461 | 0.00185 | **0.9424** | ✓ (thin, +0.0024) |

Context (authoritative N=5k, from the WITHHELD after-task): original Totoro d1/d2 = 0.9482 / **0.9473**
(d2 band 0.9409, thin pass); rorqual d2 = 0.9462 (band **0.9398**, the fail that drove WITHHELD).
The fresh Totoro reps settled d2 at ~0.946 — **coinciding with the independent rorqual 0.9462** — so
the lift's benefit is **MCSE shrinkage** (0.0032 → 0.00185 as N 5k → 15k) lifting the band above 0.94,
not a point-estimate rescue. Cross-sample convergence on ~0.946 supports legitimacy.

## Convergence (conditional-on-convergence, disclosed)
Effectively complete: n_completed == n_reps for both cells (among reps present, all converged). Of the
nominal 15,000, d1 has 14,562 present (~2.9% produced no record), d2 has 14,898 (~0.7%). The absent
reps are non-converged base fits (per the WITHHELD exclusion diagnosis: the profile route correctly
declines a CI on a non-converged fit). Coverage is honestly conditional-on-convergence with the rate
disclosed; any public wording must carry "for converged fits."

## D-43 verification panel verdict (the gate)
Full audit: `docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md` (Workflow `wf_dcbe24f8-af6`,
3 adversarial lenses + synthesis; 2 lenses independently recomputed to 4 dp on Totoro).
**Disposition: BOTH cells CERTIFY (3-0 EARN each), under strict wording; d2 thin.** Neither reached the
≥2-WITHHOLD threshold. Two load-bearing qualifications: (1) conditional-on-convergence is mandatory —
worst-case unconditional coverage 0.9200 (d1) / 0.9397 (d2) is below the gate, so the qualifier must
travel with the number on every surface; (2) the certified property is clearing the **0.94 gate**, not
nominal 0.95 (point ~0.946–0.948; d2 z=−2.11 below nominal). The drafted flip-wording fails three ways
(nominal-0.95 phrasing; no convergence qualifier; no d≤2 scope) and must be corrected before any flip.
Panel/chair lean: flip d1 confidently; d2 = earn-under-strict-wording OR defer to 1.0.
(The initial single-agent Rose run terminated without a file under ssh/classifier flakiness; this panel
is its more robust replacement.)

## Deliverable to Shinichi
`docs/dev-log/2026-07-17-sigma-coverage-earn-vs-defer-memo.md` — the earn-vs-defer memo with the pooled
table, the two honesty caveats, Rose's verdict, and the two wording decisions he must make if he flips
(the public number for two cells; the "nominal vs 0.94-gate" phrasing).

## Fences honored
No public surface flipped (widget / NEWS / confint help / roxygen unchanged). binomial/nbinom2/ordinal
FENCED. Off-diagonal stays bootstrap. Committed rep-level MCSE only (`m3-pilot-report.R:768`), NOT the
clustered ~0.0015. Results kept LOCAL (D-50). All my writes this session are NEW files — the contended
coverage code (`profile-derived.R`, `z-confint-gllvmTMB.R`, reworked by the concurrent lane's
`c0754666`) was not touched.

## Hazard log (coordination) — RESOLVED
- **The concurrent coverage lane CLOSED this session and handed me this exact follow-up** (mid-turn
  session-close message). It left my uncommitted body + the fresh-seed extension in
  `dev/profile-rescore-run.R` untouched. So there is no live competing writer; I am now sole owner of
  the coverage lane. HEAD moved `1abd78d1 → c0754666` during the session as it landed.
- The lane landed **4 local, unpushed** commits on `claude/release-0.5.0`: `f0f17333` (coverage
  WITHHELD), `be40d8ae` (unconditional `phylo_diag` + fail-loud — blast radius: `simulate()` and six
  bootstrap-CI functions now error on unsupported RE tiers), `c0754666` (correlation profile RESTORED
  recovery-only — Fisher-z on Σ_total, `interval_status="recovery_unvalidated"`, **not** coverage-
  certified; CI-08/CI-10 deferred until the diagonal is settled), plus disp_group DEFERRED (design
  parked). `check-log.md` unstaged edit is the lane's; left untouched.
- **Phase C consequence:** `c0754666` reworked `profile-derived.R`/`z-confint-gllvmTMB.R`, so the
  flip-wording DRAFT's line numbers and the old "S6 safe recipe" are STALE — the diagonal-certificate
  wiring must be re-derived against the current code. The diagonal certificate (this task) is the
  prerequisite for the correlation lane's own certification.
- Branch is **ahead** with the 4 local commits unpushed; not pushed unilaterally — flagged for Shinichi.
- Tier-2 phylo-multinomial lane is safely isolated in its own worktree (`gtmb-tier2a`) — not a conflict.

## Follow-up / next arc
1. Integrate Rose's verdict into the memo + this report.
2. Shinichi decides: (A) FLIP — re-derive S6 wiring + roxygen vs current code, apply the three-surface
   flip with the confirmed number + "for converged fits" wording, `document()`, test, one commit,
   second-reviewer claim-vs-evidence check; or (B) DEFER — recovery-only for 0.6, certificate to 1.0.
3. Held sign-offs still await Shinichi (disp_group DEFERRED; family-breadth + tweedie-comment).
