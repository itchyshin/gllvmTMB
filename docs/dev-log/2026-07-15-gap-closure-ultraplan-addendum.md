# Gap-closure ultra-plan — post-Lane-A-commit addendum (2026-07-15)

**Extends** `docs/dev-log/2026-07-13-gap-closure-ultraplan.md` (do not rebuild it —
this only adds the batch that unblocks once Lane A commits). **Branch:**
`claude/release-0.5.0`.

## Trigger (when this fires)

This addendum is **parked** until the single gate clears:

> **Lane A commits its uncommitted diff** (or the maintainer commits it) — i.e.
> `R/fit-multi.R`, `src/gllvmTMB.cpp`, `R/extract-sigma.R`, `R/bootstrap-sigma.R`,
> `R/diagnose.R`, `R/extract-correlations.R`, `R/predictive-diagnostics.R`,
> `dev/m3-grid.R`, `dev/m3-pilot-report.R` are no longer showing as uncommitted.

A background monitor watches git state and re-pings the session when this happens.
Until then, everything below is blocked — do not start it.

## Lane-awareness rules (standing, per maintainer 2026-07-15)

1. **Branch off Lane A's commit, don't diverge from it.** Once Lane A commits, pull
   its tip and build on top; never resurrect the old uncommitted-diff hazard.
2. **A3 / the coverage certificate is Lane A's to own.** Do NOT flip any
   point-only→coverage-checked cell on the capability widget or in NEWS — those
   flips are earned by Lane A's grid. This addendum produces *recovery* evidence and
   *design/impl*, never coverage claims.
3. **nbinom2 stays fenced** (G1 landed; G2/G3 pending) until Item 1 re-earns it on a
   real shared-phi coverage run — not on an assertion (D-43 default NOT-DONE).
4. **Merge gates hold.** API/engine changes (`disp_group=`) and any grammar change
   are implemented on a branch and presented for maintainer sign-off before merge.
5. **Live-TMB / Totoro work is a Codex handoff**, not a Claude fan-out (division of
   labour). Claude implements pure-logic + R wiring + validation *scaffolding*;
   Codex runs the real fits, `R CMD check`, and the compute campaign.

## The unblocked batch (fan-out once triggered)

Model routing per `~/shinichi-brain/memory/MODEL-ROUTING.md`: mechanical → Haiku;
focused impl → Sonnet; correctness/engine → Opus/Fable.

| Slice | Work | Depends on | Lane / model | Gate |
|---|---|---|---|---|
| **S1 — G2/G3 fences** | Add the approved nbinom2 caveat to `R/families.R` (→`man/families.Rd`) and `R/extract-sigma.R` (→`man/extract_Sigma.Rd`) roxygen; one clean `devtools::document()`; verify only these two man-pages change. | Lane A commit (clean roxygen base) | Claude / Haiku | none (approved wording) |
| **S2 — Item 4 metric fix** | `dev/m3-pilot-report.R`: add `n_traits` to the aggregate row (~L617); denom `n_converged_fits * n_traits` in the gate (~L274); update `dev/test-pilot-scale-gate.R`. | Lane A commit | Claude / Sonnet | none (dev harness) |
| **S3 — Item 1 shared dispersion (impl)** | Implement `disp_group=` Route A (TMB `map=` parameter-tying; R-side index in `R/fit-multi.R`; zero C++ diff target). Design in `docs/design/82-shared-dispersion.md`. | Lane A commit | Claude impl + **Codex verify** / Opus | **maintainer sign-off before merge** (API change) |
| **S4 — Item 1 validation** | Re-run `dev/nbinom2-mitigation-ladder.R` with shared phi → does median Σ̂/truth reach nominal? Then a small LOCAL nbinom2 coverage smoke (1–2 cells, `GLLVMTMB_HEAVY_TESTS=1`). "Works" = recovery to truth, not assertion. | S3 | **Codex** (live TMB) | evidence gate before any un-fence |
| **S5 — nbinom2 re-fence or un-fence** | If S4 clears: revise G1/G2/G3 to default-vs-opt-in wording (per checklist §6 item 3) and hand the earned cell to Lane A's A3. If not: keep the recovery-only fence, document the residual gap. | S4 | Claude / Sonnet | Lane A owns the widget flip |
| **S6 — Phase D diagnostics breadth** | Extend `predictive_check()` / residuals / `diagnostic_table()` beyond Gaussian/Poisson/NB2 → binomial, Gamma, beta. Independent of Item 1. | Lane A commit | Claude scaffold + **Codex** fits | tests ship with impl |
| **S7 — Phase B slope-recovery evidence** | Reconcile merged `nbinom1-*` work; nbinom1 + tweedie slope-recovery evidence (Design 80 `p`-fix escape hatch). Bare-`||` grammar already landed (`900c1af3`). | Lane A commit | **Codex** (live TMB) | #388 validate-before-advertise |

**Dependency shape:** S1, S2, S6 are independent and parallel-safe the moment the
gate clears. S3→S4→S5 is the serial flagship chain (and its live parts are Codex).
S7 is an independent Codex lane. The Phase A2 coverage campaign remains Lane A +
Codex/Totoro — not in this batch.

## What Claude fires autonomously vs what needs you / Codex

- **Autonomous on trigger (conflict-safe, no gate):** S1, S2, S6-scaffold, and the
  *implementation* of S3 on a branch (not merged).
- **Needs your sign-off:** merging S3 (`disp_group=` API) and any grammar change.
- **Needs Codex (live TMB):** S4 validation fits, S6 family fits, S7 — handed over
  via `protocols/handoff.md` + a `check-log.md` line.

## First move when triggered

1. Pull Lane A's commit; confirm the tree is clean and the build still loads.
2. Fan out S1 + S2 + S6-scaffold in parallel (conflict-safe).
3. Implement S3 on a branch; open it for sign-off with the `82-shared-dispersion.md`
   validation plan attached; hand S4 to Codex.
4. Report status to the maintainer at the stopping point (open items, sign-off asks,
   Codex handoffs) per the repo's touchpoint rule.
