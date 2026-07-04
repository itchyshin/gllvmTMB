# Session Handoff: twin code review filed → next, solve the issues

**Meta:** 2026-07-03 · from **Claude** (Claude Code) · TARGET **Claude** · repo `gllvmTMB` (+ sister `GLLVM.jl`)

> You are the next Claude, picking up after a twin code review of **gllvmTMB**
> (R + TMB C++) and its Julia twin **GLLVM.jl**. The review is done and every
> finding is now a GitHub issue. **Your mission (maintainer's explicit
> instruction at handover): start solving ALL the open issues together across
> BOTH packages — the ones this review filed AND the pre-existing ones.**

---

## Mission / why

The maintainer wants a single, coordinated fix campaign that clears the open-issue
backlog on both sister packages, not just the review output. Treat the two
trackers as one workstream because a large share of the review findings are
**twin divergences** — the same statistic implemented differently in R/C++ vs
Julia — so fixing one side implies a decision about the other.

## Critical context (read or you will go wrong)

1. **This session changed NO repository code.** It ran a read-only review and
   filed issues via `gh`. The only repo file it writes is *this handover doc*.
2. **The working tree is dirty with ~351 uncommitted files on branch
   `codex/r-bridge-grouped-dispersion` — that is Codex's in-progress work, NOT
   this session's.** Do **not** revert, stage, or "clean up" those files
   (`CLAUDE.md`: "Do not revert Codex or human changes unless explicitly asked").
   `docs/dev-log/check-log.md` is among the dirty files, so this handover does
   **not** append to it.
3. **Many issues are HIGH-RISK to fix.** Fixes touching formula grammar (the
   4×5 keyword grid), likelihoods, families, or `src/gllvmTMB.cpp` are on the
   `ROADMAP.md` "Discussion Checkpoints" list — **stop for the maintainer before
   merging those.** The twin-parameterization issues (ordinal link, phylo
   variance scale, psi/residual semantics, dispersion granularity) are exactly
   this kind.
4. **48 of the 160 filed issues are `PLAUSIBLE`, not `CONFIRMED`** (labeled as
   such in each body). Re-read the code and confirm before spending fix effort;
   some may be intended behavior.
5. **The structured findings data lived in a session scratchpad that is now
   gone.** The durable source of truth is the **GitHub issues themselves** —
   regenerate any working list with `gh issue list` (commands below).

## What was accomplished this session

- Twin code review of `gllvmTMB` (R + `src/gllvmTMB.cpp`) and `GLLVM.jl` (`src/`).
- 229 raw candidates → 201 deduped → adversarially verified (2-vote on the
  high-value tier, 1-vote on the rest) → **160 filed**, 41 dropped as not-real.
- **Issues filed (one per finding, routed by language):**
  - `itchyshin/gllvmTMB`: **123** issues, **#582–#704**
  - `itchyshin/GLLVM.jl`: **37** issues, **#128–#164**
- Verdict mix filed: **112 CONFIRMED + 48 PLAUSIBLE**. Severity spans bug,
  correctness, robustness, convention, cleanup.

## Current open-issue landscape (your backlog)

| Repo | Open total | From this review | Pre-existing open |
|---|---|---|---|
| itchyshin/gllvmTMB | **151** | ~124 (#582–#704) | **27** (< #582) |
| itchyshin/GLLVM.jl | **61** | ~37 (#128–#164) | **23** (< #128) |
| **Both** | **~212** | ~161 | **~50** |

Highest-value cluster to fix first — the **CONFIRMED twin divergences** (same
math, different implementations; a correctness decision, not a nitpick):
- sign of the phylo log-determinant (sparse Ainv path)
- phylo variance normalized on different scales (R/C++ vs Julia)
- ordinal link: probit (R/C++) vs cumulative-logit (Julia)
- `psi` / residual semantics differ (Julia folds residual into `diag(psi)`)
- Gamma/NB2/Beta dispersion granularity (per-trait vector vs single scalar)
- W-tier reduced-rank term drops cross-trait covariance in Julia but not C++

## Key decisions & rationale

- **One issue per finding, two trackers** (maintainer's choice): R/C++ →
  `gllvmTMB`, Julia → `GLLVM.jl`.
- **Filed all 125 verified + 35 re-verified tail** (maintainer approved "all").
  The 35 tail items had their automated verifiers killed by a usage cap; this
  session re-verified them by reading the code before filing.
- **One finding dropped as a non-defect:** `src/gllvmTMB.cpp:1370` "Q_base
  rebuilt" — that is normal TMB per-evaluation reconstruction, not a bug.

## Files created / modified

- **Created:** `docs/dev-log/handover/2026-07-03-claude-handover.md` (this file).
- **Repo code:** none.
- **External (not in repo, now ephemeral):** 160 GitHub issues on the two
  trackers — the durable artifact.

## Next immediate steps (ordered)

1. **Rehydrate.** Read this doc, then `AGENTS.md` + `CLAUDE.md`, then the newest
   `docs/dev-log/check-log.md` entry (do not edit the dirty tree). Run
   `git status --short --branch` and `git diff --stat` first (repo is
   authoritative).
2. **Regenerate the master issue list** (scratchpad is gone):
   ```sh
   gh issue list --repo itchyshin/gllvmTMB --state open --limit 500 \
     --json number,title,labels,body > /tmp/gtmb_issues.json
   gh issue list --repo itchyshin/GLLVM.jl --state open --limit 500 \
     --json number,title,labels,body > /tmp/gjl_issues.json
   ```
3. **Triage & cluster** all ~212 into fix-batches by theme (twin-divergence /
   extractor-tier gap / profile-refit-drops-structure / dead-code cleanup /
   robustness guards). Rank by leverage: **CONFIRMED bug+correctness twin
   divergences first**, then robustness, then convention/cleanup.
4. **For each twin divergence, decide the canonical side** (which package is
   "right") — this is a **maintainer checkpoint**, not an autonomous call.
   Present the decision matrix before implementing.
5. **Implement by risk tier.** Cleanup/dead-code (e.g. duplicate `%||%`, dead
   `R/parsing.R`, dead `gll_ordered_probability_matrix`) is low-risk and can go
   first as confidence-builders. Grammar/likelihood/family/C++/Julia-numerics
   fixes are HIGH-RISK → maintainer checkpoint before merge, and need the live
   toolchain (see split below).
6. **Honor Definition of Done** (AGENTS.md, 6 items): simulation-recovery test
   for any likelihood/family/keyword change, roxygen + example, check-log entry,
   after-task report, 3-OS CI. Close each issue with the commit/PR that fixes it.

## Claude ↔ Codex split for the fix campaign

- **Codex** runs the live toolchain — real R/TMB + Julia fits, `R CMD check`,
  simulation-recovery tests, rendering. **Every numeric fix** (likelihood, C++,
  Julia families, dispersion, phylo scale) must be validated by Codex.
- **Claude** (you) does the triage/clustering, decides fix ordering, writes the
  canonical-side decision matrices for the maintainer, refactors R-logic and
  prose, and reviews Codex's diffs. The common loop: **plan in Claude → execute
  numerics in Codex → review the diff in Claude.**
- Run **Shannon** before any branch switch or merge-order decision (multiple
  open coordination surfaces: the dirty codex branch + a 212-issue campaign).

## Blockers / open questions (need maintainer)

- **Canonical side per twin divergence** (e.g. ordinal probit vs cumulative-logit
  — which parameterization is the intended contract?). Cannot fix without this.
- **Coordination with the live `codex/r-bridge-grouped-dispersion` branch** (351
  uncommitted files). Is that about to land? Fixes should sequence around it.
- **Bulk issue operations** (labeling, milestone assignment, closing) are
  outward-facing — confirm scope with the maintainer; the auto-approval gate
  blocks un-sanctioned `gh` write batches.

## Gotchas & failed approaches (do not repeat)

- **Do not fan out a huge verify pass with aggressive retries.** This session's
  first harness ran 4× retries × 2 votes over 200+ candidates, hit the
  1000-agent cap and **exhausted the session usage budget** (which resets on a
  clock — hit 11:10am, then 5:10pm). Cap concurrency (≤ a few waves), bound
  retries, single-vote the low-value tier.
- **The usage cap blocks subagents but not local `gh`/Bash** — verification can
  be done in the main loop by reading code when the cap is hit.
- **Filing/altering issues in bulk trips the auto-approval classifier** — get
  explicit maintainer approval for each outward batch.

## ⚠️ Handover commit status — READ

This handover doc is **committed locally** on `codex/r-bridge-grouped-dispersion`
but **deliberately NOT pushed**. At handover the local branch was **96 commits
ahead of `origin`** and carried **~179 uncommitted modified tracked files** — all
Codex's in-progress work. Pushing this branch would publish those 96 unpushed
Codex commits, which is **not this session's call**. **Pushing is the maintainer's
decision.** The commit is safe locally (same machine); if you re-clone into a
fresh tree it will not be present until the maintainer pushes. Do not `git push`
this branch or open a PR from it without the maintainer's say-so; to get only the
doc upstream, cherry-pick this single commit onto a branch cut from
`origin/codex/r-bridge-grouped-dispersion` rather than pushing all 96.

## How to resume

Repo-root, in the maintainer's authenticated terminal:

- **Interactive (recommended — steer the triage):**
  ```sh
  claude "Rehydrate from docs/dev-log/handover/2026-07-03-claude-handover.md + AGENTS.md, then start the fix campaign: triage all open issues on itchyshin/gllvmTMB and itchyshin/GLLVM.jl into ranked fix-batches and present the twin-divergence canonical-side decision matrix before implementing."
  ```
- **Autonomous, clean context (hands-off, capped):**
  ```sh
  claude -p "Rehydrate from docs/dev-log/handover/2026-07-03-claude-handover.md + AGENTS.md, then triage all open issues on both packages into ranked fix-batches; implement only low-risk cleanup issues, and STOP for maintainer on any grammar/likelihood/family/C++ change." --max-budget-usd 10
  ```

## Mission-control summary

| Repo | Branch / CI | What shipped this session | Plan by leverage |
|---|---|---|---|
| itchyshin/gllvmTMB | `codex/r-bridge-grouped-dispersion` (dirty, ~351 files, Codex's) · CI n/a (docs-only) | 123 review issues #582–#704 filed | 1) CONFIRMED twin-divergence correctness fixes (maintainer picks canonical side) → 2) robustness guards → 3) dead-code/cleanup (quick wins) |
| itchyshin/GLLVM.jl | (Julia twin) | 37 review issues #128–#164 filed | Mirror the twin-divergence decisions; align families/links/psi with the chosen canonical side |
| Both | — | 160 issues total (112 CONFIRMED / 48 PLAUSIBLE); ~50 pre-existing open issues remain in scope | ~212 open → cluster, rank, fix by risk tier; Codex runs numerics, Claude plans + reviews |
