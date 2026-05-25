# After Task: Convergence Final Wording Closeout

**Branch**: `codex/convergence-wording-audit-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Fisher / Rose / Grace`
**Spawned subagents**: none

## 1. Goal

Close the public `convergence-start-values` article's final wording
gate. The roadmap stop condition was that `pdHess = FALSE` be framed
as an uncertainty / identifiability warning, with bootstrap and profile
limits named.

## 2. Implemented

- Tightened the scope boundary so bootstrap/profile are follow-up paths
  with named limits rather than blanket replacements for Wald SEs.
- Clarified that `se = FALSE` and degraded `sdreport()` status preserve
  useful point estimates only when uncertainty is routed elsewhere and
  failures/fallbacks are reported.
- Clarified that bootstrap depends on successful refits and that many
  failed refits are a diagnostic result.
- Clarified that profile likelihood is restricted to supported scalar
  targets with stable profiles.
- Updated `ROADMAP.md` and the article gate matrix to mark
  `convergence-start-values` as final-wording-audit passed.
- Added `docs/dev-log/audits/2026-05-24-convergence-final-wording-review.md`
  as the durable audit record.

## 3. Files Changed

- `vignettes/articles/convergence-start-values.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-24-convergence-final-wording-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-convergence-final-wording-closeout.md`

No R source, TMB source, formula grammar, exported functions, roxygen,
generated Rd files, NAMESPACE, NEWS, README, `_pkgdown.yml`, tests, or
validation-debt statuses changed.

## 4. Checks Run

- `git status --short --branch`
  -> clean `main...origin/main` before branching.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent merged article/roadmap lanes only; no competing open PR.
- `gh run list --repo itchyshin/gllvmTMB --limit 8 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,event,url,createdAt`
  -> latest #254 main R-CMD-check and pkgdown completed successfully.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/convergence-start-values", "articles/roadmap")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  -> completed; `pkgdown-site/articles/convergence-start-values.html`
  and `pkgdown-site/articles/roadmap.html` were written.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n 'final wording audit passed|2026-05-24-convergence-final-wording-review|bootstrap evidence depends on successful refits|supported scalar targets with stable profiles|report failed refits|not a cure for an unstable fitted surface|not a general substitute for bootstrap|Technical reference closeout' vignettes/articles/convergence-start-values.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md docs/dev-log/audits/2026-05-24-convergence-final-wording-review.md pkgdown-site/articles/convergence-start-values.html pkgdown-site/articles/roadmap.html`
  -> source/rendered pages show final status, profile/bootstrap
  boundary language, and the updated next queue.
- `rg -n 'Scope boundary|DIA-08|DIA-09|DIA-10|EXT-13|EXT-18|CI-02|CI-03|M3\\.3a|M3\\.4' vignettes/articles/convergence-start-values.Rmd pkgdown-site/articles/convergence-start-values.html docs/dev-log/audits/2026-05-24-convergence-final-wording-review.md docs/design/35-validation-debt-register.md`
  -> scope boundary and validation row IDs remain present in source,
  rendered HTML, audit record, and register.
- `rg -n 'pdHess = FALSE means model failure|point estimates.*useless|bootstrap.*guarantee|profile.*default|profile-likelihood default|wald.*safe|Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|meta_known_V|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(' vignettes/articles/convergence-start-values.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md docs/dev-log/audits/2026-05-24-convergence-final-wording-review.md`
  -> no output.
- `rg -n 'articles/(animal-model|behavioural-syndromes|joint-sdm|phylogenetic-gllvm|functional-biogeography|psychometrics-irt|simulation-recovery-validated|cross-package-validation|choose-your-model|data-shape-flowchart|lambda-constraint|profile-likelihood-ci|mixed-family-extractors|ordinal-probit|troubleshooting-profile|stacked-trait-gllvm|gllvm-vocabulary)\\.html|\\]\\((animal-model|behavioural-syndromes|joint-sdm|phylogenetic-gllvm|functional-biogeography|psychometrics-irt|simulation-recovery-validated|cross-package-validation|choose-your-model|data-shape-flowchart|lambda-constraint|profile-likelihood-ci|mixed-family-extractors|ordinal-probit|troubleshooting-profile|stacked-trait-gllvm|gllvm-vocabulary)\\.html\\)' vignettes/articles/convergence-start-values.Rmd pkgdown-site/articles/convergence-start-values.html ROADMAP.md pkgdown-site/articles/roadmap.html`
  -> no output; no hidden-article links were introduced.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "convergence OR start-values OR pdHess OR article surface reset OR diagnostic" --json number,title,url,labels,updatedAt --limit 20`
  -> #230 remains the relevant article-surface ledger; #248 and #228
  are later diagnostics lanes and were not touched.
- `find vignettes -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -print`
  -> no output.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No tests were added. This is a public-article wording and status
closeout. The touched article render exercises the existing example
fit and diagnostic chunks.

## 6. Consistency Audit

Article-tier audit: `convergence-start-values` remains Tier 1. It
answers an applied user's operational question about what to try after
a hard fit.

Prose-style audit: pass. The article names the purpose before the
mechanics, keeps the `pdHess` warning concrete, and tells the reader
what to try next.

Rose pre-publish audit: pass. Scope row IDs remain present, no stale
terminology was found, and hidden profile/diagnostics articles are not
advertised as ready next steps.

Fisher inference audit: pass for wording. The article separates point
estimates from Hessian-based uncertainty and names limits for both
bootstrap and profile workflows.

Grace pkgdown audit: pass locally.

## 7. Roadmap Tick

`convergence-start-values` moved from "final wording audit pending" to
"final wording audit passed." The Next Shared Work Queue now starts
with the technical reference closeout for `response-families` and
`api-keyword-grid`.

## 7a. GitHub Issue Ledger

- #230, `Article surface reset and user-first tooling gate`, remains
  the relevant tracker. This PR closes the
  `convergence-start-values` final wording condition inside that broader
  issue.
- #248 and #228 were returned by the search but are later diagnostics
  implementation lanes.

## 8. What Did Not Go Smoothly

No blocker. The article already had the main `pdHess` distinction; the
closeout made bootstrap/profile limits more explicit.

## 9. Team Learning

Ada kept the branch to one article plus the matching roadmap/gate
ledger.

Fisher checked that the text did not equate weak Hessian curvature with
model failure and did not overpromise bootstrap/profile intervals.

Rose checked row-ID traceability and hidden-article discipline.

Grace checked the rendered article and pkgdown metadata.

## 10. Known Limitations And Next Actions

- This closeout does not move DIA, EXT, or CI validation-debt statuses.
- It does not implement #248 identifiability diagnostics or #228
  predictive diagnostics.
- The next shared queue item is technical reference closeout for
  `response-families` and `api-keyword-grid`.
