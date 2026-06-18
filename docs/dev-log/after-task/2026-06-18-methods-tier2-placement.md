# After Task: Methods Tier 2 Placement

## Goal

Make the article-council step 3 true in source: decide the public Tier 2
placement for `profile-likelihood-ci` and `troubleshooting-profile` without
widening interval, bridge, release, or scientific-coverage claims.

## Implemented

`profile-likelihood-ci` and `troubleshooting-profile` now live in the visible
pkgdown `Technical reference` group, not in the internal drafts bucket.
`profile-likelihood-ci` now has explicit Tier 2 YAML and a scope boundary tied
to CI-01..CI-10 and EXT-13. `troubleshooting-profile` already had Tier 2 YAML
and scope wording, so it moved without a content rewrite. The article-council
ledger, ROADMAP, and local dashboard now record the decision.

## Mathematical Contract

No model, likelihood, formula grammar, or interval algorithm changed. The
article wording says only that the CI APIs exist and that Gaussian CI routes
have covered row evidence (CI-01..CI-07, EXT-13 Gaussian). Empirical coverage
and mixed-family interval calibration remain partial or blocked by CI-08 and
CI-10. No REML, AI-REML, bridge-complete, release-ready, or scientific-coverage
claim was added.

## Files Changed

- `_pkgdown.yml`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-methods-tier2-placement.md`

## Checks Run

- `PATH="/opt/homebrew/bin:$PATH" gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,isDraft,headRefName,updatedAt,url`
  -> only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago" -- _pkgdown.yml vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/troubleshooting-profile.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md docs/dev-log/check-log.md docs/dev-log/after-task ROADMAP.md docs/design`
  -> recent overlapping edits are the current mission-control/article-council
  lane.
- `rg -n "publication-grade|release-ready|bridge complete|scientific coverage passed|coverage passed|fast GLLVM|AI-REML|REML|full parity|complete bridge|profile-likelihood default|genuine bootstrap|meta_known_V|gllvmTMB_wide|trio|\\bf S|\\bS_B\\b|\\bS_W\\b" _pkgdown.yml ROADMAP.md vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/troubleshooting-profile.Rmd docs/dev-log/audits/2026-06-18-article-council-ledger.md`
  -> expected guarded hits in ROADMAP / ledger only; no profile article
  overclaim remains.
- `rg -n "articles/profile-likelihood-ci\\.html|articles/troubleshooting-profile\\.html|profile-likelihood-ci\\.html|troubleshooting-profile\\.html|Profile-likelihood CIs|Troubleshooting profile CIs|Technical reference" _pkgdown.yml vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd README.md ROADMAP.md docs/dev-log/audits/2026-06-18-article-council-ledger.md`
  -> public navbar links present in `_pkgdown.yml`; remaining article links are
  direct references from existing pages.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null`
  -> passed.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> passed.
- `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> completed successfully and rendered both touched articles.
- `rg -n "Technical reference|Profile-likelihood CIs|Troubleshooting profile CIs|profile-likelihood-ci\\.html|troubleshooting-profile\\.html" pkgdown-site/articles/index.html pkgdown-site/articles/profile-likelihood-ci.html pkgdown-site/articles/troubleshooting-profile.html pkgdown-site/index.html`
  -> rendered dropdown and article index contain the two Tier 2 links.
- `rg -n "Internal drafts and technical notes|profile-likelihood-ci|troubleshooting-profile" pkgdown-site/articles/index.html`
  -> the two pages appear under Technical reference and not under Internal
  drafts.

## Tests Of The Tests

No package tests were added because this was navigation/prose placement only.
The integration check is rendered pkgdown HTML: it verifies that the source
YAML change produces the intended public article routing.

## Consistency Audit

Rose: WARN/PASS. The remaining broad release and coverage gates stay guarded.
The only remaining `publication-grade` hits are in existing guarded roadmap or
ledger sentences, not in the moved profile article. Pat: PASS for placement:
these pages are public lookups, not first-stop worked examples. Grace: PASS:
pkgdown config check and full article render completed. Fisher: PASS with
guard: CI-08/CI-10 still block calibrated coverage claims.

## What Did Not Go Smoothly

The first stale scan found one remaining "publication-grade CIs" sentence in
`profile-likelihood-ci`; it was replaced with bounded empirical-bootstrap
wording before render.

## Team Learning

Tier 2 pages should have explicit YAML reasons before they enter the visible
article surface. ROADMAP visibility statements and `_pkgdown.yml` placement can
drift, so the article-council ledger must reconcile both.

## Known Limitations

This does not finish the broader reader-facing docs audit, the lambda rewrite,
the bridge landing decision, release issue #486, or the power/coverage gates.
The guard remains: PR green != bridge complete != release ready != scientific
coverage passed.

## Next Actions

Continue article-council step 4: decide whether `data-shape-flowchart`,
`stacked-trait-gllvm`, and `gllvm-vocabulary` should merge into Get Started or
return as compact guides.
