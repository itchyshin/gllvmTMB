# After-task report: internal ordinary unique wording cleanup

Date: 2026-06-18
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This is a small internal consistency cleanup in the `unique()` deprecation lane.
It does not change parser behavior or model behavior.

## Changes

- `R/fit-multi.R`: the PGLLVM foot-gun detector comment now names
  `indep(0 + trait | species)` as the ordinary species-tier diagonal spelling,
  with legacy `unique()` / `diag` retained as compatibility/internal routing.
- `R/extract-sigma.R`: one internal error message now says
  "ordinary diagonal-compatibility random-regression" instead of "ordinary
  unique random-regression".

## Verification

- `parse("R/fit-multi.R"); parse("R/extract-sigma.R")` passed.
- `devtools::test(filter = "extract-sigma|ordinary-latent|canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")`
  passed with expected INLA/heavy skips.
- Focused stale scan showed the remaining hits are intentional augmented
  compatibility or source-specific `phylo_unique()` wording.
- `git diff --check` passed.

## Not claimed

- No `unique()` keyword removal.
- No source-specific/kernel latent-Psi fold.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
