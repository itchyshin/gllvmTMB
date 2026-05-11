# After Task: CI, Site, And Team Repair

## Goal

Implement the May 11 repair plan: copy drmTMB's CI discipline first,
make the pkgdown homepage reader-first, fix stale correlation-CI
wording, and turn Rose into a narrow pre-publish gate.

## Implemented

- `pkgdown` now runs via `workflow_run` after a successful
  `R-CMD-check` on `main` / `master`, with `workflow_dispatch`
  retained.
- `README.md` now follows the drmTMB landing-page pattern: purpose,
  Start here, preview status, install smoke test, tiny example,
  supported workflows, covariance grid, boundaries, and sister
  packages.
- `vignettes/gllvmTMB.Rmd` now describes
  `extract_correlations()` as using `method = "fisher-z"` by default.
- `R/extract-correlations.R` and `man/extract_correlations.Rd` now
  describe the actual four method names: `fisher-z`, `profile`,
  `wald`, and `bootstrap`.
- `.agents/skills/rose-pre-publish-audit/SKILL.md`, `AGENTS.md`, and
  `CONTRIBUTING.md` now define the narrow Rose pre-publish gate.
- The active Claude plan at
  `~/.claude/plans/please-have-a-robust-elephant.md` is now a short
  current plan plus backlog.

## Mathematical Contract

No likelihood, formula grammar, estimator, or public R API changed.
The only mathematical documentation change is the correction that
correlation CIs default to Fisher-z Wald intervals, with profile and
bootstrap as alternatives and `wald` as an alias.

## Files Changed

- `.github/workflows/pkgdown.yaml`
- `README.md`
- `vignettes/gllvmTMB.Rmd`
- `R/extract-correlations.R`
- `man/extract_correlations.Rd`
- `AGENTS.md`
- `CONTRIBUTING.md`
- `.agents/skills/rose-pre-publish-audit/SKILL.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/decisions.md`
- `~/.claude/plans/please-have-a-robust-elephant.md`

## Checks Run

- README smoke test with `devtools::load_all(quiet = TRUE)`: tiny fit
  converged with convergence 0; communality and Fisher-z correlations
  returned.
- `devtools::document(quiet = TRUE)`: passed and regenerated
  `man/extract_correlations.Rd`.
- `pkgdown::check_pkgdown()`: passed with `No problems found`.
- `pkgdown::build_home(preview = FALSE)` and
  `pkgdown::build_article("gllvmTMB", quiet = TRUE)`: rendered the
  homepage and Get Started article.
- `gh workflow list --repo itchyshin/gllvmTMB`: confirmed
  `R-CMD-check` and `pkgdown` workflows are registered.
- Rose stale-method sweep: no stale public claim remained in touched
  source or rendered homepage/article.

## Tests Of The Tests

The README smoke test executes the same fit shape shown on the new
homepage, then calls both `extract_communality()` and
`extract_correlations()`. The rendered article check verifies the
corrected `fisher-z` wording appears in generated HTML, not only in
the Rmd source.

## Consistency Audit

The public prose now routes users from purpose to start pages before
the 3 x 5 keyword grid. The CI policy in `AGENTS.md`,
`CONTRIBUTING.md`, and `.github/workflows/pkgdown.yaml` all say the
same thing: full 3-OS R-CMD-check remains, pkgdown follows green
main checks, and slow-test gating is not part of this repair.

## What Did Not Go Smoothly

Rendering `vignettes/gllvmTMB.Rmd` created an untracked
`vignettes/ord-1.png` because the vignette sets `fig.path = ""`.
That generated artifact was removed; the source change does not need
to track rendered figures.

## Team Learning

The useful transplant from drmTMB is discipline, not just YAML.
gllvmTMB has a larger model and test surface, so a runtime gap is
expected. The immediate team fix is narrower dispatch: Grace owns
CI/pkgdown, Rose owns cross-file consistency, Pat/Darwin own the
reader path, and Boole/Gauss/Noether are invoked only for syntax,
math, likelihood, or TMB changes.

## Known Limitations

R-CMD-check is still expected to take roughly 30-35 minutes on the
current full 3-OS surface. Fast-lane / slow-lane CI remains backlog
work.

## Next Actions

- After the next main push, confirm pkgdown starts only after the
  green R-CMD-check workflow_run event.
- Let the Claude/cloud team read `AGENTS.md`,
  `.agents/skills/rose-pre-publish-audit/SKILL.md`, and the short
  active plan before dispatching further work.
- Defer export-surface cleanup, weights unification, and slow-test
  gating until this feedback loop is stable.
