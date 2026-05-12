# After-Task: Response Families Tier-2 Reference

## Goal

Port the response-family reference into the current public site as a
Tier-2 lookup page, while correcting the stale legacy claim that every
exported constructor in `R/families.R` is already wired into the
multivariate engine.

## Scope

This task adds one article:

- `vignettes/articles/response-families.Rmd`

Supporting hygiene updates are limited to `_pkgdown.yml`, `NEWS.md`,
`vignettes/articles/choose-your-model.Rmd`, and
`docs/dev-log/check-log.md`.

## Reader And Tier

The reader is an applied or methods user who already chose a
stacked-trait model and now needs to pick a response likelihood. Tier
2 is justified because this is a lookup reference, not a new worked
biological example.

## Contract

The article distinguishes:

- the 15 families mapped by `family_to_id()` in `R/fit-multi.R`; and
- exported helper constructors in `R/families.R` that are not yet
  mapped by the multivariate engine.

No family implementation, likelihood parameterisation, formula
grammar, or exported API changed.

## Checks Run

Before editing:

- `git status --short --branch` showed a clean
  `codex/api-keyword-grid-tier2` branch.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json ...`
  showed only PR #46, the current branch.
- `git log --all --oneline --since="6 hours ago"` confirmed the
  recent Claude audit PRs had already merged and no other open branch
  owned the response-family article.

Final validation:

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/response-families", new_process = FALSE); pkgdown::build_article("articles/choose-your-model", new_process = FALSE)'`:
  passed. Both renders emitted only the known missing `../logo.png`
  pkgdown warning.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`:
  passed with "No problems found".
- Rose pre-publish gate: PASS. The engine-supported family list
  matches the 15 `family_to_id()` entries in `R/fit-multi.R`; exported
  but unmapped constructors are listed as unsupported in multivariate
  fits; the stale `mixed-response.html` links in `choose-your-model`
  now point to `response-families.html`; and the two-part-family
  caveat matches `R/extract-correlations.R` / `R/extract-sigma.R`.
- `git diff --check`: passed.

## Consistency Audit

The article was checked against:

- `R/fit-multi.R` for the actual engine-supported family mapping;
- `R/families.R` and `NAMESPACE` for exported constructors;
- `tests/testthat/test-stage37-mixed-family.R` for the long-format
  mixed-family API;
- `vignettes/articles/choose-your-model.Rmd` for stale links to the
  not-yet-ported mixed-response article.

## What Did Not Go Smoothly

The legacy dispatch note said the current package supported the full
set named in `R/families.R`. A source cross-check showed a narrower
truth: only the 15 `family_to_id()` entries are currently documented
engine families. The article now names the other exported constructors
as unsupported in multivariate fits rather than advertising them.

The correlation wording also needed narrowing. `extract_correlations()`
reports fitted covariance-tier correlations; two-part families can
support those latent/link-scale correlations, but raw observed-response
correlations need a separate estimand that the current article does not
define.

## Team Learning

- **Boole** owns the API distinction: exported constructor is not the
  same as multivariate engine support.
- **Pat** owns reader fit: start with the quick lookup, then show the
  family argument in long, wide data-frame, and wide matrix forms.
- **Rose** owns cross-file consistency: family claims must match
  `R/fit-multi.R`, `R/families.R`, `NAMESPACE`, and public articles.

## Known Limitations And Next Actions

The mixed-response article remains a separate queue item because it
needs a runnable analysis and interpretation, not just the
`family = list(...)` dispatch snippet. The ordinal-probit article also
remains separate because it needs its own latent-threshold explanation.
