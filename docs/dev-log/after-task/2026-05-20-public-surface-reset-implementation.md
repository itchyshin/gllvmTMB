# After-task: public surface reset implementation

**Date:** 2026-05-20
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230
**Active reviewers:** Ada, Pat, Boole, Fisher, Florence, Grace, Rose.
**No spawned subagents were running in this slice.**

## Goal

Implement the reset plan instead of leaving it as a chat plan: archive the
old roadmap, create a short live roadmap, restrict the public pkgdown article
dropdown to six pages, simplify the landing page, add an article gate matrix,
and apply first-pass safety fixes to the visible articles.

## Implemented

- Archived the prior long `ROADMAP.md` to
  `docs/dev-log/roadmap-archive/2026-05-20-pre-reset-roadmap.md`.
- Replaced `ROADMAP.md` with a short dashboard covering the public surface,
  next 8 slices, infrastructure gates, restoration queue, finish-line
  criteria, and reset working rules.
- Updated `_pkgdown.yml` to show:
  - Model guide: `morphometrics`;
  - Concepts: `covariance-correlation`, `api-keyword-grid`,
    `response-families`;
  - Methods: `convergence-start-values`, `pitfalls`;
  - hidden `Under audit` pages for every other article;
  - Roadmap through top nav only.
- Simplified `README.md` as the landing page:
  - leads with the user question;
  - routes into the six-page learning path;
  - marks advanced pages as under audit;
  - replaces the large feature-status matrix with a compact current-status
    table linked to the validation-debt register and roadmap.
- Added `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`.
- Updated the reset audit to point at the gate matrix and the six-page public
  surface.
- Applied public article safety fixes:
  - explicit `trait = "trait"` in public long examples;
  - `S` drift corrected to `Psi` / `psi`;
  - morphometrics comparison softened to the simulated rank-2 Gaussian truth;
  - hidden-page next-step links removed from visible pages.

## Files Changed

- `README.md`
- `ROADMAP.md`
- `_pkgdown.yml`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/morphometrics.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/response-families.Rmd`
- `vignettes/articles/pitfalls.Rmd`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-20-article-surface-reset.md`
- `docs/dev-log/roadmap-archive/2026-05-20-pre-reset-roadmap.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/team-improvements.md`

## Checks Run

- `git diff --check` -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> passed:
  `No problems found.`
- Targeted render of Get Started, the six visible articles, and roadmap
  -> passed after one Get Started reshape fix; only pre-existing
  `../logo.png` warnings.
- Homepage + targeted article render through `pkgdown::build_home()` and
  `pkgdown::build_article()` -> passed; only pre-existing `logo.png` /
  `../logo.png` warnings.
- Hidden-link scan over README, Get Started, and visible articles -> no hits.
- Stale `S` / `S_true` / `S only` scan over README, Get Started, and visible
  articles -> no hits.
- Landing-page overclaim scan for old routes and claims -> no hits.
- GitHub connector issue comment attempt -> failed with 403.
- `gh issue comment 230 --repo itchyshin/gllvmTMB --body-file -` -> posted:
  <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4503649236>.

## What Did Not Go Smoothly

- The first targeted render caught a real Get Started break: the temporary
  simplified example removed `session`, but the wide reshape still used it as
  an `idvar`. This is fixed.
- The first homepage render command used `build_home(new_process = FALSE)`;
  this pkgdown version does not support that argument. The corrected
  `build_home(quiet = TRUE)` command passed.
- The HTML was rendered locally but not visually reviewed with the maintainer
  in-browser yet. That remains part of the article gates.

## Reviewer Notes

Ada: The reset is now executable. The site has a small surface and a ledger
for restoring pages one by one.

Pat: The homepage no longer asks a new user to parse the validation register
before choosing a first article. The first route is Get Started ->
Morphometrics -> Covariance/correlation.

Boole: Public long examples now name `trait = "trait"`; wide examples use
`traits(...)`.

Fisher: The homepage no longer says broad advanced examples are ready. `pdHess
= FALSE` remains framed as an uncertainty warning in the methods path.

Florence: Figure-heavy advanced articles remain hidden until rendered figure
review.

Grace: `pkgdown::check_pkgdown()` and targeted render passed. Missing logo
warnings are pre-existing.

Rose: The reset closes the specific drift the maintainer flagged: hidden
article links, stale `S` notation, overclaiming status, and roadmap sprawl.

## Next Safe Slice

Start Slice 7 / 8 as planned: define the example object contract, then create
the morphometrics example object. That will let Get Started and Morphometrics
drop the remaining setup-heavy simulation code and become genuinely beginner
friendly.
