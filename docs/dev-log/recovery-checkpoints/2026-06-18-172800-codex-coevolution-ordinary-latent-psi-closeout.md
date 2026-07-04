# Recovery Checkpoint: Coevolution + Ordinary Latent-Psi Closeout

**Date:** 2026-06-18 17:28 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**HEAD:** `5346391`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Git State

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
 M AGENTS.md
 M CLAUDE.md
 M NEWS.md
 M R/animal-keyword.R
 M R/brms-sugar.R
 M R/fit-multi.R
 M R/kernel-keywords.R
 M R/unique-keyword.R
 M docs/design/01-formula-grammar.md
 M docs/design/35-validation-debt-register.md
 M docs/design/65-cross-lineage-coevolution-kernel.md
 M docs/dev-log/check-log.md
 M docs/dev-log/dashboard/status.json
 M docs/dev-log/dashboard/sweep.json
 M man/animal_unique.Rd
 M man/diag_re.Rd
 M man/indep.Rd
 M man/kernel_latent.Rd
 M man/latent.Rd
 M man/phylo_unique.Rd
 M man/spatial_unique.Rd
 M man/unique_keyword.Rd
 M tests/testthat/test-brms-sugar.R
 M tests/testthat/test-canonical-keywords.R
 M tests/testthat/test-coevolution-two-kernel.R
 M tests/testthat/test-example-coevolution-kernel.R
 M tests/testthat/test-keyword-grid.R
 M tests/testthat/test-spatial-orientation.R
 M tests/testthat/test-stage2-rr-diag.R
 M vignettes/articles/animal-model.Rmd
 M vignettes/articles/functional-biogeography.Rmd
 M vignettes/articles/phylogenetic-gllvm.Rmd
 M vignettes/articles/response-families.Rmd
?? docs/dev-log/after-task/2026-06-18-coe04-high-overlap-failure-calibration.md
?? docs/dev-log/after-task/2026-06-18-ordinary-latent-psi-fold.md
?? docs/dev-log/after-task/2026-06-18-psi-unique-second-sweep.md
?? docs/dev-log/after-task/2026-06-18-unique-family-soft-deprecation.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-172800-codex-coevolution-ordinary-latent-psi-closeout.md
?? tests/testthat/test-unique-family-deprecation.R
```

There are also older untracked recovery checkpoints from the long mission-
control run. Do not remove or stage them blindly.

## Diff Stat

```text
33 files changed, 935 insertions(+), 219 deletions(-)
```

## Completed In This Sitting

- Finished the narrow COE-04 coevolution model gate:
  - added the non-identical high-overlap failure-calibration fixture;
  - preserved `kernel_unique()` / `*_unique()` as compatibility syntax only;
  - kept Paper 2 multi-kernel coevolution latent-only.
- Added parser lifecycle warnings for `unique()`, `phylo_unique()`,
  `animal_unique()`, `spatial_unique()`, and `kernel_unique()` while preserving
  rewrites and fits.
- Implemented the first real `unique()` follow-on fold:
  - ordinary `latent()` now emits an internal diagonal Psi companion by default;
  - `latent(..., residual = FALSE)` gives the old no-residual `rr` subset;
  - explicit `latent() + unique()` compatibility remains accepted.
- Updated NEWS, formula grammar, AGENTS/CLAUDE, generated Rd, check-log,
  after-task reports, and dashboard JSON.
- Synced dashboard files to `/tmp/gllvm-dashboard/`; `http://127.0.0.1:8770/`
  serves the `2026-06-18 17:26 MDT` status/sweep JSON.

## Commands Run

- Pre-edit lane check:
  - `gh pr list --state open`
  - `git log --all --oneline --since="6 hours ago"`
  - `git diff --check`
- Documentation:
  - `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
- Tests:
  - `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|stage2-rr-diag", reporter = "summary")'`
    passed with expected INLA and glmmTMB-Hessian skips.
  - `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|keyword-grid|brms-sugar|spatial-deprecation|spatial-orientation|kernel-equivalence|stage2-rr-diag", reporter = "summary")'`
    passed with the same expected skips.
  - Earlier coevolution closeout commands passed:
    - `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
    - `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
- Dashboard:
  - `Rscript --vanilla -e 'jsonlite::fromJSON("docs/dev-log/dashboard/status.json"); jsonlite::fromJSON("docs/dev-log/dashboard/sweep.json"); cat("json ok\n")'`
  - `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  - `curl -sS http://127.0.0.1:8770/status.json | python3 -m json.tool | sed -n '1,35p'`
  - `curl -sS http://127.0.0.1:8770/sweep.json | python3 -m json.tool | rg -n "17:26|ordinary latent-Psi|residual = FALSE|source-specific/kernel"`
- Stale wording:
  - `rg -n 'latent\(\) does not yet auto-emit Psi|latent-Psi fold lands|later latent-Psi fold|without unique.*LLt|only the latent-implied|no parser-wide deprecation|not latent-Psi auto-folding|does not yet auto' NEWS.md docs/dev-log/dashboard docs/design AGENTS.md CLAUDE.md R tests/testthat man vignettes`
  - `rg -n 'two `latent\(\) \+ unique\(\)` pairs|recommended.*latent\(\).*unique|Use `unique\(\)` paired with `latent\(\)`|latent-Psi auto-folding' R NEWS.md docs/dev-log/dashboard docs/design AGENTS.md CLAUDE.md`
- Final checks before this checkpoint:
  - `git diff --check` passed.
  - `git status --short --branch`
  - `git diff --stat`

## Still Not Claimed

- No `unique()` API removal.
- No source-specific `phylo_latent()` / `animal_latent()` /
  `spatial_latent()` Psi fold.
- No `kernel_latent()` Psi fold; Paper 2 multi-kernel coevolution remains
  latent-only.
- No extractor contract change for `part = "unique"`.
- No `common =` replacement beyond preserving explicit compatibility syntax.
- No free-correlation reaction-norm redesign.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Safest Action

Stop here for the coevolution-first lane. The next grand-plan item is the
broader `unique()` deprecation/removal plan: source-specific folds, kernel
compatibility strategy, extractor naming / `part = "unique"`, `common =`
migration, examples, and eventual removal. Re-run the pre-edit lane check before
touching shared files again.

## Blocking Question

None for the stop point. A maintainer decision is useful before removing any
`unique()` exports or changing extractor `part = "unique"` semantics.
