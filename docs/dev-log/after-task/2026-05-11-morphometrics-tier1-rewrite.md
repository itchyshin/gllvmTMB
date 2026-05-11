# After Task: Morphometrics Tier-1 Rewrite

## Goal

Implement Phase 1, Priority 1a row 1: make
`vignettes/articles/morphometrics.Rmd` the first concrete application
of the long-format plus wide-format article convention, and replace
the legacy live helper calls identified in the Priority 1a proposal.

This is the Codex implementation task. Claude's prior role was the
proposal and coordination lane: article audit, task allocation, and
Shannon cross-team reports.

Status: implementation and local validation complete. The matching
`docs/dev-log/check-log.md` entry was appended after PR #25 merged and
the append-order collision was cleared.

## Implemented

- Rewrote the article opening so the reader sees the biological
  question before the model equation.
- Added explicit long and wide data objects in the simulation setup.
- Paired every live model-fit example in the article with the
  corresponding long and wide formula:
  - main `latent(d = 2) + unique()` fit;
  - first replicate in the recovery loop, used as an equivalence
    check without doubling every recovery fit;
  - comparison fits for `latent(d = T)`, `dep()`, and `indep()`.
- Added live log-likelihood equality checks for long versus wide
  examples.
- Replaced the article's legacy `getLoadings()` and `ordiplot()` live
  calls with `extract_ordination()`, `rotate_loadings()`, and
  `plot(fit, type = "ordination", level = "unit")`.
- Removed the rendered bootstrap CI path from the communality section.
  The article uses `extract_correlations()` with its fast Fisher-z /
  Wald default and `extract_communality()` point estimates.
- Fixed a wrapper-warning issue where canonical `level = "unit"`
  calls were internally translated to legacy `"B"` and then warned
  when public wrappers called public extractors.
- Updated roxygen/Rd wording around canonical `unit` / `unit_obs`
  levels and CI method descriptions.
- Replaced a remaining public plot subtitle that displayed internal
  `B` / `W` tier names with between-unit / within-unit wording.

## Mathematical Contract

The model equation, formula syntax, and implementation target are the
same object:

`latent(0 + trait | individual, d = 2) + unique(0 + trait | individual)`
fits

`Sigma_B = Lambda Lambda^T + diag(s)`.

The long call uses `value ~ ...` with one row per
`(individual, trait)`. The wide call uses
`traits(length, mass, wing, tarsus, bill) ~ ...` with one row per
individual. The right-hand side is intentionally the same in both
calls.

No TMB likelihood, family, formula grammar, parser rule, or covariance
keyword was changed.

## Files Changed

- `vignettes/articles/morphometrics.Rmd`
- `R/normalise-level.R`
- `R/output-methods.R`
- `R/plot-gllvmTMB.R`
- `R/rotate-loadings.R`
- `R/extractors.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- Generated Rd files for the touched roxygen topics.
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-11-morphometrics-tier1-rewrite.md`

## Checks Run

- Read prior coordination and after-task reports:
  - `docs/dev-log/after-task/2026-05-11-second-shannon-audit.md`
  - `docs/dev-log/after-task/2026-05-11-task-allocation-doc.md`
  - `docs/dev-log/after-task/2026-05-11-long-wide-convention.md`
  - `docs/dev-log/after-task/2026-05-11-priority-1a-proposal.md`
- `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  passed: 37 tests, 0 failures, 0 warnings.
- `Rscript --vanilla -e 'devtools::test()'` passed before the final
  subtitle / roxygen wording patch: 1263 passed, 0 failed, 6 warnings,
  11 skipped, duration 1462.4 s. The warnings were existing
  deprecation-warning tests around legacy `B`, `W`, and `spde`
  aliases.
- After the final wording patch,
  `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  passed: 37 tests, 0 failures, 0 warnings, duration 11.3 s.
- After PR #25 merged and this branch appended the check-log entry,
  `Rscript --vanilla -e 'devtools::test(filter = "plot-gllvmTMB")'`
  passed again: 37 tests, 0 failures, 0 warnings, duration 11.0 s.
- Focused long/wide smoke test passed: main rank-2, saturated
  `latent(d = T)`, `dep()`, and `indep()` long/wide pairs all had
  maximum log-likelihood difference 0.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed
  and regenerated the touched Rd files.
- After the final roxygen wording patch, the same document command
  completed again and regenerated `man/extract_Sigma_B.Rd`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics")'`
  completed and wrote `articles/morphometrics.html`. It reported the
  existing `../logo.png` pkgdown warning, not an article-code failure.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  "No problems found." This was rerun after the check-log append and
  still passed.
- `git diff --check` passed.
- `_R_CHECK_SYSTEM_CLOCK_=FALSE Rscript --vanilla -e 'devtools::check(document = FALSE, manual = FALSE, args = "--no-tests", quiet = FALSE, error_on = "never")'`
  completed with 0 errors, 1 warning, and 1 note. The warning was an
  Apple clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension'`.
  The note was the pre-existing duplicated `tidyselect` entry in
  `Imports` and `Suggests`. Neither comes from this morphometrics
  branch; `DESCRIPTION` is also in an open citation-policy PR lane, so
  this task did not edit it.

## Tests Of The Tests

- The new plot-wrapper regression checks assert that canonical
  `level = "unit"` calls do not warn in `getLoadings()`, `getLV()`,
  `rotate_loadings()`, and `plot(type = "ordination")`.
- Existing legacy-alias plot checks still assert that explicit
  `level = "B"` / `"W"` calls warn as deprecated aliases.
- The article smoke test compares long and wide log-likelihoods for
  every model family shown in the article's live fit examples.
- The final plot-wrapper focused test re-exercises the only code path
  touched after the full suite: public `unit` / `unit_obs` names flowing
  through plotting, loadings, score, and rotation wrappers without
  accidental legacy-alias warnings.

## Consistency Audit

- `rg -n "gllvmTMB\\(|gllvmTMB_wide\\(|traits\\(" vignettes/articles/morphometrics.Rmd`
  shows each live fit context has a long and wide formula pair: the
  main fit, the first recovery-loop fit, and the three comparison
  fits.
- `rg -n "getLoadings\\(|ordiplot\\(|extract_ICC_site\\(|extract_residual_split\\(" vignettes/articles/morphometrics.Rmd`
  returns no live legacy-helper hits.
- `rg -n "Upper triangle: between \\(B\\)|Between-unit \\(B\\)|Within-unit \\(W\\)|level = \\\"B\\\"|level = \\\"W\\\"|global / between|local / within|profile-likelihood default|method = \\\"bootstrap\\\"" vignettes/articles/morphometrics.Rmd R/extractors.R R/output-methods.R R/plot-gllvmTMB.R R/rotate-loadings.R man/extract_Sigma_B.Rd man/extract_Sigma_W.Rd man/extract_communality.Rd man/extract_ordination.Rd man/getLV.Rd man/getLoadings.Rd man/getResidualCov.Rd man/plot.gllvmTMB_multi.Rd man/rotate_loadings.Rd tests/testthat/test-plot-gllvmTMB.R`
  found only intentional test references to legacy `level = "B"` /
  `"W"` and internal bootstrap result labels in `extract_communality()`;
  the touched user-facing prose no longer presents `B` / `W` as the
  primary syntax.
- `rg -n "Author and maintainer|Sole developer|Authors@R|citation\\(\"gllvmTMB\"\\)|sdmTMB|TMB|fmesher|inst/CITATION|COPYRIGHTS" DESCRIPTION README.md inst/COPYRIGHTS vignettes/gllvmTMB.Rmd docs/dev-log/after-task/2026-05-11-morphometrics-tier1-rewrite.md`
  confirmed that authorship, citation, and provenance wording belong
  in their own lane. Open PR #26 covers citation policy; PR #23
  (Phase 3 design docs), PR #24 (after-task protocol), and PR #25
  (PR #22 check-log evidence) have now merged to `origin/main`. This
  branch did not edit the provenance files.
- `gh pr list --state open --json number,title,headRefName,author,updatedAt --limit 30`
  showed the active open-PR queue. `gh pr view 25 --json files`
  confirmed PR #25 also edited `docs/dev-log/check-log.md`; Codex
  posted coordination comments on PR #25, waited for it to merge, then
  appended this branch's check-log entry after `origin/main` included
  merge commit `50d5382`.

## What Did Not Go Smoothly

- I initially stopped after pairing the main fit only. The maintainer
  clarified that every live fit example on the page should show the
  long and wide formulas. The recovery and comparison sections were
  then patched to follow the stronger rule.
- I initially attempted a communality CI path that would fall into
  bootstrap. The maintainer clarified that profile or Wald-style
  intervals should be the ordinary route, with bootstrap only a
  deliberate optional check. The rendered article now avoids the
  bootstrap path.
- The working tree briefly drifted onto Claude/agent branches while
  the dirty Codex edits were present. The edits were moved back to
  `codex/morphometrics-tier1-rewrite` and the branch was
  fast-forwarded to current `main`.
- Full `devtools::test()` spent 689.8 s in `phylo-q-decomposition`
  and 349.7 s in `profile-ci`. This was not a failure, but it is a
  reminder that full-suite checks are now long enough to reserve for
  meaningful closure points.
- The package check surfaced two non-branch issues: the Apple clang
  warning from an R header, and duplicated `tidyselect` in
  `DESCRIPTION`. The latter belongs in the citation / metadata lane,
  not this article rewrite, especially while Claude-owned metadata PRs
  are open.

## Team Learning

- The phrase "long + wide examples" must mean every live fit example
  a reader sees, not only the first or canonical example.
- Cross-checking after-task reports is useful before implementation:
  the Shannon, task-allocation, long/wide, and Priority 1a reports
  together explain who owns the task and what must be verified.
- Wrapper-to-wrapper calls should pass canonical boundary names back
  into public extractors. Internal `"B"` / `"W"` names are fine inside
  implementation slots, but they should not leak into user-facing
  warning paths when the user typed `level = "unit"`.
- The drmTMB mean-scale covariance after-task report is a useful
  standard for gllvmTMB closures: name the mathematical contract, list
  tests-of-tests, record exact `rg` audits with verdicts, and say
  plainly what went wrong.
- Authorship and acknowledgement need their own focused PR. The
  maintainer decision for the next lane is: describe Shinichi as
  "Author and maintainer of gllvmTMB"; add a custom `inst/CITATION`;
  acknowledge TMB, sdmTMB, fmesher, MCMCglmm / Hadfield, glmmTMB /
  reduced-rank lineage, and GALAMM where relevant; keep legal
  copyright/provenance narrower than public acknowledgements.

## Known Limitations

- This PR only rewrites `morphometrics.Rmd`. The remaining Phase 1
  articles still need their own long/wide pairing passes.
- The existing pkgdown logo warning during article rendering remains
  outside this task.
- The no-tests package check is not fully clean on this machine because
  of the Apple clang warning and duplicated `tidyselect` note described
  above. No morphometrics-specific check failure remains.
- Citation / provenance cleanup is intentionally left to PR #26 and
  follow-up metadata work.

## Next Actions

1. Open this morphometrics PR after final lightweight checks, then
   watch CI without fix-up churn.
2. Start a separate acknowledgement / provenance PR after the open
   Claude metadata/citation lanes settle.
3. Return to `vignettes/gllvmTMB.Rmd` / the landing path after
   morphometrics lands, using this article as the Tier-1 exemplar.
