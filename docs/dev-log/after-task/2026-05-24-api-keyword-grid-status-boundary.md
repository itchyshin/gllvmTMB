# After Task: Formula Keyword Grid Status Boundary

**Branch**: `codex/api-keyword-grid-status-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: Ada, Boole, Pat, Rose, Grace

## 1. Goal

Make the visible Formula keyword grid technical reference honest about
which keyword-row claims are covered, partial, or blocked in the
current validation-debt register.

## 1a. Mathematical Contract

No formula grammar, likelihood, parameterisation, family constructor,
or extractor behaviour changed. This task only changes prose and
example snippets in `vignettes/articles/api-keyword-grid.Rmd`.

The article now separates the public grid into row-ID backed states:

| Claim | Article wording | Register evidence |
|---|---|---|
| Core no-correlation grammar and Gaussian `latent() + unique()` | covered core; standalone `indep()` / `dep()` partial; no public no-prefix scalar keyword | FG-01--FG-06 and FAM-01 covered; FG-07--FG-09 partial |
| Animal covariance keywords and relatedness inputs | five covariance cells covered; slope and cross-package agreement partial | ANI-01--ANI-05, ANI-07, ANI-08 covered; ANI-06, ANI-09, ANI-10 partial |
| Phylogenetic covariance row | main paired decomposition covered; scalar, marginal-only, saturated, and slope paths partial | FG-12 and PHY-01--PHY-03 covered; PHY-04--PHY-06 partial |
| Spatial row | mesh/dispatch/orientation/alias checks covered; covariance recovery depth partial | SPA-01 and SPA-05--SPA-07 covered; SPA-02--SPA-04 partial |
| `meta_V()` helper | exact single-V partial, block-V covered, proportional mode blocked | MET-01 partial; MET-02 covered; MET-03 blocked; MET-04 partial |

## 2. Implemented

- Replaced compressed whole-row `partial` labels in
  `vignettes/articles/api-keyword-grid.Rmd` with row-ID backed
  covered/partial/blocked statements.
- Added a per-cell `animal_*` syntax section because the public grid
  already lists those keywords and ANI-01--ANI-05 are covered.
- Added `animal_slope()` helper caveat with ANI-06.
- Expanded `meta_V()` helper caveat with MET-01, MET-02, and MET-03.

## 3. Files Changed

- Public article: `vignettes/articles/api-keyword-grid.Rmd`.
- Dev log: `docs/dev-log/check-log.md`.
- After-task report:
  `docs/dev-log/after-task/2026-05-24-api-keyword-grid-status-boundary.md`.

No generated pkgdown files were committed. The rendered
`pkgdown-site/articles/api-keyword-grid.html` was used for QA only.

## 3a. Decisions and Rejected Alternatives

Decision: keep this article Tier 2.

Rationale: its YAML already declares
`tier: 2 # technical reference for the covariance keyword grammar`.
The page is a lookup table and syntax reference, not a worked example.

Rejected alternative: promote the hidden animal-model article or add a
full animal worked example here. That would change the reader path and
needs a separate Tier-1 article review. This slice only makes the
existing technical reference internally honest.

## 4. Checks Run

- `gh run watch 26355011907 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> post-merge `main` R-CMD-check for PR #243 passed on Ubuntu in
  27m38s, macOS in 28m29s, and Windows in 35m49s.
- `gh run watch 26355720491 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> downstream pkgdown deploy for PR #243 passed in 7m33s. GitHub
  emitted a Node.js 20 deprecation annotation for Pages actions; the
  run succeeded.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"` -> only recent
  merged article/tooling lanes and their source-branch commits were
  present; no competing open PR was detected.
- `git status --short --branch` -> `## main...origin/main`.
- `rg -n "Scope boundary|validation-debt|FAM-|FG-|COV-|MIX-|covered|partial|blocked" vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd README.md`
  -> found `api-keyword-grid.Rmd` still compressed whole keyword rows
  instead of citing the current validation rows.
- `rg -n "animal_scalar|animal_unique|animal_indep|animal_dep|animal_latent|animal_slope" R man docs/design/01-formula-grammar.md docs/design/14-known-relatedness-keywords.md`
  -> confirmed the animal examples match exported signatures and the
  design tables.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/api-keyword-grid", quiet = FALSE, new_process = FALSE)'`
  -> completed; `pkgdown-site/articles/api-keyword-grid.html` was
  created.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n "ANI-|PHY-|SPA-|MET-|FG-|animal_scalar|animal_slope|meta_V\\(|proportional known-V|sparse A\\^-1" vignettes/articles/api-keyword-grid.Rmd pkgdown-site/articles/api-keyword-grid.html`
  -> source and rendered HTML both contain the new row IDs, animal
  examples, and helper caveats.
- `rg -n "gllvmTMB\\(|traits\\(|trait =" vignettes/articles/api-keyword-grid.Rmd pkgdown-site/articles/api-keyword-grid.html`
  -> the long-format example passes `trait =`; the wide example uses
  `traits(...)` and no `trait =`.
- `rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(|\\bscalar\\(" vignettes/articles/api-keyword-grid.Rmd`
  -> no matches.
- `node_repl: await import("playwright")`
  -> unavailable in this session, so no Playwright screenshot was
  taken. The rendered HTML was checked via pkgdown render plus
  source/rendered rg scans.
- `git diff --check` -> clean.

## 5. Tests of the Tests

No tests were added or modified. This is an article-only
status-boundary change. The executable guard is the touched article
render, which would fail if the shown examples or chunk syntax were
unsupported.

## 6. Consistency Audit

Rose verdict: PASS.

- Keyword-grid claims now cite validation-debt row IDs for covered,
  partial, and blocked states.
- Boole syntax check: `animal_*` examples match exported signatures
  and design-table syntax; no grammar changed.
- Long-format convention: the only full long `gllvmTMB()` example
  still passes `trait =`; the wide example uses `traits(...)`.
- Stale-wording scan found no legacy `S_B` / `S_W`, deprecated primary
  syntax, primary `gllvmTMB_wide()`, profile-default wording, or
  public no-prefix `scalar()` example in the touched article.
- Convention-change cascade: not applicable. No argument name, keyword
  default, function signature, or syntax requirement changed.

## 7. Roadmap Tick

N/A. This slice does not change ROADMAP status. It advances the #230
article-surface reset by making one visible technical reference safer
to publish.

## 7a. GitHub Issue Ledger

- This slice advances #230, "Article surface reset and user-first
  tooling gate", by improving a visible technical reference.
- No issue was closed. #230 remains broader than this single article
  update.

## 8. What Did Not Go Smoothly

The first wording pass accidentally mentioned a no-prefix `scalar()`
keyword in the `none` row. A quick source/export scan caught that
before validation, and the article now says the scalar cell has no
public no-prefix keyword.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the lane bounded to one visible technical reference after
waiting for PR #243 main CI and pkgdown deploy.

Boole: status prose can mention row families without implying every
cell has the same validation depth.

Pat: a lookup table becomes safer when partial cells are visible at
the point of syntax choice, not hidden in a design register.

Rose: row-level `partial` labels were too coarse now that the animal
and phylo rows have covered subpaths; public prose should point to the
actual row IDs.

Grace: local gates were the touched article render,
`pkgdown::check_pkgdown()`, source/rendered consistency, and then PR CI.

No spawned subagents were running.

## 10. Known Limitations And Next Actions

- This did not make the hidden animal, phylogenetic, spatial, or
  meta-analysis articles public.
- `animal_slope()` recovery depth, scalar/indep/dep phylo depth,
  spatial covariance recovery depth, exact single-V inference, and
  proportional `meta_V()` remain at the statuses stated in the
  validation-debt register.
- Next safest action: open a narrow article PR and let CI validate it
  before merge.
