# After Task: Response Families Article Boundary

**Branch**: `codex/response-families-boundary-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: Ada, Pat, Rose, Grace

## 1. Goal

Make the visible Response families technical reference honest about
which family claims are covered, partial, or blocked during the
article-surface reset.

## 1a. Mathematical Contract

No likelihood, formula grammar, parameterisation, family constructor,
or extractor behaviour changed. This task only changes prose in
`vignettes/articles/response-families.Rmd`.

The article now separates three interpretation levels:

| Claim | Article wording | Register evidence |
|---|---|---|
| Covered public family surface | Gaussian, binomial links, Poisson, NB2 | FAM-01--FAM-04, FAM-06, FAM-08 |
| Partial family surface | beta-binomial, Gamma, beta, lognormal, Student-t, Tweedie, ordinal probit, truncated counts | FAM-05, FAM-09--FAM-15 |
| Not advertised as current interpretation | response-scale two-part correlations and mixed-family delta/hurdle correlations | FAM-17, MIX-10 |

## 2. Implemented

- Added a scope-boundary block near the top of
  `vignettes/articles/response-families.Rmd`.
- Added row-ID citations for covered, partial, and blocked family
  claims.
- Tightened the `delta_lognormal()` and `delta_gamma()` quick-lookup
  rows so readers report model/link-scale correlations unless a later
  response-scale estimand is defined.
- Added a sentence in the mixed-family section stating that delta and
  hurdle families are deliberately not used in the mixed-family example
  path because MIX-10 is blocked.

## 3. Files Changed

- Public article: `vignettes/articles/response-families.Rmd`.
- Dev log: `docs/dev-log/check-log.md`.
- After-task report:
  `docs/dev-log/after-task/2026-05-24-response-families-boundary.md`.

No generated pkgdown files were committed. The rendered
`pkgdown-site/articles/response-families.html` was used for QA only.

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a Tier-2 technical reference, not a worked
example rewrite.

Rationale: the article already declares
`tier: 2 # technical reference for the multivariate family surface` and
already contains paired long/wide single-family calls. The missing
piece was the AGENTS.md scope-boundary contract for advertised
capabilities.

Rejected alternative: rewrite the page as a full mixed-response worked
example. That would require a stronger simulated object, diagnostics,
and interpretation path; #230 explicitly treats that as a later public
article/tooling gate.

## 4. Checks Run

- `gh run watch 26353374213 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> post-merge `main` R-CMD-check for PR #242 passed on Ubuntu in
  23m08s, macOS in 27m17s, and Windows in 35m17s.
- `gh run watch 26354017845 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> downstream pkgdown deploy for PR #242 passed in 7m57s. GitHub
  emitted a Node.js 20 deprecation annotation for Pages actions; the
  run succeeded.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"` -> only recent
  merged article/tooling lanes and their source-branch commits were
  present; no competing open PR was detected.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 5 --json databaseId,workflowName,status,conclusion,headSha,displayTitle,createdAt,updatedAt,url,event`
  -> latest `R-CMD-check` and `pkgdown` on main commit `6a6cd81`
  were successful.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/response-families", quiet = FALSE, new_process = FALSE)'`
  -> completed; `pkgdown-site/articles/response-families.html` was
  created.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n "FAM-|MIX-10|Scope boundary|family_to_id|delta/hurdle|response-scale|model/link-scale" vignettes/articles/response-families.Rmd pkgdown-site/articles/response-families.html`
  -> source and rendered HTML both contain the new boundary and
  delta/hurdle caveats.
- `rg -n "gllvmTMB\\(|traits\\(" vignettes/articles/response-families.Rmd`
  -> long-format examples pass `trait =`; the wide example uses
  `traits(...)` and no `trait =`.
- `rg -n "Currently supported|gaussian\\(\\)|binomial\\(\\)|poisson\\(\\)|lognormal\\(\\)|Gamma\\(\\)|nbinom2\\(\\)|tweedie\\(\\)|Beta\\(\\)|betabinomial\\(\\)|student\\(\\)|truncated_poisson\\(\\)|truncated_nbinom2\\(\\)|delta_lognormal\\(\\)|delta_gamma\\(\\)|ordinal_probit\\(\\)" R/fit-multi.R vignettes/articles/response-families.Rmd docs/design/35-validation-debt-register.md`
  -> the article's quick lookup agrees with the current
  `family_to_id()` supported list and with the cited register rows.
- `rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(" vignettes/articles/response-families.Rmd`
  -> no matches.
- `git diff --check` -> clean.

## 5. Tests of the Tests

No tests were added or modified. This is an article-only
scope-boundary change. The executable guard is the touched article
render, which would fail if the shown examples or chunk syntax were
unsupported.

## 6. Consistency Audit

Rose verdict: PASS.

- Method/default/family claims: the quick-lookup list matches the
  current `family_to_id()` "Currently supported" message in
  `R/fit-multi.R`.
- Scope-boundary claims: the article now cites FAM and MIX register
  row IDs for covered, partial, and blocked claims.
- Long-format convention: long `gllvmTMB()` examples still pass
  `trait =`; the wide example still uses `traits(...)`.
- Stale-wording scan found no legacy `S_B` / `S_W`, deprecated primary
  syntax, primary `gllvmTMB_wide()`, or profile-default wording in the
  touched article.
- Convention-change cascade: not applicable. No argument name, keyword
  default, function signature, or syntax requirement changed.

## 7. Roadmap Tick

N/A. This slice does not change ROADMAP status. It advances the #230
article-surface reset by making one visible technical reference safer
to publish.

## 7a. GitHub Issue Ledger

- Inspected #230, "Article surface reset and user-first tooling gate".
  This slice advances the "article inventory plus validation-debt row
  status before public claims" gate.
- No issue was closed. #230 remains broader than this single article
  update.

## 8. What Did Not Go Smoothly

No implementation blocker. The main constraint was wording the
delta-family boundary precisely: `delta_lognormal()` and
`delta_gamma()` are engine-mapped standard hurdle likelihoods, but the
article must not imply response-scale total correlations or
mixed-family delta/hurdle correlations are current supported
interpretations.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the lane to one visible article after waiting for PR #242
main CI and pkgdown deploy.

Pat: the page stays useful as a lookup because it does not turn into a
second worked example; it now tells readers where the family boundary
is before they over-interpret delta-family correlations.

Rose: row IDs belong near public family claims, not only in the
validation-debt register.

Grace: local gates were the touched article render,
`pkgdown::check_pkgdown()`, source/rendered consistency, and then PR CI.

No spawned subagents were running.

## 10. Known Limitations And Next Actions

- The article still is not the mixed-response worked example.
- Delta-family response-scale correlations remain undefined in this
  article, and mixed-family delta/hurdle correlations remain blocked
  under MIX-10.
- Next safest action: open a narrow article PR and let CI validate it
  before merge.
