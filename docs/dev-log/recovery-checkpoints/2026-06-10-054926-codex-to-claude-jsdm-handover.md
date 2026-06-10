# Handover Checkpoint: Codex to Claude

**Date:** 2026-06-10 05:49 MDT
**Repository:** `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
**Current branch:** `main`
**Local status before this note:** clean; `main` equals `origin/main` at
`2b0c74811083072367e750ea6090036644cebcd0`
(`docs: publish binary JSDM loading workflow (#472)`).
**Open PRs at handover:** none.
**Shannon coordination status:** PASS. Clean tree, no open PR fan-out,
recent CI and pkgdown green on `main`, after-task coverage present for
the completed public JSDM article work.

This is a clean handover after publishing the binary JSDM article and
loading-suggestion workflow. The maintainer is reviewing the public
article visually and may still find small wording or layout issues. Treat
those as one-by-one public-doc polish, not as permission to reopen broad
capability work.

## First Commands For Claude

Run these before editing:

```sh
git status --short --branch
git fetch --prune
git pull --ff-only
gh pr list --repo itchyshin/gllvmTMB --state open \
  --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url
gh run list --repo itchyshin/gllvmTMB --limit 12 \
  --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,createdAt
tail -n 220 docs/dev-log/check-log.md
```

For any edit to shared coordination/design files, also run the
pre-edit lane check from `AGENTS.md`:

```sh
gh pr list --repo itchyshin/gllvmTMB --state open
git log --all --oneline --since="6 hours ago"
```

## Current Git / PR / CI State

Recent merged sequence:

```text
2b0c748 docs: publish binary JSDM loading workflow (#472)
1ee41ef docs: polish diagnostics model-selection REML workflow (#471)
5f880c5 docs: tighten public article navigation (#470)
a29c4a4 feat: add Gaussian REML pilot (#469)
87bfc28 docs: add latent-rank model selection article
```

Open PR census at handover:

```text
[]
```

Recent validation evidence on `2b0c748`:

- PR #472 `R-CMD-check` passed before merge:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27249243024>
- Post-merge `main` `R-CMD-check` passed:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27249608138>
- Post-merge pkgdown built and deployed successfully:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27249987638>
- Later `full-check` passed on the same merge SHA:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27268342408>
- Later power pilot sweeps on the same merge SHA also passed:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27251633670> and
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27262452873>

Live-site spot checks after deploy:

- `https://itchyshin.github.io/gllvmTMB/articles/joint-sdm.html`
  contains the public JSDM article, links to
  `suggest_lambda_constraints()`, and shows `wald_retention` plus the
  optional `profile_retention` path.
- `https://itchyshin.github.io/gllvmTMB/reference/suggest_lambda_constraints.html`
  contains the new reference page and documents `varimax_threshold`,
  `wald_retention`, and `profile_retention`.

The pkgdown build step took about 21 minutes inside a 25m55s deployment
run. That is green, but future article work should still render affected
articles locally before relying on the full site build.

## What Just Landed

PR #472 made the binary JSDM article public-ready enough to publish:

- added exported `suggest_lambda_constraints()`;
- kept the single-method `suggest_lambda_constraint()` surface;
- showed the fast default comparison between `varimax_threshold` and
  `wald_retention` in `vignettes/articles/joint-sdm.Rmd`;
- left `profile_retention` as an explicit slower optional path;
- clarified that `loading_ci(method = "profile")` is implemented, while
  bootstrap retention is not yet implemented;
- updated `_pkgdown.yml`, `NEWS.md`, generated Rd, validation-debt
  wording, check-log, and the after-task report.

Relevant after-task report:

- `docs/dev-log/after-task/2026-06-09-public-jsdm-article.md`

Relevant check-log section:

- `docs/dev-log/check-log.md` entry headed
  `2026-06-09 -- Lambda suggestion comparison helper for the JSDM article`

## Known Loose Ends

- Bootstrap-based loading/constraint retention is deliberately deferred.
  The maintainer explicitly asked to remember this. The future method
  should probably be a `bootstrap_retention` convention or plural-helper
  method that uses refits/resampling to decide zero pins, with slow-path
  tests and public wording that does not oversell it.
- `profile_retention` works, but it is slow on the shipped JSDM fixture
  compared with the Wald path. Keep it opt-in in public articles unless
  speed improves.
- The in-app browser may still be looking at `http://localhost:8123`.
  Treat the live deployed site as the publication source of truth. Restart
  a local preview server only if the maintainer asks to inspect local
  edits.
- Do not restart Julia bridge work, hidden structured-random-slope
  articles, cross-lineage coevolution public promotion, or broad random
  slope capability work from this handoff unless the maintainer explicitly
  reopens those lanes.

## Next Best Lane

If Claude is asked to continue immediately, the safest order is:

1. Handle maintainer copyedits on the live JSDM article one by one.
   Keep them public-doc scoped and rerun the affected article render plus
   `pkgdown::check_pkgdown()` if navigation or reference docs change.
2. If capability work resumes, design the bootstrap-retention extension
   narrowly. Start from `suggest_lambda_constraint()` /
   `suggest_lambda_constraints()`, use the shipped JSDM fixture, and add
   focused tests before public article claims.
3. Keep all public documentation on the long/wide paired example rule and
   explicit scope-boundary rule. Do not let reader-facing prose drift back
   into `PLANNED`, `PARTIAL`, or validation-ledger jargon.

## Commands Run For This Handoff

```sh
git status --short --branch
git log --oneline -5
gh pr list --state open --json number,title,headRefName,baseRefName,isDraft,url --limit 10
gh run list --repo itchyshin/gllvmTMB --limit 12 \
  --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,createdAt
curl -L -sS https://itchyshin.github.io/gllvmTMB/articles/joint-sdm.html | rg -n "suggest_lambda_constraints|wald_retention|profile_retention|Joint species distribution"
curl -L -sS https://itchyshin.github.io/gllvmTMB/reference/suggest_lambda_constraints.html | rg -n "suggest_lambda_constraints|profile_retention|wald_retention"
gh pr list --state open
git log --all --oneline --since="6 hours ago"
```

Outcomes:

- branch was clean on `main` before writing this handoff;
- open PR list was empty;
- exact pre-edit lane check was empty for both open PRs and commits in
  the last six hours;
- live-site spot checks found the expected article and reference content;
- recent Actions runs are green on the current `main` SHA.

## Commands Still Needed

None for the handoff itself. If Claude edits anything after this, run the
usual focused render/test gate for that slice and add a new check-log
entry.

## Blocking Questions

None. The next action depends on the maintainer: either small public JSDM
copyedits from visual review, or a new narrow bootstrap-retention design
slice.
