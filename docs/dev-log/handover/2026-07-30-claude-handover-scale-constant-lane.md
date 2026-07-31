# Claude → Claude handover — the scale-constant lane (session close)

**2026-07-30 · from Claude (Fable 5) · TARGET = Claude · everything merged, nothing blocked**

You are Claude, picking up the lane that took the **scale-dependent-constants class** — an item
the `CLAUDE.md` snapshot had twice flagged as having *"no owner… falls between lanes by default."*
It now has one, and a body of evidence. This doc is the authoritative close; the earlier
`2026-07-30-claude-handover-scale-class-and-next-lane.md` is a subset of it.

> **⚠ MULTI-LANE REPO.** This is ONE lane. The lane map
> `docs/dev-log/handover/2026-07-25-active-lane-split.md` is authoritative for ownership, and other
> lanes' pointers in the `CLAUDE.md` snapshot remain valid — do not read this as the project's status.

## Mission control

| | |
|---|---|
| **repo / branch** | gllvmTMB · all work **merged to `main`**; this handover on `claude/session-handover-20260730b` |
| **CI** | green on every merged PR |
| **shipped** | 8 PRs merged (#832, #839, #842, #845, #846, #849, #854, #858) |
| **claim state** | **no public capability claim made or moved.** `NEWS.md` untouched by this lane; one new export (#832) fenced per-row |
| **compute** | none running; nothing on Totoro/DRAC |
| **blocked on** | nothing |
| **plan by leverage** | #851/#855 (scale class) → #856 (pooled `sigma_eps`) → #847+#848 (ridge τ + disclosure) → #843 → #837 → #844 |

## Critical context — read or you will redo refuted work

1. **#851 is a CLASS, not a bug.** ~10 instances, 10 confirmed by running fits at 1× and
   10×/0.01×. The generative mechanism: the package argues from *"latent scores are standardised
   N(0, I)"* and then applies constants to **Λ** — but standardising the latent is exactly what
   pushes the response scale **into** Λ. Fixing instances singly will keep finding more.
2. **#851 is far broader than the loadings.** At k=5000 *every* reported quantity is violated,
   including **correlations and communality** (rel.err 1) — the headline JSDM outputs. A ratio from
   a degenerate fit is garbage regardless of its invariance. Convergence is green throughout.
3. **AGHQ's integrator is CORRECT; its estimator is NOT ESTABLISHED.** Six independent checks vs no
   test comparing a point estimate to truth. Do not reopen the integrator.
4. **Two fixes were attempted and withdrawn this session.** Both looked good on their headline
   metric. Read *Gotchas* before proposing a third.

## What was accomplished

- **#832** — exported `profile_ci_total_variance()` behind a per-row `interval_status` fence
  (`"certified-0.94"` only inside the D-43 regime). Internal route **byte-unchanged** (137
  insertions, 0 deletions), so fence 4 holds structurally.
- **#839** — #813 steps 1–2: instrumentation + measurement. **The withdrawal reason is half right**
  — the constraint is tight (median error 1.1e-5 vs a 0.05 tolerance, zero points rejected), so
  **step 4's exact-constraint solver targets a problem that is not there**. Unconverged refits are
  genuinely accepted (3/60).
- **#842** — AGHQ/ridge verification audit; four defects (D1–D4).
- **#845 / #846** — landed **1,474 lines of dev-log across 9 files** that existed only in one
  working tree, untracked and one `git clean` from gone.
- **#849** — the D3 decision (keep the ridge, fix τ), answering a cross-lane request.
- **#854** — `dev/scale-equivariance-check.R`, the acceptance oracle.
- **#858** — first-pass handover (superseded by this doc).
- **Issues filed:** #837, #843, #844, #847, #848, #851, #855, #856.

## Current working state

**Working:** everything merged; `main` clean; no open PRs from this lane.
**In progress:** none.
**Blocked:** none. Two *decisions* are outstanding (see Blockers).

## Key decisions & rationale

- **D3 decided: keep the ridge, fix τ.** A cross-lane request argued the default *"never helps"*
  from the σ table. σ cannot show runaway — at `lam_sd = 3` the ridge cuts runaway **32% → 8%** and
  improves ρ while costing σ. A trade, not a free harm; defaulting it off reintroduces 32% runaway.
- **Do not make `start_method = "res"` the default** — soft-deprecated on 89 fits. But its campaign
  **never varied scale**, so it says nothing about #851's regime. Take its *mechanism* (it seeds the
  latent scores) not the method.
- **Nothing promoted.** No coverage claim, no `NEWS.md` change, #813 stays OPEN.

## Files created / modified (this lane only)

**Package code**
- `NAMESPACE` — +1 export
- `R/profile-derived.R` — export + `.details` instrumentation
- `man/profile_ci_total_variance.Rd` — new

**Tests**
- `tests/testthat/test-profile-ci-total-variance-export.R` — new, 24 tests
- `tests/testthat/test-profile-refit-instrumentation.R` — new, 12 light-tier tests

**dev/**
- `dev/profile-communality-constraint-audit.R` — new
- `dev/scale-equivariance-check.R` — new (**the acceptance oracle**)

**docs/**
- `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md`
- `docs/dev-log/audits/2026-07-30-scale-constant-class-sweep.md`
- `docs/dev-log/after-task/2026-07-30-export-profile-ci-total-variance.md`
- `docs/dev-log/after-task/2026-07-30-813-instrument-and-continuation.md`
- `docs/dev-log/plan-actual/2026-07-30-813-instrument-continuation.md`
- `docs/dev-log/handover/2026-07-30-claude-handover-session-close.md`
- `docs/dev-log/handover/2026-07-30-claude-handover-scale-class-and-next-lane.md`
- `docs/dev-log/handover/2026-07-30-claude-handover-scale-constant-lane.md` (this doc)
- `CLAUDE.md` — snapshot bullet prepended (this handover)
- `.gitignore` — `.claude/settings.local.json`, `.claude/launch.json`

**Rescued orphans (#845/#846)** — `dev/phylo-multinomial-harness-DRAFT.R`,
`docs/dev-log/2026-07-17-tier2a-ultra-plan-DRAFT.md`,
`docs/dev-log/2026-07-22-quadrature-regime-trap-and-the-correlation-boundary-gap.md`,
`docs/dev-log/after-task/2026-07-17-tier2a-s0-planning-and-codemap.md`,
`docs/dev-log/after-task/2026-07-26-binary-olre-loglik-sign-sweep.md`,
`docs/dev-log/after-task/2026-07-29-hmsc-cross-package-scout.md`,
`docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`,
`docs/dev-log/handover/2026-07-17-tier2a-S2-codex-build-brief-DRAFT.md`,
`docs/dev-log/handover/2026-07-17-tier2a-inflight-S0-done.md`

**Unmerged, deliberately:** `claude/fix-loading-start-scale-20260730` @ `86e72398` — WIP, **DO NOT
MERGE**, kept for the diagnosis.

## Next immediate steps

1. **#856 first — it gates #855.** Is `log_sigma_eps` being a scalar deliberate? It is shared across
   all gaussian *and lognormal* rows while every other family's dispersion is per-trait. Doc gap or
   capability gap changes the #855 design.
2. **#851 via #855.** Feasibility gate is **complete**. Entry: one choke point (`R/fit-multi.R:3609`)
   + two direct-`y` consumers. **Exit is the bulk of the work**: the classified extractor set, plus
   three by-name readers — `residuals()` reads `tmb_data$y` (`R/predictive-diagnostics.R:278`),
   `predict()`/`simulate()` read `report$eta`/`report$sigma_eps`
   (`R/methods-gllvmTMB.R:1626`, `:1094-1099`) — plus a trait-aware `sigma_eps`.
   ⚠ **Write the two-scale recovery test FIRST.** No existing test can validate a back-transform:
   every recovery test sits at `s_t ≈ 1`, and `1^k ≈ 1` for any exponent.
3. **#847 + #848 together** — same code area, and they compose into a silently penalised MAP fit.

## Blockers / open questions

- **Needs Shinichi:** #856 (deliberate or incidental?); and the sequencing call between #851/#855
  and #847/#848.
- Working tree has **4 entries needing a human call**: `capability-surface.html` (three-way
  divergence), two handovers with local-only edits, and `.claude/` (gitignored on `main`, not yet
  in effect on the 450-behind local branch).

## Gotchas / failed approaches — do NOT redo

- **Sequential continuation for #813** met its pre-registered criterion (8 → 0) and was **withdrawn**:
  the criterion counted drops at **1e-6 deviance**, four orders below the χ²₁ cutoff, and the fix's
  own fixed point is nearly the condition that removes them. Scoring a fix on the metric it optimises.
- **Scale-Λ-alone for #851** changes the *balance* of the two variance components, not the scale,
  and drove `test-getlv-se.R` to a non-PD Hessian.
- **`‖Λ‖/k` is not an acceptance test.** The WIP fix passed it and was *worse than baseline* above
  5e4. Use `dev/scale-equivariance-check.R`, **both blocks**.
- **Do not re-run campaign 12** (AGHQ T×n). Its O(1/T) premise is unsupported — σ-by-p is flat; the
  measurable driver is **‖Λ‖**, answered in six objective evaluations.
- **Process:** three times this session, working from a summary instead of re-deriving from source
  cost something — a table said 8 orphan files when git said 9; one of three `rep(0.5, rank)` sites
  was fixed with all three visible in the same grep output; an unverified structural argument was
  promoted into a design doc as settled. **The artifact is not the evidence.**

## How to resume

Read this doc → the `CLAUDE.md` snapshot → the lane map → #855 and #851 → the two audits. Spawn the
repo's review lens (Rose) before any public claim. Claude runs the planning/refactor/prose work and
logic tests here; the live-toolchain fits also ran fine in-session on this platform.

**One-command resume — paste in your own authenticated terminal, from the repo root:**

```
claude "Rehydrate from docs/dev-log/handover/2026-07-30-claude-handover-scale-constant-lane.md + the CLAUDE.md snapshot, then continue with the Next Immediate Steps — starting with #856, since it gates #855."
```
