# Public workflow polish: diagnostics, model selection, and REML

## Task goal

Make the public article path read in the order an applied user should use it:
diagnose the fitted model, compare one ML candidate set with AIC/BIC, interpret
the selected Gaussian latent-rank model, then use `REML = TRUE` only as a final
Gaussian covariance refit.

## Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
README, NEWS, roadmap, validation-register, or pkgdown navigation change. The
article still describes the same Gaussian `latent() + unique()` model,
`Sigma = Lambda Lambda^T + Psi`; this task only changed prose order and
cross-links.

## Files changed

- `vignettes/articles/model-selection-latent-rank.Rmd`
- `vignettes/articles/fit-diagnostics.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-09-public-workflow-polish.md`

## Checks run

- Full pkgdown site build:
  `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::build_site(preview = FALSE, lazy = FALSE, install = TRUE, new_process = TRUE)'`
  passed and rendered all articles under a temp-installed current checkout.
- Targeted article renders:
  `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); pkgdown::build_article("articles/model-selection-latent-rank", lazy = FALSE, new_process = FALSE)'`
  passed.
  `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); pkgdown::build_article("articles/fit-diagnostics", lazy = FALSE, new_process = FALSE)'`
  passed.
- pkgdown consistency:
  `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  passed with `No problems found`.
- Rendered HTML check:
  `rg -n "A safe reporting order|Read AIC And BIC Beside Diagnostics|Interpret The Selected Model|Refit The Selected Gaussian Model With REML|Use one ML candidate table|How many latent dimensions should I fit|only after a Gaussian model has been chosen" pkgdown-site/articles/model-selection-latent-rank.html pkgdown-site/articles/fit-diagnostics.html`
  found the intended workflow wording and section order.
- Browser preview:
  `http://127.0.0.1:8123/articles/model-selection-latent-rank.html` showed
  the expected headings in order and no horizontal overflow.
- Whitespace:
  `git diff --check` passed.

## Consistency audit

- Long-format call / register-row scan:
  `rg -n "gllvmTMB\\(|trait = \"trait\"|REML|AIC|BIC|DIA-08|DIA-10|MIS-33|FG-04|FG-06" vignettes/articles/model-selection-latent-rank.Rmd vignettes/articles/fit-diagnostics.Rmd docs/design/35-validation-debt-register.md`
  confirmed long-format examples retain `trait = "trait"` and that the article
  claims map to covered rows FG-04, FG-06, DIA-08, DIA-10, and MIS-33.
- Stale terminology / overclaim scan:
  `rg -n "gllvmTMB_wide|meta_known_V|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|REML.*non-Gaussian|non-Gaussian.*REML" vignettes/articles/model-selection-latent-rank.Rmd vignettes/articles/fit-diagnostics.Rmd || true`
  found only the intentional negative boundary that the article does not
  advertise REML for non-Gaussian fits.
- Navigation preview:
  the local article dropdown contains the public path and no JSDM/profile-CI
  dropdown links.

## Tests of the tests

No tests were added. The integration test for this prose move is article
rendering: moving the REML chunk exposed stale installed-package state during
the first render attempt, and the full `pkgdown::build_site(..., install = TRUE)`
run confirmed the article executes against the current checkout.

## What did not go smoothly

`Rscript` and `pandoc` were not on the default shell path. The first
`pkgdown::build_articles(lazy = FALSE)` attempt also used stale installed
package state and stopped before the current-source render path. The final
full-site build used `PATH="/opt/homebrew/bin:$PATH"` and `install = TRUE`,
which matches CI more closely and rendered the moved REML chunk successfully.

## Team learning

Ada kept this as an article workflow slice instead of starting new capability.
The useful order is now visible in prose and in the article sections.

Pat's reader path is clearer: a new user sees diagnostics first, then ML
AIC/BIC comparison, then interpretation, then REML only as the chosen Gaussian
model's covariance refit.

Rose caught the scope boundary and stale-term risks. The article still says
what is in scope and what is not, with MIS-33 for Gaussian REML and DIA rows for
diagnostics.

Grace's build check mattered: targeted renders passed only after forcing local
source, and the full site build with temp-install is the stronger evidence.

## Design docs, pkgdown, and roadmap

No design-doc, README, NEWS, generated Rd, or roadmap source change was needed.
`pkgdown-site` was rebuilt locally for preview, but the committed source change
is the two article `.Rmd` files plus the dev-log artefacts.

**Roadmap tick**: N/A. This advances the public learning path under existing
article-completion work but does not change a `ROADMAP.md` status row.

## GitHub issue ledger

Inspected:

- #230, article surface reset and user-first tooling gate.
- #347, article completion / public learning path.

This slice advances both but does not close either. No new issue was created.

## Known limitations and next actions

The scheduled Power pilot replacement run `27225948960` was still in progress
at the last poll, with 46 completed-success jobs, three active shards, and no
failed or cancelled jobs. The previous red run `27214714881` failed because
GitHub reported a runner shutdown / cancellation, not because a power cell
assertion failed.
