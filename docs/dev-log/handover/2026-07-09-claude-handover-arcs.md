# Session Handoff → next Claude (2026-07-09, "CRAN-first ultra-plan" session)

**Meta:** 2026-07-09 · from Claude (Ada) · TARGET = next Claude · context full. This SUPERSEDES the
morning `2026-07-09-claude-handover.md` (that one was the old B_lv coverage-campaign plan, now parked).
This session pivoted to the **CRAN-first ultra-plan** and executed several arcs.

## Goals / mission
**v1.0 = a clean CRAN release of a working, honest, R-only `gllvmTMB`.** Paper, R↔Julia parity, and
the paper-grade coverage campaign are all **post-1.0**. The durable ultra-plan (arc map, compute,
model routing, timeline, issue backlog) lives at **`~/.claude/plans/misty-snacking-papert.md`** —
READ IT FIRST (it is Claude-local, same machine, not in the repo). Arc map:
- **A** release spine & honest surface · **B** cluster2/functional-phylo (rescoped) · **C**
  missing-data · **D** lv/B_lv honest-ship · **E** capability-honesty sweep (~45 issues) · plus the
  open v1.0 issue backlog. Julia/paper/full-coverage = post-1.0.

## Critical context (read or you WILL redo work)
1. **THREE big backlog items turned out ALREADY BUILT this session** — #588 (cluster2 Sigma-table
   extraction), the #723 "27 mixed-family failures" cluster, and the **entire Arc C missing-data
   layer**. **v1.0 is much closer than the plan's timeline estimated.** ⇒ **Before building ANY arc or
   issue, re-verify it isn't already done**: `git log`, run the actual test, check the register. The
   recall-before-scout discipline paid off three times today.
2. **The real remaining v1.0 work is NOT new engine** — it's **Arc E (honest-surface / register
   sweep + real correctness bugs)** and **Arc A (release mechanics)** + the CRAN blockers. Many of
   Arc E's ~45 issues may already be fixed (like #588) — triage each against `main` first.
3. **Functional-phylo / multi-latent capability map is settled + documented** (PR #737, doc 78):
   4 reduced-rank tier slots (`unit`/B, `unit_obs`/W, `cluster`=phylo/animal-only, `spde`);
   `cluster2` is **diagonal-only, hard-rejected in TMB**. Co-location routing rule: **`cluster` keys
   the A/tree; the co-located plain `latent` rides `unit`**. Ordination lives at ONE of {site,
   species}; the other is diagonal. **Guard: `phylo_latent(unique=TRUE)` = structured + DIAGONAL ψ,
   NOT a non-phylo ordination** (that's a *second* `latent` term). See the brain dossier
   `shinichi-brain/projects/gllvm-tmb` (heavily updated today).

## What was accomplished (this session)
- **Approved + saved the CRAN-first ultra-plan** (pivoted from the B_lv coverage campaign).
- **Merged #736** — the scale-free convergence verdict (Arc A prerequisite; `main` @ `882e4c8c`).
- **Arc B DONE → PR #738** (open): functional-phylogeography validated. Real-signal recovery test
  (`test-funcphylo-spatial-recovery.R` + `dev/funcphylo-spatial-recovery.R`, 12/12 converged, spatial
  cosine 0.993, corr-structure 0.000) + `docs/design/78-functional-phylogeography-recipe.md` +
  after-task. **Verified #588 already fixed → closed it.** Spatial-focus recipe (maintainer's framing:
  spatial ordination = focus, phylogeny = diagonal control).
- **#723 CI blocker → PR #739** (open, 1 CI check from green): the 27 mixed-family failures were
  already fixed on `main`; today's nightly was down to 3 STALE-TEST failures — fixed
  (`test-m1-2` fixture 60→240 for the #715 rebuild; `test-phylo-q` migrated 4 `expect_equal(convergence,
  0L)` → `expect_converged()`), plus the `theta_diag_B` warning-flood (`.frequency="once"`) and the
  nightly OS-matrix trim (ubuntu-only nightly, 3-OS on release tags). Local: m1-2 41/0, phylo-q 14/0.
- **Arc C → DISCOVERED ALREADY SHIPPED** on `main` (verified live): missing-response mask
  (`miss_control(response="include")`, `is_y_observed`, TMB-gated) + nested any-distribution missing
  predictors (`mi()`/`miss_control(predictor="model")`, FIML/Laplace) for **Gaussian/binary/ordered/
  categorical/phylo**. Register MIS-21..34 covered; design 59 ACCEPTED; tests pass. Marked done.
- **Multi-latent capability investigation → PR #737** (open): doc + after-task
  (`2026-07-09-multilatent-capability-findings.md`) — Codex-ready record.
- **Brain updated extensively** (v1.0 scope, funcphylo recipe + routing, unique=TRUE guard,
  multi-latent facts, Arc C shipped, the three already-built discoveries).

## Current working state
- **Working:** `main` @ `882e4c8c` (#736 merged). PRs #737/#738/#739 pushed + verified.
- **In progress:** #739's last recovery CI check (merge when green → closes the CI blocker).
- **Not started:** Arc E (honesty sweep + real bugs), Arc A release mechanics, version bump.

## Landing State (git ledger)
| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `claude/converged-verdict` | y | y | #736 **merged** | LANDED (on `main`) |
| `claude/arc-b-funcphylo-validation` | y | y | #738 open | CARRIED-OVER — review/merge (low-risk) |
| `docs/multilatent-capability-findings` | y | y | #737 open | CARRIED-OVER — review/merge (low-risk) |
| `claude/fix-723-mixed-family-extractors` | y | y | #739 open, CI 1-check-from-green | CARRIED-OVER — **merge when green** |
| `docs/handover-2026-07-09-arcs` (this doc) | pending | pending | to open | this handover |
| `claude/blv-coverage-campaign` | y | y | none | PARKED — old plan, superseded (prunable) |
| ~20 `missing-data-*` local branches | y | (local) | — | PARKED — all merged ancestors of `main`, prunable |
| `~/.claude/plans/misty-snacking-papert.md` | Claude-local | n/a | n/a | **the ultra-plan — read it** |

*Why carried over: #737/#738/#739 are low-risk (docs/tests/CI) but left for the maintainer's
merge cadence; #739 additionally waits on its last CI check. Resume: `gh pr merge <n> --merge`.*

## Next immediate steps (ordered)
1. **Merge #739 when green** (`gh pr checks 739`; then `gh pr merge 739 --merge`) → closes the CI
   blocker. Then #738 and #737 (low-risk; agent may merge own or leave for maintainer).
2. **Arc E — the real remaining mountain, but TRIAGE FIRST.** ~45 open issues bucketed in the plan;
   several are likely already fixed (re-verify each vs `main` before touching — the #588 pattern).
   Start with the **7 CRAN blockers**: #483 (NAMESPACE/man regen for `engine=julia`), #484
   (`cran-comments.md`), #485 (NEWS `engine=julia`), #486 (first `--as-cran` punch list), #344/#345
   (release gates), #723 (nearly done via #739). Genuine correctness bugs remain (e.g. #611 phylo
   log-det sign, #612 Ainv marginal-vs-conditional, #593 binomial trials, #614 lognormal median).
3. **Arc A release mechanics** (LAST, after E is honest): register current, lifecycle-mark
   experimental, cran-comments, NEWS, `cran-extrachecks`, **bump 0.2.0→1.0.0**.
4. **Optional frontier (maintainer's call):** FG-18 — `mi()` × the `latent(lv=~x)` score lane +
   non-Gaussian/mixed response masks under `lv`. The one genuine open missing-data edge.
5. **Housekeeping:** prune the ~20 stale `missing-data-*` and the parked `blv-coverage-campaign`
   branches.

## Blockers / open questions (🔴 = needs maintainer)
- 🔴 **Merge #737/#738/#739?** All low-risk; #739 also needs its last CI check green.
- 🔴 **Arc C: done, or pursue FG-18** (`mi()` × `lv`)?
- 🔴 **Version bump to 1.0.0** only after Arc E is honest + all 7 CRAN blockers clear.
- 🟡 Compute: **Totoro live**; DRAC **fir/vulcan** reachable; nibi/rorqual/narval need **Duo MFA**.

## Gotchas & failed approaches (do not retry)
- **Always re-verify "unbuilt" before building** — three already-built discoveries today. `git log`,
  run the test, check the register FIRST.
- **`phylo_latent(unique=TRUE)` ≠ a non-phylo ordination** — it's structured + DIAGONAL ψ. The
  ordination decomposition is two separate `latent` terms. (Semantics guard, banked in the brain.)
- **Heavy tests are slow** (bootstrap/profile refits, minutes each). A subagent handed the heavy
  m1-4 diagnosis **stalled waiting on a monitor** and produced nothing — do heavy R runs yourself
  with a structured failure-capture, or give subagents a tight "run fast mode first" brief.
- **Don't run two `devtools::load_all` R sessions on the same tree concurrently** if a subagent is
  mid-fit (compile/state race) — though `main`'s `.so` is prebuilt so pure R reloads are usually safe.
- **The morning `2026-07-09-claude-handover.md`** describes the OLD B_lv campaign plan — superseded;
  do not resume from it. Use THIS doc + the ultra-plan file.

## Key decisions & rationale
- **CRAN-first, R-only v1.0** (maintainer). Julia/paper/full-coverage-proof post-1.0.
- **cluster2 / functional-phylogeography:** fits TODAY; ordination at one tier, diagonal at the other;
  `cluster2="site"` routing. cluster2 rescoped to validation+docs (done as Arc B), not a new tier.
- **Missing-data (Arc C):** already shipped — the nested any-distribution predictor capability the
  maintainer wanted is built (brms-`mi()`-class).
- Recorded across the brain dossier `shinichi-brain/projects/gllvm-tmb`.

## Mission control
| Item | State |
|---|---|
| Repo | `gllvmTMB` @ `origin/main` = `882e4c8c` (#736 merged) |
| Ultra-plan | `~/.claude/plans/misty-snacking-papert.md` (CRAN-first, 5 arcs + issue backlog) |
| Arc A (release spine) | verdict prerequisite merged; release mechanics + register + 1.0.0 bump remain |
| Arc B (functional-phylo) | **DONE** — PR #738 (recovery-validated + doc 78) |
| Arc C (missing-data) | **DONE** — already shipped on `main` (verified) |
| Arc D (lv/B_lv) | not started (trio built; honest-ship + guarded LR-pivot pending) |
| Arc E (honesty sweep) | not started — the real remaining work; ~45 issues, TRIAGE vs `main` first |
| CI blocker #723 | PR #739, 1 check from green → merge |
| Open PRs | #737 (docs), #738 (Arc B), #739 (#723) — all low-risk |
| Version | DESCRIPTION stays `0.2.0` until Arc E honest + blockers clear |
| Compute | Totoro live; fir/vulcan up; nibi/rorqual/narval need Duo MFA |

## How to resume
1. **Rehydrate:** read this doc → `~/.claude/plans/misty-snacking-papert.md` (the ultra-plan) →
   `CLAUDE.md`/`AGENTS.md` → `~/.claude/memory/memory_summary.md` → the brain dossier
   `shinichi-brain/projects/gllvm-tmb` (today's updates: v1.0 scope, funcphylo recipe, unique=TRUE
   guard, multi-latent facts, Arc C shipped).
2. **Confirm state, don't assume:** `git log --oneline origin/main -3`; `gh pr list`;
   `gh pr checks 739`. Re-verify any "unbuilt" arc/issue against `main` before building (the #588/
   #723/Arc-C pattern).
3. **Spawn Rose** (scope honesty) before any register promotion or public claim.
4. **Claude vs Codex:** Claude plans/refactors/prose + pure-logic; the live heavy R/TMB campaigns +
   `R CMD check` go to Codex (maintainer plans to bring Codex in "in a few days" for volume). Every
   state-changing result must land in a **repo doc** (Codex reads `origin`, not chat/brain).

### One-command resume (paste in your authenticated terminal, from the repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-09-claude-handover-arcs.md + the ultra-plan at ~/.claude/plans/misty-snacking-papert.md. State: v1.0 CRAN-first R-only; Arc B (#738) + Arc C (already shipped) done; #723 CI blocker on PR #739 (merge when green); Arcs A+E remain. THREE backlog items were already-built this session (#588, #723 cluster, Arc C) — always re-verify an issue isn't already fixed before building. Merge #739 when green, then triage Arc E's issues against main and start the CRAN release mechanics. Do NOT auto-merge #737/#738 without my OK."
```
