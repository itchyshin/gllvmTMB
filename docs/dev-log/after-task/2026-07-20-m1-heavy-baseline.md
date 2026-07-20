# After Task: 0.6 M1 Heavy-Baseline Repair

**Branch**: `codex/gllvmtmb-060-m1-baseline-20260720`

**Date**: 2026-07-20

**Status**: IN PROGRESS — this skeleton is the branch-first coordination commit

**Roles (engaged)**: Ada, Shannon, Grace, Emmy, Rose

## 1. Goal

Establish the truthful release baseline for gllvmTMB 0.6 at a freshly fetched
`origin/main`: reproduce and classify every scheduled-heavy failure, reuse only
independently verified repair hunks, restore a green Ubuntu heavy receipt, and
produce a complete release ledger before Design 86 EVA work can begin.

## 2. Implemented

- P0 ownership and clean-lane preflight completed far enough to open this branch.
- The dirty primary checkout and all historical worktrees are quarantined as
  parked prior-session evidence; none is an active writer.
- A clean builder and detached verifier were created at
  `de211f762812c574646938adaca22cbf41c6175e`.
- No test repair, package behavior change, remote compute, or release action is
  included in this branch-first commit.

## 2a. Mathematical Contract

No public R API, likelihood, estimator, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown-navigation change is authorised in M1.
Design 85 remains NO-GO; Design 86 is a separate later macro and has not begun.

## 3. Files Changed

- `docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md`
- `docs/dev-log/recovery-checkpoints/2026-07-20-123822-codex-p0-checkpoint.md`

This inventory will be updated before closeout.

## 3a. Decisions and Rejected Alternatives

- **Decision**: Codex is the only future writer for the five-macro programme;
  historical dirty worktrees are immutable parked state. **Rationale**: no open
  PRs exist, session ownership is Codex, and touching old dirty lanes would risk
  destroying unrelated work. **Rejected**: switching, cleaning, stashing,
  pruning, rebasing, or merging old worktrees. **Confidence**: high.
- **Decision**: start M1 from fresh `origin/main`. **Rejected**: wholesale
  cherry-pick of `0f1ef2bc`, because several profile-related hunks revive
  superseded contracts. **Confidence**: high after independent diff review.

## 4. Checks Run

- `git fetch origin main --prune` — PASS; `origin/main` remained
  `de211f762812c574646938adaca22cbf41c6175e`.
- Builder and detached verifier `git status --short --branch` — PASS; both were
  clean at the same source SHA before this documentation commit.
- GitHub census — PASS for coordination: zero open PRs. Fast R-CMD-check and
  pkgdown are green at current main. Scheduled-heavy evidence is not green or
  current: run `29729444717` failed at `ff045a38` with 46 failures/errors, and
  no heavy rerun covers the 15 later commits now on main.
- Mission Control JSON parse, diff check, scoped commit, and live endpoint —
  PASS; local-only brain-vault commit `44b8764` records P0/M1 active status.

Heavy reproduction and all task-level checks remain pending.

## 5. Tests of the Tests

Pending. Each modified expectation must first fail against the current contract,
then pass after the smallest justified repair. A passing stale test is not proof.

## 6. Consistency Audit

Pending until the repair file set is frozen. Exact `rg` patterns and one-line
verdicts will be recorded here or in `docs/dev-log/check-log.md`.

## 7. Roadmap Tick

N/A at branch start. M1 does not change a public capability or roadmap status.

## 7a. GitHub Issue Ledger

Pending targeted issue census before closeout. No issue was created merely to
represent this execution branch.

## 8. What Did Not Go Smoothly

The primary checkout was 52 commits ahead and 45 behind the observed
`origin/main`, with shared dev-log edits and untracked prior-session material.
The repository also retained 36 worktrees. That prevented an honest claim that
the old estate itself was clean, so P0 distinguishes exclusive future ownership
from immutable historical residue.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the five-macro programme serial and withheld Design 86, compute,
public-feature, tag, submission, and readiness gates.

**Shannon** found that programme ownership did not make the dirty worktree estate
safe. The durable rule is one new writer plus frozen historical lanes, not a
claim that every old checkout is clean.

**Grace** separated routine three-OS/package-site green evidence from the red
Ubuntu scheduled-heavy suite and found that no current-main heavy receipt exists.

**Emmy** reviewed the parked repair branch file-by-file and rejected a wholesale
cherry-pick; only contract-aligned test hunks may be transplanted.

**Rose** requires retained failure provenance, explicit non-claims, and a final
neighbour audit before M1 can close.

## 10. Known Limitations And Next Actions

1. Make this documentation-only branch-first commit.
2. Reproduce the current-main heavy suite locally in the isolated builder.
3. Classify all failures, including the seven not enumerated in the parked
   handover summary.
4. Selectively apply reviewed repair hunks and write failure-before-fix evidence.
5. Run targeted, complete, and scheduled-heavy Ubuntu gates.
6. Build the complete 0.6 release ledger and obtain Rose's adversarial M1 verdict.

M1 is not complete, gllvmTMB 0.6 is not release-ready, and EVA is not an admitted
or public capability.
