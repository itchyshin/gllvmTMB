# Session Handoff → next Claude: v1.0.0 is release-ready — the task is the one-by-one pkgdown + function-docs review WITH Shinichi

**Meta:** 2026-07-10 · from Claude (Ada/Fable) · fresh-session recommended · **TARGET = the next Claude.**

You are the next Claude. gllvmTMB is **1.0.0 on `main`, cross-OS verified, but NOT submitted to CRAN.**
Your job is the one thing that has NOT been done: **sit with Shinichi and walk every rendered pkgdown
page and every exported function's docs, one by one.** Automated audits happened; a human review did not.

---

## Critical context (read or you will misjudge the state)

1. **NOTHING has been submitted to CRAN.** The maintainer asked directly; the answer is no. Submission is
   Shinichi's act (his CRAN account + the web form). Do not attempt it. v1.0.0 is *release-ready*, not released.
2. **The pkgdown pages and the function docs have NOT been reviewed page-by-page with a human.** What DID
   happen: a two-pass automated audit (a readiness pass, then a **Fable-tier editorial-quality re-audit**),
   and an automated cleanup landed as **open PR [#746](https://github.com/itchyshin/gllvmTMB/pull/746)**
   (2 articles cut, 26 improved, `_pkgdown.yml` reorganised). `pkgdown::check_pkgdown()` passes at the
   config level. **But no one has looked at the rendered site or read the docs with Shinichi.** That review
   is THIS session's task and it is deliberately slow — go one page / one function at a time.
3. **The maintainer wants to do this together, unhurried.** Do not batch-rewrite. Present each page /
   function, discuss, fix on his call, move to the next. This is the opposite of the fan-out workflows that
   got us here.

---

## Goals / mission
Drive gllvmTMB to a **clean, honest CRAN 1.0.0** (maintainer, locked 2026-07-09; brain
`[[gllvmTMB]]`). The engineering is done. What remains before Shinichi tags + submits is **a public
surface he is proud of** — every rendered article correct and clear, every exported function's help
page accurate. Julia parity and the paper are post-1.0.

## Current working state
- **`main` @ `e4188105` = gllvmTMB 1.0.0.** All five v1.0 arcs (A release spine · B functional-phylo · C
  missing-data · D lv honest-ship · E capability-honesty) done and merged (#737–#745).
- **Verified:** 3-OS `R CMD check` PASS (ubuntu + macOS + windows, run 29088925957) · local `--as-cran`
  **0E/0W/0N** · full test suite **0 failures / 4478 pass** · PDF manual builds clean · all URLs/DOIs resolve.
- **Open:** PR **#746** (article estate cleanup) — awaiting Shinichi's review + merge. **One decision is
  open:** the QG `animal-model` article — I de-scaffolded + fixed it rather than deleting (its stats verify);
  Shinichi may still want it cut.
- **Not done:** the human page-by-page + function-by-function review (this session); the issue closeout
  (below); tag + submit (Shinichi).

## The task for THIS session — the one-by-one review
Go through the pkgdown site and the reference docs WITH Shinichi, deliberately:

**A. Rendered pkgdown pages.** Build the site (`pkgdown::build_site()` or per-article
`pkgdown::build_article("<slug>")`; the CI `pkgdown.yaml` also builds it). Then, page by page:
- Does it render? Is it clear, correct, non-redundant, honest (no claim beyond validated behaviour)?
- The **visible first-click path** is the navbar: Model Guides · Concepts · Diagnostics. The **under-audit
  drafts** and **developer notes** are grouped separately (out of the first-click path) in `_pkgdown.yml`.
- **Inputs to lean on** (already ground-truthed, so you don't re-derive):
  - `docs/dev-log/after-task/2026-07-10-article-estate-cleanup.md` — the full **keep / improve / cut table**
    with Fable's per-article reasoning AND the **maintainer follow-ups** (the editorial / live-render items
    the automated pass deliberately left). Start here.
  - PR #746's diff — what the cleanup already changed.
- **Known follow-ups that need a live render / Shinichi's call** (from that report): a few articles
  (lambda-constraint, functional-biogeography) need a **larger fixture re-simulated to a positive-definite
  Hessian** so their CI examples show real intervals instead of `[NA, NA]`; `animal-model`'s `$report$…`
  reach-ins need an **exported phylo-loading accessor that does not yet exist**; a couple of subjective
  section trims. These are Codex-lane (live R) or Shinichi-editorial.

**B. Function docs (reference).** Walk the exported functions' `.Rd`/roxygen one by one:
- Is each help page accurate, with a runnable example, and grouped in `_pkgdown.yml reference:`?
- PR #746 added the previously-ungrouped exports (a **Profile-likelihood CIs** group + a
  **Deprecated/compatibility** group). Confirm every export is grouped and reads correctly.
- Watch for the pattern Fable caught estate-wide: **register-code jargon** (ANI-*/PHY-*/CI-*/FG-*/DIA-*)
  leaking into user-facing text, and **teaching that reaches into `$report$…` internals** instead of the
  exported extractors.

## Landing State (git ledger)
| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `main` @ `e4188105` (gllvmTMB 1.0.0) | y | y | #737–#745 merged | **LANDED** |
| `claude/article-cleanup` | y | y | **#746 open** | **CARRIED-OVER** — Shinichi reviews/merges; QG decision open |
| `handover/2026-07-10-claude` (this doc + `dev/issue-closeout-2026-07-10.sh` + CLAUDE.md pointer) | y | y | this PR | docs-only; Shinichi merges |
| CRAN submission | — | — | — | **NOT DONE** (Shinichi's act) |

## Next Immediate Steps (ordered)
1. **Rehydrate** (recipe below). Read the article-cleanup report first.
2. **Review + merge PR #746** with Shinichi (or he does). Settle the `animal-model` cut-vs-keep call.
3. **The page-by-page + function-by-function review** (the main task) — build the site, walk each page and
   each reference topic with him, fix on his call. Slow and deliberate.
4. **Close out the maintainer follow-ups** from the article report (the PD-Hessian fixture re-sims etc. are
   Codex-lane / live R — hand those to Codex or Totoro if fits are needed).
5. **When Shinichi is satisfied:** he runs the issue closeout, tags `v1.0.0`, and submits.

## Blockers / user acts (🔴 = only Shinichi/Codex can do)
- 🔴 **Issue closeout is safety-blocked for the agent.** Bulk GitHub issue closes are refused by the
  permission layer even with authorization. The full, evidence-commented script (75 close / 19 defer =
  all 94 open issues) is committed at **`dev/issue-closeout-2026-07-10.sh`** — Shinichi runs
  `bash dev/issue-closeout-2026-07-10.sh`.
- 🔴 **CRAN submission** — Shinichi's account + the web form.
- 🟡 **Live-R follow-ups** (PD-Hessian fixtures, the phylo-loading accessor) — Codex-lane.

## Gotchas & failed approaches (do not repeat)
- **Do NOT batch-rewrite the articles this session.** The maintainer explicitly wants a slow, one-by-one
  human review. The fan-out audit/cleanup is already done and is INPUT, not a substitute.
- **Do NOT claim anything is "submitted" or "released."** It is release-*ready*, on `main`, unsubmitted.
- **`git checkout main` shows PRE-#746 article content** — the cleanup is on the open PR, not on main yet.
- **Retired articles are archived, not deleted** — `dev/held-articles/{data-shape-flowchart,stacked-trait-gllvm}.Rmd`.
- **The vault (`~/shinichi-brain`) is a separate repo** — the daily brain-check no longer `git add -A`s;
  commit your own vault edits scoped (`git -C ~/shinichi-brain add <file>`).

---

## Mission control
| Item | State |
|---|---|
| Repo | `gllvmTMB` @ `origin/main` = `e4188105` = **1.0.0** |
| CRAN | **release-ready, NOT submitted** (Shinichi's act) |
| 3-OS `R CMD check` | **PASS** ubuntu · macOS · windows |
| Local `--as-cran` | **0E / 0W / 0N** |
| Test suite | **0 failures / 4478 pass** (938 gated skips) |
| PDF manual · URLs | build clean · all resolve |
| Arcs A–E | **all done** (#737–#745 merged) |
| Open PR | **#746** article cleanup (2 cut · 26 improved · pkgdown reorg) — Shinichi reviews |
| **This session's job** | **one-by-one pkgdown pages + function docs review WITH Shinichi** |
| Issue closeout | staged + committed `dev/issue-closeout-2026-07-10.sh` (Shinichi runs; agent safety-blocked) |
| Post-1.0 | Julia parity · the paper · full coverage campaign |

---

## How to Resume
1. **Rehydrate, in order:** this doc → `docs/dev-log/after-task/2026-07-10-article-estate-cleanup.md`
   (the keep/improve/cut table + follow-ups) → PR #746 diff → `_pkgdown.yml` (the grouping) →
   `docs/design/61-capability-status.md` + `docs/design/35-validation-debt-register.md` (what's validated,
   so honesty checks are grounded) → `~/.claude/memory/memory_summary.md` → brain `[[gllvmTMB]]` dossier.
2. **Confirm state:** `git log --oneline -3 origin/main`; `gh pr view 746`; build the site.
3. Speak as **Ada**; use **Fable-tier** judgment for the quality calls and spawn **Rose** before any public
   claim. But this is a **human-paced** review — present, discuss, fix on Shinichi's call, next.
4. **Claude vs Codex:** you do the review + prose fixes + `_pkgdown.yml`; hand live-R items (fixture
   re-sims for PD Hessians, the phylo-loading accessor, any real fits) to **Codex**.

### One-command resume (paste in your authenticated terminal, from the repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-10-claude-handover.md + the article-cleanup report. gllvmTMB is 1.0.0 on main, cross-OS verified, NOT submitted to CRAN. PR #746 (article cleanup) is open. Today we go through the pkgdown pages and the function docs ONE BY ONE together, slowly — build the site and walk each page and each reference topic with me, fixing on my call. Start by showing me the article keep/improve/cut table and the first rendered page."
```
