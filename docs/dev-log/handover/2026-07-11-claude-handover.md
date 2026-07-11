# gllvmTMB — Claude → Claude session handover (2026-07-11, session close)

**Meta:** 2026-07-11 · from Claude (Opus 4.8) · session close · **You are the next
Claude, picking up the one-by-one pkgdown/function-doc review with Shinichi.** This
supersedes the interim 2026-07-11 note earlier today.

---

## Critical Context — read this or it goes wrong

1. **First CRAN release is `0.5.0`, NOT 1.0 (brain decision D-42).** Everything is
   renumbered. Do not reintroduce 1.0 anywhere reader-facing.
2. **All session work is on branch `claude/release-0.5.0`, committed but UNPUSHED
   (local-only, no upstream).** A fresh Claude *on Shinichi's Mac* sees it in the
   local working tree. A fresh clone / another machine needs it **pushed first** —
   **pushing and opening a PR is Shinichi's call** (this is a release branch). Only
   #746 is on `main`; the 0.5.0 renumber + all doc fixes are *only* on this branch.
3. **Nothing is deployed.** The pkgdown CSS fix and every doc edit go live only on the
   **next pkgdown rebuild** (the Action, which fires when the branch lands on `main`).
   The live site still shows `1.0.0` and the old content — that is expected, not a bug.

## Mission / goal

**0.5.0 = a clean, honest first CRAN release of a working, R-only `gllvmTMB`** (D-42).
The engineering is done and cross-OS clean (`--as-cran` 0E/0W/0N, 4478 tests). The
remaining work is the **one-by-one human doc review WITH Shinichi** — slow, page by
page, fixing on his call — where the honesty-fencing lands and 0.5.0 becomes
CRAN-*ready*. `1.0` is reserved for the capability-maturity milestone (Julia parity,
the method paper, the full coverage campaign).

## What was accomplished this session

- **D-42 — renumber 1.0.0 → 0.5.0** (decided by a 5–0 review panel; recorded in the
  brain `DECISIONS.md`). Full detail: `docs/dev-log/after-task/2026-07-11-version-0.5.0-renumber.md`.
- **8 doc-honesty ship-blockers fixed + adversarially verified** (8/8 pass). Detail:
  `docs/dev-log/after-task/2026-07-11-doc-honesty-blockers.md`.
- **PR #746 (article cleanup) merged** — to `main` and into the release branch (3
  article conflicts resolved as a union of #746's improvements + our honesty fixes).
- **Issue closeout run** — 75 issues closed, 19 deferred with comments, 0 errors.
- **pkgdown CLAUDE/AGENTS leak fixed** — the workflow now hides both root `.md` files
  before the build (they were live pages + in search.json/sitemap).
- **Navbar CSS fixed** to match drmTMB (see Gotchas — the first attempt was wrong).
- **Doc walk: pages 1–3 done** — Landing (README), Get-started, Morphometrics — each
  reviewed by the Pat/Rose/Fisher panel and fixed.

## Current working state

- **Working:** branch is clean (0 uncommitted tracked changes), 11 session commits.
  The engineering on `main` is `--as-cran` 0/0/0, 4478 tests / 0 failures (pre-session).
- **In progress:** the one-by-one doc walk. **Page 4 = `model-selection-latent-rank`**
  is the next page.
- **Not yet done / pending maintainer:** tag `v0.5.0`, cut the GitHub release, one clean
  `--as-cran` on the release branch, CRAN submission. Nothing is deployed.

## Key decisions & rationale (cross-link brain `DECISIONS.md`)

- **D-42** — gllvmTMB first CRAN = 0.5.0, not 1.0. Grounded in the capability docs:
  interval coverage failed its gate (CI-08: 13/15 cells <94%; CI-10 mixed-family →0.55),
  delta/hurdle latent-scale correlation is "do not advertise", API mid-deprecation,
  and 1.0 is reserved for the maturity milestone. Mirrors **D-40** (drmTMB 0.5.0).
- **D-41** — lab packages ship EXPERIMENTAL on first CRAN; gllvmTMB keeps the label.
- **4×4 grid is canonical in reader docs** (Shinichi, 2026-07-11): `unique()` is
  soft-deprecated and *the reader does not need that history*. Reader pages are all
  4×4; the `unique()` deprecation prose was removed from README / api-keyword-grid /
  covariance-correlation. **Note:** `AGENTS.md`/`CLAUDE.md` still describe the full
  **4×5** grid (developer-facing, includes the compat `unique` column) — that is
  intentional; do not "fix" it to 4×4.

## The doc-walk method — REUSE THIS (Shinichi's chosen workflow)

For each pkgdown page: run a **Pat / Rose / Fisher** review panel via the `Workflow`
tool (Pat = new-user/CRAN; Rose = claim-vs-evidence honesty; Fisher = statistical
correctness), **reusing the shared estate-map below** (built once from the landing-page
skim — do NOT re-skim the estate per page). Present the three comment sets + a
consolidation to Shinichi; he decides; fix on his call; commit per page. Give him the
live `/articles/<slug>.html` link for the page (live = pre-fix deploy until rebuilt).
The panel-workflow scripts from pages 2–3 are in this session's
`workflows/scripts/doc-walk-panel-*.js` — copy their shape.

### Standing checks every page must pass (the estate-map carries these)

- **Honesty fencing** — every interval marked recovery-grade / coverage **NOT
  calibrated** (CI-08/CI-10); diagnostics are displays, not calibration; delta/hurdle
  latent-scale correlation = **do-not-advertise**.
- **No register-code leak** — `MIS-*/DIA-*/RE-*/MET-*/MIX-10/CI-08/10` belong ONLY in
  tier-3b dev notes / the register, never reader-facing prose. *(Check your own fence
  edits too — I leaked "(CI-08/CI-10)" into a fix and the panel caught it.)*
- **Orientation** — the NOT-PCA/NMDS contrast (model-based ordination) wherever a page
  shows ordination; raw loadings paired with the rotation caveat + `getLoadings()`, not
  `fit$report$*`; **EXPERIMENTAL / 0.5.0 / pre-CRAN stated IN PROSE**.
- **⭐ Stale / time-relevant content (Shinichi, standing, 2026-07-11)** — flag anything
  accurate when written but now needing update: internal dev-process leaks ("under
  audit", "rendered HTML review pass"), "coming soon"/roadmap tables, old version refs,
  superseded claims. First instance: the morphometrics "does not cover" rung table
  (trimmed).
- **Grid is 4×4** in reader docs; `unique()` history stays out.

### Reusable estate-map (paste into each page's panel prompt; no re-skim)

> PKGDOWN TIERS: **Tier 1 Model Guides** (first-click: morphometrics ✓done,
> model-selection-latent-rank, joint-sdm, missing-data) — full honesty+orientation
> bar. **Tier 2 Reference Concepts** (gllvm-vocabulary, covariance-correlation,
> api-keyword-grid, response-families) + Diagnostics (fit-diagnostics,
> convergence-start-values, pitfalls). **Tier 3a under-audit drafts** (choose-your-model,
> animal, phylo, cross-lineage-coevolution, mixed-family, ordinal, psychometrics,
> lambda-constraint, behavioural-syndromes, functional-biogeography, meta, spatial,
> profile-CI) — must carry a coverage caveat + say what they do NOT cover; stay OUT of
> the first-click path. **Tier 3b dev notes** (cross-package-validation, simulation-*,
> roadmap) — register-code shorthand OK only here.
> READER PATH: README → Start Here → Get-started → morphometrics → latent-rank /
> covariance-correlation → diagnostics.
> BASELINES: 0.5.0 / pre-CRAN / lifecycle-EXPERIMENTAL (D-42, D-41), stated in prose;
> zero 'stable'/'1.0'/'on CRAN' leakage. Sigma = Lambda Lambda^T + diag(psi);
> model-based ordination NOT PCA/NMDS; scores are predicted EB conditional modes of u_i.

## Landing State ledger (git truth — what the next agent can actually fetch)

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `gllvmTMB` `claude/release-0.5.0` `@e3913c5e` (11 session commits, HEAD) | y | **NO** | none | **CARRIED-OVER** |
| `main` (has PR #746 only) | y | y | #746 merged | LANDED |
| brain `DECISIONS.md` D-42 (`~/shinichi-brain`) | y (local) | n/a — vault has no remote (D-37) | n/a | LANDED |

**CARRIED-OVER — why + resume:** `claude/release-0.5.0` holds the 0.5.0 renumber, the
8 blocker fixes, the #746 merge, the CSS/CLAUDE-AGENTS pkgdown fixes, and the doc-walk
edits (pages 1–3). It is **committed but unpushed on purpose** — it is a release branch
and pushing / opening a PR is Shinichi's decision. A next-Claude on Shinichi's Mac
resumes from the local branch directly (`git switch claude/release-0.5.0`). If resuming
elsewhere, Shinichi must `git push -u origin claude/release-0.5.0` first.
*(Unrelated pre-existing unpushed branches — `feat/power-pilot-*`, `missing-data-*`,
`page-sweep`, `remove-unique-family` — are NOT this session's work; ignore them.)*

## Next immediate steps (ordered)

1. **Page 4 — `model-selection-latent-rank`** (Tier 1): run the Pat/Rose/Fisher panel
   (with the stale-content check), present to Shinichi, fix on his call, commit.
2. Continue the walk: **joint-sdm**, **covariance-correlation**, then the remaining
   Tier-2 concepts and the diagnostics lane; internal Tier-3 drafts last.
3. Resolve the open maintainer calls as they come up (below).

## Blockers / open questions (Shinichi's calls)

- **`animal-model`** cut-vs-keep (member audit recommended KEEP-internal; gated on an
  exported h²/Lambda_phy accessor or blessing the `$report` fields).
- **`simulation-recovery-validated`** — repo-wide slug rename (its body already disowns
  "validated"; only the slug/navbar still overclaims). Maintainer act (ripple).
- **`profile_cross_rho_ci`** — honesty-fenced this session but still exported in a public
  reference group; fuller option is `@keywords internal` + a register row.
- **Response-families pkgdown split** — I moved the mis-filed predictor tags + added a
  fencing desc, but the full covered-vs-blocked family partition is left to coordinate
  with the #746 pkgdown reorg.

## Gotchas & failed approaches — do NOT retry these

- **Navbar CSS:** making the navbar `position: sticky` was **WRONG**. Both gllvmTMB and
  drmTMB use a `fixed-top` navbar; the real bug is that the navbar height varies with
  width (56–123px) while pkgdown offsets content by a fixed ~56px. The fix (committed)
  is drmTMB's rule: `@media(min-width:992px){ body>.container .row>main,aside{margin-top:8rem} }`.
- **`roxygen2::roxygenise(load_code = "source")` CORRUPTS S3 registrations** (turns
  `S3method()` into `export()` in NAMESPACE, and `\method{}` into bare `name.class()`
  in man pages). Do **not** use it. The 4 man/.Rd touched this session (`latent`,
  `spde`, `profile_cross_rho_ci`, `plot.gllvmTMB_multi`) were **hand-synced** to the
  roxygen source; **Codex must run a real `devtools::document()`** to regenerate cleanly.
- **"GLLVM mission control"** appears as the home `<h1>`/`<title>` in a *local* pkgdown
  build — it's a stale local-build artifact; the deployed `<title>` is correct
  ("Fit Multivariate Models… • gllvmTMB"). Not a real bug.
- **Check your own fence edits:** my Get-started CI-fence edit leaked "(CI-08/CI-10)"
  into reader prose; the panel caught it. Grep the file for register codes after editing.

## How to resume

**Next Claude, on Shinichi's Mac:**
1. `git switch claude/release-0.5.0` (the branch is local; the doc fixes live here).
2. Read, in order: **this doc** → `docs/dev-log/after-task/2026-07-11-version-0.5.0-renumber.md`
   → `…/2026-07-11-doc-honesty-blockers.md` → the `CLAUDE.md` status block →
   `~/.claude/memory/memory_summary.md` (gllvmTMB rules) → brain `DECISIONS.md` D-42.
3. **Spawn the Rose lens (claim-vs-evidence honesty) before any public claim** — and for
   each page, the Pat/Rose/Fisher panel per the method above.
4. Claude lane = plan / refactor / prose / logic + CI checks. **Codex lane = the live
   toolchain** (see below).

**One-command resume** (paste in an authenticated `claude` terminal, from the repo root):

```
claude "Rehydrate from docs/dev-log/handover/2026-07-11-claude-handover.md + the CLAUDE.md status block, switch to branch claude/release-0.5.0, then continue the one-by-one pkgdown doc walk at page 4 (model-selection-latent-rank) with the Pat/Rose/Fisher panel."
```

## Codex follow-ups (live toolchain — hand these to Codex)

- Run a real **`devtools::document()`** on the branch (reproduces the 4 hand-synced
  man/.Rd from the roxygen source; confirms no S3 corruption).
- Confirm the **Get-started `getLoadings()` render** (it replaced a `$report$Lambda_B`
  reach-in in an `eval=TRUE` chunk — I could not run the fit locally).
- One clean **`devtools::check(args="--as-cran")`** on the release branch before submit.

## Mission-control summary

| Repo | Branch / CI | What shipped this session | Plan by leverage |
|---|---|---|---|
| `gllvmTMB` | `claude/release-0.5.0` @`e3913c5e` · **unpushed** · main CI green (`--as-cran` 0/0/0) | 0.5.0 renumber (D-42) · 8 blocker fixes · #746 merged · closeout run (75/19) · pkgdown CLAUDE/AGENTS leak + navbar CSS fixed · doc walk pages 1–3 | **1.** finish the doc walk (page 4 → rest) — makes 0.5.0 CRAN-ready · **2.** maintainer acts: tag v0.5.0, release, `--as-cran`, submit · **3.** Codex: real `document()`, render check |
