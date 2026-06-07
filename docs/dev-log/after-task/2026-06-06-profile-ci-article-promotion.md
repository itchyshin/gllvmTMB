# After Task: Profile-Likelihood CI Article Promotion

**Branch**: `codex/profile-ci-article-promotion-2026-06-06`
**Date**: `2026-06-06`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`

## 1. Goal

Start the #347 Wave-1 article-promotion lane with the smallest ready page:
`profile-likelihood-ci`.

The slice promotes one article only. `troubleshooting-profile` remains internal
until the split-vs-merge governance decision is recorded separately.

## 2. Implemented

- Moved `articles/profile-likelihood-ci` from the `_pkgdown.yml` internal
  article bucket into the public `Methods` group.
- Added the profile article to the public navbar under `Articles -> Methods`.
- Added the exported `tmbprofile_wrapper()` helper to the pkgdown Reference
  index under advanced validation utilities, closing the #347 discoverability
  gap.
- Left `articles/troubleshooting-profile` internal.

No R code, examples, roxygen, generated Rd files, tests, NEWS, README, or
validation-debt rows changed.

## 3. Files Changed

- `_pkgdown.yml` -- public article/nav move and Reference-index addition.
- `docs/dev-log/check-log.md` -- command log and interpretation.
- `docs/dev-log/after-task/2026-06-06-profile-ci-article-promotion.md` -- this
  report.

## 4. Checks Run

- `ruby -e 'require "yaml"; YAML.load_file("_pkgdown.yml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- `rg -n "profile-likelihood-ci|tmbprofile_wrapper|troubleshooting-profile" _pkgdown.yml vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/troubleshooting-profile.Rmd`
  -> confirmed the article move, internal companion-page status, and
  `tmbprofile_wrapper()` visibility.
- `rg -n "profile-likelihood default|extract_correlations\\([^\\n]*method *= *\\\"profile\\\"|gllvmTMB_wide\\(Y|meta_known_V|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(" vignettes/articles/profile-likelihood-ci.Rmd _pkgdown.yml`
  -> no hits.
- `rg -n "CI-0[1-9]|CI-10|EXT-13|M3|covered|partial|Preview" vignettes/articles/profile-likelihood-ci.Rmd docs/design/35-validation-debt-register.md`
  -> article Preview banner and register rows remain aligned.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/profile-likelihood-ci", lazy = FALSE, quiet = FALSE)'`
  -> rendered `pkgdown-site/articles/profile-likelihood-ci.html`.
- `rg -n "Profile-likelihood confidence intervals|profile-likelihood-ci.html|tmbprofile_wrapper.html|Profile-likelihood CIs" pkgdown-site/articles/profile-likelihood-ci.html pkgdown-site/articles/index.html pkgdown-site/reference/index.html`
  -> rendered article/index/reference links are present.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `✔ No problems found.`
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'ns <- readLines("NAMESPACE"); ref <- readLines("_pkgdown.yml"); stopifnot(any(ns == "export(tmbprofile_wrapper)")); stopifnot(any(trimws(ref) == "- tmbprofile_wrapper")); cat("export-reference-ok\n")'`
  -> `export-reference-ok`.

## 5. Definition-of-Done Notes

1. **Implementation**: local branch only at report time; PR / CI still needed.
2. **Simulation recovery test**: not applicable. This is a docs/navigation
   promotion and does not add a likelihood, family, keyword, or estimator.
3. **Documentation**: `_pkgdown.yml` navigation and Reference index updated;
   no roxygen/Rd content changed.
4. **Runnable user-facing example**: the existing promoted article rendered
   locally with `pkgdown::build_article(..., lazy = FALSE)`.
5. **Check-log entry**: added in `docs/dev-log/check-log.md`.
6. **Review pass**: Pat/Rose/Grace scope. No Boole/Gauss/Noether trigger
   because no API, formula grammar, likelihood, or TMB plumbing changed.

## 6. Scope Boundary

IN: `profile-likelihood-ci` is public in the Methods group and keeps its
existing Preview boundary for Gaussian CI evidence (`CI-02..CI-07` covered).

PARTIAL: non-Gaussian and mixed-family CI coverage remains M3 work (`CI-08`,
`CI-10` partial). The article's banner already says this.

PLANNED: `troubleshooting-profile` remains internal pending the companion-page
governance decision from #347.

## 7. Reviewer Notes

**Pat**: the article already has a runnable long/wide example and a clear
three-method API path.

**Rose**: the promoted slice keeps the Preview banner and does not change
capability claims. The stale-term scan found no new drift, and the
export-to-Reference parity check covers `tmbprofile_wrapper()`.

**Grace**: local article render and `pkgdown::check_pkgdown()` passed.

**Ada**: this is intentionally one article, not the full profile pair, because
#347 says article promotion should proceed one at a time.
