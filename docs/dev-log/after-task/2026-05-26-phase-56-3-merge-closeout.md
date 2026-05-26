# After Task: Phase 56.3 merge close-out — Shannon post-#295 cross-reference

**Branch**: `agent/phase56-3-merge-closeout`
**Date**: `2026-05-26`
**Roles (engaged)**: Shannon (coordination; Design 56 §9.x close-out)

## 1. Goal

Execute Shannon's queued Design 56 §9.x post-merge work after Ada merged Codex's [#295](https://github.com/itchyshin/gllvmTMB/pull/295) ("Phase 56.3: wire phylo_unique augmented parser") at SHA `6026710` (merged 2026-05-26T19:58:34Z). Two deliverables, both process-only:

1. Move the "Codex Phase 56.3" row in `docs/dev-log/coordination-board.md` from Active lanes → Recently resolved with the merge SHA.
2. Record the **#294 → #295** cross-reference and capture the Phase 56.4 lane that becomes active per Codex's 2026-05-26 evidence-first sequencing answer.

This after-task is **not** a code PR; it documents the merge transition. No engine, parser, R/, test, register, NEWS, article, or deprecation edits per Ada 2026-05-26 hard-scope.

## 2. Implemented

- **#295 merged.** SHA `6026710` on `main`. 3-OS green pre-merge (ubuntu 26m19s, macOS 23m28s, windows 30m46s). Parser surface for `phylo_unique(1 + x | species)` (wide) and `phylo_unique(0 + trait + (0 + trait):x | species)` (long) now routes to the augmented phylo path with two-column `Z_phy_aug` (intercept + slope) and `n_lhs_cols = 2L`. Status recorded as **`claimed`** (not `covered`) in `docs/design/01-formula-grammar.md`. Validation-debt rows untouched.
- **Rose pre-publish posted before merge.** [Comment #issuecomment-4547768272](https://github.com/itchyshin/gllvmTMB/pull/295#issuecomment-4547768272). Verdict: APPROVE; Design 56 §7 fail-loud preserved (double-guard at parser + R-side wiring with rich `cli::cli_abort` messages); wide↔long Z parity established at the matrix-construction level (test 4 in `test-phase56-3-phylo-unique-parser.R`); legacy `phylo_unique(0 + trait | species)` preserved (test 2).
- **Codex sequencing now anchored.** Per Codex's 2026-05-26 coordination answers (recorded in #287 via PR #296 and re-summarized below): #295 is the **anchor slice**, not the whole 16-cell rollout; Phase 56.4 next activates the same `phylo_unique` recovery cell (wide/long byte-identity + Gaussian recovery + forced `n_lhs_cols` mismatch negative test); fan-out groups by **backend / risk** after anchor green (`phylo_unique(..., vcv = A_user)` → `animal_unique` → `spatial_*` → `*_latent` / `*_indep` / `*_dep`), **not** one PR per cell.
- **Coord-board synced.** Codex Phase 56.3 row moved out of Active lanes; new Codex Phase 56.4 row in. Recently resolved gained the #295 entry.

## 3. Files Changed

- `docs/dev-log/after-task/2026-05-26-phase-56-3-merge-closeout.md` (NEW; this file)
- `docs/dev-log/coordination-board.md` (Active lanes + Recently resolved; file-ownership rows refreshed)

## 3a. Decisions and Rejected Alternatives

**Decision**: In the new Active lane row, name the next Codex lane as "Phase 56.4 — `phylo_unique` recovery test activation (anchor cell)" rather than a generic "Phase 56.4 — skeleton activation."

**Rationale**: Codex explicitly framed 56.4 as anchor-cell evidence-first work, not the broader "remove all `skip_until_stage3()` gates" pass. The 15 other skeleton files remain skip-gated until their respective backend lands in the fan-out grouping.

**Rejected alternative**: bundle "Phase 56.4 = all 16-cell activation" into the row. Rejected because it misrepresents Codex's stated sequencing and would mis-cue future agents.

**Confidence**: high.

## 4. Checks Run

- `git log -1 --format='%h %s' main` → `6026710 Phase 56.3: wire phylo_unique augmented parser (#295)` (confirms merge SHA against the recorded value).
- `gh pr view 295 --json state,mergedAt,mergeCommit` → `{state: "MERGED", mergedAt: "2026-05-26T19:58:34Z", mergeCommit: {oid: "602671020e4fd479a53a675c42f9c7c4db6a28f6"}}`.
- `gh pr list --state open` → empty (no open PRs).

Process-only docs change. No `devtools::check()`, `devtools::test()`, or `pkgdown::check_pkgdown()` needed.

## 5. Tests of the Tests

N/A — no test surface touched. #295's regression test `test-phase56-3-phylo-unique-parser.R` (PASS 25 locally, 3-OS green in CI) is the validation that landed for the parser surface.

## 6. Consistency Audit

- `rg "phase56-3" docs/dev-log/after-task/ docs/dev-log/audits/` — confirms both Codex's #295 after-task and this close-out exist on `main`.
- Coord-board has exactly one "Phase 56.3" row in Recently resolved and exactly one "Phase 56.4" row in Active lanes (no dupes).
- File-ownership row for `R/brms-sugar.R` and `R/parse-multi-formula.R` now points at the merged 56.3 state, with 56.4 onward queued for next Codex branch.

## 7. Roadmap Tick

No ROADMAP row changed. Active Plan tick: "Phase 56.3 complete; Phase 56.4 active (anchor cell recovery)." Captured in coord-board, not ROADMAP.

## 7a. GitHub Issue Ledger

No GitHub issue applies to this slice. No new issue created.

## 8. What Did Not Go Smoothly

- #295's CI took two attempts on the same content — earlier in the day a run was in progress, then a fresh run kicked off (different run ID). Both eventually passed; no functional issue, just CI noise that briefly cleared the watcher backlog.
- One transient note: the `pr-289-review` / `pr-295-review` local-branch pattern for Rose pre-publish was clean but required manual cleanup each time. For future Codex PRs Shannon could script this as a small helper; deferred as a process improvement, not a current blocker.

## 9. Team Learning

- **Shannon (coord)**: the "Rose pre-publish before merge + after-task cross-reference after merge" cadence is now stable across three Codex PRs (#289 → #292, #293 → #294, #295 → this PR). The post-merge close-out is consistently ~5 min of work and lands without CI surprise. Pattern proven.
- **Rose (scope honesty)**: Codex's "claimed not covered" discipline in `docs/design/01-formula-grammar.md` + the explicit `CLAUDE.md` note ("Do not advertise it as covered until the Phase 56.4 recovery and validation-debt evidence lands") is the right shape for parser PRs that ship before recovery evidence. Worth standardizing as a precedent.

## 10. Known Limitations And Next Actions

**Known limitations**:

- The augmented `phylo_unique` LHS is parser-claimed but recovery-unvalidated. Phase 56.4 lands the byte-identity and recovery evidence.
- 15 of the 16 APPLICABLE cells remain skip-gated in `test-{phylo,animal,spatial,relmat}-{latent,unique,indep,dep}-slope-gaussian.R`. Fan-out happens after anchor cell green per Codex 2026-05-26 sequencing.

**Next actions** (per Active Plan 2026-05-26 + Codex 2026-05-26 coordination answers):

- **Codex** owns Phase 56.4: `phylo_unique(1 + x | species)` recovery test activation — wide/long byte-identity + Gaussian recovery + forced `n_lhs_cols` mismatch negative test. Expected within hours of #295 merge per Codex.
- **Shannon**: Rose pre-publish + coord-board sync + after-task cross-reference for the 56.4 PR when it lands (same pattern as #289 / #293 / #295). Auto-poll cron `0d2e7dec` running every 10 min for hands-free pickup.
- **A6** (Shannon + Emmy + Rose) remains audit-only. Prep memo at `docs/dev-log/audits/2026-05-26-phase-a6-prep.md` (#291) staged. A6 itself unblocks after Phase 56.5 closes.
- `codex/morphometrics-long-wide` stays paused per Codex 2026-05-26 — no Phase 56 reactivation.

## Cross-references

- PR [#295](https://github.com/itchyshin/gllvmTMB/pull/295) — Phase 56.3 anchor parser slice (merged at `6026710`).
- PR [#294](https://github.com/itchyshin/gllvmTMB/pull/294) — Phase 56.2 merge close-out (predecessor; at `1108d3b`).
- PR [#293](https://github.com/itchyshin/gllvmTMB/pull/293) — Phase 56.2 `n_traits` classification (`72f67de`).
- PR [#292](https://github.com/itchyshin/gllvmTMB/pull/292) — Phase 56.1 merge close-out (`e4d67aa`).
- PR [#296](https://github.com/itchyshin/gllvmTMB/pull/296) — #287 audit tidy with Codex sequencing cross-refs (`e443b6a`).
- Rose pre-publish on #295: [#issuecomment-4547768272](https://github.com/itchyshin/gllvmTMB/pull/295#issuecomment-4547768272).
- `docs/design/01-formula-grammar.md` (post-#295 row for the augmented LHS forms, marked `claimed`).
- `docs/design/55-structural-slope-grammar.md` — grammar contract.
- `docs/design/56-augmented-lhs-engine-stage3.md` §5.2 (engine shape), §7 (fail-loud invariant), §9.x (Shannon post-merge role).
- `docs/dev-log/audits/2026-05-26-phase-56-5-per-cell-scoping.md` — per-cell pre-spec defaults (now with §2 prologue from #296).

---

— Shannon, 2026-05-26
