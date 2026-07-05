# After Task: Covariance/Correlation Model-First Accessibility

**Branch**: `codex/covariance-correlation-accessibility-20260622`
**Date**: `2026-06-22`
**Roles (engaged)**: `Ada / Pat / Noether / Rose / Grace`

## 1. Goal

Make the `covariance-correlation` Concepts article easier and more honest for
readers by starting with the fitted Gaussian teaching model, then introducing
`Sigma` as the covariance implied by that model. This follows the maintainer
direction that `Sigma` is important, but it is not itself the model.

## 2. Implemented

- Renamed the article to `Covariance and correlation: the model behind Sigma`.
- Added Tier-2 metadata to mark the article as a Concepts reference.
- Rewrote the opening around the Gaussian stacked-trait model:
  `y_it = mu_t + lambda_t^T u_i + epsilon_it`, with `u_i ~ N(0, I_d)` and
  `epsilon_it ~ N(0, psi_tt)`.
- Added plain-language definitions of `mu_t`, `u_i`, and `psi_tt`.
- Made the `Sigma` teaching point explicit: `Sigma` is the model-implied
  covariance summary, not the model itself.
- Reframed the `Lambda`, `Psi`, `Sigma`, and `R` table around model object,
  R syntax, and report-ready interpretation.
- Changed a plot title from `Latent + unique trait correlations` to
  `Ordinary latent trait correlations`.
- Reworded the OLRE section from "unique component" to "diagonal component".

## 3. Files Changed

- `vignettes/articles/covariance-correlation.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-covariance-correlation-model-first-accessibility.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a narrow Concepts-article PR rather than widening into
more article rewrites.

Rationale: PRs #529, #530, and #531 already changed the beginner path,
navigation, and Developer Notes labels. This slice fixes one high-value
Concepts article without reopening the entire article taxonomy.

Rejected alternative: delete or retire advanced article material in the same
PR. That belongs in a separate article-tier audit.

Confidence: high for article accessibility and low deployment risk; no parser,
TMB, or examples API changed.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,statusCheckRollup --limit 20`
  -> `[]`; no open PR overlap before the slice.
- `git log --all --oneline --since='6 hours ago' --decorate`
  -> recent merged #529/#530/#531 sequence only, plus unrelated
  `origin/power-pilot-results`; no competing covariance/correlation article
  edit detected.
- Reran before shared dev-log edits:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,statusCheckRollup --limit 20`
  -> `[]`.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/covariance-correlation", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> PASS; rendered `pkgdown-site/articles/covariance-correlation.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS (`No problems found`).
- `rg -n "gllvmTMB\(" vignettes/articles/covariance-correlation.Rmd`
  -> PASS with manual API-shape check; long examples include `trait =`, wide
  examples use `traits(...)` through `gllvmTMB()`.
- `rg -n "Covariance and correlation: the model behind Sigma|Start from the model|Sigma is not the model itself|Ordinary latent trait correlations" pkgdown-site/articles/covariance-correlation.html`
  -> PASS for title, opening, and updated plot title. The `Sigma is not...`
  prose was line-wrapped in the rendered HTML, so that exact single-line
  alternative did not match.
- `git diff --check`
  -> PASS.

## 5. Tests of the Tests

No tests were added or modified. The relevant gate is article rendering plus
pkgdown validation because this PR changes prose and rendered article output
only.

## 6. Consistency Audit

- `rg -n "Latent \+ unique|unique component|unique variance|trait-specific unique|gllvmTMB_wide|Lamdba|depreciat|depriciat|loadings-only by default|latent\(\) now includes|no-residual low-rank" vignettes/articles/covariance-correlation.Rmd`
  -> PASS; no matches.
- `rg -n "gllvmTMB_wide|meta_known_V|diag\(U\)|diag\(S\)|\\bf S|\bS_B\b|\bS_W\b|profile-likelihood default|removed in 0\.2\.0|primary new-user API|\bphylo\(|\bgr\(|\bmeta\(|phylo_rr\(" vignettes/articles/covariance-correlation.Rmd`
  -> PASS; no matches.
- Manual consistency pass: `latent()` remains the ordinary default with its
  diagonal Psi companion; `latent(..., unique = FALSE)` appears only as the
  deliberate loadings-only comparison.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed. This PR is a targeted article-accessibility
slice under the already-open article-surface reset.

## 7a. GitHub Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search "covariance-correlation OR covariance correlation OR Sigma Lambda Psi OR article accessibility" --json number,title,url,labels,updatedAt --limit 20`
  -> #230 and #347 are the relevant documentation/article-track issues.
- #230 `Article surface reset and user-first tooling gate`
  <https://github.com/itchyshin/gllvmTMB/issues/230> remains open.
- #347 `[roadmap] Article completion (public learning path)`
  <https://github.com/itchyshin/gllvmTMB/issues/347> remains open.

## 8. What Did Not Go Smoothly

The first render pass exposed one small prose issue rather than a build error:
the covariance display equation inherited a trailing comma inside the display
math. It was removed before final validation.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the article queue in small PRs after the larger navigation work.

Pat: beginner readers need the actual fitted model before the covariance
objects, otherwise `Sigma`, `Lambda`, and `Psi` feel like disconnected jargon.

Noether: the article now states the model-to-summary direction explicitly:
model first, implied `Sigma` second.

Rose: stale `unique()` wording was scanned in the touched article. Compatibility
language remains only where it clarifies old formulas or the loadings-only
comparison.

Grace: `pkgdown::build_article()`, `pkgdown::check_pkgdown()`, and
`git diff --check` passed. No generated Rd, parser, or compiled code changed.

## 10. Known Limitations And Next Actions

This PR does not rewrite every Concepts article. The next bounded slices should
continue with article-by-article accessibility passes, especially pages that
still contain heavy mathematical notation before the motivating model or reader
question.
