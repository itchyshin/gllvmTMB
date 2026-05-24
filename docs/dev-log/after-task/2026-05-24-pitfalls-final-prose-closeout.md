# After Task: Pitfalls Final Prose Closeout

**Branch**: `codex/pitfalls-balanced-prose-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`
**Spawned subagents**: none

## 1. Goal

Close the public `pitfalls` article's final prose gate. The maintainer
asked for the points to be balanced and fairly general, with specific
models used as examples rather than as the rule.

## 2. Implemented

- Reframed the remaining example-specific wording in
  `vignettes/articles/pitfalls.Rmd`.
- Updated `ROADMAP.md` so `pitfalls` is no longer listed as the first
  shared Codex / Claude Code queue item.
- Updated the article gate matrix to mark `pitfalls` as passing final
  prose audit.
- Added `docs/dev-log/audits/2026-05-24-pitfalls-final-prose-review.md`
  as the durable Pat/Rose/Grace evidence record.

## 3. Files Changed

- `vignettes/articles/pitfalls.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-24-pitfalls-final-prose-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-pitfalls-final-prose-closeout.md`

No R source, TMB source, formula grammar, exported functions, roxygen,
generated Rd files, NAMESPACE, NEWS, README, `_pkgdown.yml`, tests, or
validation-debt statuses changed.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent merged article/roadmap lanes only; no competing open PR.
- `gh run view 26375042665 --repo itchyshin/gllvmTMB --json status,conclusion,jobs,url`
  -> previous main pkgdown run still in progress at the time local
  work began; branch held local-only.
- Re-run of the same command after local checks
  -> previous main pkgdown run completed successfully.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/pitfalls", "articles/roadmap")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  -> completed; `pkgdown-site/articles/pitfalls.html` and
  `pkgdown-site/articles/roadmap.html` were written.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- ``rg -n 'general failure mode|For any `latent\\(\\)`|first name what the matrix indexes|final prose audit passed|2026-05-24-pitfalls-final-prose-review|convergence-start-values` wording audit|pitfalls` balance pass|The points are general diagnostic' vignettes/articles/pitfalls.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md docs/dev-log/audits/2026-05-24-pitfalls-final-prose-review.md pkgdown-site/articles/pitfalls.html pkgdown-site/articles/roadmap.html``
  -> source and rendered HTML show the general framing, final audit
  status, and updated next queue.
- `rg -n 'First name what the matrix indexes|what the matrix indexes and which variance' vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> section 7's general matrix-meaning diagnostic is present in
  source and rendered HTML.
- `rg -n "Scope boundary|FG-02|FG-03|FAM-01|FG-04|FG-05|FG-06|EXT-01|EXT-14|EXT-15|LAM-04|PHY-02|PHY-03|PHY-04|PHY-07|ANI-01|ANI-07|ANI-08|MET-01|MET-03" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html docs/dev-log/audits/2026-05-24-pitfalls-final-prose-review.md`
  -> scope boundary and row IDs remain present.
- `rg -n "\b(FG-02|FG-03|FAM-01|FG-04|FG-05|FG-06|EXT-01|EXT-14|EXT-15|LAM-04|PHY-02|PHY-03|PHY-04|PHY-07|ANI-01|ANI-07|ANI-08|MET-01|MET-03)\b" docs/design/35-validation-debt-register.md`
  -> all cited row IDs exist with expected covered, partial, or
  blocked status.
- `rg -n "real harness bug|only the formulae matter here|not a special rule|functional-biogeography|n_species around 100|nonsense|WRONG|RIGHT|Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(|\\bscalar\\(" vignettes/articles/pitfalls.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md docs/dev-log/audits/2026-05-24-pitfalls-final-prose-review.md`
  -> acceptable hits only: hidden-row references to
  `functional-biogeography` in roadmap/gate-matrix rows and the code
  comment "only the formulae matter here"; stale terminology did not
  appear in the touched public prose.
- `rg -n "articles/(animal-model|behavioural-syndromes|joint-sdm|phylogenetic-gllvm|functional-biogeography|psychometrics-irt|simulation-recovery-validated|cross-package-validation|choose-your-model|data-shape-flowchart|lambda-constraint|profile-likelihood-ci|mixed-family-extractors|ordinal-probit|troubleshooting-profile|stacked-trait-gllvm|gllvm-vocabulary)\\.html|\\]\\((animal-model|behavioural-syndromes|joint-sdm|phylogenetic-gllvm|functional-biogeography|psychometrics-irt|simulation-recovery-validated|cross-package-validation|choose-your-model|data-shape-flowchart|lambda-constraint|profile-likelihood-ci|mixed-family-extractors|ordinal-probit|troubleshooting-profile|stacked-trait-gllvm|gllvm-vocabulary)\\.html\\)" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html ROADMAP.md pkgdown-site/articles/roadmap.html`
  -> no hidden-article links were introduced.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "pitfalls OR article surface reset OR validation-debt" --json number,title,url,labels,updatedAt --limit 20`
  -> #230 remains the relevant article-surface ledger; #228 is a
  later diagnostics lane and was not touched.
- `find vignettes -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -print`
  -> no generated vignette scratch images.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No tests were added. This is a prose/status closeout for an already
rendered article. The touched article render exercises the existing
examples, and `pkgdown::check_pkgdown()` covers site metadata.

## 6. Consistency Audit

Article-tier audit: `pitfalls` remains Tier 1. It is a public
troubleshooting article for first-time users, not a validation study or
internal benchmark.

Prose-style audit: pass. The article names the diagnostic purpose
before each concrete example and keeps the specific phylogenetic,
simulation, and known-matrix cases illustrative.

Rose pre-publish audit: pass. The scope boundary remains explicit,
validation row IDs exist, stale terminology scans are clean, and hidden
articles are not recommended as ready next steps.

Grace pkgdown audit: pass locally. Remote #253 pkgdown was still active
when this branch started and completed successfully before this branch
was pushed.

## 7. Roadmap Tick

`pitfalls` moved from "final prose audit pending" to "final prose audit
passed." The Next Shared Work Queue now starts with the
`convergence-start-values` wording audit.

## 7a. GitHub Issue Ledger

- #230, `Article surface reset and user-first tooling gate`, remains
  the relevant tracker. This PR closes the `pitfalls` balanced-prose
  condition inside that broader issue.
- #228, predictive diagnostics, was returned by the search but is a
  later implementation/diagnostics lane.

## 8. What Did Not Go Smoothly

An initial `rg` scan used double quotes around backtick-containing
patterns, and zsh treated the backticks as command substitutions. The
scan was rerun with single quotes and the corrected command is recorded
above.

## 9. Team Learning

Ada kept the branch narrow: one article polish, one roadmap tick, one
gate-matrix update, one audit report.

Pat's criterion was practical: a reader should leave with a reusable
diagnostic habit, not a recipe tied to one covariance family.

Rose's criterion was traceability: every advertised capability remains
inside the scope-boundary rows, and hidden pages remain out of the
ready path.

Grace's criterion was publishability: touched pages render locally and
the site check is clean before any remote push.

## 10. Known Limitations And Next Actions

- `pitfalls` still uses long-format examples only; Get Started remains
  the long/wide equivalence article.
- The next shared queue item is the `convergence-start-values` wording
  audit.
- This closeout does not change #248 identifiability diagnostics or
  #228 predictive diagnostics.
