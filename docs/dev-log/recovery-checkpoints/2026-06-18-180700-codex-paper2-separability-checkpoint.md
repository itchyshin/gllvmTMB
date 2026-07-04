# Codex recovery checkpoint -- Paper 2 separability diagnostic

Date: 2026-06-18 18:07 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Branch and status

Branch: `codex/r-bridge-grouped-dispersion`

`git status --short --branch`:

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
 M AGENTS.md
 M CLAUDE.md
 M NAMESPACE
 M NEWS.md
 M R/animal-keyword.R
 M R/brms-sugar.R
 M R/extract-omega.R
 M R/extract-sigma.R
 M R/extractors.R
 M R/fit-multi.R
 M R/kernel-helpers.R
 M R/kernel-keywords.R
 M R/profile-derived-curves.R
 M R/profile-derived.R
 M R/traits-keyword.R
 M R/unique-keyword.R
 M README.md
 M _pkgdown.yml
 M docs/design/01-formula-grammar.md
 M docs/design/35-validation-debt-register.md
 M docs/design/65-cross-lineage-coevolution-kernel.md
 M docs/dev-log/check-log.md
 M docs/dev-log/dashboard/status.json
 M docs/dev-log/dashboard/sweep.json
 M man/animal_unique.Rd
 M man/diag_re.Rd
 M man/extract_ICC_site.Rd
 M man/extract_Sigma.Rd
 M man/extract_communality.Rd
 M man/extract_ordination.Rd
 M man/indep.Rd
 M man/kernel_latent.Rd
 M man/latent.Rd
 M man/phylo_unique.Rd
 M man/spatial_unique.Rd
 M man/traits.Rd
 M man/unique_keyword.Rd
 M tests/testthat/test-brms-sugar.R
 M tests/testthat/test-canonical-keywords.R
 M tests/testthat/test-coevolution-two-kernel.R
 M tests/testthat/test-example-coevolution-kernel.R
 M tests/testthat/test-extract-sigma.R
 M tests/testthat/test-extractors-extra.R
 M tests/testthat/test-extractors.R
 M tests/testthat/test-keyword-grid.R
 M tests/testthat/test-m1-3-extract-sigma-mixed-family.R
 M tests/testthat/test-mixed-family-extractor.R
 M tests/testthat/test-spatial-orientation.R
 M tests/testthat/test-stage2-rr-diag.R
 M vignettes/articles/animal-model.Rmd
 M vignettes/articles/covariance-correlation.Rmd
 M vignettes/articles/functional-biogeography.Rmd
 M vignettes/articles/phylogenetic-gllvm.Rmd
 M vignettes/articles/response-families.Rmd
?? docs/dev-log/after-task/2026-06-18-paper2-kernel-separability-diagnostic.md
?? docs/dev-log/audits/2026-06-18-paper2-coevolution-estimand-gate.md
?? man/diagnose_kernel_separability.Rd
?? tests/testthat/test-unique-family-deprecation.R
```

There are additional pre-existing untracked after-task and recovery-checkpoint
files from this long lane; do not delete or assume they are unrelated without
checking.

## Diff stat

`git diff --stat` reports 54 tracked files changed, 1720 insertions and 439
deletions. The newest separability slice adds:

- `R/kernel-helpers.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- `NAMESPACE`
- `man/diagnose_kernel_separability.Rd`
- `_pkgdown.yml`
- `NEWS.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/audits/2026-06-18-paper2-coevolution-estimand-gate.md`
- `docs/dev-log/after-task/2026-06-18-paper2-kernel-separability-diagnostic.md`

## Commands already run

- `gh pr list --state open`
  -> only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current coevolution stack, headed by
  `5346391 test(coevolution): add poisson recovery gate`.
- `sed -n '1,260p'` and `sed -n '261,520p'` on the maintainer Paper 2 note
  attachment.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `NAMESPACE` and `man/diagnose_kernel_separability.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel|coevolution-recovery", reporter = "summary")'`
  -> first run failed because helper validation stripped kernel names.
- Fixed with `stats::setNames()`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel|coevolution-recovery", reporter = "summary")'`
  -> passed with 13 expected heavy skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> first run failed because `diagnose_kernel_separability` was missing from
  `_pkgdown.yml`.
- Added `_pkgdown.yml` reference entry.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  -> passed.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  -> live `http://127.0.0.1:8770/` dashboard synced.

## Current interpretation

The coevolution engine stop point is stronger than before, but the full Paper 2
model is still not complete. `diagnose_kernel_separability()` now provides a
pre-fit screen for raw/aliased versus residualized/opposed kernel candidates.
It does not replace formal kernel-collinearity simulations, interval
calibration, module extraction, mechanistic validation, or empirical data audit.

`kernel_unique()` and `*_unique()` remain compatibility syntax only. Do not
expand them for Paper 2 multi-kernel coevolution in the next slice.

## Commands still worth running

- Optional broader non-heavy suite:
  `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
- Optional heavy confirmation before commit:
  `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
- Re-run:
  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  before any commit touching exported docs or `_pkgdown.yml`.

## Next safest action

If continuing coevolution first, implement the formal raw-`W` versus
residualized-`W_tip` kernel-collinearity simulation gate. If switching to the
post-coevolution plan, continue the `unique()` deprecation cleanup without
expanding `kernel_unique()` into Paper 2 support.

No push, no staging, and no GLLVM.jl #101 mutation were performed.
