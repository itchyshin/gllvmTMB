# After-Task: Troubleshooting profile companion promotion

## Scope

Promote `vignettes/articles/troubleshooting-profile.Rmd` as a public
Methods companion to `profile-likelihood-ci`, following the governance
decision recorded on issue #347 after PR #459 deployed.

This is a navigation and scope-boundary slice. It does not change CI
machinery, profile likelihood code, bootstrap code, formula grammar,
likelihood parameterisation, or validation-debt status.

## Files Touched

- `_pkgdown.yml`
  - Adds `troubleshooting-profile` to the public Methods navbar and
    article index.
  - Removes it from the internal article bucket.
- `vignettes/articles/troubleshooting-profile.Rmd`
  - Adds `tier: 2` front matter.
  - Adds a public scope-boundary block naming covered, partial, and
    planned validation rows.
- `docs/dev-log/check-log.md`
  - Records pre-edit lane checks, render checks, stale-wording scans,
    Rose/article-tier audit results, and decisions.
- `docs/dev-log/recovery-checkpoints/2026-06-06-214400-codex-checkpoint.md`
  - Records the context-compaction recovery state before this slice.
- `docs/dev-log/after-task/2026-06-06-troubleshooting-profile-companion.md`
  - This after-task report.

## Checks

- `ruby -e 'require "yaml"; YAML.load_file("_pkgdown.yml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- `git diff --check`
  -> clean.
- `rg -n "profile-likelihood default|extract_correlations\\([^\\n]*method *= *\\\"profile\\\"|gllvmTMB_wide\\(Y|meta_known_V|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(" vignettes/articles/troubleshooting-profile.Rmd _pkgdown.yml`
  -> no hits.
- `rg -n "^CI-0?2|^CI-0?3|^CI-08|^CI-10|^EXT-13|^DIA-01|^DIA-03|^DIA-05|CI-02|CI-03|CI-08|CI-10|EXT-13|DIA-01|DIA-03|DIA-05" docs/design/35-validation-debt-register.md vignettes/articles/troubleshooting-profile.Rmd`
  -> confirmed the new scope boundary maps to covered `CI-02`, `CI-03`,
  `DIA-01`, `DIA-03`, and `DIA-05`; partial `CI-08`, `CI-10`, and
  `EXT-13` remain M3 work.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/troubleshooting-profile", lazy = FALSE, quiet = FALSE)'`
  -> rendered `pkgdown-site/articles/troubleshooting-profile.html`.
- `rg -n "Troubleshooting profile CIs|Troubleshooting profile-likelihood CIs|troubleshooting-profile.html|Profile-likelihood confidence intervals|profile-likelihood-ci.html" pkgdown-site/articles/troubleshooting-profile.html pkgdown-site/articles/index.html`
  -> rendered HTML shows the companion page in the public navbar and
  article index; backlink to `profile-likelihood-ci.html` resolves in
  the rendered article.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `✔ No problems found.`
- `Rscript --vanilla -e 'ns <- readLines("NAMESPACE"); ref <- readLines("_pkgdown.yml"); f <- c("check_identifiability", "sanity_multi", "gllvmTMB_diagnose"); stopifnot(all(paste0("export(", f, ")") %in% ns)); stopifnot(all(paste0("    - ", f) %in% ref)); cat("troubleshooting-reference-links-ok\n")'`
  -> `troubleshooting-reference-links-ok`.

Rose pre-publish result: PASS for this narrow navigation/prose slice.
No stale syntax, notation, deprecated API, or correlation-default drift
hit was found in the touched files. The new public scope boundary cites
register rows for covered, partial, and planned status.

Article-tier result: Tier 2. This page is a technical troubleshooting
reference for readers already using profile-likelihood CIs; it is not a
Tier-1 worked example. The worked path remains in `profile-likelihood-ci`.

## Definition of Done Accounting

1. **Implementation.** Navigation and article-scope edits are local in
   this branch; final status depends on PR CI and merge.
2. **Simulation recovery test.** Not applicable: no new likelihood,
   family, keyword, estimator, or validation row is added.
3. **Documentation.** Public article navigation and scope boundary are
   updated. No roxygen or Rd files changed.
4. **Runnable user-facing example.** Not applicable: this is a
   troubleshooting reference with global `eval = FALSE`; the companion
   runnable workflow is `profile-likelihood-ci`.
5. **Check-log entry.** Added in this branch with exact commands and
   stale-wording scan patterns.
6. **Review pass.** Rose and article-tier checks passed for this narrow
   slice. No Boole/Gauss/Noether review is triggered because grammar,
   likelihood, and TMB code are untouched.

## Interpretation

The companion-page split is preferable to merging the troubleshooting
material into `profile-likelihood-ci`: the promoted profile article
teaches the API and worked path, while this page catalogues failure
modes and next actions. Keeping them separate gives readers a shorter
primary CI guide and a focused defensive-practice reference.

No capability moves to `covered`. The new scope boundary explicitly
keeps CI-08, CI-10, and EXT-13 in the M3 partial lane.
