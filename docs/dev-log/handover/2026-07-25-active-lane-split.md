# Active-lane split — 2026-07-25

This coordination note prevents a new session from treating this repository as
a single writable lane.  It is a map, not a release/capability claim.

| Lane | Owner | State | Start here | Boundary |
| --- | --- | --- | --- | --- |
| 0.6 release / M5 | Claude | separate committed/pushed release worktree | `2026-07-23-codex-handover.md` | reword/RC ceremony only; no CRAN submission or final tag without Shinichi |
| Profile / Tier-2a | Claude | dirty primary checkout on `claude/profile-coverage-remeasure-20260718` | `2026-07-25-claude-handover.md` | do not overwrite its uncommitted files from another checkout |
| Eta simulation | Codex | **left in Codex** at `/private/tmp/gllvmtmb-design100-progress-oracle` on `codex/design100-progress-oracle-20260724` | Codex's local Design-100 materials | Claude must not run, edit, claim, or absorb this lane |
| Design-103 private diagnosis | Codex | closed `TECHNICAL_PARTIAL`, local-only | `/private/tmp/gllvmtmb-design103-covariance-mechanism/dev/design103-covariance-mechanism/ADJUDICATION.md` | no package/public claim; new model design needs fresh approval |
| Docs-infra / phylo-column question | Claude | pkgdown repaired and MERGED (`a900c4ae`, PR #787); CI economy open as PR #788 | `2026-07-25-claude-handover-phylo-column.md` | docs/CI only — no package source or API change; the M3 freeze (`NAMESPACE c97ae039`) stays untouched |
| **Site × Species phylo capability + peer evidence** | Claude | **CLOSED 2026-07-25.** Capability **CANCELLED** by Shinichi on evidence — no new API, `NAMESPACE c97ae039` untouched. Bug fixes + first gllvm fit-level comparators landed on `main` `a0f568d1..84ca8290`. D-43 panel **3/3 NOT-DONE**; **nothing promoted**. | `2026-07-25-claude-handover-arc-closed.md` | do not re-open the capability without a new maintainer decision; do not re-cite the retired s9 / s10 figures (see that doc's Corrections table) |

Before any repository mutation, re-check `git worktree list`, `git status -sb`
in the intended worktree, and the target lane's named handover.  The active
checkout is not a safe generic workspace.

**Milestone state is NOT in this note and must be re-derived from git.** This map
records *ownership*, not progress. On 2026-07-25 a fresh session rehydrated from a
Mission Control board that still read "M4 UNDERWAY / draft PR #780" and planned
against a six-day-old picture — including a proposal to audit and cut the public
surface, which would have reopened M3's signed API freeze. It was withdrawn only
after `git` was consulted. Verified that day: M1 · M3 · M4 all CLOSED, PR #780
merged 2026-07-23, RC.1 frozen, the RC.1 review 3/3 NOT-READY with submission
WITHHELD, and the RC.2 non-CRAN closeout recorded. The rung remains **NOT READY**.

**Standing interest (Shinichi, 2026-07-25):** *"I am still interested in EVA stuff too — please remember."* EVA is **cut from 0.6 to 0.7** and **Codex-owned** (`design90`–`design98` + the eta lane); Design 85 is negative evidence and READ-ONLY, Design 86 is design-only. Picking it up is a **lane reassignment + Gate-0 scope freeze decision**, not agent initiative. Keep it on the menu; raise it with him.

**Next arc is UNCHOSEN** — Shinichi ruled out CRAN and the paper for now and reserved the choice. Ask.
