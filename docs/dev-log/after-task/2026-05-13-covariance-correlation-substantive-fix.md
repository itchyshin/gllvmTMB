# After Task: Covariance-Correlation Substantive Fix

## Goal

Take the Codex-owned `covariance-correlation.Rmd` lane after Claude
dropped that file from PR #55, fix the substantive phylogenetic
decomposition and legacy-level wording, and leave enough coordination
evidence for the next agent.

## Implemented

- Posted a coordination comment on PR #55 confirming that Codex owns
  `vignettes/articles/covariance-correlation.Rmd` and will avoid the
  three articles still in Claude's PR:
  <https://github.com/itchyshin/gllvmTMB/pull/55#issuecomment-4439530651>.
- Updated `vignettes/articles/covariance-correlation.Rmd` so the
  phylogenetic section distinguishes ordinary non-phylogenetic
  `unique()` from `phylo_unique()`.
- Replaced legacy `extract_communality(fit, "B")` article calls with
  canonical `extract_communality(fit, level = "unit")`.
- Replaced `Sigma_B` / `S_B` article comments with canonical
  `Sigma_unit` / `s_unit` wording.
- Updated `extract_Sigma()` so the missing-`unique()` advisory reports
  the canonical level label (`Sigma_unit`, `Sigma_unit_obs`) instead of
  the internal legacy slot (`Sigma_B`, `Sigma_W`).
- Updated `extract_Sigma()` roxygen and regenerated
  `man/extract_Sigma.Rd` so canonical `level = "unit"` /
  `"unit_obs"` names are primary and `"B"` / `"W"` are described as
  legacy aliases.
- Added / adjusted targeted tests so extractor tests use canonical
  levels where legacy behaviour is not under test, and so the advisory
  cannot drift back to `Sigma_B`.

## Mathematical Contract

No likelihood, TMB parameterisation, response family, NAMESPACE export,
or formula grammar changed.

The public prose now matches the existing phylogenetic design:

```text
Sigma_phy = Lambda_phy Lambda_phy^T + S_phy
Sigma_non = Lambda_non Lambda_non^T + S_non
Omega     = Sigma_phy + Sigma_non
```

`phylo_latent()` supplies the shared phylogenetic component;
`phylo_unique()` supplies the phylogenetic diagonal component when it
is fitted; ordinary `unique()` belongs to the non-phylogenetic unit
tier. The extractor code change only changes the user-facing advisory
label from internal `B` / `W` names to canonical `unit` / `unit_obs`
names.

## Files Changed

- `R/extract-sigma.R`
- `man/extract_Sigma.Rd`
- `tests/testthat/test-extract-omega.R`
- `tests/testthat/test-extract-sigma.R`
- `vignettes/articles/covariance-correlation.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-13-covariance-correlation-substantive-fix.md`

## Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,files,updatedAt,url,statusCheckRollup`
  showed three open Claude PRs (#55, #59, #60) and no overlap with the
  article or extractor files touched here. The only shared area is
  distinct files under `docs/dev-log/after-task/`.
- `git log --all --oneline --since="6 hours ago"` showed recent Claude
  coordination commits, including the PR #55 commit that dropped
  `covariance-correlation.Rmd`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed
  and wrote `man/extract_Sigma.Rd`.
- `tail -12 man/extract_Sigma.Rd` ended in the expected `\seealso{...}`
  block.
- `grep -c '^\\keyword' man/extract_Sigma.Rd` returned `0`, which is
  expected because this topic has no keyword tag.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma")'`
  passed: `FAIL 0 | WARN 0 | SKIP 0 | PASS 31`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|sigma-rename|extract-omega|mixed-response-sigma")'`
  passed: `FAIL 0 | WARN 0 | SKIP 1 | PASS 70`. The skip is the
  existing `.normalise_level()` migration skip in
  `test-sigma-rename.R`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", new_process = FALSE)'`
  rendered the affected article. The only warning was the known
  `../logo.png` pkgdown image warning.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found."
- `git diff --check` passed after the article, extractor, test,
  generated Rd, check-log, and after-task edits.

## Tests Of The Tests

- The first advisory-label patch failed the new assertion because
  `level_label` was computed after level normalisation and therefore
  still read as internal `"B"`. The failing targeted test showed the
  rendered-page problem was real, not cosmetic.
- After moving `level_label` through `.canonical_level_name()`, the
  targeted extractor tests passed with zero warnings.
- The rendered article was scanned after rebuilding; no stale
  `Sigma_B`, `S_B`, `+ U`, `diag(U)`, `U_phy`, `U_non`, or
  "no associated" wording remained in the source or rendered HTML.

## Consistency Audit

- Shannon: `WARN`, not `FAIL`. Three Claude PRs are open and CI is in
  progress, but there is no file overlap with this lane. The dev-log
  after-task files are distinct.
- Rose: `PASS` for the touched article and `extract_Sigma()` topic.
  Focused scans found only intentional legacy-alias documentation in
  `R/extract-sigma.R` / `man/extract_Sigma.Rd`, not stale primary
  examples.
- Boole: the public extractor examples now use canonical
  `level = "unit"` syntax; legacy aliases remain documented as aliases.
- Noether: the article equations now match the design note's
  `Sigma_phy`, `Sigma_non`, and `Omega` decomposition.
- Pat: the article now tells a reader which unique term to try next:
  `phylo_unique()` for phylogenetic diagonal variance and ordinary
  `unique()` for the non-phylogenetic species tier.
- Grace: targeted tests, article render, `devtools::document()`,
  `pkgdown::check_pkgdown()`, and whitespace checks cover this narrow
  doc/API-message lane. Full package test/check remains for a PR gate.

## What Did Not Go Smoothly

- The first code patch changed the message construction but left
  `level_label <- level`, so canonical calls still rendered `Sigma_B`.
  The targeted assertion caught it immediately.
- One early `rg` command used shell backticks in a pattern and zsh
  tried to execute `unique()`. The scan was rerun with safe quoting and
  the failed command was not counted as validation.

## Team Learning

- Shannon should stay early in multi-agent article lanes; Claude's PR
  #55 had already moved out of our file, which made the safe lane clear.
- Rose scans need to include rendered article output, not only Rmd
  source, because runtime notes can reintroduce stale names.
- Boole's API-language check is cheap and valuable when articles show
  extractor output directly.
- Noether's equation/source alignment matters even for "documentation"
  PRs: the article text must follow the implemented
  `phylo_latent()` / `phylo_unique()` split.

## Known Limitations

- Full `devtools::test()` and `devtools::check()` were not run.
- `extract_Omega()` still reports `tiers_used` in its existing internal
  tier vocabulary when called with legacy `tiers = c("B", "W")`; this
  task did not redesign that API.
- The pkgdown article render still emits the existing missing
  `../logo.png` warning, unrelated to this change.

## Next Actions

- Open a focused Codex PR once the local branch is pushed.
- Let PR #55 continue independently; it no longer owns
  `covariance-correlation.Rmd`.
