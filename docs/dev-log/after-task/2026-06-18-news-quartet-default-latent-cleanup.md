# After-task report: NEWS and quartet-reference default latent cleanup

Date: 2026-06-18 21:59 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice updated current NEWS wording and the `indep()` / `dep()` reference
descriptions so the ordinary decomposition mode is default `latent()` with
Psi, not a new-user `latent()+unique()` headline.

Explicit `latent()+unique()` remains compatibility syntax. Source-specific
explicit-Psi terms remain outside this slice.

## Files touched

- `NEWS.md`
- `R/brms-sugar.R`
- `man/indep.Rd`
- `man/dep.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Validation

- `Rscript --vanilla -e 'parse("R/brms-sugar.R")'` passed.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` passed and
  regenerated `man/indep.Rd` and `man/dep.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")'`
  passed with three expected INLA skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  `No problems found.`
- `rg -n 'worked Gaussian `latent\\(\\) \\+ unique\\(\\)` example|The decomposition mode pairs `latent \\+ unique`|\\*\\*Decomposition\\*\\* \\(`latent \\+ unique`\\)' NEWS.md R/brms-sugar.R man/indep.Rd man/dep.Rd`
  returned no hits.
- `git diff --check` passed.

## Definition-of-done notes

1. Implementation: prose/reference cleanup only; local on the active #489
   branch.
2. Simulation recovery: not applicable; no new likelihood, family, keyword, or
   estimator was added.
3. Documentation: roxygen and generated Rd were updated together.
4. Runnable example: no executable example changed; examples retain
   compatibility syntax only where explicitly labelled.
5. Check-log: appended in `docs/dev-log/check-log.md`.
6. Review pass: Rose/Boole wording and formula-surface consistency are the
   relevant lenses; no likelihood or parser implementation changed.

## Still guarded

- `unique()` remains compatibility syntax.
- Source-specific and kernel latent-Psi folds remain future work.
- Coevolution remains `COE-04 partial`.
- Bridge completion, release readiness, and scientific coverage are not
  claimed.
