# After Task: Phase 56.1 merge close-out — Shannon post-#289 cross-reference

**Branch**: `agent/phase56-1-merge-closeout`
**Date**: `2026-05-26`
**Roles (engaged)**: Shannon (coordination; Design 56 §9.1 close-out)

## 1. Goal

Execute the Shannon-side Design 56 §9.1 post-merge work after Ada merged Codex's [#289](https://github.com/itchyshin/gllvmTMB/pull/289) at SHA `3133863`. Two deliverables, both process-only:

1. Move the "Codex Phase 56.1" row in `docs/dev-log/coordination-board.md` from Active lanes → Recently resolved with the merge SHA.
2. Record the **#285 → #289** cross-reference so future agents can trace the Phase A scaffold close → Phase 56.1 dormant TMB promotion handoff.

This after-task is **not** a code PR; it documents the merge transition. No engine, parser, R/, test, register, NEWS, article, or deprecation edits.

## 2. Implemented

- **#289 merged.** `3133863` on `main`. Engine surface now carries the dormant augmented-LHS plumbing (`use_phylo_slope_correlated` flag defaulting to 0; block-local `n_lhs_cols ∈ {1, 2}`; `b_phy_aug` / `Z_phy_aug` arrays; `log_sd_b` / `atanh_cor_b` vectors; defensive `error()` guards). Legacy `phylo_slope()` byte-identity preserved by the `use_phylo_slope_correlated == 0` guard.
- **Phase 56.2 now active.** Codex started on `codex/phase56-2-rside-audit-2026-05-26`. Audit memo landed at `docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md` (in #289 itself), classifying the nine Design 56 §4 `n_traits` sites: 7 stay `n_traits` (legacy trait-indexed phylo covariance paths), 1 already promoted (DATA_ARRAY assembly added by #289), 1 split-by-flag (legacy vs augmented init). The "nine sites" list is therefore a **classification checklist**, not a mechanical replacement table — a notable Design 56 §4 correction Codex surfaced during 56.2 scoping.
- **Coord-board synced.** Codex Phase 56.1 row moved out of Active lanes; new Codex Phase 56.2 row in. Recently resolved updated.

## 3. Files Changed

- `docs/dev-log/after-task/2026-05-26-phase-56-1-merge-closeout.md` (NEW; this file)
- `docs/dev-log/coordination-board.md` (Active lanes + Recently resolved; no other sections)

## 3a. Decisions and Rejected Alternatives

**Decision**: write the cross-reference as a NEW after-task file rather than appending to the existing `2026-05-26-structural-slope-phase-a-scaffold-close.md` (#285's after-task).

**Rationale**: the #285 after-task documents the scaffold-close state at the time it was written; appending the #289 merge to it retroactively muddies the audit trail. A new dated file is the cleaner cross-reference.

**Rejected alternative**: bundle the cross-reference into the coord-board "Recently resolved" entry only, skipping the after-task file. Rejected because the after-task surface is the canonical "what happened in this slice and why" log; future agents will look there, not at the coord-board.

**Confidence**: high.

## 4. Checks Run

- `git log -1 --format='%h %s' main` → `3133863 Phase 56.1: add dormant phylo augmented TMB stubs (#289)` (confirms #289 merge SHA against the maintainer's report).
- `ls docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md` → exists on `main` (Codex's 56.2 audit memo is present and links to #289 at `3133863`).
- `grep -c "Phase 56.1" docs/dev-log/coordination-board.md` (before edit, after edit) — verify row moved, not duplicated.

No `devtools::check()`, `devtools::test()`, or `pkgdown::check_pkgdown()` needed — process-only docs change.

## 5. Tests of the Tests

N/A — no test surface touched.

## 6. Consistency Audit

- `rg "use_phylo_slope_correlated" docs/` — Design 56 §5.2 (canonical contract) and #289's after-task + check-log entries appear as expected.
- `rg "phase56-2-rside-audit" docs/` — Codex's 56.2 audit memo discoverable from `main`.
- `rg "n_lhs_cols" docs/dev-log/` — Codex's 56.2 audit + Design 56 §5.2 + #289 after-task all use the term consistently as block-local.

## 7. Roadmap Tick

No ROADMAP row changed. The Active Plan tick is "Phase 56.1 complete; Phase 56.2 active" — captured in coord-board, not ROADMAP.

## 7a. GitHub Issue Ledger

No GitHub issue applies to this slice. No new issue created. The Phase 56.1 surface itself was tracked entirely via PRs (#289), the Design 56 stub (#279) and expansion (#280), and the in-flight 56.2 branch (Codex).

## 8. What Did Not Go Smoothly

- Earlier stop-hook iterations during the Phase A scaffold close repeatedly fired on a "finish the plan" goal-hook that physically can't resolve in one session (the plan is 30-50 days, multi-person, mostly Codex-owned). Each iteration produced ~1 small in-scope action and a restatement that the hook is unsatisfiable. Recommendation surfaced to the maintainer: retire or rephrase the goal-hook to something session-completable. (Process note for future agents; not a blocker.)
- The Design 56 §4 "nine `n_traits` sites" wording read as a mechanical replacement list during initial drafting. Codex's 56.2 audit caught and corrected this. The lesson: classification checklists masquerading as replacement lists are a known anti-pattern; flag explicitly when authoring future audit checklists.

## 9. Team Learning

- **Shannon (coord)**: the wide↔long byte-identity contract is robust through merge — confirmed by simulating the squash before any merge happened (PR comment on #289). Pattern worth keeping: before claiming "no conflict with X", actually run `git merge-tree` against current main.
- **Rose (scope honesty)**: #289's "dormant" framing (default flag = 0; legacy guard preserves byte-identity) is the right shape for engine work that lands before parser activation. Captured in coord-board pattern as a precedent for future dormant promotions.

Other roles not engaged in this slice.

## 10. Known Limitations And Next Actions

**Known limitations**:

- This after-task documents handoff only; it does not validate the augmented-LHS engine surface against simulated truth. That validation lives in #289's regression test (`test-phase56-1-phylo-augmented-stub.R`, PASS 9), and the broader recovery validation is Phase 56.5's deliverable (skeletons gated by `skip_until_stage3()` in `test-{phylo,animal,spatial,relmat}-{latent,unique,indep,dep}-slope-gaussian.R`).
- A6 prep memo ([#291](https://github.com/itchyshin/gllvmTMB/pull/291), at `6f413cf`) staged but not actioned. A6 itself is blocked behind Phase 56.5 close per Active Plan 2026-05-26.

**Next actions** (per Active Plan 2026-05-26):

- **Codex** owns Phase 56.2 → 56.6 (engine + parser + skeleton activation + cell walks).
- **Shannon**: Rose pre-publish + coord-board sync + after-task cross-reference for each Codex PR as they land (same pattern as #289). Stand by until Codex's 56.2 PR opens.
- **A6** (Shannon + Emmy + Rose) unblocks after Phase 56.5 closes.

## Cross-references

- PR [#289](https://github.com/itchyshin/gllvmTMB/pull/289) — Phase 56.1 dormant TMB promotion (merged at `3133863`).
- PR [#285](https://github.com/itchyshin/gllvmTMB/pull/285) — Phase A scaffold close after-task report (predecessor to this cross-reference).
- PR [#290](https://github.com/itchyshin/gllvmTMB/pull/290) — coord-board Phase 56.1 handoff row (at `f6d6cc6`).
- PR [#291](https://github.com/itchyshin/gllvmTMB/pull/291) — A6 prep memo (at `6f413cf`, staged for later).
- `docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md` — Codex's Phase 56.2 classification.
- `docs/dev-log/after-task/2026-05-26-phase56-1-dormant-tmb-promotion.md` — #289's own after-task (Codex-authored).
- `docs/design/55-structural-slope-grammar.md` — grammar contract.
- `docs/design/56-augmented-lhs-engine-stage3.md` §5.2 + §9.1 + §7 — engine shape, Shannon post-merge role, fail-loud invariant.

---

— Shannon, 2026-05-26
