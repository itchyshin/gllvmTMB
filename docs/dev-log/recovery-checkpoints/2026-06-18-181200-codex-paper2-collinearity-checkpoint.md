# Codex recovery checkpoint -- Paper 2 collinearity gate

Date: 2026-06-18 18:12 MDT

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
?? docs/dev-log/after-task/2026-06-18-paper2-kernel-collinearity-gate.md
?? docs/dev-log/after-task/2026-06-18-paper2-kernel-separability-diagnostic.md
?? docs/dev-log/audits/2026-06-18-paper2-coevolution-estimand-gate.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-180700-codex-paper2-separability-checkpoint.md
?? man/diagnose_kernel_separability.Rd
?? tests/testthat/test-unique-family-deprecation.R
```

There are additional pre-existing untracked after-task and recovery checkpoint
files from this long local lane. Do not delete them.

## Diff stat

`git diff --stat` reports 54 tracked files changed, 1853 insertions and 439
deletions.

The newest coevolution slice touched:

- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-paper2-kernel-collinearity-gate.md`

## Commands already run

- `gh pr list --state open`
  -> only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current coevolution stack, headed by
  `5346391 test(coevolution): add poisson recovery gate`.
- Exploratory R threshold probe for `K_tip(alpha)`.
  -> `alpha = 0` near-orthogonal, `alpha = 0.15` moderate,
  `alpha = 0.25` high, `alpha = 1` high.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel|coevolution-recovery", reporter = "summary")'`
  -> passed with 13 expected heavy skips.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  -> passed.
- `rg -n "formal kernel-collinearity simulations|next scientific gate" ...`
  -> no hits after dashboard/ledger correction.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  -> live dashboard synced.
- `curl -fsS http://127.0.0.1:8770/sweep.json | rg -n "Paper 2 collinearity|kernel-collinearity simulation gate"`
  -> confirmed the live board contains the new collinearity entry.

## Current interpretation

The coevolution model is stronger locally and the next narrow `COE-04`
pre-fit collinearity gate is covered. The full Paper 2 scientific model is not
complete: broader fitted calibration, interval evidence, module extraction,
mechanistic validation, empirical trait/data audit, and broader non-Gaussian /
mixed-family recovery remain gated.

## Next safest action

Switch to the `unique()` deprecation / compatibility cleanup lane. Keep
`kernel_unique()` and source-specific `*_unique()` as compatibility syntax only
for now; do not expand them for Paper 2 multi-kernel coevolution.

No push, no staging, and no GLLVM.jl #101 mutation were performed.
