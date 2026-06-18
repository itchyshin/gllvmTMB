# After-task report: hide lambda articles from public dropdown

## Task goal

Make the public article surface match the article-council ledger by keeping
`lambda-constraint` and `lambda-constraint-suggest` buildable but out of the
public Articles dropdown and out of public recommended-next-step routing until
their binary loading-constraint teaching path passes rendered review.

## Mathematical contract

No likelihood, formula grammar, covariance parameterisation, response family,
validation-row status, exported API, or example-data contract changed. The LAM
rows remain whatever `docs/design/35-validation-debt-register.md` says they
are; this task changes article placement and reader routing only.

## Files changed

- `_pkgdown.yml`
- `vignettes/articles/joint-sdm.Rmd`
- `vignettes/articles/lambda-constraint.Rmd`
- `vignettes/articles/lambda-constraint-suggest.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-lambda-navbar-hide.md`

## Checks run

- Pre-edit lane check:
  `/opt/homebrew/bin/gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,isDraft,headRefName,updatedAt,url`
  -> only draft PR #489 was open.
  `git log --all --oneline --since="6 hours ago" -- _pkgdown.yml vignettes docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/audits ROADMAP.md docs/design`
  -> no separate hot-file owner detected.
- Public-route scan:
  `rg -n "articles/lambda-constraint\\.html|lambda-constraint\\.html|lambda-constraint-suggest\\.html|Confirmatory loadings|Suggesting Lambda constraint|Loading constraints" README.md vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd vignettes/articles/model-selection-latent-rank.Rmd vignettes/articles/joint-sdm.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd vignettes/articles/fit-diagnostics.Rmd vignettes/articles/convergence-start-values.Rmd vignettes/articles/pitfalls.Rmd vignettes/articles/missing-data.Rmd _pkgdown.yml`
  -> no hits after the edit.
- Internal-link scan:
  `rg -n "lambda-constraint|lambda-constraint-suggest" vignettes/articles/*.Rmd`
  -> remaining links are in internal articles or the hidden lambda pages
  themselves.
- Pkgdown:
  `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> no problems found.
  `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> completed successfully.
- Rendered HTML scans:
  `rg -n "Loading constraints|Confirmatory loadings|Suggesting Lambda constraint|lambda-constraint\\.html|lambda-constraint-suggest\\.html" pkgdown-site/articles/joint-sdm.html pkgdown-site/articles/index.html`
  -> no `joint-sdm` hits; lambda pages remain only in the generated internal
  article index listing.
  `rg -n "Internal article gate|first-stop tutorial|first-stop technical reference" pkgdown-site/articles/lambda-constraint.html pkgdown-site/articles/lambda-constraint-suggest.html`
  -> both rendered gate notes are present.
- Stale wording:
  `rg -n "release-ready|bridge complete|scientific coverage passed|coverage passed|publication-grade|fast GLLVM|AI-REML|REML|full parity|complete bridge" ROADMAP.md _pkgdown.yml vignettes/articles/joint-sdm.Rmd vignettes/articles/lambda-constraint.Rmd vignettes/articles/lambda-constraint-suggest.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md`
  -> expected guard / publication-grade-boundary hits only.
  `rg -n "gllvmTMB_wide|meta_known_V|\\bS_B\\b|\\bS_W\\b|\\\\bf S|profile-likelihood default|trio" ROADMAP.md _pkgdown.yml vignettes/articles/joint-sdm.Rmd vignettes/articles/lambda-constraint.Rmd vignettes/articles/lambda-constraint-suggest.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md`
  -> no hits.
- Whitespace:
  `git diff --check`
  -> clean.

## Consistency audit

The article-council ledger, roadmap, pkgdown navigation source, public
`joint-sdm` article, and rendered HTML now agree: lambda pages are buildable
internal articles, not public-dropdown pages or public next-step links. The
guard remains active: PR green != bridge complete != release ready !=
scientific coverage passed.

## Tests of the tests

No tests were added. The regression this slice protects against is hidden-page
routing from public articles. The public-route `rg` scan and rendered
`joint-sdm.html` scan would fail if a visible source or rendered public article
still linked to `lambda-constraint.html` or `lambda-constraint-suggest.html`.

## What did not go smoothly

The first `pkgdown::check_pkgdown()` attempt failed because Pandoc was not on
the shell PATH. Rerunning with `/opt/homebrew/bin` prepended fixed the
environment problem and returned `No problems found.`

## Team learning

Ada kept the task to one article-surface decision rather than combining it with
profile-page placement or a lambda rewrite.

Pat's reader-path lens caught that hiding the dropdown was not enough while
`joint-sdm` still recommended the hidden pages.

Rose's audit lens kept the cleanup tied to source and rendered routing scans
instead of trusting the navbar diff alone.

Grace's pkgdown lens required both `check_pkgdown()` and a non-lazy article
build before closeout.

Boole's syntax/API lens kept the public `joint-sdm` explanation on documented
helper functions (`confirmatory_lambda`, `suggest_lambda_constraint`) without
routing to an unfinished teaching article.

## Design-doc updates

No design document changed. The article-council ledger was updated because it
is the controlling article-surface audit for this decision.

## Pkgdown/documentation updates

`_pkgdown.yml` now lists the lambda pages only under "Internal drafts and
technical notes." Both lambda source articles carry an internal gate note, and
the rendered pages show that note.

## Roadmap tick

The roadmap gained a 2026-06-18 lambda surface cleanup checkpoint under the
article-order correction section. It records that the next lambda action is the
binary JSDM article plan and rendered review, not capability promotion.

## GitHub issue ledger

Inspected current PR/run state while choosing the slice: gllvmTMB #489 remains
draft/open/clean; GLLVM.jl #101 CI remains the bridge gate; release issue #486
remains open. No issue was commented on, closed, or created for this article
surface cleanup.

## Known limitations and next actions

The lambda articles are still on disk and rendered in the internal article
index. That is intentional. The next bounded lambda task is to rewrite/review
the main binary loading-constraint article as a public teaching path, then
decide whether the suggester article returns as a Tier 2 companion.
