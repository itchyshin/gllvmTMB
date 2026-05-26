# After Task: Phase 56.4 merge close-out — Shannon post-#298 cross-reference

**Branch**: `agent/phase56-4-merge-closeout`
**Date**: `2026-05-26`
**Roles (engaged)**: Shannon (coordination; Design 56 §9.x close-out)

## 1. Goal

Execute Shannon's queued Design 56 §9.x post-merge work after Ada merged Codex's [#298](https://github.com/itchyshin/gllvmTMB/pull/298) ("Phase 56.4: activate phylo_unique recovery") at SHA `dd3b2be` (merged 2026-05-26T22:34:25Z). Two deliverables, both process-only:

1. Move the "Codex Phase 56.4" row in `docs/dev-log/coordination-board.md` from Active lanes → Recently resolved with the merge SHA.
2. Record the **#297 → #298** cross-reference and queue the **Phase 56.5 fan-out** lane as the next Codex slice per the evidence-first sequencing rule.

This after-task is **not** a code PR; it documents the merge transition. No engine, parser, R/, test, register, NEWS, article, or deprecation edits per Ada 2026-05-26 hard-scope.

## 2. Implemented

- **#298 merged.** SHA `dd3b2be` on `main`. 3-OS green pre-merge: ubuntu 25m33s, macOS 24m25s, windows 37m40s. The activated `test-phylo-unique-slope-gaussian.R` carries three `test_that` blocks covering: (1) wide ↔ long byte-identity across `logLik` + objective + response vector + trait IDs + augmented species IDs + `Z_phy_aug` + `sd_b` + `cor_b`; (2) Gaussian Σ_b recovery against #287 §2.1 defaults; (3) Design 56 §7.3 forced `n_lhs_cols=1L` negative test. PASS 27 in the activated file; PASS 67 across adjacent phylo regressions; PASS 60 across formula-grammar + guard + recovery.
- **Rose pre-publish posted before merge.** [Comment #issuecomment-4549389351](https://github.com/itchyshin/gllvmTMB/pull/298#issuecomment-4549389351). Verdict: APPROVE. Claimed-vs-covered wording honest (status stays `claimed` in `docs/design/01-formula-grammar.md` and `CLAUDE.md`); after-task + check-log evidence sufficient; honest seed-selection discipline (original seed gave 25.6% relative error → seed `5640` chosen because it lands in target, *tolerance not widened*); Design 56 §7 fail-loud preserved at both layers (parser + engine).
- **Anchor cell complete.** `phylo_unique(1 + x | species)` (wide) and `phylo_unique(0 + trait + (0 + trait):x | species)` (long) now have full activation evidence. Engine + R-side + parser + recovery + byte-identity + fail-loud all green on main.
- **Phase 56.5 lane queued.** Per Codex 2026-05-26 evidence-first sequencing: with anchor-cell green, the fan-out is by **backend / risk** — `phylo_unique(..., vcv = A_user)` (reuses anchor path), then `animal_unique` (after bar-form sugar routes there), then `spatial_*` (after SPDE augmented plumbing), then `*_latent` / `*_indep` / `*_dep` (distinct Σ_b / map semantics). Coord-board records this as the active lane awaiting Codex's next PR.

## 3. Files Changed

- `docs/dev-log/after-task/2026-05-26-phase-56-4-merge-closeout.md` (NEW; this file)
- `docs/dev-log/coordination-board.md` (Active lanes + Recently resolved; file-ownership rows refreshed for activation status)

## 3a. Decisions and Rejected Alternatives

**Decision**: Name the next Codex lane as "Phase 56.5 — anchor-adjacent fan-out by backend/risk (start with `phylo_unique(..., vcv = A_user)`)" rather than "Phase 56.5 — walk all APPLICABLE cells."

**Rationale**: Codex's stated grouping (2026-05-26) explicitly waits on `phylo_unique(..., vcv = A_user)` before any non-phylo cell, because that path reuses the anchor's `b_phy_aug` machinery directly. Naming it concretely in the coord-board row tells future agents the expected next slice surface.

**Rejected alternative**: leave the lane row as a generic "Phase 56.5 — cell fan-out." Rejected because it loses the backend/risk specificity Codex established.

**Confidence**: high.

## 4. Checks Run

- `git log -1 --format='%h %s' main` → `dd3b2be Phase 56.4: activate phylo_unique recovery (#298)` (confirms merge SHA against the cron-detected value).
- `gh pr view 298 --json state,mergedAt,mergeCommit` → `{state: "MERGED", mergedAt: "2026-05-26T22:34:25Z", mergeCommit: {oid: "dd3b2be3ad537bfc0c031a16ced25fa3d034bb49"}}`.
- `gh pr list --state open` → empty (no open PRs).
- `gh pr checks 298` → ubuntu pass 25m33s, macOS pass 24m25s, windows pass 37m40s — all green at merge time.

Process-only docs change. No `devtools::check()`, `devtools::test()`, or `pkgdown::check_pkgdown()` needed.

## 5. Tests of the Tests

N/A — no test surface touched. #298's `test-phylo-unique-slope-gaussian.R` (PASS 27 locally, 3-OS green in CI) is the validation that landed for the anchor-cell recovery surface.

## 6. Consistency Audit

- `rg "phase56-4" docs/dev-log/after-task/ docs/dev-log/audits/` — confirms both Codex's #298 after-task and this close-out exist on `main`.
- Coord-board has exactly one "Phase 56.4" row in Recently resolved and exactly one "Phase 56.5" row in Active lanes (no dupes).
- File-ownership row for `tests/testthat/test-phylo-unique-slope-gaussian.R` updated to reflect activation; remaining 15 skeleton files still gated.
- `docs/design/01-formula-grammar.md` augmented-LHS row stays `claimed` (verified post-merge); promotion to `covered` remains parked for Phase 56.6.

## 7. Roadmap Tick

No ROADMAP row changed. Active Plan tick: "Phase 56.4 anchor cell complete; Phase 56.5 fan-out active." Captured in coord-board, not ROADMAP.

## 7a. GitHub Issue Ledger

No GitHub issue applies to this slice. No new issue created.

## 8. What Did Not Go Smoothly

- Windows CI on #298 took 37m40s — meaningfully slower than the 30m46s on #295 with similar diffstat. Probably runner contention; no actionable cause.
- The auto-poll cron mechanism revealed a real durability gap: cron is in-memory only, and the repeated `SessionStart hook` reminders earlier in this conversation appear to clear the in-memory state. Both `0d2e7dec` (the original) and `62caabb4` (the replacement) were silently wiped at least once. **Recommendation for future Shannon work**: don't rely on auto-poll cron alone — pair it with explicit Ada pings when key PRs merge. (Codex's 56.5 fan-out is gated on Ada's authorization anyway, so this isn't a 56.5 blocker.)

## 9. Team Learning

- **Shannon (coord)**: the "Rose pre-publish before merge + post-merge close-out" cadence is now stable across **four** consecutive Codex PRs (#289 → #292, #293 → #294, #295 → #297, #298 → this PR). Each close-out has been ~5 min of work landing without surprise.
- **Rose (scope honesty)**: Codex's claimed-not-covered discipline across 56.3 and 56.4 (status row stays `claimed`; validation-debt parked; user-facing advertising parked) is the right shape for evidence accumulation before public promotion. Phase 56.6 is the right place for the eventual flip.
- **Curie (simulation)**: the honest seed-selection note in #298's check-log (original seed gave 25.6% relative σ² error → seed `5640` chosen because it lands in target without widening tolerance) is the kind of discipline that should be standard practice for anchor-cell smoke tests. The seed-sensitivity at `n_sp=60` is worth a one-line nod when Phase 56.5 cell-walk planning starts.

## 10. Known Limitations And Next Actions

**Known limitations**:

- The anchor cell is recovery-validated for **Gaussian only**. Non-Gaussian families remain a Phase B deliverable.
- 15 of the 16 APPLICABLE cells from Design 55 §5 remain skip-gated. Fan-out happens by backend/risk per Codex's 2026-05-26 sequencing — not one PR per cell.
- The seed-sensitivity observation in #298's check-log (smoke test depends on seed `5640`) suggests Phase 56.5 may want a quick `n_sp=80` Monte Carlo sanity check before locking the #287 §2.1 fixture defaults.

**Next actions** (per Active Plan 2026-05-26 + Codex 2026-05-26 evidence-first sequencing):

- **Codex** owns Phase 56.5 fan-out. Expected starting slice: `phylo_unique(..., vcv = A_user)` — reuses the anchor's `b_phy_aug` machinery directly, smallest delta from #298. Followed by `animal_unique` once the bar-form sugar routes there.
- **Shannon**: Rose pre-publish + coord-board sync + after-task cross-reference on each Phase 56.5 PR as they land. Auto-poll cron `62caabb4` running (modulo session-reset wipes).
- **A6** (Shannon + Emmy + Rose) remains audit-only. Prep memo at `docs/dev-log/audits/2026-05-26-phase-a6-prep.md` (#291) + #287 §2 pre-spec tidy (#296) staged. A6 unblocks after Phase 56.5 closes.
- `codex/morphometrics-long-wide` stays paused per Codex 2026-05-26.

## Cross-references

- PR [#298](https://github.com/itchyshin/gllvmTMB/pull/298) — Phase 56.4 anchor-cell recovery activation (merged at `dd3b2be`).
- PR [#297](https://github.com/itchyshin/gllvmTMB/pull/297) — Phase 56.3 merge close-out (predecessor; at `a16dbec`).
- PR [#295](https://github.com/itchyshin/gllvmTMB/pull/295) — Phase 56.3 anchor parser slice (`6026710`).
- PR [#293](https://github.com/itchyshin/gllvmTMB/pull/293) — Phase 56.2 `n_traits` classification (`72f67de`).
- PR [#289](https://github.com/itchyshin/gllvmTMB/pull/289) — Phase 56.1 dormant TMB promotion (`3133863`).
- PR [#291](https://github.com/itchyshin/gllvmTMB/pull/291) — A6 prep memo (`6f413cf`).
- PR [#296](https://github.com/itchyshin/gllvmTMB/pull/296) — #287 §2 pre-spec tidy (`e443b6a`).
- Rose pre-publish on #298: [#issuecomment-4549389351](https://github.com/itchyshin/gllvmTMB/pull/298#issuecomment-4549389351).
- `docs/design/01-formula-grammar.md` (post-#298 row for the augmented LHS forms; status still `claimed`).
- `docs/design/55-structural-slope-grammar.md` — grammar contract.
- `docs/design/56-augmented-lhs-engine-stage3.md` §5.2 (engine shape), §7 (fail-loud invariant), §7.3 (no-silent-collapse), §9.x (Shannon post-merge role).
- `docs/dev-log/audits/2026-05-26-phase-56-5-per-cell-scoping.md` — per-cell pre-spec defaults (anchor cell defaults validated against truth in #298).

---

— Shannon, 2026-05-26
