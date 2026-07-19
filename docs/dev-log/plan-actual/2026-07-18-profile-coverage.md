# Plan-vs-actual reconcile (Melissa) — Profile-route coverage certificate arc — 2026-07-18/19

Plan: `~/.claude/plans/jazzy-frolicking-shamir.md` (resume + remote-control) over `~/.claude/plans/memoized-gliding-dongarra.md` (v2 arc). Reconciled across the six axes; material deviations only.

| axis | planned | actual | tag |
|---|---|---|---|
| **Scope** | poll B3b → aggregate → panel → close → reconcile | same; B3b MAIN completed 32/32; anchor secondary (partial) | on-plan |
| **Evidence** | rep-clustered MCSE, IUT earn, LOCAL results (D-50) | delivered; 8 cells n_sim≈4000; results LOCAL, never GitHub | on-plan |
| **Routing** | Opus only on the panel; inline/Haiku/Sonnet elsewhere | panel dispatch BLOCKED (Opus classifier outage) → provisional single-context read instead of 4 fresh Opus lenses | **DRIFT (external, unavoidable)** → Rose: formal panel deferred, flagged Needs-you |
| **Safety gates** | D-43 default NOT-DONE, ≥2 NOT-DONE withholds, no "certified" pre-panel | honored — provisional read WITHHELD (non-promoting); nothing promoted; register non-promoting | on-plan (gate preserved despite the routing drift, because outcome is non-promoting) |
| **Public claims** | promote ONLY panel-earned cells | NOTHING promoted; register CI-08/CI-10 got a non-promoting disambiguation + WITHHELD note; widget untouched (still accurate: 0.94-gate, not 0.95) | on-plan |
| **Handoff** | after-task + widget + CLAUDE.md pointer + handover + reconcile | after-task filled (kept -DRAFT); handover v3 written; this reconcile; CLAUDE.md pointer pending; formal panel deferred | on-plan w/ 1 carried item |

## ADAPTIVE deviations (justified, recorded — NOT defects)
1. **Curie `-P 32` not `-P 80`** (per-task Bartlett cache would rerun the ~3–4 CPU-hr b-estimate per task → -P 80 wastes ~240–320 CPU-hr). Confirmed benign: the 4 redundant per-cell b̂ log-copies agreed exactly (range 0.0000).
2. **Standalone `dev/run-bartlett-anchor-n400.R`** (the shared grid hardcodes NS=c(50,150); `--ns=` only subsets). The n=400 anchor turned out anomalous (b̂=318) — flagged for investigation; secondary, gates nothing.
3. **Stale `anchor.DONE` handled by gating on MAIN, not the marker** (false-positive from the aborted first anchor launch). Correct call.
4. **Completion-gate latency (this session):** `b3b-poll.sh` gated on `workers==0`, which stuck on 2 zombie processes for ~6h after MAIN was genuinely complete (DONE + 32/32 chunks). Latency only, no correctness impact; recorded as a lesson (gate on DONE+chunks, not process count).

## DRIFT (routed to Rose)
- **Formal 4-lens D-43 panel not run** (Opus-classifier outage). Provisional single-context read substituted. Because the outcome is WITHHELD (non-promoting), no over-claim resulted, but the formal panel is a genuine deferred verification item. → Rose: flagged Needs-you in the handover + after-task; run to confirm when tooling recovers.

## No unexplained scope drop, no skipped smoke, no silent promotion, no undeclared handoff state.
