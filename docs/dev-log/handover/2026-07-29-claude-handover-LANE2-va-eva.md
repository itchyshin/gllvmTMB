# Claude → Claude handover — LANE 2: VA / EVA

**2026-07-29.** You are Claude, opening the variational-approximation lane. A sibling lane
(LANE 1, `…-LANE1-aghq-and-evidence.md`) runs AGHQ/evidence in parallel — read its fence.

---

## 🔴 READ THIS FIRST — do NOT start from scratch

**There are ~90 unmerged commits of VA/EVA work already, across at least twelve branches, from
both platforms.** Starting a clean VA implementation would be the most expensive available mistake
in this repo — the "have we done this before?" miss, at ninety-commit scale, across a Claude/Codex
boundary where neither side's context can see the other's.

| branch | unmerged vs `main` |
|---|---|
| `codex/design87-eva-parity-admission-20260723` | **37** |
| `claude/va-wiring-20260726` | **19** |
| `codex/design100-progress-oracle-20260724` | **15** |
| `claude/design86-eva-contract-20260722` | **13** |
| `claude/va-implementation-20260725` | 3 |
| `claude/va-phase1-proof` | 3 |
| `codex/design102-recovery-envelope-20260724` · `codex/design103-covariance-mechanism-20260724` · `codex/design90-eva-reliability-atlas-20260723` · `claude/va-feasibility-audit` · `claude/va-phase1-record` · `claude/eva-record-consolidation-20260725` | 1 each |

Verified 2026-07-29 via `git rev-list --count origin/main..origin/<branch>`. Several are named
`*-record*`, `*-audit*`, `*-proof*`, `*-atlas*` — those are almost certainly **findings someone
already paid for**. Read before you build.

## Mission control

| | |
|---|---|
| **status** | VA/EVA are **UNREACHABLE BY USERS** — `R/gllvmTMB.R:1426` states *"This version supports `engine = "laplace"` only"* |
| **code** | `R/approximation-engine.R` · `R/eva-proto.R` · `R/va-r3-proto.R` |
| **risk** | **LOW** — nothing you do here can break a shipping user. That is what makes it a good parallel lane |
| **claim state** | mission control records VA as **FROZEN as a comparator**; no capability claim |
| **START HERE** | this doc → the branch inventory above |

## Goal for this lane

Decide what VA/EVA *is* in this package — a live engine, a frozen comparator, or a dead end — and
get the ~90 orphaned commits to a resolved state. **Not** to write more VA code before knowing
what already exists.

## The first arc — inventory, not implementation

Before any code:

1. **Reconcile the twelve branches.** For each: what does it do, does it still apply to current
   `main`, is it superseded, and is it a *finding* (keep the doc) or an *attempt* (may be
   discarded)? Produce a **merge / salvage / discard verdict per branch**, with evidence.
2. **Read the design record.** `docs/design/86-*`, `87-*`, `90-*`, `94-*` and the `design9x`
   family cover EVA contracts, parity admission, and reliability atlases. The project has already
   thought hard about this.
3. **Then, and only then**, decide whether VA/EVA should become reachable (`engine = "va"`), stay
   an internal comparator, or be retired.

## ⚠ Lane-ownership caution — D-88

`codex/design87-eva-parity-admission-20260723` (**37 commits**) is the largest single body of work
in that list and it is **Codex's**. The house rule is that Claude and Codex run **sequentially per
subject**, never concurrently. Before a Claude lane starts rewriting EVA:

* run `tools/lane_preflight.sh` and `tools/session_ownership.sh`;
* establish whether that Codex lane is **dormant or paused**, not merely quiet — *silence is never
  proof of sole ownership*;
* if it is live, **surface it to Shinichi — ownership is his call, not an agent's.**

## What LANE 1 owns — do not edit

`R/profile-ci.R` · `R/coverage-study.R` · `R/confint-inspect.R` · `R/z-confint-gllvmTMB.R` ·
`R/aghq-control.R` · `R/aghq-report.R` · `R/imports.R` · `NAMESPACE` · `NEWS.md` ·
`R/fit-multi.R` and `R/gllvmTMB.R` (shared — **coordinate before editing**) ·
`tests/testthat/test-{profile-*,coverage-study-nonfinite,aghq-control-wiring,gaussian-link-guard}.R`

Reading is fine. **Do not run `devtools::document()`** — it rewrites `NAMESPACE`, which LANE 1 owns.

## A defect that IS yours

`tests/testthat/test-eva-gate1.R` **fails under `R CMD check`** — it reads
`docs/design/86-eva-gate1-parameters.json`, and `.Rbuildignore:18` contains `^docs$`, so the file
is absent from the installed tarball. It passes under `devtools::test()` because `load_all()` has
the source tree. **Tests must not depend on files outside the tarball.** Real packaging defect,
7 failures, in this lane's file.

## Context you inherit from LANE 1 — relevant, verified

* **AGHQ merged** (PR #801) but its capability claim is **WITHHELD**. It is not the settled
  alternative to VA that its presence on `main` might suggest.
* A **432,000-fit campaign** established that the AGHQ "stall" is a property of the likelihood in
  a regime, not a bug — and that **family dominates**: binomial **0.0000** stall rate in 144,000
  fits, poisson 0.7401, gaussian 0.8956. If VA is being positioned against AGHQ, that asymmetry is
  the most useful known fact.
* **Nothing in gllvmTMB has certified interval coverage.** Do not let a VA arc imply otherwise.
* `docs/dev-log/2026-07-29-flat-regime-campaign-results.md` has the full numbers.

## House rules

* Own worktree + own branch; **never `git add -A`**; scoped staging only.
* Tests ship with implementation; write the failing test first.
* Local `devtools::test()` **and `rcmdcheck`** before pushing — `load_all()` cannot catch namespace
  or packaging defects, which is exactly how the `.onLoad` bug and the `docs/` dependency survived.
* Reader surfaces carry **no internal register codes**.
* **Never push twice in quick succession** — GitHub auto-cancels the in-flight run.
* Totoro is idle and available; cap **150 cores**; results stay **LOCAL (D-50)**.

## Gotchas paid for in blood (inherited)

* **Check the PRIMARY source, not the summary citing it.**
* **An agent's confident `file:line` is not evidence** — five agent claims failed verification in
  one session.
* **`devtools::test()` cannot catch namespace defects** — 7,872 green tests while the installed
  package could not load.

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git worktree add /private/tmp/gllvmtmb-va -b claude/va-consolidation-20260729 origin/main
```

One-command resume, from the repo root, in your own authenticated terminal:

```
claude "Rehydrate from docs/dev-log/handover/2026-07-29-claude-handover-LANE2-va-eva.md. Do NOT write VA code yet. First reconcile the ~90 unmerged commits across the twelve VA/EVA branches listed there and give me a merge/salvage/discard verdict per branch, then check whether the Codex design87 lane is dormant before claiming the subject."
```
