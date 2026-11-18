# After Task: Design 125 G4c fork B + D-159 citation + Poisson W REPLACE sync

**Branch**: `cursor/mspl-forkB-decision`
**Date**: `2026-08-18`
**Roles (engaged)**: Ada / Rose / Shannon
**Workspace**: `/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-forkB-decision`

## 1. Goal

Record the 2026-08-18 G0 **g0_unlock** on the Design 125 docs surface:
profile fork **B**, vault number **D-159** where MSPL-interval cites said
D-148, and Poisson \(W\) **PARK → REPLACE** in Design 125 / ADEMP. No
`R/` / `src/` (L0 is a sibling lane). No public `se`.

## 2. Implemented

| Item | State |
|---|---|
| G4c | **SIGNED fork B** — unpenalized Laplace at fixed MSPL nuisance; A = ablation only |
| Vault number | Live Design 125 / ADEMP / Design 118 MSPL-interval cites now say **D-159**. **D-148** remains never-ask-bare. **D-149** unchanged |
| Poisson \(W\) | Design 125 / ADEMP current-state wording is **SIGNED REPLACE** (#1111), not PARK |
| Public doors | Still closed. #1077 still draft. `MSPL-04` still `blocked` |
| Code | Untouched |

## 3. Files Changed

- `docs/dev-log/decisions.md` (2026-08-18 G4c entry + D-159 + REPLACE sync)
- `docs/design/125-mspl-profile-led-intervals.md`
- `docs/design/118-mspl-interval-calibration-protocol.md` (numbering note only)
- `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`
- `docs/dev-log/research/2026-08-17-mspl-profile-led-r1-lessons.md`
- `docs/dev-log/research/2026-08-17-mspl-profile-led-ci-ultra-plan.md`
- `docs/dev-log/research/2026-08-17-mspl-profile-bootstrap-ci-next.md`
- `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md`
- `docs/dev-log/research/2026-08-16-mspl-se-from-papers.md`
- `docs/dev-log/handover/2026-08-17-cursor-handover-mspl-se-ci.md` (D-148→D-159)
- `LOOP/decision-queue.md` (G4c FORK-B; G1 REPLACE)
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-18-mspl-design-125-g4c-fork-B.md` (this file)

Not touched: `R/`, `src/`, `NEWS.md`, `README.md`, `_pkgdown.yml`,
register, #1077.

## 3a. Decisions and Rejected Alternatives

- **Decision:** fork B, A = ablation. **Rationale:** Shinichi G0
  `g0_unlock`. **Rejected:** leaving G4c FORK-DEFER; treating #1090's
  penalised probe as the signature path. **Confidence:** high.
- **Decision:** rewrite D-148 → D-159 only where the cite meant
  MSPL-interval withhold. **Rationale:** vault renumber 2026-08-18;
  D-148 is never-ask-bare. **Rejected:** rewriting draft-reply D-148
  cites; rewriting every historical handover. **Confidence:** high.
- **Decision:** PARK → REPLACE in Design 125 / ADEMP current-state
  sentences only. **Rationale:** #1111 already on `main`. **Rejected:**
  rewriting 2026-08-17 after-tasks that correctly recorded PARK as
  then-signed. **Confidence:** high.

## 4. Checks Run

```sh
rg -n 'G4c|fork B|SIGNED REPLACE' \
  docs/design/125-mspl-profile-led-intervals.md \
  docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md
rg -n 'D-148|D-159' \
  docs/design/125-mspl-profile-led-intervals.md \
  docs/design/118-mspl-interval-calibration-protocol.md \
  docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md
# leftover D-148 in those three = numbering-note / never-ask-bare disambiguation
# deliberately not run: R CMD check, undraft #1077, public se, Totoro
```

## 5. Tests of the Tests

N/A — docs-only; no test files.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `G4c FORK-DEFER` as **current** state in Design 125 / ADEMP | should be absent as current; historical 2026-08-17 row may remain labelled historical |
| `SIGNED PARK SE doors` as **current** Poisson W in Design 125 / ADEMP | should be absent; REPLACE + #1111 present |
| `D-148` as the MSPL-interval withhold in Design 125 / ADEMP / Design 118 | should be D-159; leftover D-148 only names the collision |
| `R/` `src/` in this PR | empty |

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row. Interval programme stays fenced.

## 7a. GitHub Issue Ledger

No relevant open issue for this docs ledger sync; no new issue created.
#1077 stays draft (not this PR). #1111 already merged.

## 8. What Did Not Go Smoothly

**Two agents were dispatched on this same G0 and wrote into the same
worktree concurrently.** An Opus lane created
`~/local-scratch/lanes/gllvmTMB-mspl-forkB-decision` and began editing
`decisions.md` and Design 125; a Grok accelerator, believing that lane had
stalled after its 118-second preflight, adopted the same worktree and edited
the same files minutes later. It had **not** stalled. The overlap produced one
real defect — a duplicated *"2026-08-18 sync"* paragraph in the Design 125
header, both writers having added the same amendment note — which was
consolidated into a single block before commit. The two versions did not
otherwise contradict each other, so nothing had to be discarded on the merits;
this was luck, not process. **Lesson:** a worktree is the lane boundary (D-146),
so adopting another agent's worktree defeats the mechanism that is supposed to
keep lanes apart. The correct move on finding a live worktree is a new one, or a
handoff — never a silent co-write. Surfaced to the maintainer per D-87/D-88
rather than resolved unilaterally.

Separately: several stale branches (`claude/lane-mspl-profile-led-ci`,
`claude/mspl-interval-computable-pin`) still carry Design 125 wording that walks
Poisson \(W\) *backwards* to **UNSIGNED / operational PARK**. That reading is
refuted by `main` (#1102 signed REPLACE; #1111 landed the tape), and those
branches have no open PR. They were **not** merged in, and they should not
re-land that wording over this sync.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** The unlock is the fork pick plus two ledger corrections, not a
public-interval ship. L0 owns code.

**Rose.** D-148 collision is the same class as other vault-number
duplicates: the first heading wins, so the live MSPL docs were pointing
at the wrong rule. Fix the live cites; leave draft-reply D-148 alone.

**Shannon.** Named lane `cursor/mspl-forkB-decision`. Did not touch `R/` or
`src/` — the L0 plumbing arm is a separate lane. `LOOP/decision-queue.md` **is**
in this PR, because that file is where the G4c gate state is recorded and
leaving it reading `FORK-DEFER` would have contradicted every other surface;
`LOOP/GOAL.md` and `LOOP/checkpoint.md` were deliberately left alone, as
[#1124](https://github.com/itchyshin/gllvmTMB/pull/1124) owns those two. Six
open PRs also touch `docs/dev-log/check-log.md`, so a textual conflict there is
expected for whichever merges second.

## 10. Known Limitations And Next Actions

- L0 implements the internal fork-B path; this PR does not.
- #1077 stays draft. Public `se` / `vcov` / `confint` stay refused.
- Historical handovers that said PARK or D-148 on 2026-08-17 remain as
  then-true records.
- Totoro / T\* / MSPL-04 still need later G0s.
