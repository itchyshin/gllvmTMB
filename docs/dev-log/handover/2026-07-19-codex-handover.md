# Handover → Codex — gllvmTMB, the 0.6-finishing core arc (other lanes PARKED)

**Meta:** 2026-07-19 · AUTHOR = Claude (Opus 4.8) · TARGET = **Codex** · repo = **gllvmTMB** (same repo — Codex continues here), branch `claude/profile-coverage-remeasure-20260718` (off `claude/release-0.5.0`).

> **Cross-tool, SAME repo.** Claude → Codex on **gllvmTMB**; the two run **sequentially, one at a time per repo**
> (AGENTS.md). Codex takes over gllvmTMB to drive **the core arc to finish 0.6** and runs the **live toolchain**
> (real R/TMB fits, `devtools::test()`, `R CMD check --as-cran`, sims, rendering). The other gllvmTMB lanes
> (CI-11, multinom/tier-2a, Ayumi) are **PARKED — NOT part of this arc**; leave them untouched (details below).
>
> **Where the 0.6 work is queued (grounded in `ROADMAP.md`):** the roadmap does not name a single "0.6 core" — its
> **Next Shared Work Queue** is the concrete starting point: top item (explicitly **Codex-owned**) = finish the
> **latent-rank model-selection article**; then confirmatory-loading evidence; then one-page-at-a-time hidden-
> article restoration. The **Long Horizon** then runs to a **Pre-CRAN** stage (public-API audit, clean CRAN-style
> checks, current validation-debt register). Interval coverage — the standing headline (D-42) — is now largely
> MEASURED (profile + CI-11 → WITHHELD/partial). **Confirm the exact slice with the maintainer, then start from
> the roadmap queue** (one branch / one PR).

## Goals / mission
Finish **gllvmTMB 0.6** — close the 0.5.0→0.6 gap list. The 0.5.0 engineering (arcs A–E, #737–#745) is merged and
cross-OS verified but **not CRAN-submitted**; 0.6 is the release target. Reader-facing surfaces never show
internal register codes; intervals are framed recovery-only until earned.

## Candidate 0.6-core items (from CLAUDE.md / recent handovers — Codex + maintainer PICK the arc)
- **Interval-coverage headline — largely MEASURED this cycle** (profile route + CI-11 cross-family both ran to a
  D-43 verdict = WITHHELD/partial; see below). Remaining: decide how the register/reader-docs reflect the honest
  "measured, qualified, not certified" state.
- **The one-by-one pkgdown + function-doc honesty review WITH the maintainer** (slow, deliberate; intervals
  recovery-only; delta/hurdle latent-scale correlation "do not advertise") — flagged as the one thing NOT done
  for 0.5.0.
- **Open article-cleanup PR #746** (2 cut, 26 improved, pkgdown reorganised; the QG `animal-model` cut/keep call).
- **Issue closeout** staged at `dev/issue-closeout-2026-07-10.sh` (reword version strings to 0.5.0/0.6 first;
  maintainer runs bulk closes).
- Toward the 1.0 maturity milestone (NOT 0.6 unless the maintainer pulls it in): Julia parity, the paper, the full
  coverage campaign.

## What was accomplished (this session — part of the interval-coverage headline)
- **Profile-route Bartlett re-score CLOSED → certificate WITHHELD at 0.95.** B3b ran to completion on Totoro (8
  gaussian cells, n_sim≈4000, LOCAL D-50). Formal 4-lens D-43 panel → WITHHELD, unanimous for n≥150; the opt-in
  Bartlett crit lifts n≥150 to ~0.949 but within MCSE of the uncorrected baseline (no demonstrable work); the
  n=400 anchor b̂=318 was a **pooling outlier** (fresh n=400 normal, b̂=7.46). Nothing promoted. Committed
  `9476cbe4`. Record: `docs/dev-log/after-task/2026-07-18-profile-cert-v2.md`.
- Consolidated the concurrent gllvmTMB lanes + reviewed CI-11's closure/register proposal.

## Current lane state — what's THE ARC vs PARKED
| lane | state | is it the 0.6 arc? |
|---|---|---|
| **profile-coverage / Bartlett** | ✅ DONE, committed `9476cbe4`, WITHHELD | part of the interval-coverage headline; **closed** — fold branch to `release-0.5.0` (4 ahead, clean) |
| **CI-11 cross-family** | ✅ CLOSED, committed + pushed (`claude/cross-family-ci11-20260718`) | **PARKED** — human-gated: maintainer merge review (HIGH-RISK API); register PROPOSAL (`docs/dev-log/2026-07-19-ci11-register-update-PROPOSAL.md`, apply only after Ayumi + fresh D-43); `multiple_r` fix (`task_25cbceb0`); hardening minors (`task_7368e457`) |
| **multinom / tier-2a phylo-multinomial** | 🔶 IN-FLIGHT, uncommitted (`?? dev/phylo-multinomial-*`, tier-2a docs, PR #753 draft) | **PARKED** — Lane C's active build; handover `docs/dev-log/handover/2026-07-17-claude-handover-tier2-phylo-multinomial.md`. Do not disturb. |
| **Ayumi external real-data pass** | ⏳ this afternoon | **PARKED** — feeds CI-11 |

Both interval lanes (profile + CI-11) landed on the same honest picture: **profile/likelihood routes robust; naive
plug-in/bootstrap fenced; verdict WITHHELD/partial, not certified.** Coherent 0.6 interval story.

## Files created / modified (this session)
Committed `9476cbe4`: `CLAUDE.md`, `docs/design/35-validation-debt-register.md`, `docs/dev-log/after-task/2026-07-18-profile-cert-v2.md` (renamed final), `docs/dev-log/handover/2026-07-19-claude-handover-profile-cert-v3.md`, `docs/dev-log/plan-actual/2026-07-18-profile-coverage.md`. Committed `a6a53e6f`: this handover + `CLAUDE.md` pointer.
**Never-stage (declared, belong to other lanes / not commit):** `docs/dev-log/check-log.md` (entangled: my profile
entry + Lane C tier-2a append in ONE block — do not `git add` it wholesale), the pre-existing `M docs/dev-log/handover/2026-07-18-claude-handover-profile-route.md`, the `?? …tier2a…` files, `.claude/`, and the Bartlett worktree `.claude/worktrees/agent-a1b37d9e4b149949e` (decided NOT to commit).

## Next immediate steps (Codex, in gllvmTMB)
1. **Rehydrate:** read `AGENTS.md` natively, then this doc + `ROADMAP.md` + the profile/CI-11 after-tasks. Team
   mirror `.codex/agents/*.toml` — **Rose audit mandatory** before any public/claim change; load the
   `cran-release-gate` skill at any release rung (default NOT READY).
2. **Start from `ROADMAP.md` "Next Shared Work Queue"** — top Codex-owned item = finish the latent-rank
   model-selection article; then confirmatory-loading / hidden-article restoration; the Long Horizon's Pre-CRAN
   stage is the release gate. Confirm the exact slice with the maintainer before deep work (one branch / one PR).
3. **Run the live toolchain** (this is why it's Codex): `export NOT_CRAN=true` + the compiler/PATH env `AGENTS.md`
   specifies; real fits, `devtools::test()`, `R CMD check --as-cran`, sims, `pkgdown::build_site()`. Local checks
   over GitHub Actions (cost discipline). Any Totoro/DRAC campaign → results LOCAL (D-50), never GitHub.
4. **Do NOT touch the parked lanes** (CI-11 human-gated items, multinom/tier-2a `??` files, Ayumi) or the
   entangled `check-log.md`/Bartlett worktree. If the 0.6 arc genuinely needs one, flag it to the maintainer.

## Handover blockers — RESOLVED (2026-07-19) — Codex: these are DONE
- ✅ **0.6-core scope: GROUNDED.** No longer an open flag — start from `ROADMAP.md` "Next Shared Work Queue" (top
  Codex-owned item: finish the latent-rank model-selection article), then Long Horizon Pre-CRAN; confirm the exact
  slice with the maintainer on arrival. This session was the interval-coverage sub-arc (now measured/WITHHELD).
- ✅ **Branch PUSHED.** `claude/profile-coverage-remeasure-20260718` is pushed to `origin` — no longer a fragile
  local-only tree; a fresh Codex checkout has the full closeout.

## Gotchas / failed approaches (this session)
- Poll completion-gate on `workers==0` stuck on 2 zombie processes ~6h after the Totoro run was done — gate on
  `DONE + all-chunks-present`, not process count.
- Bartlett b-estimator uses `mean(W)` (correct; χ²₁ median≈0.455 would be a bug) but has NO pooling outlier-guard
  → one rogue rep produced the b̂=318 anchor.
- Committing a renamed file: `git add old-DRAFT.md` fails post-rename; stage the new path and VERIFY content
  landed (`git show HEAD:<path>`) — an R100 rename can commit the OLD blob.

## How to resume (Codex, in gllvmTMB — paste at repo root; AGENTS.md is native)
```
Rehydrate from docs/dev-log/handover/2026-07-19-codex-handover.md + AGENTS.md. Confirm the specific 0.6-finishing
core arc from ROADMAP.md + the maintainer (candidate list in the doc), then execute it with the LIVE toolchain
(export NOT_CRAN=true; fits, devtools::test, R CMD check --as-cran, sims, pkgdown) — Rose audit before any public
claim, cran-release-gate at any release rung. Do NOT touch the parked lanes (CI-11, multinom/tier-2a, Ayumi) or
the entangled check-log.md / Bartlett worktree. Profile-coverage is DONE (WITHHELD, 9476cbe4).
```

## Mission-control summary
| repo | branch / state | shipped this session | next (by leverage) |
|---|---|---|---|
| **gllvmTMB** | `claude/profile-coverage-remeasure-20260718` @ `a6a53e6f` (local, UNPUSHED) | profile-route Bartlett WITHHELD, closed + committed; lanes consolidated | **Codex: finish 0.6 core** (confirm scope) via live toolchain · fold profile branch to release-0.5.0 · parked: CI-11 (merge/register + Ayumi pm), multinom build |
