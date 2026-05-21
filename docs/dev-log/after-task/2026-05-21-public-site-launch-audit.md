# After-task Report: Public-Site Launch Audit

Date: 2026-05-21 07:07 MDT
Branch: `codex/article-audit-2026-05-20`

## Scope

Ada ran a launch-level audit of the revised public pkgdown surface and roadmap.
This was not a broad article rewrite. The goal was to check whether the reset
surface can be shown as the current working website without routing readers to
immature hidden pages.

Active lenses:

- Ada: sequencing and integration.
- Pat: first-reader path through landing page, Get Started, and six articles.
- Rose: stale claims, hidden-page routing, and reset consistency.
- Grace: pkgdown and local package checks.
- Shannon: branch, PR, and ledger consistency.
- Florence: figure-heavy work remains active from the previous plot-suite
  slice; no new figure API was added in this audit.

No spawned subagents were running for this launch audit.

## Changes Made

- Rewrote the opening of `vignettes/gllvmTMB.Rmd` so Get Started begins with
  the reader question, prepared morphometrics object, long/wide fit path, and
  first summaries instead of covariance-dispatch theory.
- Softened `vignettes/articles/morphometrics.Rmd` so the hidden complexity
  ladder is clearly an under-audit restoration map, not a recommended reading
  path.
- Rebuilt the Get Started HTML and inspected the rendered public path through
  the local browser at `http://127.0.0.1:8765`.

## Audit Result

Launch-level result: **PASS with warnings**.

The revised public surface is coherent enough to show as the current working
website:

- top navbar exposes Get Started, six public articles, Roadmap, Reference, and
  Changelog;
- article index exposes only Model guide, Concepts, and Methods;
- no visible page inspected in the browser linked to hidden immature articles;
- Roadmap renders as the top-nav live dashboard;
- hidden/internal articles still render during full site build, so they are
  not silently broken.

Warnings:

- `pitfalls` is acceptable for launch but still reads like a collected list;
  it should later become more systematic.
- `devtools::test()` passed with 16 warnings from legacy/deprecated paths.
  These are not launch blockers, but they should become a separate warning
  cleanup slice.
- The six articles are launch-audited, not publication-final. Figure-heavy
  interpretation still needs Florence review as each article becomes a real
  model guide.

## Checks Run

- `git status --short --branch`
- `gh pr list --state open --repo itchyshin/gllvmTMB`
- `git log --all --oneline --since='6 hours ago'`
- `Rscript --vanilla -e 'pkgdown::build_site(lazy = FALSE)'`
- `Rscript --vanilla -e 'pkgdown::build_article("gllvmTMB", lazy = FALSE)'`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
- `git diff --check`
- `Rscript --vanilla -e 'devtools::test()'`
- Browser inspection of:
  - `/`
  - `/articles/gllvmTMB.html`
  - `/articles/index.html`
  - `/articles/roadmap.html`
  - the six visible public articles

Results:

- `pkgdown::build_site(lazy = FALSE)`: passed.
- `pkgdown::check_pkgdown()`: passed, `No problems found.`
- `git diff --check`: clean.
- `devtools::test()`: `FAIL 0 | WARN 16 | SKIP 14 | PASS 2158`.

## Stale-Link And Claim Scans

- Public clickable hidden-article links: no hits in README, Get Started, six
  visible article sources, Roadmap, or rendered public HTML.
- Stale wording scan: acceptable hits only. `choose-your-model` is present only
  in the internal article list; `meta_known_V` is present only as a deprecated
  reference alias; Roadmap explicitly says visible does not mean
  publication-ready.
- pkgdown `title: internal` behavior was checked against installed pkgdown help
  and NEWS.

## Definition Of Done Notes

1. Implementation: docs/site audit changes are in the working tree, not yet
   merged.
2. Simulation recovery: not applicable to this audit. Existing example-object
   tests were covered by the full `devtools::test()` run.
3. Documentation: Get Started and Morphometrics source plus rendered HTML were
   updated.
4. Runnable user-facing example: Get Started now routes to the prepared
   morphometrics fixture and shows long/wide fits early.
5. Check-log: appended in `docs/dev-log/check-log.md`.
6. Review pass: Rose/Pat/Grace/Shannon launch lenses applied; Florence remains
   a gate for future figure-heavy article restoration.

## Next Suggested Slice

Create the PR after reviewing the large reset diff as one coherent branch. If
the maintainer wants one more small improvement before PR, the best next target
is a narrow `pitfalls` structure pass: group the seven pitfalls into syntax,
data-shape, covariance, and inference sections without adding new claims.

Issue #230 was updated with this launch-audit result:
<https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4508579203>.
