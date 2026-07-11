# gllvmTMB — Claude → Codex handover (2026-07-11, PM)

**Meta:** 2026-07-11 · from Claude (Opus 4.8) · **to Codex** · supersedes the AM
`2026-07-11-claude-handover.md`. Cross-tool handoff: **you (Codex) read `origin`, not
the authoring session's disk — so everything below is pushed to the branch.**

---

## Critical Context — read this or it goes wrong

1. **First CRAN release is `0.5.0`, NOT 1.0 (brain D-42).** 1.0 is the maturity milestone
   (Julia parity, the paper, the coverage campaign). Never reintroduce 1.0 reader-facing.
2. **All work is on branch `claude/release-0.5.0` — now PUSHED to `origin`.** `main` already
   has the `1.0.0 → 0.5.0` version correction (PR #748, merged). The branch carries the rest.
3. **Standing rule (Shinichi, 2026-07-11): reader-facing content contains ONLY what makes
   sense to the reader.** Internal validation-register codes (`EXT-18`, `FG-04`, `CI-08`,
   `DIA-10`, `MIS-33`, `LV-05`, … shape `[A-Z]{2,5}-[0-9]+`) and dev bookkeeping NEVER appear
   on ANY reader-facing surface: **articles · pkgdown Reference (roxygen `#'` prose) ·
   the Changelog (NEWS.md) · AND printed function output** (e.g. a `validation_row` column in
   a printed extractor table — the subtle one). Fix prose by rewriting to plain language;
   fix OUTPUT columns with an S3 `print` method that hides them (keep them in the object).
   Brain: "Reader-facing rule — only what makes sense to the reader".
4. **Nothing on the branch is on the live site yet** (except the version number, via #748).
   The site reflects the cleanups only after `claude/release-0.5.0` lands on `main` + pkgdown
   rebuilds. So "1.0.0", the register codes, and `validation_row = EXT-18` still show live —
   expected until the branch merges.

## Mission / goal

**0.5.0 = a clean, honest first CRAN release of a working, R-only gllvmTMB (D-42).** The
engineering is done + cross-OS clean. The remaining work is (a) **land the branch on `main`**
so all the doc-honesty cleanups reach the public site, and (b) **finish the one-by-one doc
walk** with the Pat/Rose/Fisher panel. CRAN submission is Shinichi's act.

## What was accomplished this session (all committed on the branch, 9 commits)

- **PR #748 merged to `main`** — version `1.0.0 → 0.5.0` correction (DESCRIPTION + NEWS heading
  + "First stable release" → "First CRAN release"). `main` now reads 0.5.0.
- **Doc walk pages 4, 5, 6 done + committed** (`model-selection-latent-rank`, `joint-sdm`,
  `covariance-correlation`) — each Pat/Rose/Fisher panel-reviewed: register-code strip,
  lifecycle baseline, interval fences, LV terminology, rotation caveat, PCA/NMDS contrast.
- **LV-terminology sweep** — 26 construct→"latent variable (LV)" across 12 vignettes (`16599194`).
- **Register-code sweep, articles** — ~128 codes across 11 reader-facing vignettes (`08c0c22f`).
- **Register-code sweep, reference/roxygen** — 87 codes across 28 R files; regenerated `man/`
  via `devtools::document()` (0 codes in man/, exit 0, no S3 corruption) (`a35c4b0e`).
- **`validation_row` API fix** — S3 `print.gllvmTMB_reportable_table` hides the internal
  provenance column from `extract_Sigma_table()`/`extract_correlations()` output; `document()`
  clean, `devtools::test()` = **0 fail / 1761 pass** (`12f54ce4`).
- **functional-biogeography pulled from nav** (`_pkgdown.yml`) pending its rewrite (`fa67f0f1`).
- **NEWS changelog register sweep — PARTIAL (WIP)** — ~115 of 168 codes removed; **53 remain**
  (`5c4d5d71`). See Next Steps.
- **Page-7 panel (`fit-diagnostics`) ran — findings captured, fixes NOT yet applied.**
- Three durable rules recorded in the brain: the **reader-facing rule** (above), the **LV/latent
  variable** convention, and **one AI platform at a time** (Shinichi rarely runs Claude+Codex in
  parallel — whichever session is active owns the live work).

## Current working state

- **Working / committed on `claude/release-0.5.0` (pushed):** pages 1–6 doc-walk fixes, both
  register sweeps (articles + reference), LV sweep, validation_row fix, func-biogeog nav.
- **In progress:** NEWS changelog sweep (53 codes left, committed WIP); the doc walk (page 7
  panel done, fixes pending; pages 8+ not started).
- **Blocked / maintainer:** landing the branch on `main`; a clean `--as-cran`; tag `v0.5.0`;
  CRAN submission (Shinichi's act). Doc-walk page disposition triage (below).

## Key decisions & rationale (brain `DECISIONS.md`)

- **D-42** — gllvmTMB first CRAN = 0.5.0 not 1.0.
- **D-41** — lab packages ship EXPERIMENTAL on first CRAN.
- **4×4 grid canonical in reader docs** (`unique()` history stays out of reader pages).
- **Reader-facing rule** (2026-07-11, this session) — see Critical Context #3.

## Landing State ledger (git truth — what you can actually fetch)

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `claude/release-0.5.0` `@<HEAD>` (9 session commits) | y | **y** | none yet | **LANDED on origin; needs → main PR** |
| `main` — version 0.5.0 (PR #748) | y | y | #748 merged | LANDED |
| NEWS.md sweep (53 codes remain) | y (WIP) | y | — | **CARRIED-OVER — finish the sweep** |
| page-7 `fit-diagnostics` fixes | n | — | — | **CARRIED-OVER — panel done, apply fixes** |
| map/cheatsheet drafts | n (scratchpad only) | n | — | **PARKED — ephemeral, not in repo** |

## Next immediate steps (ordered — Codex owns the live toolchain)

1. **Land the branch on `main`.** Open the `claude/release-0.5.0 → main` PR
   (`gh pr create --base main --head claude/release-0.5.0`). **Expect a small conflict** on the
   version files (`DESCRIPTION`/`NEWS.md`/`README.md`/`_pkgdown.yml`/`cran-comments.md`/`inst/CITATION`)
   because #748 and the branch's renumber commit `2bf9ed0a` both set 0.5.0 — resolve by keeping
   0.5.0 + the branch's content. Merging this puts every cleanup on the public site.
2. **Finish the NEWS register sweep** — 53 codes remain in `NEWS.md`. Strip per the reader-facing
   rule (mostly parenthetical → delete; inline → plain language; keep `(#341)` GitHub refs and
   version headings). Verify: `grep -oE '\b[A-Z]{2,5}-[0-9]+\b' NEWS.md | grep -vE 'UTF-8|GPL-'`
   must be EMPTY. Commit.
3. **Apply page-7 (`fit-diagnostics`) panel fixes** (full output: `docs/dev-log/…` / the workflow
   journal — key items): (a) add a lifecycle sentence near the top (0.5.0 / pre-CRAN / EXPERIMENTAL);
   (b) reword the closing paragraph (~L256-257) to **drop "(see the validation-debt register)"** and
   **replace the bare word "validated"** (the page teaches readers NOT to over-read it) — keep the
   exemplary "does not calibrate CIs, prove the latent rank…" list verbatim; (c) optional nit: explain
   `boundary_sigma_eps`. Commit.
4. **Run the live checks Claude could not fully run:** `devtools::document()` (confirm clean),
   `devtools::test()`, one `devtools::check(args = "--as-cran")` on the branch, and a `pkgdown`
   render — confirm the Get-started `getLoadings()` render and that `sigma_rows_B` now prints
   WITHOUT the `validation_row` column (the `12f54ce4` fix).
5. **Continue the doc walk** (Pat/Rose/Fisher panel, same method — see the AM handover + the
   workflow scripts under the session scratchpad): remaining stable pages are `convergence-start-values`,
   `profile-likelihood-ci`, `troubleshooting-profile`, `pitfalls`, the Tier-2 concepts
   (`gllvm-vocabulary`, `api-keyword-grid`, `fixed-effect-zero-constraints`, `response-families`),
   and Tier-1 `missing-data`. **First get Shinichi's disposition triage** — some pages may be
   cut/merged/rewritten (he flagged this; functional-biogeography already pulled).

## Blockers / open questions (Shinichi's calls)

- **Merge of the `→ main` PR** and the release acts (tag `v0.5.0`, CRAN submit) are Shinichi's.
- **Doc-walk disposition:** which remaining stable pages are keepers vs cut/merge/rewrite.
- **functional-biogeography:** rewrite or delete (pulled from nav; still has codes; out of scope).
- **0.2.0 NEWS label:** small follow-up — the 0.2.0 heading was "first CRAN release" (wrong; never
  on CRAN), changed to "first public release" in #748; refine if 0.2.0 was never public.
- **Map/cheatsheet:** parked. If revisited, do ONE artifact (the cheatsheet), not both. The rich
  horizontal-pipeline map broke as a PDF (CSS grid collapsed) — use fixed-dimension SVG/HTML if retried.

## Gotchas & failed approaches — do NOT retry

- **`roxygenise(load_code="source")` corrupts S3** (turns `S3method()`→`export()`). Use
  **`devtools::document()`** — it worked cleanly this session (regenerated `man/`, no corruption).
- **Register codes leak from OUTPUT columns, not just prose.** `extract_Sigma_table()` /
  `extract_correlations()` carry a `validation_row` column of codes. It's REQUIRED by the
  route-matrix / julia-gate machinery + ~10 tests — do NOT delete the column; hide it in `print`
  (already done via `gllvmTMB_reportable_table`).
- **Image-generation for the cheatsheet/map is a trap** — it hallucinates function names (the exact
  reason the reference image Shinichi first showed had `set_families()`/`rr()`/`form_gllvmTMB()`).
  Reference artifacts must be code-generated for accuracy.
- **Branch-switch races:** a `git switch` mid-operation can leave a dirty tree that breaks a
  cherry-pick with "local changes would be overwritten." Ensure a clean tree before switching.

## How to resume (Codex)

1. `AGENTS.md` is native — read it, then this doc, then the AM handover for the doc-walk method.
2. Live env: standard R/TMB toolchain on the Mac (Rscript 4.6.0, devtools/pkgdown/roxygen2/TMB
   present). `export NOT_CRAN=true` for tests; the package compiles (TMB) on `load_all()`/`document()`.
3. Team: `.codex/agents/*.toml` — **Rose audit is mandatory before any public claim.**
4. Start on the branch: `git fetch && git switch claude/release-0.5.0`.

**One-command resume** (paste in Codex at the repo root):

```
Rehydrate from docs/dev-log/handover/2026-07-11-codex-handover.md + the AGENTS.md snapshot,
switch to branch claude/release-0.5.0, then execute the Next Immediate Steps — starting with
opening the claude/release-0.5.0 → main PR (resolve the version-file conflict) and finishing the
53-code NEWS sweep.
```

## Mission-control summary

| Repo | Branch / CI | What shipped this session | Plan by leverage |
|---|---|---|---|
| `gllvmTMB` | `claude/release-0.5.0` · **pushed** · `main` @ 0.5.0 (#748 merged) | version fix merged · pages 4–6 · LV sweep · register sweeps (articles + reference) · validation_row print-fix · NEWS sweep (WIP) · page-7 panel | **1.** open + land the `→ main` PR (cleanups go live) · **2.** finish NEWS + page-7 · **3.** `--as-cran` + render · **4.** continue the doc walk (after disposition triage) |
