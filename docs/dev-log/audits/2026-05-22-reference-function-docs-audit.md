# Reference Function Documentation Audit

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Rose, Pat, Florence, Fisher, Grace
**Spawned subagents:** none

## Purpose

Move the next work lane away from new articles and toward the function surface
users meet through `?function`, pkgdown Reference, examples, and plot helper
arguments. The public articles can keep improving later, but the current
friction is in exported help pages that still describe internal classes,
legacy aliases, and developer-first wording.

This audit treats the applied user as the primary reader. They should see a
fit returned by `gllvmTMB()`, wide data-frame examples where that is the common
entry path, and report-ready tables or plots without hand-indexing matrices.

## Current Findings

| Surface | Evidence | Risk | First action |
|---|---|---|---|
| Homepage deployment | PR #233 merged to `main`, but live pkgdown still showed the old landing page while main R-CMD-check was running. | Users see stale long-first wording until the main pkgdown workflow redeploys. | Wait for main R-CMD-check and pkgdown, then verify the live homepage before pushing another public-doc PR. |
| Loadings / ordination help | `R/rotate-loadings.R`, `R/output-methods.R`, and generated Rd pages mention `gllvmTMB_multi`, `"B"` / `"W"` aliases, and "post-hoc" wording in user-facing titles and arguments. | A new user meets internals before the modelling concept. The loadings pages also sound like migration wrappers rather than a confident gllvmTMB surface. | Clean `rotate_loadings()`, `extract_ordination()`, `getLoadings()`, `getLV()`, `getResidualCov()`, `ordiplot()`, and `suggest_lambda_constraint()` as one cluster. |
| Plot helper naming | `plot_correlations()` and `plot_Sigma_table()` expose `style = "raindrop"` and `raindrop_level`. | The geometry is useful, but the name is not yet the public concept the maintainer wants. | Add a confidence-eye surface while keeping `raindrop` as a compatibility alias if feasible. |
| Method pages | `_pkgdown.yml` lists S3 pages as `print.gllvmTMB_multi`, `summary.gllvmTMB_multi`, `plot.gllvmTMB_multi`, and related internal-class topics. | Reference navigation reads like an implementation map rather than a user help index. | Retitle and group method topics around "fitted multivariate model" while preserving S3 aliases. |
| Extractor pages | Many `extract_*()` pages use `A gllvmTMB_multi fit` instead of `a fit returned by gllvmTMB()`. | Report-ready helpers look internal, even when their returned rows are the right user abstraction. | Sweep the extractor roxygen/Rd wording after the loadings cluster. |
| Diagnostics / uncertainty pages | `check_gllvmTMB()`, `gllvmTMB_diagnose()`, `bootstrap_Sigma()`, `confint_inspect()`, and validation helpers mix user entry points with developer audit wording. | Users may not know which diagnostic to run first, especially after Hessian warnings or missing interval bounds. | Make the first-line diagnostic pages action-first, then leave advanced validation pages clearly marked. |
| Deprecated aliases | `meta_known_V()`, `meta()`, `phylo()`, `spatial()`, and `gllvmTMB_wide()` still need careful wording. | Over-cleaning could imply removal; under-cleaning keeps old syntax looking primary. | Sweep later, with Rose checking soft-deprecation language against the validation-debt register. |

## Confidence Eye Decision

Florence would like the plot to make interval provenance visible without
suggesting a Bayesian posterior or a calibrated confidence distribution. The
working public term is **confidence eye**: a pale interval-derived compatibility
shape plus a brighter hollow estimate circle. CI lines should remain optional,
but the default should be visually calmer when the eye already carries the
uncertainty information.

Fisher's wording guardrail: say the eye is drawn from supplied interval bounds.
Do not say the shaded area is a posterior probability distribution unless a
method supplies that object directly.

Rose's API guardrail: if the argument name changes, keep the old `raindrop`
spelling as an alias for at least this release and document the new name in
roxygen, generated Rd, tests, and pkgdown examples together.

## First 36 Slices

| Slice | Theme | Done when |
|---|---|---|
| 1 | Verify main CI after PR #233 | Main R-CMD-check has a recorded conclusion and the pkgdown workflow is either running or its failure is diagnosed. |
| 2 | Verify live homepage | `https://itchyshin.github.io/gllvmTMB/` shows the wide-first landing copy from PR #233, or the deploy blocker is identified. |
| 3 | Commit this audit | Audit document and check-log entry record the reference-function lane. |
| 4 | Branch hygiene | Confirm no open PR/file-overlap before the first roxygen edit. |
| 5 | `rotate_loadings()` prose | Title and description say "fit returned by gllvmTMB()" and explain rotation as interpretation-preserving. |
| 6 | `rotate_loadings()` examples | Example is runnable or honestly scoped; long and wide paths are not confused. |
| 7 | `compare_loadings()` prose | Validation/comparison wording is concrete and not framed as ordinary first-use interpretation. |
| 8 | `getLoadings()` / `getLV()` prose | Migration wrappers stay available but no longer look like the primary public path. |
| 9 | `getResidualCov()` / `getResidualCor()` prose | Sigma / correlation wording uses current `Sigma` / `psi` notation. |
| 10 | `ordiplot()` prose | Page explains it as a compatibility plotting method, not the main Florence-grade plot surface. |
| 11 | Loadings cluster documentation | `devtools::document()` regenerates Rd and focused stale-word scans are clean. |
| 12 | Loadings cluster validation | `pkgdown::check_pkgdown()` and `git diff --check` are clean. |
| 13 | Confidence-eye API sketch | Decide exact spelling: likely `style = "eye"` plus `style = "raindrop"` alias, or `eye = TRUE` if less disruptive. |
| 14 | Confidence-eye geometry | Hollow estimate circle is brighter than the pale interval shape; row spacing stays even. |
| 15 | Confidence-eye line option | `show_intervals` remains available; default for eye view avoids unnecessary extra linework. |
| 16 | Confidence-eye metadata | Plot attributes still expose interval data for tests and downstream checks. |
| 17 | Confidence-eye tests | Existing raindrop tests are extended without breaking old spelling. |
| 18 | Confidence-eye docs | Roxygen and Rd use "confidence eye" and state the interval-bound limitation. |
| 19 | `plot_correlations()` polish | Help page leads with interpretation and pairwise rows, not internal class names. |
| 20 | `plot_Sigma_table()` polish | Help page leads with report-ready Sigma rows and honest interval fallback. |
| 21 | Plot helper visual QA | Render a small example and inspect row spacing, dot/eye contrast, and missing-bound rows. |
| 22 | Plot helper validation | Focused plot tests, `pkgdown::check_pkgdown()`, and `git diff --check` are clean. |
| 23 | S3 method titles | Retitle S3 help pages so pkgdown navigation is less `gllvmTMB_multi`-first. |
| 24 | S3 method examples | Keep examples minimal and runnable where feasible; avoid unsupported article-like prose. |
| 25 | `extract_Sigma()` wording | Matrix output is described as low-level; point users to `extract_Sigma_table()` for reporting. |
| 26 | `extract_Sigma_table()` wording | Return-value contract is clear for fits and bootstrap objects. |
| 27 | `extract_correlations()` wording | Pairwise row output, interval methods, and missing bounds are stated plainly. |
| 28 | Communality / repeatability wording | Pages explain point estimates versus interval-bearing bootstrap/profile outputs. |
| 29 | Ordination extractor wording | `extract_ordination()` aligns with the loadings cluster and avoids `B/W` as primary language. |
| 30 | Extractor validation | Roxygen/Rd regenerate and stale `gllvmTMB_multi` wording is limited to necessary S3/internal contexts. |
| 31 | First-line diagnostic titles | `check_gllvmTMB()`, `gllvmTMB_diagnose()`, `bootstrap_Sigma()`, and `confint_inspect()` tell users what to run next. |
| 32 | Hessian / bootstrap wording | Point estimates with weak Hessian SEs are not described as total model failure. |
| 33 | Advanced validation boundary | `coverage_study()`, `profile_targets()`, and identifiability helpers stay clearly developer/advanced. |
| 34 | Deprecated alias sweep | `gllvmTMB_wide()`, `meta_known_V()`, and alias keyword pages are marked as migration paths, not primary syntax. |
| 35 | Rose pre-publish pass | Cross-file terms, defaults, method lists, and pkgdown reference parity are checked. |
| 36 | Checkpoint report | Write a short status report with completed files, commands, known residuals, and next safest slice. |

## Held Slices 37-50

These stay out of the first push unless the first 36 finish cleanly.

| Slice range | Theme |
|---|---|
| 37-40 | Reference-index regrouping and search-result description cleanup. |
| 41-44 | Validation-debt row cross-check for every newly advertised plot/doc claim. |
| 45-47 | NEWS / README micro-cleanups only if needed to keep function docs honest. |
| 48-50 | After-task report, Shannon coordination audit, and PR handoff. |

## Evidence Commands

```sh
gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,url,mergeStateStatus
git log --all --oneline --since="6 hours ago"
rg -n 'gllvmTMB_multi|Legacy aliases|deprecated alias|level = c\("unit", "unit_obs", "B", "W"\)|post-hoc|post hoc|canonical interface|canonical replacement|long-format engine|stacked-trait|raindrop|confidence-I|extracting Sigma|matrix by hand' R man README.md _pkgdown.yml
sed -n '120,190p' _pkgdown.yml
sed -n '1,220p' R/rotate-loadings.R
sed -n '1,230p' R/output-methods.R
```

## Stop Points

Stop for maintainer discussion after this audit, after the loadings/ordination
cluster renders, after the first confidence-eye screenshot, and before any PR
push that changes plot helper arguments.
