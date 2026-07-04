# Recovery Checkpoint: Coevolution + `unique()` Soft-Deprecation Closeout

**Date:** 2026-06-18 17:15 MDT
**Agent:** Codex
**Branch:** `codex/r-bridge-grouped-dispersion`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Current Git State

`git status --short --branch`:

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
 M AGENTS.md
 M CLAUDE.md
 M NEWS.md
 M R/animal-keyword.R
 M R/brms-sugar.R
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
 M man/kernel_latent.Rd
 M man/phylo_unique.Rd
 M man/spatial_unique.Rd
 M man/unique_keyword.Rd
 M tests/testthat/test-brms-sugar.R
 M tests/testthat/test-canonical-keywords.R
 M tests/testthat/test-coevolution-two-kernel.R
 M tests/testthat/test-example-coevolution-kernel.R
 M tests/testthat/test-keyword-grid.R
 M tests/testthat/test-spatial-orientation.R
 M vignettes/articles/animal-model.Rmd
 M vignettes/articles/functional-biogeography.Rmd
 M vignettes/articles/phylogenetic-gllvm.Rmd
 M vignettes/articles/response-families.Rmd
?? docs/dev-log/after-task/2026-06-18-coe04-high-overlap-failure-calibration.md
?? docs/dev-log/after-task/2026-06-18-psi-unique-second-sweep.md
?? docs/dev-log/after-task/2026-06-18-unique-family-soft-deprecation.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-171500-codex-coevolution-unique-softdep-closeout.md
?? tests/testthat/test-unique-family-deprecation.R
```

Existing older untracked recovery checkpoints from 2026-06-17 and earlier
2026-06-18 are still present and intentionally left untouched.

`git diff --stat`:

```text
29 files changed, 693 insertions(+), 103 deletions(-)
```

## What Was Completed

- COE-04 gained a high-overlap non-identical failure-calibration gate. The
  model detects signal in that hard setting but does not promote
  component-specific recovery.
- The current public/story surfaces now say `COE-04` remains partial.
- The Psi / `unique()` second sweep moved standalone diagonal teaching toward
  `indep()` / source-specific `*_indep()` while preserving explicit-Psi
  compatibility examples.
- The first parser-level lifecycle slice for the `unique()` family landed:
  `unique()`, `phylo_unique()`, `animal_unique()`, `spatial_unique()`, and
  `kernel_unique()` soft-warn via `lifecycle::deprecate_soft()` while the
  compatibility rewrites remain live.
- Dashboard source was synced to `/tmp/gllvm-dashboard/`; the live server at
  `http://127.0.0.1:8770/` returned valid `status.json` and `sweep.json`.

## Commands Run

- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> passed.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> passed with expected heavy skips.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> passed with expected heavy skips.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> passed with no skips shown by testthat.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated Rd.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation", reporter = "summary")'`
  -> passed after fixing duplicate-warning and brittle-deparse issues.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|keyword-grid|brms-sugar|spatial-deprecation|spatial-orientation|kernel-equivalence", reporter = "summary")'`
  -> passed with three expected INLA skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  -> passed.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  -> synced dashboard source to the live server directory.
- `curl -s --max-time 2 http://127.0.0.1:8770/status.json | python3 -m json.tool`
  -> live status JSON parsed.
- `curl -s --max-time 2 http://127.0.0.1:8770/sweep.json | python3 -m json.tool`
  -> live sweep JSON parsed.

## Commands Still Needed

- No additional local command is required for the completed coevolution +
  first soft-deprecation slice.
- Before any commit, inspect the final staged scope manually and do not use
  `git add -A`.
- Full `devtools::check()` was not run in this closeout slice.

## Next Safest Action

Stop here for this slice. The next grand-plan item is the deeper `unique()`
deprecation/removal design and implementation: decide the latent-Psi fold,
extractor semantics for `part = "unique"`, free-correlation reaction-norm
replacement, and migration story before escalating beyond soft warnings.

## Blocking Question

None for the completed slice. The next slice needs a maintainer decision on
whether to implement the latent-Psi fold before or alongside wider
`unique()` removal.
