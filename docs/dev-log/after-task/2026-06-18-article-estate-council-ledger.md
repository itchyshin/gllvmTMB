# Article Estate Council Ledger

**Date:** 2026-06-18
**Branch:** `codex/r-bridge-grouped-dispersion`

## Task Goal

Create a repo-visible article council ledger so the full gllvmTMB article estate
can be triaged one page at a time before any future navbar move, rewrite, merge,
split, demotion, or retirement.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette content, article content, or pkgdown navigation changed. This is a
governance and roadmap-control artifact only.

## Files Created Or Changed

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-article-estate-council-ledger.md`

No `_pkgdown.yml` or `vignettes/` files were changed in this slice.

## What Changed

The new article council ledger lists the full article estate, including Get
Started, visible navbar pages, technical references, hidden/internal drafts, and
capstone/validation pages. Each row records current navigation status, proposed
tier, action, capability rows, blockers, reviewers, exact next edit, and the
render/check command expected before publication movement.

`ROADMAP.md` now points to the ledger and states that the ledger is required
before any future article movement. The roadmap pointer does not itself promote
or hide any page.

## Checks Run

- `sed -n '1,260p' .agents/skills/article-tier-audit/SKILL.md`
  -> read the article-tier audit skill before editing.
- `sed -n '1,260p' .agents/skills/after-task-audit/SKILL.md`
  -> read the after-task audit skill before closeout.
- `sed -n '1,220p' .agents/skills/prose-style-review/SKILL.md`
  -> read the prose-style review skill because the task is prose-heavy.
- `git status --short --branch`
  -> branch `codex/r-bridge-grouped-dispersion`, ahead 25; only untracked
  recovery checkpoints before this slice.
- `git diff --stat`
  -> no tracked diff before this slice.
- `git diff --check`
  -> clean before this slice and clean after the roadmap/ledger edits.
- `/opt/homebrew/bin/gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,isDraft,headRefName,updatedAt,url`
  -> only draft PR #489 open.
- `git log --all --oneline --since="6 hours ago" -- ROADMAP.md _pkgdown.yml vignettes docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/audits docs/design`
  -> recent overlapping edits are the current #489 evidence/dashboard lane.
- `find vignettes vignettes/articles -maxdepth 2 -type f \( -name '*.Rmd' -o -name '*.qmd' \) | sort`
  -> inventoried the on-disk article estate.
- `sed -n '1,240p' _pkgdown.yml`
  -> inspected current navbar and article grouping.
- `sed -n '1,260p' docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> inspected the existing article gate matrix.
- `rg -n "2026-06-18-article-council-ledger|Article Council Ledger|article-council ledger|lambda-constraint|profile-likelihood-ci|troubleshooting-profile|random-regression-reaction-norms|functional-biogeography" ROADMAP.md docs/dev-log/audits/2026-06-18-article-council-ledger.md`
  -> confirmed the roadmap pointer and highest-risk article decisions are
  present.
- `rg -n "release-ready|bridge complete|scientific coverage passed|coverage passed|publication-grade|fast GLLVM|AI-REML|REML|full parity|complete bridge" ROADMAP.md docs/dev-log/audits/2026-06-18-article-council-ledger.md`
  -> found only the intentional mission guard and existing/explicit
  publication-grade boundaries; no new bridge, release, REML, AI-REML, or
  coverage promotion was introduced.

## Consistency Audit

The ledger keeps `lambda-constraint` visible-state tension explicit: the
current navbar has the loading-constraint pages visible, while the article-gate
matrix says the binary loading-constraint lane should become coherent before
promotion. This slice records that as the next article decision rather than
changing navigation without a render/review pass.

The ledger also keeps `profile-likelihood-ci` and `troubleshooting-profile` as
Tier 2 placement decisions rather than interval-calibration evidence. It keeps
`random-regression-reaction-norms`, `random-slopes-nongaussian`,
`simulation-recovery-validated`, and `functional-biogeography` internal until
their capability, scoring, reader-path, and figure gates are met.

## Tests Of The Tests

No package tests were added or changed. The controlling verification for this
slice is reproducibility of the ledger and roadmap pointer plus stale-claim
scans. A future navbar/content PR must add rendered HTML evidence and article
specific stale scans for every moved page.

## What Did Not Go Smoothly

The current article surface is not a simple public/hidden split. `_pkgdown.yml`
has loading-constraint pages visible, while the article gate matrix still warns
against promotion until the binary/JSDM teaching lane is coherent. The ledger
records that mismatch as the first article council decision.

## Team Learning

Ada: The article estate needs its own serial gate after bridge/capability
evidence; otherwise the project can appear finished while public teaching pages
still drift.

Pat and Boole: Every article row now starts from a reader question and tier
decision rather than from file existence.

Rose: The ledger makes hidden/public routing and stale-claim risk auditable
before navbar edits.

Grace: Render/check commands are named in every row so a future navigation
change cannot skip pkgdown/article verification.

Fisher, Curie, Gauss, and Noether: Capability rows, inference rows, interval
semantics, and likelihood/method claims stay separate in the article decisions.

Florence and Darwin: Figure-heavy and biological-story pages are explicitly
held until rendered visual and interpretation review.

Shannon: The lane is now repo-visible, which gives future Codex/Claude sessions
a coordination anchor outside chat.

## Design-Doc Updates

No design document changed. The new ledger lives under
`docs/dev-log/audits/` and extends the existing article gate matrix.

## pkgdown / Documentation Updates

No pkgdown navigation or vignette/article body changed. `ROADMAP.md` now links
to the ledger. A future article movement must run `pkgdown::build_articles(lazy
= FALSE)` for touched pages and `pkgdown::check_pkgdown()` before the navbar is
treated as ready.

## Roadmap Tick

Article restoration gate updated: `ROADMAP.md` now names the 2026-06-18
article council ledger as the required control artifact before article
movement. No public article status chip or navbar entry changed.

## GitHub Issue Ledger

No GitHub issues were mutated. Issue #230 remains the reset ledger referenced by
the article gate matrix, and #489 remains the only open draft PR observed in the
pre-edit lane check.

## Known Limitations And Next Actions

- The ledger is a council decision map, not a completed article audit.
- The next bounded article slice should resolve `lambda-constraint` and
  `lambda-constraint-suggest`: either rework the binary/JSDM path and render it,
  or remove them from the public dropdown until ready.
- The following slice should decide Tier 2 placement for `profile-likelihood-ci`
  and `troubleshooting-profile`.
- No hidden article should be linked as a recommended next step until its row in
  the ledger has rendered evidence and reviewer signoff.
