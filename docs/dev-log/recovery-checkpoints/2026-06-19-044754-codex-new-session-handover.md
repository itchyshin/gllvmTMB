# Codex new-session handover checkpoint

Date: 2026-06-19 04:47 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Current goal

Finish the overall plan one gate at a time. The maintainer asked for the next
session to inherit the plan and continue slow/steady from the local dashboard:

- coevolution first;
- then `unique()` deprecation / compatibility cleanup;
- then remaining planned dashboard/article/public-readiness gates;
- do not push;
- do not mutate GLLVM.jl #101;
- never use `git add -A`;
- run the pre-edit lane check before touching shared files.

Dashboard URLs were live immediately before this checkpoint:

- `http://127.0.0.1:8765/` -> HTTP 200
- `http://127.0.0.1:8770/` -> HTTP 200

## Git state

`git status --short --branch`:

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
 M AGENTS.md
 M CLAUDE.md
 M NAMESPACE
 M NEWS.md
 M R/animal-keyword.R
 M R/bootstrap-sigma.R
 M R/brms-sugar.R
 M R/check-consistency.R
 M R/check-identifiability.R
 M R/communality-ci.R
 M R/confint-inspect.R
 M R/coverage-study.R
 M R/extract-correlations.R
 M R/extract-omega.R
 M R/extract-repeatability.R
 M R/extract-sigma-table.R
 M R/extract-sigma.R
 M R/extract-two-psi-cross-check.R
 M R/extractors.R
 M R/fit-multi.R
 M R/gllvmTMB-wide.R
 M R/gllvmTMB.R
 M R/init-warmstart.R
 M R/kernel-helpers.R
 M R/kernel-keywords.R
 M R/phylo-signal-ci.R
 M R/profile-derived-curves.R
 M R/profile-derived.R
 M R/profile-targets.R
 M R/rotate-loadings.R
 M R/simulate-unit-trait.R
 M R/traits-keyword.R
 M R/unique-keyword.R
 M R/z-confint-gllvmTMB.R
 M README.md
 M _pkgdown.yml
 M data-raw/examples/make-behavioural-reaction-norm-example.R
 M data-raw/examples/make-covariance-edge-cases-example.R
 M data-raw/examples/make-model-selection-rank-example.R
 M data-raw/examples/make-morphometrics-example.R
 M docs/design/00-vision.md
 M docs/design/01-formula-grammar.md
 M docs/design/02-data-shape-and-weights.md
 M docs/design/03-likelihoods.md
 M docs/design/03-phylogenetic-gllvm.md
 M docs/design/04-random-effects.md
 M docs/design/05-testing-strategy.md
 M docs/design/06-extractors-contract.md
 M docs/design/35-validation-debt-register.md
 M docs/design/43-asreml-speed-techniques.md
 M docs/design/44-m3-3-inference-replacement.md
 M docs/design/48-m3-4-boundary-regimes.md
 M docs/design/49-robust-modeling-roadmap.md
 M docs/design/59-phase-b-matrix-completion.md
 M docs/design/61-capability-status.md
 M docs/design/65-cross-lineage-coevolution-kernel.md
 M docs/design/66-capstone-power-study.md
 M docs/dev-log/audits/2026-06-18-article-council-ledger.md
 M docs/dev-log/check-log.md
 M docs/dev-log/dashboard/status.json
 M docs/dev-log/dashboard/sweep.json
 M inst/extdata/examples/behavioural-reaction-norm-example.rds
 M inst/extdata/examples/covariance-edge-cases-example.rds
 M inst/extdata/examples/model-selection-rank-example.rds
 M inst/extdata/examples/morphometrics-example.rds
 M man/animal_unique.Rd
 M man/bootstrap_Sigma.Rd
 M man/compare_dep_vs_two_psi.Rd
 M man/compare_indep_vs_two_psi.Rd
 M man/confint.gllvmTMB_multi.Rd
 M man/confint_inspect.Rd
 M man/coverage_study.Rd
 M man/dep.Rd
 M man/diag_re.Rd
 M man/extract_ICC_site.Rd
 M man/extract_Omega.Rd
 M man/extract_Sigma.Rd
 M man/extract_Sigma_table.Rd
 M man/extract_communality.Rd
 M man/extract_correlations.Rd
 M man/extract_ordination.Rd
 M man/extract_phylo_signal.Rd
 M man/extract_proportions.Rd
 M man/extract_repeatability.Rd
 M man/extract_residual_split.Rd
 M man/extract_rotated_loadings_table.Rd
 M man/gllvmTMB.Rd
 M man/gllvmTMB_check_consistency.Rd
 M man/gllvmTMBcontrol.Rd
 M man/indep.Rd
 M man/kernel_latent.Rd
 M man/latent.Rd
 M man/phylo_unique.Rd
 M man/profile_ci_phylo_signal.Rd
 M man/profile_targets.Rd
 M man/rotate_loadings.Rd
 M man/simulate_unit_trait.Rd
 M man/spatial_unique.Rd
 M man/traits.Rd
 M man/unique_keyword.Rd
 M tests/testthat/test-brms-sugar.R
 M tests/testthat/test-canonical-keywords.R
 M tests/testthat/test-coevolution-recovery.R
 M tests/testthat/test-coevolution-two-kernel.R
 M tests/testthat/test-example-behavioural-reaction-norm.R
 M tests/testthat/test-example-coevolution-kernel.R
 M tests/testthat/test-example-model-selection-rank.R
 M tests/testthat/test-example-morphometrics.R
 M tests/testthat/test-extract-sigma.R
 M tests/testthat/test-extractors-extra.R
 M tests/testthat/test-extractors.R
 M tests/testthat/test-family-gamma.R
 M tests/testthat/test-gllvmTMB-diagnose.R
 M tests/testthat/test-gllvmTMB-wide.R
 M tests/testthat/test-joint-sdm-binary-long-wide.R
 M tests/testthat/test-keyword-grid.R
 M tests/testthat/test-lme4-style-weights.R
 M tests/testthat/test-m1-3-extract-sigma-mixed-family.R
 M tests/testthat/test-mixed-family-extractor.R
 M tests/testthat/test-ordinary-latent-random-regression.R
 M tests/testthat/test-spatial-orientation.R
 M tests/testthat/test-stage2-rr-diag.R
 M tests/testthat/test-weights-unified.R
 M tests/testthat/test-wide-weights-matrix.R
 M vignettes/articles/animal-model.Rmd
 M vignettes/articles/api-keyword-grid.Rmd
 M vignettes/articles/behavioural-syndromes.Rmd
 M vignettes/articles/choose-your-model.Rmd
 M vignettes/articles/convergence-start-values.Rmd
 M vignettes/articles/covariance-correlation.Rmd
 M vignettes/articles/cross-lineage-coevolution.Rmd
 M vignettes/articles/cross-package-validation.Rmd
 M vignettes/articles/data-shape-flowchart.Rmd
 M vignettes/articles/fit-diagnostics.Rmd
 M vignettes/articles/functional-biogeography.Rmd
 M vignettes/articles/gllvm-vocabulary.Rmd
 M vignettes/articles/joint-sdm.Rmd
 M vignettes/articles/lambda-constraint-suggest.Rmd
 M vignettes/articles/lambda-constraint.Rmd
 M vignettes/articles/mixed-family-extractors.Rmd
 M vignettes/articles/model-selection-latent-rank.Rmd
 M vignettes/articles/morphometrics.Rmd
 M vignettes/articles/ordinal-probit.Rmd
 M vignettes/articles/phylogenetic-gllvm.Rmd
 M vignettes/articles/pitfalls.Rmd
 M vignettes/articles/profile-likelihood-ci.Rmd
 M vignettes/articles/psychometrics-irt.Rmd
 M vignettes/articles/random-regression-reaction-norms.Rmd
 M vignettes/articles/random-slopes-nongaussian.Rmd
 M vignettes/articles/response-families.Rmd
 M vignettes/articles/simulation-recovery-validated.Rmd
 M vignettes/articles/simulation-verification.Rmd
 M vignettes/articles/stacked-trait-gllvm.Rmd
 M vignettes/gllvmTMB.Rmd
?? docs/dev-log/after-task/2026-06-19-behavioural-syndromes-browser-review.md
?? docs/dev-log/after-task/2026-06-19-coe04-mixed-family-recovery.md
?? docs/dev-log/after-task/2026-06-19-mixed-family-extractors-browser-review.md
?? docs/dev-log/after-task/2026-06-19-unique-article-wording-closeout.md
?? docs/dev-log/recovery-checkpoints/2026-06-19-044754-codex-new-session-handover.md
```

The actual `git status` has many additional inherited untracked after-task and
recovery files from earlier slices. Do not treat them as newly created by this
checkpoint. Use `git status --short --branch` in the new session as
authoritative.

`git diff --stat` summary immediately before this checkpoint:

```text
155 files changed, 31785 insertions(+), 21400 deletions(-)
```

`git diff --check`:

```text
clean
```

## Commands run in this sitting

Coevolution / COE-04:

- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 13 | PASS 92`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 367`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 16 | PASS 207`.

Unique compatibility cleanup:

- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/api-keyword-grid.Rmd", output_dir = tempdir(), quiet = TRUE)'`
  -> passed.
- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/choose-your-model.Rmd", output_dir = tempdir(), quiet = TRUE)'`
  -> passed.
- Focused stale-phrase scan over the two articles -> no stale matches.

Article/browser gates completed:

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> passed.
- System Chrome desktop/mobile screenshots, full-page captures, DOM image/link
  checks, and stale-overclaim scans for `behavioural-syndromes` -> passed.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> passed.
- System Chrome desktop/mobile screenshots, full-page captures, DOM image/link
  checks, and stale-overclaim scans for `mixed-family-extractors` -> passed.

Ordinal browser gate started but not closed:

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/ordinal-probit", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> passed and wrote `pkgdown-site/articles/ordinal-probit.html`.
- System Chrome wrote:
  - `/tmp/ordinal-probit-desktop.png`
  - `/tmp/ordinal-probit-mobile.png`
  - `/tmp/ordinal-probit-desktop-full.png`
  - `/tmp/ordinal-probit-mobile-full.png`
- Chrome DevTools Protocol metrics for `ordinal-probit`:
  - title `Ordinal-probit threshold traits • gllvmTMB`
  - H1 `Ordinal-probit threshold traits`
  - mobile H1 rectangle inside viewport: `left = 12`, `right = 378`,
    `width = 366`
  - mobile `documentScrollWidth = 390` at viewport width `390`
  - only package logo image; no article PNG assets expected
  - overflow findings were expected scrollable code/output spans
- Stale-overclaim scan for `ordinal-probit`:
  - only matched intended internal gate wording.
- **Not yet done for ordinal:** visual inspection with `view_image`, local
  image/link parser check, ledger/check-log/dashboard/after-task edits,
  dashboard refresh.

Dashboard / housekeeping:

- `python3 -m json.tool docs/dev-log/dashboard/status.json`
  -> valid.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json`
  -> valid.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  -> refreshed local dashboard.
- `curl` checks for `8765` and `8770`
  -> both HTTP 200.

## Files changed in this sitting

New or updated by this sitting:

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-coe04-mixed-family-recovery.md`
- `docs/dev-log/after-task/2026-06-19-unique-article-wording-closeout.md`
- `docs/dev-log/after-task/2026-06-19-behavioural-syndromes-browser-review.md`
- `docs/dev-log/after-task/2026-06-19-mixed-family-extractors-browser-review.md`
- this checkpoint

Note: the worktree contains many inherited modifications and untracked
after-task/checkpoint files from earlier plan slices. Do not revert or tidy
unrelated files.

## Completed in this sitting

1. COE-04 mixed-family recovery gate:
   - added two-cell Gaussian-host / Poisson-partner shape-recovery evidence;
   - full and one-component comparators converge;
   - full model beats either comparator by more than 200 log-likelihood units;
   - own-component `Gamma_shape` correlations exceed 0.90;
   - cross-component matches stay below 0.12;
   - still narrow, point-estimate, no interval/rho/scientific-completion claim.

2. `unique()` deprecation / compatibility article wording:
   - `api-keyword-grid` teaches `indep()`, `dep()`, and supported
     source-specific shorthand first;
   - `choose-your-model` labels paired `phylo_unique()` as explicit
     phylogenetic-Psi compatibility syntax only when separately identifiable;
   - no keyword removal, no `deprecate_warn()`, no Paper 2 `kernel_unique()`
     expansion.

3. `behavioural-syndromes` browser review:
   - system Chrome browser evidence passed;
   - article remains internal pending final public-placement decision.

4. `mixed-family-extractors` browser review:
   - system Chrome browser evidence passed;
   - article remains internal pending NB/beta teaching fixture, CI-10/MIX-10,
     and final placement.

## Next safest action

Start the new session by reading, in order:

1. `AGENTS.md`
2. this checkpoint
3. `git status --short --branch`
4. `git diff --stat`
5. `git diff --check`
6. latest `docs/dev-log/check-log.md`
7. `docs/dev-log/dashboard/status.json` and `docs/dev-log/dashboard/sweep.json`
8. `docs/dev-log/audits/2026-06-18-article-council-ledger.md`

Then continue with the in-progress `ordinal-probit` browser gate:

1. Inspect screenshots:
   - `/tmp/ordinal-probit-desktop.png`
   - `/tmp/ordinal-probit-mobile.png`
   - `/tmp/ordinal-probit-desktop-full.png`
   - `/tmp/ordinal-probit-mobile-full.png`
2. Run local HTML image/link parser for
   `pkgdown-site/articles/ordinal-probit.html`.
3. If visual/link checks pass, run the pre-edit lane check:
   - `gh pr list --state open`
   - `git log --all --oneline --since="6 hours ago"`
4. Update:
   - `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
   - `docs/dev-log/check-log.md`
   - `docs/dev-log/dashboard/status.json`
   - `docs/dev-log/dashboard/sweep.json`
   - new after-task report for ordinal browser review.
5. Validate:
   - JSON tool on dashboard files;
   - `git diff --check`;
   - `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`;
   - HTTP 200 on `8765` and `8770`.

After ordinal, return to the dashboard/article-council backlog and keep going
one narrow gate at a time. Likely nearby browser/render gates still open:

- `random-slopes-nongaussian` true browser review;
- final public-placement decisions for browser-reviewed internal articles;
- `lambda-constraint` Confidence Eye / PD fixture or profile/bootstrap loading
  interval repair;
- broader mixed-family NB/beta teaching fixture;
- coevolution remains partial beyond the narrow mixed-family gate: no in-engine
  rho estimation, rho profile intervals, formal reusable null/Type-I
  calibration, interval calibration, module uncertainty/rank calibration, or
  broader non-Gaussian/mixed-family coverage.

## Blocking questions

None. The next session can continue from local evidence.

