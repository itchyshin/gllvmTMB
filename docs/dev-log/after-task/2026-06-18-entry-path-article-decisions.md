# After Task: Entry-Path Article Decisions

## Goal

Close article-council step 4 without widening scientific or release claims:
decide whether `data-shape-flowchart`, `stacked-trait-gllvm`, and
`gllvm-vocabulary` should merge into Get Started, return as compact public
guides, or stay internal.

## Implemented

`gllvm-vocabulary` returned as a visible Tier 2 Technical reference glossary.
It now has Tier 2 YAML, a scope boundary, and no links to hidden worked-example
pages. `data-shape-flowchart` and `stacked-trait-gllvm` stay buildable but
internal as Tier 3 drafts, with gate notes telling readers to use Get Started,
Morphometrics, or the formula keyword grid until the biological example set is
promoted one article at a time. `pitfalls` now links to the public glossary
instead of saying the glossary is under audit.

## Mathematical Contract

No model equations, likelihoods, parser rules, families, or estimators changed.
The only mathematical-adjacent prose touched was glossary wording that keeps
`Sigma`, `Lambda`, and `psi` terminology within the existing article-council
scope.

## Files Changed

- `_pkgdown.yml`
- `ROADMAP.md`
- `vignettes/articles/gllvm-vocabulary.Rmd`
- `vignettes/articles/data-shape-flowchart.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`
- `vignettes/articles/pitfalls.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-entry-path-article-decisions.md`

## Checks Run

- Skill gates read: article-tier audit, Rose pre-publish audit, and
  after-task audit.
- Pre-edit lane check:
  `PATH="/opt/homebrew/bin:$PATH" gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,isDraft,headRefName,updatedAt,url`
  and
  `git log --all --oneline --since="6 hours ago" -- _pkgdown.yml ROADMAP.md vignettes/articles/data-shape-flowchart.Rmd vignettes/articles/stacked-trait-gllvm.Rmd vignettes/articles/gllvm-vocabulary.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/dashboard docs/design`.
- Live evidence poll:
  `gh pr view 489`, `gh pr view 101`, `gh issue view 486`,
  `gh run view 27752749643`, `gh run view 27752884846`,
  `gh run view 27763712855`, and
  `git ls-remote origin refs/heads/power-pilot-results`.
- Hidden-link scans:
  `rg -n "lambda-constraint\\.html|phylogenetic-gllvm\\.html|animal-model\\.html|mixed-family-extractors\\.html|choose-your-model\\.html|data-shape-flowchart\\.html|stacked-trait-gllvm\\.html" vignettes/articles/gllvm-vocabulary.Rmd _pkgdown.yml ROADMAP.md docs/dev-log/audits/2026-06-18-article-council-ledger.md vignettes/articles/pitfalls.Rmd`
  and the same pattern across current public articles and `_pkgdown.yml`.
- Stale-wording scan:
  `rg -n "public vocabulary glossary is under audit|publication-grade|release-ready|bridge complete|scientific coverage passed|coverage passed|fast GLLVM|AI-REML|REML|full parity|complete bridge|profile-likelihood default|genuine bootstrap|meta_known_V|gllvmTMB_wide|trio|\\\\bf S|\\bS_B\\b|\\bS_W\\b" _pkgdown.yml ROADMAP.md vignettes/articles/data-shape-flowchart.Rmd vignettes/articles/stacked-trait-gllvm.Rmd vignettes/articles/gllvm-vocabulary.Rmd vignettes/articles/pitfalls.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md`.
- JSON validation:
  `python3 -m json.tool docs/dev-log/dashboard/status.json` and
  `python3 -m json.tool docs/dev-log/dashboard/sweep.json`.
- Whitespace:
  `git diff --check` passed after the closeout edits.
- Pkgdown:
  `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  and
  `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`.
- Rendered HTML checks:
  `rg -n "Vocabulary glossary|gllvm-vocabulary\\.html|Technical reference" pkgdown-site/articles/index.html pkgdown-site/articles/gllvm-vocabulary.html pkgdown-site/index.html`,
  `rg -n "data-shape-flowchart|stacked-trait-gllvm|gllvm-vocabulary" pkgdown-site/articles/index.html`,
  `rg -n "lambda-constraint\\.html|phylogenetic-gllvm\\.html|animal-model\\.html|mixed-family-extractors\\.html|choose-your-model\\.html|data-shape-flowchart\\.html|stacked-trait-gllvm\\.html" pkgdown-site/articles/gllvm-vocabulary.html`,
  and
  `rg -n "public vocabulary glossary is under audit|Vocabulary glossary|gllvm-vocabulary\\.html" pkgdown-site/articles/pitfalls.html`.

## Tests Of The Tests

No code tests were added because this slice changes article placement and prose
routing only. The integration check is the full article render plus rendered
HTML grep: it would fail or expose the stale route if the glossary link,
Technical reference placement, or hidden-page pruning were wrong.

## Consistency Audit

Rose verdict: PASS for this slice. The hidden-link scans returned no matches in
the glossary or public article route set. The stale-wording scan returned only
guarded `publication-grade` caveats in `ROADMAP.md` and the mission-control
guard in the article ledger. The live GitHub poll did not require a separate
volatile evidence update: #489 is still draft and green at `03fdda1`, #101 is
still draft with CI run `27763712855` in progress at `f7be594`, release issue
#486 is open, full-check `27752749643` and power-pilot `27752884846` remain
completed success, and `power-pilot-results` remains at `1a2aac6`.

## What Did Not Go Smoothly

The shell did not have `node` on PATH, so dashboard JSON was updated with the
in-app Node REPL instead. The first REPL attempt reused an existing top-level
binding and failed harmlessly; the retry used a local block and updated both
JSON files.

## Team Learning

Pat's reader path was the main decision lens: a glossary can be public as Tier
2 if it reduces jargon without sending readers into unfinished worked examples.
Rose's guard remains active: PR green != bridge complete != release ready !=
scientific coverage passed.

## Known Limitations

This does not complete the article estate. The next article-council step is the
biological worked-example triage: `behavioural-syndromes`,
`phylogenetic-gllvm`, and `animal-model`. The public docs still wait for bridge
landing decisions before broader claim wording changes.

## Next Actions

Run the biological worked-example council one article at a time, starting with
the capability rows, example object, figure quality, and rendered HTML path for
each candidate.
