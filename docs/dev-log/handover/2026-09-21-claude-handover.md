# Claude handover — make the first gllvmTMB tutorial route runnable

**Date:** 2026-09-21 (America/Edmonton)
**From:** Codex
**To:** Claude Code
**Repository:** `itchyshin/gllvmTMB`
**Branch:** `claude/gllvmtmb-beginner-reader-20260921`

## Goals / mission

The reader-first documentation arc serves biology PhD students first, while
remaining useful to other applied scientists.  A page should answer a scientific
question, give one complete runnable route, explain what the result means, then
state the next decision and honest limit.  Public prose must not lead with
internal test, campaign, process, or implementation language.

This lane is deliberately narrow: make the first visible route in the gllvmTMB
beginner article runnable in the order a new reader encounters it.  It does not
change the statistical model, a formula, a fixture, a default, an API, or an
evidence claim.

## Critical context

- The landing question is: **Do body measurements vary together among
  individuals?**  The page should first let a reader load data, fit a Gaussian
  GLLVM, check the fit, and inspect covariance; the mathematics comes after the
  first interpretable result.
- On current `main`, `vignettes/gllvmTMB.Rmd` first shows an `eval = FALSE`
  formula using `df_wide` before the package and data are loaded.  The complete
  teaching fit appears later.  That order makes the first code a non-runnable
  sketch rather than a first route.
- The live reader-prose PR #1306 changes only three specialist articles:
  integrated survey design, Canada warbler iSDM, and phylogenetic categorical
  PGLMM.  It does **not** own this beginner vignette.
- This is a multi-lane repository.  Do not update an `AGENTS.md` snapshot
  pointer; the coordination board and active-lane split are the shared map.
- Use `origin` as the GitHub remote.  The original Dropbox checkout was stale
  and has foreign uncommitted files; this handover branch was created from a
  fresh single-branch clone at `origin/main` commit `d5197e30f`.

## What was accomplished

1. A source-plus-served-page audit identified the concrete first-reader failure
   in `vignettes/gllvmTMB.Rmd`: lines roughly 63--103 use `df_wide` before the
   data-loading route beginning around lines 147--165; the complete fit begins
   around lines 210--243.
2. Confirmed that PR #1306 has no file overlap with this lane.
3. Created the clean branch and claimed the initial ownership lease for
   `vignettes/gllvmTMB.Rmd` and this handover document.
4. Ran the handover landing gate successfully before writing this document.

## Current working state

- **Working:** the branch is clean and based on current GitHub main.
- **In progress:** no prose change has been made yet; the next action is the
  bounded reorder/rewrite below.
- **Not working / blocked:** nothing.  Do not treat unrelated unpushed branches
  in the older Dropbox checkout as this lane's state.

## Key decisions and rationale

1. Start with a complete analysis, not a shortened formula illustration.  A
   reader needs all setup needed to run the first call before being asked to
   understand the formula grammar.
2. Preserve both wide and long examples.  The first route should use the
   existing wide-data teaching fit; the long-data equivalent follows naturally.
3. Keep the existing current-limits link and all cautious claims.  Moving the
   explanation does not turn a successful fit into a general validation claim.
4. Keep detailed covariance notation after the first result.  Explain it in
   plain language rather than delete it; advanced readers still need the link
   between the model and `Sigma`.
5. Do not touch figures, visual design, engine code, formula grammar, fixture
   data, README, package metadata, CI policy, release work, or repository names.

## Landing state

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---|---|
| `claude/gllvmtmb-beginner-reader-20260921` at `d5197e30f` plus this handover | no | no | none | CARRIED-OVER |
| gllvmTMB PR #1306 `codex/reader-public-prose` | yes | yes | open draft | PROTECTED |

**CARRIED-OVER:** this branch intentionally contains only a forthcoming handover
document at this point.  Commit and push the document before a fresh Claude
session relies on it; then open a **draft** PR.  The next implementation commit
belongs to the same branch.

**FINDINGS-OF-RECORD: none.**  The reader-order finding is a repository-grounded
documentation task, not a new scientific or methods result.

## Files created / modified

At the time this handover was written:

- `docs/dev-log/handover/2026-09-21-claude-handover.md` — this durable handover.

No tutorial, model, fixture, or test file has been changed yet.

## Next immediate steps

1. Rehydrate, run lane preflight, and classify this handover against current
   `origin/main` as `OWED`, `DONE`, `RETRACTED`, or `PROTECTED`.
2. Claim `vignettes/gllvmTMB.Rmd` before editing.  If its lease conflicts,
   stop and narrow or ask the maintainer; never bypass the lease.
3. Replace the early `first-model-sketch` with a complete, visible starter
   sequence in this order:

   ```r
   library(gllvmTMB)
   morph <- readRDS(system.file(
     "extdata", "examples", "morphometrics-example.rds",
     package = "gllvmTMB"
   ))
   df_wide <- morph$data_wide
   fit <- gllvmTMB(
     morph$formula_wide,
     data = df_wide,
     unit = morph$fit_args$unit,
     family = morph$fit_args$family
   )
   as.numeric(logLik(fit))
   ```

   Use the repository's existing setup safeguards if direct installed-package
   data lookup is unavailable during source rendering.  The visible first route
   must not rely on a hidden previous chunk.
4. Place the current mathematical explanation after that first fit and its
   first plain-language covariance interpretation.  Preserve existing wide and
   long calls, `latent()` scope, rotation warning, and current-limits link.
5. Add or extend the smallest existing reader-surface source test only if the
   repository already has a scoped test location.  The durable invariant is:
   **the first visible fit must have prior visible loading/setup, and no visible
   non-runnable sketch may precede it.**  Do not invent a broad new test
   framework.
6. Run the acceptance gates below.  Estimate the live rendering time before
   running it; use Codex for any compilation/rendering that Claude cannot run.
7. Inspect the rendered first screen manually.  It must answer the question,
   show a complete starter route, say what the first output means, and point to
   the limits page before a reader reaches a family/structure expansion.
8. Commit explicit paths, push the branch, open a draft PR, and request a Pat
   or Rose reader review.  Do not auto-merge.

## Verification and acceptance gates

Run from the repository root after the prose repair:

```sh
git diff --check
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  Rscript --vanilla -e 'pkgdown::build_articles(articles = "gllvmTMB", lazy = FALSE)'
```

Also open the rendered `gllvmTMB` article and execute its first visible sequence
in a clean R session.  Confirm both wide and long routes remain present and
that no scientific limit or uncertainty qualification was silently broadened.

## Blockers / open questions

- No current blocker.
- If the installed example RDS is unavailable in a source-tree render, retain
  the existing source-tree fallback only where it is needed.  Do not make it
  part of the reader's visible first sequence.
- If rendering takes more than 30 minutes, stop after a pre-run timing check
  and report the estimate before continuing a full render.

## Gotchas and failed approaches

- Do not work in `/Users/z3437171/Dropbox/Github Local/gllvmTMB` without first
  reconciling it: it was behind GitHub main and contains foreign untracked
  files.  This clean clone was created specifically to avoid that bleed-through.
- Do not revive or edit PR #1306; its three article files are independent.
- Do not make the page formula-free.  The repair is sequence and explanation,
  not removal of the technical material.
- Do not describe a fixed data-generating model as one fixed dataset.  A
  teaching example and repeated-sampling evidence are distinct.

## How to resume

```sh
git clone --branch claude/gllvmtmb-beginner-reader-20260921 \
  git@github.com:itchyshin/gllvmTMB.git gllvmtmb-beginner-reader
cd gllvmtmb-beginner-reader
claude "Read AGENTS.md and docs/dev-log/handover/2026-09-21-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps."
```

Read `AGENTS.md` and `docs/dev-log/handover/2026-09-21-claude-handover.md`.
Run the handover rehydration steps, reconcile them with the current git state,
then continue only the OWED Next Immediate Steps.
